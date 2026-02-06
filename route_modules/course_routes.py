"""
Course Routes - API endpoints for course management.
"""
from fastapi import APIRouter, Depends
from auth import get_current_user
from models_orm import UserORM
from service_modules.course_service import CourseService, get_course_service

router = APIRouter()


# --- COURSE CRUD ---

@router.get("/api/trainer/courses")
async def get_courses(
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all courses accessible to the current trainer."""
    return service.get_courses(current_user.id)


@router.get("/api/trainer/courses/{course_id}")
async def get_course(
    course_id: str,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get a specific course with its details."""
    return service.get_course(course_id, current_user.id)


@router.post("/api/trainer/courses")
async def create_course(
    course: dict,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Create a new course."""
    return service.create_course(course, current_user.id)


@router.put("/api/trainer/courses/{course_id}")
async def update_course(
    course_id: str,
    course: dict,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update an existing course."""
    return service.update_course(course_id, course, current_user.id)


@router.delete("/api/trainer/courses/{course_id}")
async def delete_course(
    course_id: str,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Delete a course."""
    return service.delete_course(course_id, current_user.id)


@router.post("/api/trainer/courses/{course_id}/regenerate-schedule")
async def regenerate_course_schedule(
    course_id: str,
    weeks_ahead: int = 4,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Regenerate schedule entries for a course (deletes future entries and recreates)."""
    return service.update_course_schedule(course_id, current_user.id)


# --- LESSON MANAGEMENT ---

@router.get("/api/trainer/courses/{course_id}/lessons")
async def get_lessons(
    course_id: str,
    include_completed: bool = True,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all lessons for a course."""
    return service.get_lessons(course_id, current_user.id, include_completed)


@router.post("/api/trainer/courses/{course_id}/schedule")
async def schedule_lesson(
    course_id: str,
    lesson: dict,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Schedule a new lesson for a course."""
    return service.schedule_lesson(course_id, lesson, current_user.id)


@router.post("/api/trainer/courses/lessons/{lesson_id}/complete")
async def complete_lesson(
    lesson_id: int,
    completion: dict,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Mark a lesson as complete with engagement rating."""
    return service.complete_lesson(lesson_id, completion, current_user.id)


@router.delete("/api/trainer/courses/lessons/{lesson_id}")
async def delete_lesson(
    lesson_id: int,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Delete a scheduled lesson."""
    return service.delete_lesson(lesson_id, current_user.id)


# --- CLIENT ENDPOINTS ---

@router.get("/api/client/trainer/{trainer_id}/courses")
async def get_trainer_courses_for_client(
    trainer_id: str,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all courses offered by a specific trainer (for clients to browse)."""
    return service.get_trainer_courses_for_client(trainer_id)


@router.get("/api/client/gym/courses")
async def get_gym_courses_for_client(
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all courses available at the client's gym."""
    return service.get_gym_courses_for_client(current_user.id)


# --- ENROLLMENT & WAITLIST ENDPOINTS ---

@router.get("/api/lessons/{lesson_id}/availability")
async def get_lesson_availability(
    lesson_id: int,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get enrollment status and availability for a lesson."""
    return service.get_lesson_availability(lesson_id, current_user.id)


@router.post("/api/lessons/{lesson_id}/enroll")
async def enroll_in_lesson(
    lesson_id: int,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Enroll in a lesson. If full, adds to waitlist."""
    return service.enroll_in_lesson(lesson_id, current_user.id)


@router.post("/api/lessons/{lesson_id}/cancel")
async def cancel_enrollment(
    lesson_id: int,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Cancel enrollment in a lesson."""
    return service.cancel_enrollment(lesson_id, current_user.id)


@router.post("/api/waitlist/{waitlist_id}/accept")
async def accept_waitlist_spot(
    waitlist_id: int,
    add_to_calendar: bool = True,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Accept a waitlist spot when notified."""
    return service.accept_waitlist_spot(waitlist_id, current_user.id, add_to_calendar)


@router.post("/api/waitlist/{waitlist_id}/decline")
async def decline_waitlist_spot(
    waitlist_id: int,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Decline a waitlist spot."""
    return service.decline_waitlist_spot(waitlist_id, current_user.id)


@router.get("/api/trainer/lessons/{lesson_id}/enrollments")
async def get_lesson_enrollments(
    lesson_id: int,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all enrollments for a lesson (trainer only)."""
    return service.get_lesson_enrollments(lesson_id, current_user.id)


@router.get("/api/trainer/lessons/{lesson_id}/waitlist")
async def get_lesson_waitlist(
    lesson_id: int,
    service: CourseService = Depends(get_course_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get waitlist for a lesson (trainer only)."""
    return service.get_lesson_waitlist(lesson_id, current_user.id)
