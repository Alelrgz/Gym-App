"""
Password Reset Service - handles token generation, validation, and password/username recovery.
"""
import uuid
import secrets
import logging
import bcrypt
from datetime import datetime, timedelta

from database import get_db_session
from models_orm import UserORM, PasswordResetTokenORM
from .email_service import get_email_service

logger = logging.getLogger("gym_app")

TOKEN_EXPIRY_HOURS = 1


def _hash_token(token: str) -> str:
    return bcrypt.hashpw(token.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def _verify_token(plain_token: str, hashed_token: str) -> bool:
    return bcrypt.checkpw(plain_token.encode("utf-8"), hashed_token.encode("utf-8"))


def request_password_reset(email: str, base_url: str) -> dict:
    """Create a password reset token and send email. Always returns success to prevent email enumeration."""
    db = get_db_session()
    try:
        user = db.query(UserORM).filter(UserORM.email == email).first()
        if not user:
            return {"status": "success", "message": "If an account exists with that email, we've sent a reset link."}

        # Generate token
        raw_token = secrets.token_urlsafe(32)
        token_record = PasswordResetTokenORM(
            id=str(uuid.uuid4()),
            user_id=user.id,
            token_hash=_hash_token(raw_token),
            token_type="password_reset",
            expires_at=(datetime.utcnow() + timedelta(hours=TOKEN_EXPIRY_HOURS)).isoformat(),
        )
        db.add(token_record)
        db.commit()

        # Send email
        reset_url = f"{base_url}/auth/reset-password?token={raw_token}"
        email_service = get_email_service()
        if email_service.is_configured():
            email_service.send_password_reset_email(user.email, user.username, reset_url)
        else:
            logger.warning("SMTP not configured — password reset email not sent")

        return {"status": "success", "message": "If an account exists with that email, we've sent a reset link."}
    except Exception as e:
        logger.error(f"Password reset request error: {e}")
        return {"status": "success", "message": "If an account exists with that email, we've sent a reset link."}
    finally:
        db.close()


def request_username_reminder(email: str) -> dict:
    """Send username reminder via email. Always returns success to prevent email enumeration."""
    db = get_db_session()
    try:
        user = db.query(UserORM).filter(UserORM.email == email).first()
        if not user:
            return {"status": "success", "message": "If an account exists with that email, we've sent your username."}

        email_service = get_email_service()
        if email_service.is_configured():
            email_service.send_username_reminder_email(user.email, user.username)
        else:
            logger.warning("SMTP not configured — username reminder email not sent")

        return {"status": "success", "message": "If an account exists with that email, we've sent your username."}
    except Exception as e:
        logger.error(f"Username reminder error: {e}")
        return {"status": "success", "message": "If an account exists with that email, we've sent your username."}
    finally:
        db.close()


def validate_reset_token(raw_token: str):
    """Validate a reset token. Returns the user if valid, None otherwise."""
    db = get_db_session()
    try:
        # Find all unused, non-expired tokens
        now = datetime.utcnow().isoformat()
        tokens = db.query(PasswordResetTokenORM).filter(
            PasswordResetTokenORM.token_type == "password_reset",
            PasswordResetTokenORM.used_at.is_(None),
            PasswordResetTokenORM.expires_at > now,
        ).all()

        for token_record in tokens:
            if _verify_token(raw_token, token_record.token_hash):
                user = db.query(UserORM).filter(UserORM.id == token_record.user_id).first()
                return user
        return None
    except Exception as e:
        logger.error(f"Token validation error: {e}")
        return None
    finally:
        db.close()


def reset_password(raw_token: str, new_password: str) -> dict:
    """Validate token and set new password. Mark token as used."""
    db = get_db_session()
    try:
        now = datetime.utcnow().isoformat()
        tokens = db.query(PasswordResetTokenORM).filter(
            PasswordResetTokenORM.token_type == "password_reset",
            PasswordResetTokenORM.used_at.is_(None),
            PasswordResetTokenORM.expires_at > now,
        ).all()

        matched_token = None
        for token_record in tokens:
            if _verify_token(raw_token, token_record.token_hash):
                matched_token = token_record
                break

        if not matched_token:
            return {"status": "error", "message": "Invalid or expired reset link. Please request a new one."}

        user = db.query(UserORM).filter(UserORM.id == matched_token.user_id).first()
        if not user:
            return {"status": "error", "message": "Account not found."}

        # Update password
        hashed = bcrypt.hashpw(new_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        user.hashed_password = hashed
        user.must_change_password = False

        # Mark token as used
        matched_token.used_at = datetime.utcnow().isoformat()
        db.commit()

        logger.info(f"Password reset completed for user {user.id}")
        return {"status": "success", "message": "Password reset successfully. You can now log in."}
    except Exception as e:
        logger.error(f"Password reset error: {e}")
        db.rollback()
        return {"status": "error", "message": "An error occurred. Please try again."}
    finally:
        db.close()


def staff_reset_password(staff_user, member_id: str) -> dict:
    """Staff resets a member's password. Returns temporary password."""
    db = get_db_session()
    try:
        member = db.query(UserORM).filter(UserORM.id == member_id).first()
        if not member:
            return {"status": "error", "message": "Member not found."}

        # Verify same gym
        staff_gym = staff_user.gym_owner_id if staff_user.role == "staff" else staff_user.id
        member_gym = member.gym_owner_id or member.id
        if staff_gym != member_gym and staff_user.role != "owner":
            return {"status": "error", "message": "Member does not belong to your gym."}

        # Generate temporary password
        temp_password = secrets.token_urlsafe(16)
        hashed = bcrypt.hashpw(temp_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        member.hashed_password = hashed
        member.must_change_password = True
        db.commit()

        logger.info(f"Staff {staff_user.id} reset password for member {member_id}")
        return {
            "status": "success",
            "temporary_password": temp_password,
            "message": "Password reset. Client must change it on first login.",
        }
    except Exception as e:
        logger.error(f"Staff password reset error: {e}")
        db.rollback()
        return {"status": "error", "message": "An error occurred."}
    finally:
        db.close()


def staff_change_username(staff_user, member_id: str, new_username: str) -> dict:
    """Staff changes a member's username."""
    db = get_db_session()
    try:
        member = db.query(UserORM).filter(UserORM.id == member_id).first()
        if not member:
            return {"status": "error", "message": "Member not found."}

        # Verify same gym
        staff_gym = staff_user.gym_owner_id if staff_user.role == "staff" else staff_user.id
        member_gym = member.gym_owner_id or member.id
        if staff_gym != member_gym and staff_user.role != "owner":
            return {"status": "error", "message": "Member does not belong to your gym."}

        # Validate username
        if not new_username or len(new_username) < 3:
            return {"status": "error", "message": "Username must be at least 3 characters."}

        # Check uniqueness
        existing = db.query(UserORM).filter(UserORM.username == new_username, UserORM.id != member_id).first()
        if existing:
            return {"status": "error", "message": "Username already taken."}

        old_username = member.username
        member.username = new_username
        db.commit()

        logger.info(f"Staff {staff_user.id} changed username for {member_id}: {old_username} → {new_username}")
        return {"status": "success", "message": f"Username changed to '{new_username}'."}
    except Exception as e:
        logger.error(f"Staff username change error: {e}")
        db.rollback()
        return {"status": "error", "message": "An error occurred."}
    finally:
        db.close()
