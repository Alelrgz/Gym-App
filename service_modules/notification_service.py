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


def send_fcm_push(db, user_id: str, title: str, body: str, data: dict = None):
    """Send an FCM push notification to a user's registered devices.

    Resolves the gym's FCM server key automatically from the user's gym_owner_id.
    Can be called with an existing db session (e.g. from inline notification creation).
    """
    try:
        import requests as req
        from models_orm import FCMDeviceTokenORM

        # Find the user to get their gym owner
        user = db.query(UserORM).filter(UserORM.id == user_id).first()
        if not user:
            return

        # Resolve FCM server key: check user themselves (if owner), then their gym owner
        server_key = getattr(user, 'fcm_server_key', None)
        if not server_key and user.gym_owner_id:
            owner = db.query(UserORM).filter(UserORM.id == user.gym_owner_id).first()
            if owner:
                server_key = getattr(owner, 'fcm_server_key', None)

        if not server_key:
            return

        # Get device tokens for this user
        tokens = db.query(FCMDeviceTokenORM).filter(
            FCMDeviceTokenORM.user_id == user_id
        ).all()
        if not tokens:
            return

        for device in tokens:
            try:
                payload = {
                    "to": device.token,
                    "notification": {
                        "title": title,
                        "body": body[:200],
                        "sound": "default",
                    },
                    "data": {
                        **(data or {}),
                        "click_action": "FLUTTER_NOTIFICATION_CLICK",
                    },
                }
                resp = req.post(
                    "https://fcm.googleapis.com/fcm/send",
                    json=payload,
                    headers={
                        "Authorization": f"key={server_key}",
                        "Content-Type": "application/json",
                    },
                    timeout=10,
                )
                if resp.status_code == 200:
                    result = resp.json()
                    if result.get("failure", 0) > 0:
                        for r in result.get("results", []):
                            if r.get("error") in ("NotRegistered", "InvalidRegistration"):
                                db.query(FCMDeviceTokenORM).filter(
                                    FCMDeviceTokenORM.token == device.token
                                ).delete()
                                db.commit()
            except Exception as e:
                logger.error(f"FCM push error for token {device.token[:20]}...: {e}")
    except Exception as e:
        logger.error(f"FCM push setup error: {e}")


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
            except Exception:
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
