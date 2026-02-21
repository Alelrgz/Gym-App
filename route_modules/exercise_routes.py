"""
Exercise Routes - API endpoints for exercise management.
"""
import os
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from auth import get_current_user
from models import ExerciseTemplate
from models_orm import UserORM
from service_modules.exercise_service import ExerciseService, get_exercise_service

_VIDEOS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "videos")
_ALLOWED_VIDEO_EXTS = {".mp4", ".mov", ".webm", ".avi", ".mkv"}
_MAX_VIDEO_BYTES = 300 * 1024 * 1024  # 300 MB

router = APIRouter()


def require_trainer(user: UserORM):
    if user.role not in ("trainer", "owner"):
        raise HTTPException(status_code=403, detail="Only trainers can access this endpoint")


# --- TRAINER EXERCISE ROUTES ---

@router.get("/api/trainer/exercises")
async def get_exercises(
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all exercises accessible to the current trainer."""
    require_trainer(current_user)
    return service.get_exercises(current_user.id)


@router.post("/api/trainer/exercises")
async def create_exercise(
    exercise: ExerciseTemplate,
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Create a new personal exercise."""
    require_trainer(current_user)
    return service.create_exercise(exercise.model_dump(), current_user.id)


@router.put("/api/trainer/exercises/{exercise_id}")
async def update_exercise(
    exercise_id: str,
    exercise: ExerciseTemplate,
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update an existing exercise or fork a global one."""
    require_trainer(current_user)
    return service.update_exercise(exercise_id, exercise.model_dump(exclude_unset=True), current_user.id)


# --- GENERAL EXERCISE ROUTES (for course exercises page) ---

@router.get("/api/exercises")
async def get_all_exercises(
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all exercises accessible to the current user."""
    return service.get_exercises(current_user.id)


@router.post("/api/exercises")
async def create_general_exercise(
    exercise: dict,
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Create a new exercise (for course exercises)."""
    return service.create_exercise(exercise, current_user.id)


@router.put("/api/exercises/{exercise_id}")
async def update_general_exercise(
    exercise_id: str,
    exercise: dict,
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update an existing exercise."""
    return service.update_exercise(exercise_id, exercise, current_user.id)


@router.delete("/api/exercises/{exercise_id}")
async def delete_exercise(
    exercise_id: str,
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Delete a personal exercise."""
    return service.delete_exercise(exercise_id, current_user.id)


@router.post("/api/exercises/{exercise_id}/video")
async def upload_exercise_video(
    exercise_id: str,
    file: UploadFile = File(...),
    service: ExerciseService = Depends(get_exercise_service),
    current_user: UserORM = Depends(get_current_user),
):
    """Upload a video file for an exercise and save it to static/videos/."""
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in _ALLOWED_VIDEO_EXTS:
        raise HTTPException(status_code=400, detail=f"Formato non supportato. Usa: {', '.join(_ALLOWED_VIDEO_EXTS)}")

    content = await file.read()
    if len(content) > _MAX_VIDEO_BYTES:
        raise HTTPException(status_code=400, detail="File troppo grande (max 300 MB)")

    os.makedirs(_VIDEOS_DIR, exist_ok=True)
    video_id = str(uuid.uuid4())
    dest = os.path.join(_VIDEOS_DIR, f"{video_id}.mp4")
    with open(dest, "wb") as f:
        f.write(content)

    return service.update_exercise(exercise_id, {"video_id": video_id}, current_user.id)
