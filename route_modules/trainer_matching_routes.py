"""
Trainer Matching Routes - API endpoints for trainer-course matching suggestions.
"""
from fastapi import APIRouter, Depends, Query
from auth import get_current_user
from models_orm import UserORM
from service_modules.trainer_matching_service import (
    TrainerMatchingService, get_trainer_matching_service
)

router = APIRouter()


@router.get("/api/owner/course-suggestions")
async def get_all_course_suggestions(
    service: TrainerMatchingService = Depends(get_trainer_matching_service),
    current_user: UserORM = Depends(get_current_user)
):
    """
    Get trainer suggestions for all course types.
    Returns a mapping of course types to suggested trainers.
    For gym owners to see who should teach what.
    """
    if current_user.role != "owner":
        return {"error": "Only gym owners can access this endpoint"}

    return {
        "suggestions": service.suggest_trainers_for_all_course_types(current_user.id),
        "unassigned_types": service.get_unassigned_course_types(current_user.id)
    }


@router.get("/api/owner/course-suggestions/{course_type}")
async def get_course_type_suggestions(
    course_type: str,
    limit: int = Query(default=5, le=10),
    service: TrainerMatchingService = Depends(get_trainer_matching_service),
    current_user: UserORM = Depends(get_current_user)
):
    """
    Get trainer suggestions for a specific course type.
    """
    if current_user.role != "owner":
        return {"error": "Only gym owners can access this endpoint"}

    valid_types = ["yoga", "pilates", "hiit", "dance", "spin", "strength", "stretch", "cardio"]
    if course_type not in valid_types:
        return {"error": f"Invalid course type. Must be one of: {', '.join(valid_types)}"}

    return {
        "course_type": course_type,
        "suggestions": service.suggest_trainers_for_course_type(course_type, current_user.id, limit)
    }


@router.get("/api/trainer/my-course-recommendations")
async def get_my_course_recommendations(
    service: TrainerMatchingService = Depends(get_trainer_matching_service),
    current_user: UserORM = Depends(get_current_user)
):
    """
    Get course type recommendations for the current trainer based on their specialties.
    Helps trainers discover what courses they're best suited to teach.
    """
    if current_user.role != "trainer":
        return {"error": "Only trainers can access this endpoint"}

    return {
        "trainer_id": current_user.id,
        "specialties": [s.strip() for s in (current_user.specialties or "").split(",") if s.strip()],
        "recommendations": service.get_trainer_course_recommendations(current_user.id)
    }


@router.get("/api/owner/trainer/{trainer_id}/course-fit")
async def get_trainer_course_fit(
    trainer_id: str,
    service: TrainerMatchingService = Depends(get_trainer_matching_service),
    current_user: UserORM = Depends(get_current_user)
):
    """
    See how well a specific trainer fits each course type.
    For owners to evaluate trainer assignments.
    """
    if current_user.role != "owner":
        return {"error": "Only gym owners can access this endpoint"}

    return {
        "trainer_id": trainer_id,
        "course_fit": service.get_trainer_course_recommendations(trainer_id)
    }


@router.get("/api/owner/gaps")
async def get_gym_course_gaps(
    service: TrainerMatchingService = Depends(get_trainer_matching_service),
    current_user: UserORM = Depends(get_current_user)
):
    """
    Find course types not currently offered at the gym with suggested trainers.
    Helps identify opportunities to expand course offerings.
    """
    if current_user.role != "owner":
        return {"error": "Only gym owners can access this endpoint"}

    return {
        "gaps": service.get_unassigned_course_types(current_user.id)
    }
