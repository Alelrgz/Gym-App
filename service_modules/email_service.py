"""
Email Service - handles sending emails via SMTP.
Supports: global env-var config, per-gym SMTP credentials, and OAuth2 XOAUTH2.
"""
import smtplib
import ssl
import os
import base64
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta

logger = logging.getLogger("gym_app")


class EmailService:
    """Service for sending transactional emails via SMTP."""

    def __init__(self, smtp_host=None, smtp_port=None, smtp_user=None,
                 smtp_password=None, from_email=None, from_name=None,
                 oauth_provider=None, oauth_access_token=None,
                 oauth_refresh_token=None, oauth_token_expiry=None,
                 owner_orm=None):
        self.smtp_host = smtp_host or os.getenv("SMTP_HOST", "")
        self.smtp_port = smtp_port or int(os.getenv("SMTP_PORT", "587"))
        self.smtp_user = smtp_user or os.getenv("SMTP_USER", "")
        self.smtp_password = smtp_password or os.getenv("SMTP_PASSWORD", "")
        self.from_email = from_email or os.getenv("SMTP_FROM_EMAIL", self.smtp_user)
        self.from_name = from_name or os.getenv("SMTP_FROM_NAME", "FitOS")

        # OAuth2 fields
        self.oauth_provider = oauth_provider
        self.oauth_access_token = oauth_access_token
        self.oauth_refresh_token = oauth_refresh_token
        self.oauth_token_expiry = oauth_token_expiry
        self._owner_orm = owner_orm  # For persisting refreshed tokens

    def is_configured(self) -> bool:
        if self.oauth_provider and self.oauth_refresh_token:
            return bool(self.smtp_host and self.smtp_user)
        return bool(self.smtp_host and self.smtp_user and self.smtp_password)

    def _is_token_expired(self) -> bool:
        if not self.oauth_token_expiry:
            return True
        try:
            expiry = datetime.fromisoformat(self.oauth_token_expiry)
            return datetime.utcnow() >= expiry
        except (ValueError, TypeError):
            return True

    def _refresh_oauth_token(self) -> bool:
        """Refresh the OAuth access token if expired."""
        if not self.oauth_provider or not self.oauth_refresh_token:
            return False

        from route_modules.smtp_oauth_routes import refresh_oauth_token

        result = refresh_oauth_token(self.oauth_provider, self.oauth_refresh_token)
        if not result or "access_token" not in result:
            logger.error(f"Failed to refresh OAuth token for {self.oauth_provider}")
            return False

        self.oauth_access_token = result["access_token"]
        expires_in = result.get("expires_in", 3600)
        self.oauth_token_expiry = (datetime.utcnow() + timedelta(seconds=int(expires_in))).isoformat()

        if result.get("refresh_token"):
            self.oauth_refresh_token = result["refresh_token"]

        # Persist refreshed tokens to DB
        if self._owner_orm:
            try:
                from service_modules.base import get_db_session
                db = get_db_session()
                try:
                    self._owner_orm.smtp_oauth_access_token = self.oauth_access_token
                    self._owner_orm.smtp_oauth_token_expiry = self.oauth_token_expiry
                    if result.get("refresh_token"):
                        self._owner_orm.smtp_oauth_refresh_token = self.oauth_refresh_token
                    db.merge(self._owner_orm)
                    db.commit()
                except Exception as e:
                    logger.warning("Failed to commit refreshed OAuth token to DB: %s", e)
                    db.rollback()
                finally:
                    db.close()
            except Exception as e:
                logger.warning(f"Failed to persist refreshed OAuth token: {e}")

        return True

    def _xoauth2_string(self) -> str:
        """Build the XOAUTH2 auth string for SMTP."""
        auth = f"user={self.smtp_user}\x01auth=Bearer {self.oauth_access_token}\x01\x01"
        return base64.b64encode(auth.encode()).decode()

    def send_email(self, to_email: str, subject: str, html_body: str) -> bool:
        if not self.is_configured():
            logger.warning("SMTP not configured, cannot send email")
            return False

        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = f"{self.from_name} <{self.from_email}>"
            msg["To"] = to_email

            # Plain text fallback
            text_body = html_body.replace("<br>", "\n").replace("</p>", "\n")
            import re
            text_body = re.sub(r"<[^>]+>", "", text_body)

            msg.attach(MIMEText(text_body, "plain"))
            msg.attach(MIMEText(html_body, "html"))

            context = ssl.create_default_context()

            if self.oauth_provider and self.oauth_refresh_token:
                # OAuth2 XOAUTH2 authentication
                if self._is_token_expired():
                    if not self._refresh_oauth_token():
                        logger.error("OAuth token refresh failed, cannot send email")
                        return False

                with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                    server.starttls(context=context)
                    server.docmd('AUTH', 'XOAUTH2 ' + self._xoauth2_string())
                    server.sendmail(self.from_email, to_email, msg.as_string())
            else:
                # Standard password authentication
                with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                    server.starttls(context=context)
                    server.login(self.smtp_user, self.smtp_password)
                    server.sendmail(self.from_email, to_email, msg.as_string())

            logger.info(f"Email sent to {to_email}: {subject}")
            return True
        except Exception as e:
            logger.error(f"Failed to send email to {to_email}: {e}")
            return False

    def send_password_reset_email(self, to_email: str, username: str, reset_url: str) -> bool:
        subject = "FitOS - Reset Your Password"
        html = f"""
        <div style="max-width:480px;margin:0 auto;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#1a1a2e;border-radius:16px;overflow:hidden;border:1px solid rgba(255,255,255,0.1);">
            <div style="background:linear-gradient(135deg,#f97316,#ea580c);padding:24px;text-align:center;">
                <h1 style="color:white;margin:0;font-size:24px;">FitOS</h1>
            </div>
            <div style="padding:32px 24px;">
                <p style="color:#e5e7eb;font-size:16px;margin:0 0 16px;">Hi <strong style="color:white;">{username}</strong>,</p>
                <p style="color:#9ca3af;font-size:14px;margin:0 0 24px;">
                    We received a request to reset your password. Click the button below to create a new password.
                </p>
                <div style="text-align:center;margin:24px 0;">
                    <a href="{reset_url}" style="display:inline-block;background:linear-gradient(135deg,#f97316,#ea580c);color:white;text-decoration:none;padding:14px 32px;border-radius:12px;font-weight:600;font-size:16px;">
                        Reset Password
                    </a>
                </div>
                <p style="color:#6b7280;font-size:12px;margin:24px 0 0;text-align:center;">
                    This link expires in 1 hour. If you didn't request this, you can safely ignore this email.
                </p>
            </div>
        </div>
        """
        return self.send_email(to_email, subject, html)

    def send_username_reminder_email(self, to_email: str, username: str) -> bool:
        subject = "FitOS - Your Username"
        html = f"""
        <div style="max-width:480px;margin:0 auto;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#1a1a2e;border-radius:16px;overflow:hidden;border:1px solid rgba(255,255,255,0.1);">
            <div style="background:linear-gradient(135deg,#f97316,#ea580c);padding:24px;text-align:center;">
                <h1 style="color:white;margin:0;font-size:24px;">FitOS</h1>
            </div>
            <div style="padding:32px 24px;">
                <p style="color:#e5e7eb;font-size:16px;margin:0 0 16px;">Hi there,</p>
                <p style="color:#9ca3af;font-size:14px;margin:0 0 24px;">
                    You requested a reminder of your username. Here it is:
                </p>
                <div style="text-align:center;margin:24px 0;background:rgba(249,115,22,0.1);border:1px solid rgba(249,115,22,0.3);border-radius:12px;padding:16px;">
                    <p style="color:#fb923c;font-size:12px;margin:0 0 4px;text-transform:uppercase;letter-spacing:1px;">Your Username</p>
                    <p style="color:white;font-size:24px;font-weight:700;margin:0;">{username}</p>
                </div>
                <div style="text-align:center;margin:24px 0;">
                    <a href="{{{{ login_url }}}}" style="color:#f97316;text-decoration:none;font-weight:600;font-size:14px;">
                        Go to Login →
                    </a>
                </div>
                <p style="color:#6b7280;font-size:12px;margin:24px 0 0;text-align:center;">
                    If you didn't request this, you can safely ignore this email.
                </p>
            </div>
        </div>
        """
        return self.send_email(to_email, subject, html)


def get_email_service_for_gym(gym_owner) -> 'EmailService':
    """Get an EmailService configured with the gym owner's SMTP settings."""
    # Check OAuth first
    if gym_owner and gym_owner.smtp_oauth_provider and gym_owner.smtp_oauth_refresh_token:
        return EmailService(
            smtp_host=gym_owner.smtp_host,
            smtp_port=gym_owner.smtp_port or 587,
            smtp_user=gym_owner.smtp_user,
            from_email=gym_owner.smtp_from_email or gym_owner.smtp_user,
            from_name=gym_owner.smtp_from_name or gym_owner.gym_name or "FitOS",
            oauth_provider=gym_owner.smtp_oauth_provider,
            oauth_access_token=gym_owner.smtp_oauth_access_token,
            oauth_refresh_token=gym_owner.smtp_oauth_refresh_token,
            oauth_token_expiry=gym_owner.smtp_oauth_token_expiry,
            owner_orm=gym_owner,
        )

    # Standard password-based SMTP
    if gym_owner and gym_owner.smtp_host and gym_owner.smtp_user and gym_owner.smtp_password:
        return EmailService(
            smtp_host=gym_owner.smtp_host,
            smtp_port=gym_owner.smtp_port or 587,
            smtp_user=gym_owner.smtp_user,
            smtp_password=gym_owner.smtp_password,
            from_email=gym_owner.smtp_from_email or gym_owner.smtp_user,
            from_name=gym_owner.smtp_from_name or gym_owner.gym_name or "FitOS",
        )

    # Fall back to global env config
    return _email_service


# Singleton (global env config fallback)
_email_service = EmailService()

def get_email_service() -> EmailService:
    return _email_service
