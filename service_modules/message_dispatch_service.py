"""
Message Dispatch Service - handles sending automated messages through various channels.
Supports: in_app, email (per-gym SMTP), whatsapp (wa.me links), push (FCM).
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
        data: dict = None,
        gym_id: str = None
    ) -> bool:
        """
        Send a message via the specified delivery method.
        Returns True if successful, False otherwise.
        """
        if delivery_method == "in_app":
            success = self.send_in_app(client_id, title, message, data)
            # Also try push notification as a bonus for in_app
            self._try_push(client_id, title, message, gym_id)
            return success
        elif delivery_method == "email":
            return self.send_email(client_id, subject or title, message, gym_id)
        elif delivery_method == "whatsapp":
            return self.send_whatsapp(client_id, message)
        elif delivery_method == "push":
            return self.send_push(client_id, title, message, gym_id)
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
        """Send an in-app notification using the existing NotificationService."""
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
        message: str,
        gym_id: str = None
    ) -> bool:
        """Send an email notification using the gym's SMTP config or global fallback."""
        from .email_service import get_email_service, get_email_service_for_gym

        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.id == client_id).first()
            if not user or not user.email:
                logger.warning(f"No email found for client {client_id}")
                return False

            # Try gym-specific SMTP config first
            email_service = None
            if gym_id:
                owner = db.query(UserORM).filter(UserORM.id == gym_id).first()
                if owner:
                    email_service = get_email_service_for_gym(owner)

            if not email_service or not email_service.is_configured():
                email_service = get_email_service()

            if not email_service.is_configured():
                logger.warning(f"SMTP not configured. Cannot send email to {user.email}")
                return False

            # Get gym name for branding
            gym_name = "FitOS"
            if gym_id:
                owner = db.query(UserORM).filter(UserORM.id == gym_id).first()
                if owner and owner.gym_name:
                    gym_name = owner.gym_name

            html_body = f"""
            <div style="max-width:480px;margin:0 auto;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#1a1a2e;border-radius:16px;overflow:hidden;border:1px solid rgba(255,255,255,0.1);">
                <div style="background:linear-gradient(135deg,#f97316,#ea580c);padding:24px;text-align:center;">
                    <h1 style="color:white;margin:0;font-size:24px;">{gym_name}</h1>
                </div>
                <div style="padding:32px 24px;">
                    <p style="color:#e5e7eb;font-size:16px;margin:0 0 16px;">{message}</p>
                </div>
                <div style="padding:16px 24px;border-top:1px solid rgba(255,255,255,0.05);">
                    <p style="color:#6b7280;font-size:12px;margin:0;text-align:center;">
                        Questa email è stata inviata automaticamente da {gym_name}.
                    </p>
                </div>
            </div>
            """

            success = email_service.send_email(user.email, subject, html_body)
            if success:
                logger.info(f"Email sent to {user.email}: {subject}")
            else:
                logger.warning(f"Failed to send email to {user.email}: {subject}")
            return success

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
        Generate a WhatsApp wa.me link and notify the owner to send it manually.
        Full automation requires WhatsApp Business API (future feature).
        """
        import re
        from urllib.parse import quote

        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.id == client_id).first()
            if not user:
                logger.warning(f"No user found for client {client_id}")
                return False

            phone = user.phone
            if not phone:
                logger.warning(f"No phone number for client {client_id}")
                return False

            # Clean phone number, default to Italian +39 prefix
            phone_clean = re.sub(r'[\s\-\(\)]', '', phone)
            if not phone_clean.startswith('+'):
                if phone_clean.startswith('0'):
                    phone_clean = '+39' + phone_clean[1:]
                else:
                    phone_clean = '+39' + phone_clean
            phone_for_link = phone_clean.lstrip('+')

            wa_link = f"https://wa.me/{phone_for_link}?text={quote(message)}"
            logger.info(f"WhatsApp link generated for {client_id}: {wa_link}")

            # Notify the gym owner with the link so they can click to send
            from models_orm import ClientProfileORM
            profile = db.query(ClientProfileORM).filter(
                ClientProfileORM.id == client_id
            ).first()

            if profile and profile.gym_id:
                notification_service = get_notification_service()
                notification_service.create_notification(
                    user_id=profile.gym_id,
                    notification_type="whatsapp_pending",
                    title=f"WhatsApp da inviare a {user.username}",
                    message=message[:100] + "..." if len(message) > 100 else message,
                    data={
                        "type": "whatsapp_link",
                        "whatsapp_link": wa_link,
                        "client_id": client_id,
                        "client_name": user.username,
                    }
                )

            return True

        except Exception as e:
            logger.error(f"Failed to generate WhatsApp link: {e}")
            return False
        finally:
            db.close()

    def send_push(
        self,
        client_id: str,
        title: str,
        message: str,
        gym_id: str = None
    ) -> bool:
        """Send a push notification via FCM v1 API (centralized, no per-gym config)."""
        from .notification_service import send_fcm_push

        db = get_db_session()
        try:
            send_fcm_push(db, client_id, title, message, {"type": "automated_message"})
            return True
        except Exception as e:
            logger.error(f"Failed to send push notification: {e}")
            return False
        finally:
            db.close()

    def _try_push(self, client_id: str, title: str, message: str, gym_id: str = None):
        """Best-effort push notification alongside in-app."""
        try:
            self.send_push(client_id, title, message, gym_id)
        except Exception as e:
            logger.warning("Push notification failed for client %s: %s", client_id, e)


# Singleton instance
message_dispatch_service = MessageDispatchService()


def get_message_dispatch_service() -> MessageDispatchService:
    """Dependency injection helper."""
    return message_dispatch_service
