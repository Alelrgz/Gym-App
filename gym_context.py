"""
Gym Context Resolution - determines which gym the current request targets.
Supports multi-gym owners via X-Gym-Id header.
"""
from fastapi import Depends, Header, HTTPException
from typing import Optional
from auth import get_current_user
from database import get_db_session
from models_orm import GymORM, UserORM, ClientProfileORM
import logging

logger = logging.getLogger("gym_app")


def resolve_gym_id(user: UserORM, x_gym_id: Optional[str] = None) -> str:
    """
    Resolve which gym the current request targets.

    For owners: uses X-Gym-Id header if provided, otherwise defaults to first gym.
    For staff/trainers: uses their gym_owner_id (which equals the gym.id for migrated data).
    For clients: uses their profile's gym_id.

    Returns the gym ID string.
    """
    if user.role == "owner":
        db = get_db_session()
        try:
            if x_gym_id:
                # Verify owner actually owns this gym
                gym = db.query(GymORM).filter(
                    GymORM.id == x_gym_id,
                    GymORM.owner_id == user.id,
                    GymORM.is_active == True
                ).first()
                if not gym:
                    raise HTTPException(status_code=403, detail="You don't own this gym")
                return gym.id
            else:
                # Default to first active gym (backward compat: gym.id == owner.id for migrated)
                gym = db.query(GymORM).filter(
                    GymORM.owner_id == user.id,
                    GymORM.is_active == True
                ).order_by(GymORM.created_at).first()
                return gym.id if gym else user.id  # fallback for safety
        finally:
            db.close()

    elif user.role in ("staff", "trainer", "nutritionist"):
        return user.gym_owner_id or ""

    elif user.role == "client":
        db = get_db_session()
        try:
            profile = db.query(ClientProfileORM).filter(
                ClientProfileORM.id == user.id
            ).first()
            return profile.gym_id if profile else ""
        finally:
            db.close()

    return ""


async def get_gym_context(
    user: UserORM = Depends(get_current_user),
    x_gym_id: Optional[str] = Header(None)
) -> str:
    """
    FastAPI dependency that resolves the gym ID for the current request.

    Usage in routes:
        @router.get("/api/owner/something")
        async def my_endpoint(
            user = Depends(get_current_user),
            gym_id: str = Depends(get_gym_context)
        ):
            ...
    """
    return resolve_gym_id(user, x_gym_id)
