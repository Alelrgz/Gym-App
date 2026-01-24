"""
Notification Service - handles creating and managing user notifications.
"""
from .base import (
    HTTPException, json, logging, datetime,
    get_db_session, NotificationORM
)
from typing import List, Optional
import uuid

logger = logging.getLogger("gym_app")


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


def get_notification_service() -> NotificationService:
    """Dependency injection helper."""
    return notification_service
