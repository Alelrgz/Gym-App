"""
Gym Assignment Routes - API endpoints for clients to join gyms and select trainers
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from service_modules.gym_assignment_service import get_gym_assignment_service, GymAssignmentService
from models import JoinGymRequest, SelectTrainerRequest
from models_orm import UserORM

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
