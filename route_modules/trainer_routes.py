"""
Trainer Routes - API endpoints for trainer data and client roster.
"""
from fastapi import APIRouter, Depends
from auth import get_current_user
from models import TrainerData
from models_orm import UserORM
from service_modules.trainer_service import TrainerService, get_trainer_service
from service_modules.workout_service import get_workout_service
from service_modules.split_service import get_split_service

router = APIRouter()


@router.get("/api/trainer/data", response_model=TrainerData)
async def get_trainer_data(
    service: TrainerService = Depends(get_trainer_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get complete trainer data including clients, schedule, and streak."""
    # Get workout and split services for injecting their functions
    workout_service = get_workout_service()
    split_service = get_split_service()

    return service.get_trainer(
        current_user.id,
        get_workouts_fn=workout_service.get_workouts,
        get_splits_fn=split_service.get_splits
    )


@router.get("/api/trainer/clients")
async def get_trainer_clients(
    service: TrainerService = Depends(get_trainer_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get list of all clients for a trainer."""
    workout_service = get_workout_service()
    split_service = get_split_service()

    data = service.get_trainer(
        current_user.id,
        get_workouts_fn=workout_service.get_workouts,
        get_splits_fn=split_service.get_splits
    )
    return data.clients
