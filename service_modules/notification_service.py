"""
Notification Service - handles creating and managing user notifications.
"""
from .base import (
    HTTPException, json, logging, datetime,
    get_db_session, NotificationORM, UserORM
)
from typing import List, Optional
import uuid

logger = logging.getLogger("gym_app")


def _get_fcm_access_token():
    """Get OAuth2 access token for FCM v1 API using service account credentials."""
    import os, time

    # Cache the token to avoid re-fetching on every push
    if hasattr(_get_fcm_access_token, '_cached'):
        token, expiry = _get_fcm_access_token._cached
        if time.time() < expiry - 60:  # Refresh 60s before expiry
            return token

    sa_json = os.environ.get("GOOGLE_SERVICE_ACCOUNT_JSON")
    if not sa_json:
        sa_path = os.environ.get("GOOGLE_SERVICE_ACCOUNT_PATH")
        if sa_path and os.path.exists(sa_path):
            with open(sa_path) as f:
                sa_json = f.read()

    if not sa_json:
        return None

    try:
        import json as _json, requests as _req
        from jose import jwt as _jose_jwt
        sa = _json.loads(sa_json, strict=False)
        now = int(time.time())
        claims = {
            "iss": sa["client_email"],
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud": "https://oauth2.googleapis.com/token",
            "iat": now,
            "exp": now + 3600,
        }
        signed_jwt = _jose_jwt.encode(claims, sa["private_key"], algorithm="RS256")
        resp = _req.post("https://oauth2.googleapis.com/token", data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": signed_jwt,
        }, timeout=10)
        if resp.status_code == 200:
            token_data = resp.json()
            access_token = token_data["access_token"]
            _get_fcm_access_token._cached = (access_token, now + token_data.get("expires_in", 3600))
            return access_token
        else:
            logger.error(f"FCM v1 token request failed {resp.status_code}: {resp.text[:200]}")
            return None
    except Exception as e:
        logger.error(f"FCM v1 token error: {e}")
        return None


def _get_fcm_project_id():
    """Get Firebase project ID from service account or env var."""
    import os, json as _json
    project_id = os.environ.get("FIREBASE_PROJECT_ID")
    if project_id:
        return project_id
    sa_json = os.environ.get("GOOGLE_SERVICE_ACCOUNT_JSON")
    if sa_json:
        try:
            return _json.loads(sa_json, strict=False).get("project_id")
        except Exception:
            pass
    return None


def send_fcm_push(db, user_id: str, title: str, body: str, data: dict = None):
    """Send push notification to a user's registered devices via FCM v1 API.

    Uses centralized FitOS service account — no per-gym configuration needed.
    Falls back to legacy API if service account not configured (for backward compat).
    """
    try:
        import requests as req
        from models_orm import FCMDeviceTokenORM

        tokens = db.query(FCMDeviceTokenORM).filter(
            FCMDeviceTokenORM.user_id == user_id
        ).all()
        if not tokens:
            return

        # Try FCM v1 first
        access_token = _get_fcm_access_token()
        project_id = _get_fcm_project_id()

        if access_token and project_id:
            _send_via_fcm_v1(db, tokens, title, body, data, access_token, project_id)
        else:
            # Fallback: try legacy per-gym server key (deprecated but may still work for some)
            _send_via_legacy_fcm(db, user_id, tokens, title, body, data)

    except Exception as e:
        logger.error(f"Push notification error: {e}")


def _send_via_fcm_v1(db, tokens, title, body, data, access_token, project_id):
    """Send via FCM HTTP v1 API (modern, OAuth2-based)."""
    import requests as req
    from models_orm import FCMDeviceTokenORM

    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    # Serialize data values to strings (FCM v1 requires string values in data)
    str_data = {}
    if data:
        for k, v in data.items():
            str_data[str(k)] = str(v) if v is not None else ""
    str_data["click_action"] = "FLUTTER_NOTIFICATION_CLICK"

    for device in tokens:
        try:
            payload = {
                "message": {
                    "token": device.token,
                    "notification": {
                        "title": title,
                        "body": body[:200],
                    },
                    "data": str_data,
                    "android": {
                        "notification": {"sound": "default"},
                    },
                    "apns": {
                        "payload": {
                            "aps": {"sound": "default", "badge": 1},
                        },
                    },
                }
            }
            resp = req.post(url, json=payload, headers=headers, timeout=10)
            if resp.status_code == 404 or (resp.status_code == 400 and "UNREGISTERED" in resp.text):
                db.query(FCMDeviceTokenORM).filter(
                    FCMDeviceTokenORM.token == device.token
                ).delete()
                db.commit()
            elif resp.status_code != 200:
                logger.warning(f"FCM v1 error {resp.status_code}: {resp.text[:200]}")
        except Exception as e:
            logger.error(f"FCM v1 push error for token {device.token[:20]}...: {e}")


def _send_via_legacy_fcm(db, user_id, tokens, title, body, data):
    """Fallback: send via legacy FCM API (deprecated, for backward compatibility)."""
    import requests as req
    from models_orm import FCMDeviceTokenORM

    user = db.query(UserORM).filter(UserORM.id == user_id).first()
    if not user:
        return

    server_key = getattr(user, 'fcm_server_key', None)
    if not server_key and user.gym_owner_id:
        owner = db.query(UserORM).filter(UserORM.id == user.gym_owner_id).first()
        if owner:
            server_key = getattr(owner, 'fcm_server_key', None)

    if not server_key:
        return

    for device in tokens:
        try:
            payload = {
                "to": device.token,
                "notification": {"title": title, "body": body[:200], "sound": "default"},
                "data": {**(data or {}), "click_action": "FLUTTER_NOTIFICATION_CLICK"},
            }
            resp = req.post(
                "https://fcm.googleapis.com/fcm/send",
                json=payload,
                headers={"Authorization": f"key={server_key}", "Content-Type": "application/json"},
                timeout=10,
            )
            if resp.status_code == 200:
                result = resp.json()
                if result.get("failure", 0) > 0:
                    for r in result.get("results", []):
                        if r.get("error") in ("NotRegistered", "InvalidRegistration"):
                            db.query(FCMDeviceTokenORM).filter(FCMDeviceTokenORM.token == device.token).delete()
                            db.commit()
        except Exception as e:
            logger.error(f"Legacy FCM push error for token {device.token[:20]}...: {e}")


class NotificationService:
    """Service for managing user notifications."""

    def create_notification(
        self,
        user_id: str,
        notification_type: str,
        title: str,
        message: str,
        data: dict = None
    ) -> dict:
        """Create a notification for a user."""
        db = get_db_session()
        try:
            notification = NotificationORM(
                user_id=user_id,
                type=notification_type,
                title=title,
                message=message,
                data=json.dumps(data) if data else None,
                read=False,
                created_at=datetime.utcnow().isoformat()
            )
            db.add(notification)
            db.commit()
            db.refresh(notification)

            logger.info(f"Created notification for user {user_id}: {title}")

            return {
                "id": notification.id,
                "user_id": notification.user_id,
                "type": notification.type,
                "title": notification.title,
                "message": notification.message,
                "read": notification.read,
                "created_at": notification.created_at
            }

        except Exception as e:
            db.rollback()
            logger.error(f"Error creating notification: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create notification: {str(e)}")
        finally:
            db.close()

    def get_user_notifications(self, user_id: str, unread_only: bool = False, limit: int = 50) -> List[dict]:
        """Get notifications for a user."""
        db = get_db_session()
        try:
            query = db.query(NotificationORM).filter(
                NotificationORM.user_id == user_id
            )

            if unread_only:
                query = query.filter(NotificationORM.read == False)

            notifications = query.order_by(
                NotificationORM.created_at.desc()
            ).limit(limit).all()

            return [
                {
                    "id": n.id,
                    "type": n.type,
                    "title": n.title,
                    "message": n.message,
                    "data": json.loads(n.data) if n.data else None,
                    "read": n.read,
                    "created_at": n.created_at
                }
                for n in notifications
            ]

        finally:
            db.close()

    def get_unread_count(self, user_id: str) -> int:
        """Get count of unread notifications for a user."""
        db = get_db_session()
        try:
            count = db.query(NotificationORM).filter(
                NotificationORM.user_id == user_id,
                NotificationORM.read == False
            ).count()
            return count
        finally:
            db.close()

    def mark_as_read(self, notification_id: int, user_id: str) -> dict:
        """Mark a notification as read."""
        db = get_db_session()
        try:
            notification = db.query(NotificationORM).filter(
                NotificationORM.id == notification_id,
                NotificationORM.user_id == user_id
            ).first()

            if not notification:
                raise HTTPException(status_code=404, detail="Notification not found")

            notification.read = True
            db.commit()

            return {"status": "success", "message": "Notification marked as read"}

        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error marking notification as read: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to mark notification: {str(e)}")
        finally:
            db.close()

    def mark_all_as_read(self, user_id: str) -> dict:
        """Mark all notifications as read for a user."""
        db = get_db_session()
        try:
            db.query(NotificationORM).filter(
                NotificationORM.user_id == user_id,
                NotificationORM.read == False
            ).update({"read": True})
            db.commit()

            return {"status": "success", "message": "All notifications marked as read"}

        except Exception as e:
            db.rollback()
            logger.error(f"Error marking all notifications as read: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to mark notifications: {str(e)}")
        finally:
            db.close()

    def delete_notification(self, notification_id: int, user_id: str) -> dict:
        """Delete a notification."""
        db = get_db_session()
        try:
            notification = db.query(NotificationORM).filter(
                NotificationORM.id == notification_id,
                NotificationORM.user_id == user_id
            ).first()

            if not notification:
                raise HTTPException(status_code=404, detail="Notification not found")

            db.delete(notification)
            db.commit()

            return {"status": "success", "message": "Notification deleted"}

        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error deleting notification: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to delete notification: {str(e)}")
        finally:
            db.close()


# Singleton instance
notification_service = NotificationService()


# ── SQLAlchemy event: auto-send FCM push on every new notification ──
from sqlalchemy import event

@event.listens_for(NotificationORM, "after_insert")
def _auto_fcm_on_notification(mapper, connection, target):
    """Automatically send an FCM push whenever a NotificationORM row is inserted."""
    try:
        # Parse data JSON if present
        data = None
        if target.data:
            try:
                data = json.loads(target.data) if isinstance(target.data, str) else target.data
            except Exception as e:
                logger.warning("Failed to parse notification data JSON: %s", e)
                data = None

        # Use a fresh session (connection is low-level, we need ORM queries)
        db = get_db_session()
        try:
            send_fcm_push(db, target.user_id, target.title or "", target.message or "", data)
        finally:
            db.close()
    except Exception as e:
        logger.error(f"Auto FCM push error: {e}")


def get_notification_service() -> NotificationService:
    """Dependency injection helper."""
    return notification_service
