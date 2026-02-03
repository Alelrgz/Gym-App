"""
Message Dispatch Service - handles sending automated messages through various channels.
"""
from .base import (
    HTTPException, json, logging, datetime,
    get_db_session, UserORM
)
from .notification_service import get_notification_service
from typing import Optional

logger = logging.getLogger("gym_app")


class MessageDispatchService:
    """Service for dispatching automated messages through different delivery channels."""

    def send_message(
        self,
        client_id: str,
        delivery_method: str,
        title: str,
        message: str,
        subject: str = None,
        data: dict = None
    ) -> bool:
        """
        Send a message via the specified delivery method.
        Returns True if successful, False otherwise.
        """
        if delivery_method == "in_app":
            return self.send_in_app(client_id, title, message, data)
        elif delivery_method == "email":
            return self.send_email(client_id, subject or title, message)
        elif delivery_method == "whatsapp":
            return self.send_whatsapp(client_id, message)
        else:
            logger.warning(f"Unknown delivery method: {delivery_method}")
            return False

    def send_in_app(
        self,
        client_id: str,
        title: str,
        message: str,
        data: dict = None
    ) -> bool:
        """
        Send an in-app notification using the existing NotificationService.
        """
        try:
            notification_service = get_notification_service()

            notification_data = data or {}
            notification_data["type"] = "automated_message"

            notification_service.create_notification(
                user_id=client_id,
                notification_type="automated_message",
                title=title,
                message=message,
                data=notification_data
            )

            logger.info(f"Sent in-app notification to {client_id}: {title}")
            return True

        except Exception as e:
            logger.error(f"Failed to send in-app notification: {e}")
            return False

    def send_email(
        self,
        client_id: str,
        subject: str,
        message: str
    ) -> bool:
        """
        Send an email notification.
        NOTE: This is a placeholder - email service not yet implemented.
        """
        db = get_db_session()
        try:
            # Get client's email
            user = db.query(UserORM).filter(UserORM.id == client_id).first()
            if not user or not user.email:
                logger.warning(f"No email found for client {client_id}")
                return False

            # TODO: Implement actual email sending
            # This would integrate with SendGrid, Mailgun, AWS SES, etc.
            logger.warning(f"Email delivery not implemented. Would send to {user.email}: {subject}")

            # For now, return False to indicate not sent
            # When implemented, return True on success
            return False

        except Exception as e:
            logger.error(f"Failed to send email: {e}")
            return False
        finally:
            db.close()

    def send_whatsapp(
        self,
        client_id: str,
        message: str
    ) -> bool:
        """
        Send a WhatsApp notification.
        NOTE: This is a placeholder - WhatsApp integration not yet implemented.
        """
        db = get_db_session()
        try:
            # Get client's phone number
            user = db.query(UserORM).filter(UserORM.id == client_id).first()
            if not user:
                logger.warning(f"No user found for client {client_id}")
                return False

            # TODO: Get phone number from profile
            # TODO: Implement actual WhatsApp sending via Twilio or WhatsApp Business API
            logger.warning(f"WhatsApp delivery not implemented. Would send to client {client_id}")

            # For now, return False to indicate not sent
            # When implemented, return True on success
            return False

        except Exception as e:
            logger.error(f"Failed to send WhatsApp: {e}")
            return False
        finally:
            db.close()


# Singleton instance
message_dispatch_service = MessageDispatchService()


def get_message_dispatch_service() -> MessageDispatchService:
    """Dependency injection helper."""
    return message_dispatch_service
