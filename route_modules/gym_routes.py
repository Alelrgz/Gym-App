"""
Gym Routes - API endpoints for managing multiple gyms per owner.
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from database import get_db_session
from models_orm import GymORM, UserORM
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import uuid
import random
import string
import logging

logger = logging.getLogger("gym_app")
router = APIRouter()


class CreateGymRequest(BaseModel):
    name: str


class UpdateGymRequest(BaseModel):
    name: Optional[str] = None
    logo: Optional[str] = None


def _generate_gym_code(db) -> str:
    """Generate a unique 6-char gym code."""
    for _ in range(100):
        code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        existing = db.query(GymORM).filter(GymORM.gym_code == code).first()
        if not existing:
            # Also check legacy codes on UserORM
            existing_user = db.query(UserORM).filter(UserORM.gym_code == code).first()
            if not existing_user:
                return code
    raise HTTPException(status_code=500, detail="Could not generate unique gym code")


@router.get("/api/owner/gyms")
async def list_gyms(user=Depends(get_current_user)):
    """List all gyms owned by the current user."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can manage gyms")

    db = get_db_session()
    try:
        gyms = db.query(GymORM).filter(
            GymORM.owner_id == user.id,
            GymORM.is_active == True
        ).order_by(GymORM.created_at).all()

        return [
            {
                "id": g.id,
                "name": g.name or user.username,
                "logo": g.logo,
                "gym_code": g.gym_code,
                "is_active": g.is_active,
                "stripe_account_id": g.stripe_account_id,
                "stripe_account_status": g.stripe_account_status,
                "created_at": g.created_at,
            }
            for g in gyms
        ]
    finally:
        db.close()


@router.post("/api/owner/gyms")
async def create_gym(data: CreateGymRequest, user=Depends(get_current_user)):
    """Create a new gym for the current owner."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can create gyms")

    db = get_db_session()
    try:
        gym_code = _generate_gym_code(db)
        gym = GymORM(
            id=str(uuid.uuid4()),
            owner_id=user.id,
            name=data.name,
            gym_code=gym_code,
            is_active=True,
            created_at=datetime.utcnow().isoformat(),
        )
        db.add(gym)
        db.commit()
        db.refresh(gym)

        logger.info(f"Created new gym '{data.name}' (code: {gym_code}) for owner {user.id}")

        return {
            "id": gym.id,
            "name": gym.name,
            "gym_code": gym.gym_code,
            "is_active": gym.is_active,
            "created_at": gym.created_at,
        }
    except Exception as e:
        db.rollback()
        logger.error(f"Error creating gym: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create gym: {str(e)}")
    finally:
        db.close()


@router.put("/api/owner/gyms/{gym_id}")
async def update_gym(gym_id: str, data: UpdateGymRequest, user=Depends(get_current_user)):
    """Update a gym's basic info."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can update gyms")

    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(
            GymORM.id == gym_id,
            GymORM.owner_id == user.id
        ).first()

        if not gym:
            raise HTTPException(status_code=404, detail="Gym not found")

        if data.name is not None:
            gym.name = data.name
        if data.logo is not None:
            gym.logo = data.logo

        db.commit()
        db.refresh(gym)

        # Also update gym_name on UserORM if this is the migrated primary gym (id == owner.id)
        if gym.id == user.id:
            owner = db.query(UserORM).filter(UserORM.id == user.id).first()
            if owner and data.name is not None:
                owner.gym_name = data.name
                db.commit()

        return {
            "id": gym.id,
            "name": gym.name,
            "logo": gym.logo,
            "gym_code": gym.gym_code,
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.delete("/api/owner/gyms/{gym_id}")
async def deactivate_gym(gym_id: str, user=Depends(get_current_user)):
    """Deactivate a gym (soft delete). Cannot deactivate the primary gym."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can manage gyms")

    if gym_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot deactivate your primary gym")

    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(
            GymORM.id == gym_id,
            GymORM.owner_id == user.id
        ).first()

        if not gym:
            raise HTTPException(status_code=404, detail="Gym not found")

        gym.is_active = False
        db.commit()

        logger.info(f"Deactivated gym {gym_id} for owner {user.id}")
        return {"status": "success", "message": "Gym deactivated"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()
