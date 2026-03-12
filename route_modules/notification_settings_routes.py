"""
Notification Settings Routes - SMTP email config, FCM push notification tokens.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from auth import get_current_user
from models_orm import UserORM, FCMDeviceTokenORM
from datetime import datetime
import logging

logger = logging.getLogger("gym_app")

router = APIRouter()


# ═══════════════════════════════════════════════════════════
#  SMTP EMAIL SETTINGS
# ═══════════════════════════════════════════════════════════

@router.get("/api/owner/smtp-settings")
async def get_smtp_settings(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get SMTP email configuration for this gym."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    oauth_connected = bool(user.smtp_oauth_provider and user.smtp_oauth_refresh_token)
    is_configured = oauth_connected or bool(user.smtp_host and user.smtp_user and user.smtp_password)

    return {
        "smtp_host": user.smtp_host or "",
        "smtp_port": user.smtp_port or 587,
        "smtp_user": user.smtp_user or "",
        "smtp_password_set": bool(user.smtp_password),
        "smtp_from_email": user.smtp_from_email or "",
        "smtp_from_name": user.smtp_from_name or user.gym_name or "FitOS",
        "is_configured": is_configured,
        "oauth_provider": user.smtp_oauth_provider,
        "oauth_connected": oauth_connected,
    }


@router.put("/api/owner/smtp-settings")
async def update_smtp_settings(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update SMTP email configuration."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    if "smtp_host" in data:
        user.smtp_host = data["smtp_host"].strip() or None
    if "smtp_port" in data:
        user.smtp_port = int(data["smtp_port"]) if data["smtp_port"] else 587
    if "smtp_user" in data:
        user.smtp_user = data["smtp_user"].strip() or None
    if "smtp_password" in data and data["smtp_password"]:
        user.smtp_password = data["smtp_password"]
    if "smtp_from_email" in data:
        user.smtp_from_email = data["smtp_from_email"].strip() or None
    if "smtp_from_name" in data:
        user.smtp_from_name = data["smtp_from_name"].strip() or None

    db.commit()

    return {
        "status": "success",
        "is_configured": bool(user.smtp_host and user.smtp_user and user.smtp_password),
    }


@router.post("/api/owner/smtp-settings/test")
async def test_smtp_settings(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Send a test email to verify SMTP configuration."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    if not (user.smtp_host and user.smtp_user and user.smtp_password):
        raise HTTPException(status_code=400, detail="SMTP non configurato")

    from service_modules.email_service import EmailService

    test_service = EmailService(
        smtp_host=user.smtp_host,
        smtp_port=user.smtp_port or 587,
        smtp_user=user.smtp_user,
        smtp_password=user.smtp_password,
        from_email=user.smtp_from_email or user.smtp_user,
        from_name=user.smtp_from_name or user.gym_name or "FitOS",
    )

    to_email = user.smtp_from_email or user.smtp_user or user.email
    success = test_service.send_email(
        to_email,
        "FitOS - Test Email",
        """
        <div style="max-width:480px;margin:0 auto;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#1a1a2e;border-radius:16px;overflow:hidden;border:1px solid rgba(255,255,255,0.1);">
            <div style="background:linear-gradient(135deg,#f97316,#ea580c);padding:24px;text-align:center;">
                <h1 style="color:white;margin:0;font-size:24px;">FitOS</h1>
            </div>
            <div style="padding:32px 24px;text-align:center;">
                <div style="font-size:48px;margin-bottom:16px;">&#9989;</div>
                <p style="color:#4ade80;font-size:18px;font-weight:700;margin:0 0 8px;">Configurazione Riuscita!</p>
                <p style="color:#9ca3af;font-size:14px;margin:0;">Le tue email automatiche funzioneranno correttamente.</p>
            </div>
        </div>
        """
    )

    if success:
        return {"status": "success", "message": f"Email di test inviata a {to_email}"}
    else:
        raise HTTPException(status_code=500, detail="Invio fallito. Controlla le credenziali SMTP.")


# ═══════════════════════════════════════════════════════════
#  FCM PUSH NOTIFICATION SETTINGS
# ═══════════════════════════════════════════════════════════

@router.get("/api/owner/fcm-settings")
async def get_fcm_settings(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get Firebase Cloud Messaging configuration."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    return {
        "fcm_server_key_set": bool(user.fcm_server_key),
        "is_configured": bool(user.fcm_server_key),
    }


@router.put("/api/owner/fcm-settings")
async def update_fcm_settings(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update Firebase Cloud Messaging server key."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    if "fcm_server_key" in data:
        user.fcm_server_key = data["fcm_server_key"].strip() or None

    db.commit()

    return {
        "status": "success",
        "is_configured": bool(user.fcm_server_key),
    }


# ═══════════════════════════════════════════════════════════
#  FCM DEVICE TOKEN REGISTRATION (for any authenticated user)
# ═══════════════════════════════════════════════════════════

@router.post("/api/notifications/register-device")
async def register_device_token(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Register or update FCM device token for push notifications."""
    token = data.get("token", "").strip()
    platform = data.get("platform", "unknown")  # ios, android, web

    if not token:
        raise HTTPException(status_code=400, detail="Token is required")

    # Check if token already exists
    existing = db.query(FCMDeviceTokenORM).filter(FCMDeviceTokenORM.token == token).first()

    if existing:
        # Update ownership if device changed user
        existing.user_id = user.id
        existing.platform = platform
        existing.updated_at = datetime.utcnow().isoformat()
    else:
        new_token = FCMDeviceTokenORM(
            user_id=user.id,
            token=token,
            platform=platform,
        )
        db.add(new_token)

    db.commit()
    return {"status": "success"}


@router.delete("/api/notifications/unregister-device")
async def unregister_device_token(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Remove FCM device token (e.g., on logout)."""
    token = data.get("token", "").strip()
    if token:
        db.query(FCMDeviceTokenORM).filter(
            FCMDeviceTokenORM.token == token,
            FCMDeviceTokenORM.user_id == user.id,
        ).delete()
        db.commit()

    return {"status": "success"}
