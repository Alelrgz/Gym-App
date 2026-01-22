"""
Exercise Routes - API endpoints for exercise management.
"""
from fastapi import APIRouter, Depends
from auth import get_current_user
from models import ExerciseTemplate
from models_orm import UserORM
from service_modules.exercise_service import ExerciseService, get_exercise_service

router = APIRouter()


@router.get("/api/trainer/exercises")
async def get_exercises(
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all exercises accessible to the current trainer."""
    return service.get_exercises(current_user.id)


@router.post("/api/trainer/exercises")
async def create_exercise(
    exercise: ExerciseTemplate,
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Create a new personal exercise."""
    return service.create_exercise(exercise.model_dump(), current_user.id)


@router.put("/api/trainer/exercises/{exercise_id}")
async def update_exercise(
    exercise_id: str,
    exercise: ExerciseTemplate,
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update an existing exercise or fork a global one."""
    return service.update_exercise(exercise_id, exercise.model_dump(exclude_unset=True), current_user.id)
