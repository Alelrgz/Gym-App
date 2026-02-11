"""
Gym Assignment Routes - API endpoints for clients to join gyms and select trainers
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from auth import get_current_user
from service_modules.gym_assignment_service import get_gym_assignment_service, GymAssignmentService
from models import JoinGymRequest, SelectTrainerRequest
from models_orm import UserORM
from database import get_db_session
from pydantic import BaseModel
from typing import Optional
import os
from datetime import datetime

router = APIRouter()


# --- CLIENT ENDPOINTS ---

@router.post("/api/client/join-gym")
async def join_gym(
    request: JoinGymRequest,
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Join a gym using a gym code."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can join gyms")

    return service.join_gym(user.id, request.gym_code)


@router.get("/api/client/gym-info")
async def get_gym_info(
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get client's current gym and trainer information."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view gym info")

    return service.get_client_gym_info(user.id)


@router.get("/api/gym/{gym_id}/trainers")
async def get_gym_trainers(
    gym_id: str,
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get all trainers in a gym."""
    # Any authenticated user can view trainers
    return service.get_gym_trainers(gym_id)


@router.post("/api/client/select-trainer")
async def select_trainer(
    request: SelectTrainerRequest,
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Select a trainer for the client."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can select trainers")

    return service.select_trainer(user.id, request.trainer_id)


@router.post("/api/client/leave-gym")
async def leave_gym(
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Leave current gym and unassign trainer."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can leave gyms")

    return service.leave_gym(user.id)


# --- OWNER ENDPOINTS ---

@router.get("/api/owner/gym-code")
async def get_gym_code(
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get the gym code that trainers/clients can use to join."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view gym codes")

    # Use the new gym_code field
    gym_code = user.gym_code or service.generate_gym_code_for_owner(user.id)

    return {
        "gym_code": gym_code,
        "owner_name": user.username,
        "gym_name": user.gym_name or "",
        "gym_logo": user.gym_logo or "",
        "message": "Share this code with trainers and clients to let them join your gym"
    }


@router.get("/api/owner/pending-trainers")
async def get_pending_trainers(
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get list of trainers pending approval."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view pending trainers")

    return service.get_pending_trainers(user.id)


@router.post("/api/owner/approve-trainer/{trainer_id}")
async def approve_trainer(
    trainer_id: str,
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Approve a trainer's registration."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can approve trainers")

    return service.approve_trainer(user.id, trainer_id)


@router.post("/api/owner/reject-trainer/{trainer_id}")
async def reject_trainer(
    trainer_id: str,
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Reject a trainer's registration."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can reject trainers")

    return service.reject_trainer(user.id, trainer_id)


@router.get("/api/owner/approved-trainers")
async def get_approved_trainers(
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get list of approved trainers for this gym."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view trainers")

    return service.get_approved_trainers(user.id)


# --- GYM SETTINGS ENDPOINTS ---

class GymSettingsUpdate(BaseModel):
    gym_name: Optional[str] = None


@router.get("/api/owner/gym-settings")
async def get_gym_settings(user: UserORM = Depends(get_current_user)):
    """Get gym branding settings (name, logo)."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view gym settings")

    return {
        "gym_name": user.gym_name or "",
        "gym_logo": user.gym_logo or "",
    }


@router.post("/api/owner/gym-settings")
async def update_gym_settings(
    request: GymSettingsUpdate,
    user: UserORM = Depends(get_current_user)
):
    """Update gym name."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can update gym settings")

    db = get_db_session()
    try:
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            if request.gym_name is not None:
                db_user.gym_name = request.gym_name.strip()
            db.commit()
        return {"success": True, "message": "Gym settings updated"}
    finally:
        db.close()


@router.post("/api/owner/gym-logo")
async def upload_gym_logo(
    file: UploadFile = File(...),
    user: UserORM = Depends(get_current_user)
):
    """Upload or update gym logo."""
    from service_modules.upload_helper import save_file, delete_file, _optimize_image, ALLOWED_IMAGE_EXTENSIONS, MAX_IMAGE_SIZE

    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can update gym logo")

    if not file.filename or '.' not in file.filename:
        raise HTTPException(status_code=400, detail="Invalid file")

    ext = file.filename.rsplit('.', 1)[1].lower()
    if ext not in ALLOWED_IMAGE_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Invalid file type. Allowed: {', '.join(ALLOWED_IMAGE_EXTENSIONS)}")

    content = await file.read()
    if len(content) > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=400, detail="File too large. Maximum 5MB")

    # Delete old logo
    if user.gym_logo:
        await delete_file(user.gym_logo)

    optimized, ext = _optimize_image(content, max_size=(400, 400), crop_square=False)
    filename = f"gym_logo_{user.id}.{ext}"

    url = await save_file(optimized, "profiles", filename)

    db = get_db_session()
    try:
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            db_user.gym_logo = url
            db.commit()
    finally:
        db.close()

    cache_bust = f"?t={int(datetime.now().timestamp())}"
    return {
        "success": True,
        "gym_logo": url + cache_bust,
        "message": "Gym logo updated"
    }


@router.delete("/api/owner/gym-logo")
async def delete_gym_logo(user: UserORM = Depends(get_current_user)):
    """Delete gym logo."""
    from service_modules.upload_helper import delete_file

    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can delete gym logo")

    if user.gym_logo:
        await delete_file(user.gym_logo)

    db = get_db_session()
    try:
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            db_user.gym_logo = None
            db.commit()
    finally:
        db.close()

    return {"success": True, "message": "Gym logo deleted"}
