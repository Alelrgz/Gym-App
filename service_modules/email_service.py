"""
Email Service - handles sending emails via SMTP.
"""
import smtplib
import ssl
import os
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

logger = logging.getLogger("gym_app")


class EmailService:
    """Service for sending transactional emails via SMTP."""

    def __init__(self):
        self.smtp_host = os.getenv("SMTP_HOST", "")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_user = os.getenv("SMTP_USER", "")
        self.smtp_password = os.getenv("SMTP_PASSWORD", "")
        self.from_email = os.getenv("SMTP_FROM_EMAIL", self.smtp_user)
        self.from_name = os.getenv("SMTP_FROM_NAME", "FitOS")

    def is_configured(self) -> bool:
        return bool(self.smtp_host and self.smtp_user and self.smtp_password)

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


# Singleton
_email_service = EmailService()

def get_email_service() -> EmailService:
    return _email_service
