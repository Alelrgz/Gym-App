"""
Workout Routes - API endpoints for workout management.
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from models_orm import UserORM
from service_modules.workout_service import WorkoutService, get_workout_service

router = APIRouter()


def require_trainer(user: UserORM):
    if user.role not in ("trainer", "owner"):
        raise HTTPException(status_code=403, detail="Only trainers can access this endpoint")


@router.get("/api/trainer/workouts")
async def get_workouts(
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all workouts accessible to the current trainer."""
    require_trainer(current_user)
    return service.get_workouts(current_user.id)


@router.post("/api/trainer/workouts")
async def create_workout(
    workout: dict,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Create a new workout."""
    require_trainer(current_user)
    return service.create_workout(workout, current_user.id)


@router.put("/api/trainer/workouts/{workout_id}")
async def update_workout(
    workout_id: str,
    workout: dict,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update an existing workout."""
    require_trainer(current_user)
    return service.update_workout(workout_id, workout, current_user.id)


@router.delete("/api/trainer/workouts/{workout_id}")
async def delete_workout(
    workout_id: str,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Delete a workout."""
    require_trainer(current_user)
    return service.delete_workout(workout_id, current_user.id)


@router.post("/api/trainer/assign_workout")
async def assign_workout(
    assignment: dict,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Assign a workout to a client."""
    require_trainer(current_user)
    return service.assign_workout(assignment)
