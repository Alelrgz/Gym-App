"""
Course Service - handles group fitness course management.
"""
from .base import (
    HTTPException, uuid, json, logging, datetime,
    get_db_session, CourseORM, CourseLessonORM, UserORM
)

logger = logging.getLogger("gym_app")


class CourseService:
    """Service for managing courses and lessons."""

    # --- COURSE CRUD ---

    def get_courses(self, trainer_id: str, include_gym_shared: bool = True) -> list:
        """Get all courses accessible to a trainer (personal + gym-shared)."""
        db = get_db_session()
        try:
            # Get trainer's gym_id for shared courses
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            gym_id = trainer.gym_owner_id if trainer else None

            if include_gym_shared and gym_id:
                # Include courses shared in this gym
                from sqlalchemy import or_
                courses = db.query(CourseORM).filter(
                    or_(
                        CourseORM.owner_id == trainer_id,
                        (CourseORM.gym_id == gym_id) & (CourseORM.is_shared == True)
                    )
                ).all()
            else:
                courses = db.query(CourseORM).filter(CourseORM.owner_id == trainer_id).all()

            return [self._course_to_dict(c) for c in courses]
        finally:
            db.close()

    def get_course(self, course_id: str, trainer_id: str) -> dict:
        """Get a single course with access check."""
        db = get_db_session()
        try:
            course = db.query(CourseORM).filter(CourseORM.id == course_id).first()
            if not course:
                raise HTTPException(status_code=404, detail="Course not found")

            # Access check: owner or gym shared
            if not self._can_access_course(course, trainer_id, db):
                raise HTTPException(status_code=403, detail="Access denied")

            return self._course_to_dict(course)
        finally:
            db.close()

    def create_course(self, course_data: dict, trainer_id: str) -> dict:
        """Create a new course."""
        db = get_db_session()
        try:
            # Get trainer's gym for gym_id
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            gym_id = trainer.gym_owner_id if trainer else None

            new_id = str(uuid.uuid4())
            course = CourseORM(
                id=new_id,
                name=course_data["name"],
                description=course_data.get("description"),
                exercises_json=json.dumps(course_data.get("exercises", [])),
                music_links_json=json.dumps(course_data.get("music_links", [])),
                day_of_week=course_data.get("day_of_week"),
                time_slot=course_data.get("time_slot"),
                duration=course_data.get("duration", 60),
                owner_id=trainer_id,
                gym_id=gym_id,
                is_shared=course_data.get("is_shared", False)
            )
            db.add(course)
            db.commit()
            db.refresh(course)
            logger.info(f"Course created: {new_id} by trainer {trainer_id}")
            return self._course_to_dict(course)
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to create course: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create course: {str(e)}")
        finally:
            db.close()

    def update_course(self, course_id: str, updates: dict, trainer_id: str) -> dict:
        """Update an existing course (owner only)."""
        db = get_db_session()
        try:
            course = db.query(CourseORM).filter(CourseORM.id == course_id).first()
            if not course:
                raise HTTPException(status_code=404, detail="Course not found")

            if course.owner_id != trainer_id:
                raise HTTPException(status_code=403, detail="Only course owner can edit")

            if "name" in updates and updates["name"] is not None:
                course.name = updates["name"]
            if "description" in updates:
                course.description = updates["description"]
            if "exercises" in updates and updates["exercises"] is not None:
                course.exercises_json = json.dumps(updates["exercises"])
            if "music_links" in updates and updates["music_links"] is not None:
                course.music_links_json = json.dumps(updates["music_links"])
            if "day_of_week" in updates:
                course.day_of_week = updates["day_of_week"]
            if "time_slot" in updates:
                course.time_slot = updates["time_slot"]
            if "duration" in updates and updates["duration"] is not None:
                course.duration = updates["duration"]
            if "is_shared" in updates and updates["is_shared"] is not None:
                course.is_shared = updates["is_shared"]

            course.updated_at = datetime.utcnow().isoformat()
            db.commit()
            db.refresh(course)
            logger.info(f"Course updated: {course_id}")
            return self._course_to_dict(course)
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to update course: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to update course: {str(e)}")
        finally:
            db.close()

    def delete_course(self, course_id: str, trainer_id: str) -> dict:
        """Delete a course and its lessons (owner only)."""
        db = get_db_session()
        try:
            course = db.query(CourseORM).filter(CourseORM.id == course_id).first()
            if not course:
                raise HTTPException(status_code=404, detail="Course not found")

            if course.owner_id != trainer_id:
                raise HTTPException(status_code=403, detail="Only course owner can delete")

            # Delete associated lessons
            db.query(CourseLessonORM).filter(CourseLessonORM.course_id == course_id).delete()
            db.delete(course)
            db.commit()
            logger.info(f"Course deleted: {course_id}")
            return {"status": "success", "message": "Course deleted"}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to delete course: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to delete course: {str(e)}")
        finally:
            db.close()

    # --- LESSON MANAGEMENT ---

    def schedule_lesson(self, course_id: str, lesson_data: dict, trainer_id: str) -> dict:
        """Schedule a new lesson for a course."""
        db = get_db_session()
        try:
            course = db.query(CourseORM).filter(CourseORM.id == course_id).first()
            if not course:
                raise HTTPException(status_code=404, detail="Course not found")

            if not self._can_access_course(course, trainer_id, db):
                raise HTTPException(status_code=403, detail="Access denied")

            lesson = CourseLessonORM(
                course_id=course_id,
                date=lesson_data["date"],
                time=lesson_data.get("time") or course.time_slot or "9:00 AM",
                duration=lesson_data.get("duration") or course.duration,
                trainer_id=trainer_id,
                exercises_json=json.dumps(lesson_data.get("exercises")) if lesson_data.get("exercises") else None,
                music_links_json=json.dumps(lesson_data.get("music_links")) if lesson_data.get("music_links") else None
            )
            db.add(lesson)
            db.commit()
            db.refresh(lesson)
            logger.info(f"Lesson scheduled: {lesson.id} for course {course_id}")
            return self._lesson_to_dict(lesson, course)
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to schedule lesson: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to schedule lesson: {str(e)}")
        finally:
            db.close()

    def get_lessons(self, course_id: str, trainer_id: str, include_completed: bool = True) -> list:
        """Get all lessons for a course."""
        db = get_db_session()
        try:
            course = db.query(CourseORM).filter(CourseORM.id == course_id).first()
            if not course:
                raise HTTPException(status_code=404, detail="Course not found")

            if not self._can_access_course(course, trainer_id, db):
                raise HTTPException(status_code=403, detail="Access denied")

            query = db.query(CourseLessonORM).filter(CourseLessonORM.course_id == course_id)
            if not include_completed:
                query = query.filter(CourseLessonORM.completed == False)

            lessons = query.order_by(CourseLessonORM.date.desc()).all()
            return [self._lesson_to_dict(l, course) for l in lessons]
        finally:
            db.close()

    def complete_lesson(self, lesson_id: int, completion_data: dict, trainer_id: str) -> dict:
        """Mark a lesson as complete with engagement tracking."""
        db = get_db_session()
        try:
            lesson = db.query(CourseLessonORM).filter(CourseLessonORM.id == lesson_id).first()
            if not lesson:
                raise HTTPException(status_code=404, detail="Lesson not found")

            if lesson.trainer_id != trainer_id:
                raise HTTPException(status_code=403, detail="Only the assigned trainer can complete this lesson")

            engagement = completion_data.get("engagement_level")
            if not engagement or engagement < 1 or engagement > 5:
                raise HTTPException(status_code=400, detail="Engagement level must be 1-5")

            lesson.completed = True
            lesson.completed_at = datetime.utcnow().isoformat()
            lesson.engagement_level = engagement
            lesson.notes = completion_data.get("notes")
            lesson.attendee_count = completion_data.get("attendee_count")

            db.commit()
            db.refresh(lesson)

            course = db.query(CourseORM).filter(CourseORM.id == lesson.course_id).first()
            logger.info(f"Lesson completed: {lesson_id} with engagement {engagement}")
            return self._lesson_to_dict(lesson, course)
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to complete lesson: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to complete lesson: {str(e)}")
        finally:
            db.close()

    def delete_lesson(self, lesson_id: int, trainer_id: str) -> dict:
        """Delete a scheduled lesson."""
        db = get_db_session()
        try:
            lesson = db.query(CourseLessonORM).filter(CourseLessonORM.id == lesson_id).first()
            if not lesson:
                raise HTTPException(status_code=404, detail="Lesson not found")

            if lesson.trainer_id != trainer_id:
                raise HTTPException(status_code=403, detail="Only the assigned trainer can delete this lesson")

            db.delete(lesson)
            db.commit()
            logger.info(f"Lesson deleted: {lesson_id}")
            return {"status": "success", "message": "Lesson deleted"}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to delete lesson: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to delete lesson: {str(e)}")
        finally:
            db.close()

    # --- HELPER METHODS ---

    def _course_to_dict(self, course: CourseORM) -> dict:
        return {
            "id": course.id,
            "name": course.name,
            "description": course.description,
            "exercises": json.loads(course.exercises_json) if course.exercises_json else [],
            "music_links": json.loads(course.music_links_json) if course.music_links_json else [],
            "day_of_week": course.day_of_week,
            "time_slot": course.time_slot,
            "duration": course.duration,
            "owner_id": course.owner_id,
            "gym_id": course.gym_id,
            "is_shared": course.is_shared,
            "created_at": course.created_at,
            "updated_at": course.updated_at
        }

    def _lesson_to_dict(self, lesson: CourseLessonORM, course: CourseORM = None) -> dict:
        # Merge lesson data with course defaults
        exercises = json.loads(lesson.exercises_json) if lesson.exercises_json else None
        music_links = json.loads(lesson.music_links_json) if lesson.music_links_json else None

        if course and not exercises:
            exercises = json.loads(course.exercises_json) if course.exercises_json else []
        if course and not music_links:
            music_links = json.loads(course.music_links_json) if course.music_links_json else []

        return {
            "id": lesson.id,
            "course_id": lesson.course_id,
            "course_name": course.name if course else None,
            "date": lesson.date,
            "time": lesson.time,
            "duration": lesson.duration,
            "trainer_id": lesson.trainer_id,
            "exercises": exercises or [],
            "music_links": music_links or [],
            "completed": lesson.completed,
            "completed_at": lesson.completed_at,
            "engagement_level": lesson.engagement_level,
            "notes": lesson.notes,
            "attendee_count": lesson.attendee_count,
            "created_at": lesson.created_at
        }

    def _can_access_course(self, course: CourseORM, trainer_id: str, db) -> bool:
        """Check if trainer can access this course."""
        if course.owner_id == trainer_id:
            return True

        if course.is_shared and course.gym_id:
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            if trainer and trainer.gym_owner_id == course.gym_id:
                return True

        return False


# Singleton instance
course_service = CourseService()


def get_course_service() -> CourseService:
    """Dependency injection helper."""
    return course_service
