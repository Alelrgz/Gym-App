"""
Course Service - handles group fitness course management.
"""
from datetime import timedelta
from .base import (
    HTTPException, uuid, json, logging, datetime,
    get_db_session, CourseORM, CourseLessonORM, UserORM, TrainerScheduleORM,
    ClientScheduleORM, ClientProfileORM, NotificationORM
)

logger = logging.getLogger("gym_app")

# How many weeks ahead to auto-generate schedule entries
COURSE_SCHEDULE_WEEKS_AHEAD = 4


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

            # Handle days_of_week array (new) with backwards compat for day_of_week (old)
            days_of_week = course_data.get("days_of_week")
            day_of_week = course_data.get("day_of_week")
            days_json = json.dumps(days_of_week) if days_of_week else None

            course = CourseORM(
                id=new_id,
                name=course_data["name"],
                description=course_data.get("description"),
                exercises_json=json.dumps(course_data.get("exercises", [])),
                music_links_json=json.dumps(course_data.get("music_links", [])),
                day_of_week=day_of_week,
                days_of_week_json=days_json,
                time_slot=course_data.get("time_slot"),
                duration=course_data.get("duration", 60),
                owner_id=trainer_id,
                gym_id=gym_id,
                is_shared=course_data.get("is_shared", False),
                course_type=course_data.get("course_type"),
                cover_image_url=course_data.get("cover_image_url"),
                trailer_url=course_data.get("trailer_url")
            )
            db.add(course)
            db.commit()
            db.refresh(course)
            logger.info(f"Course created: {new_id} by trainer {trainer_id}")

            # Auto-generate schedule entries if days/time are set
            course_dict = self._course_to_dict(course)
            if course_data.get("days_of_week") or course_data.get("day_of_week"):
                try:
                    schedule_result = self.generate_course_schedule(new_id, trainer_id)
                    course_dict["schedule_entries_created"] = schedule_result.get("created", 0)
                except Exception as e:
                    logger.warning(f"Failed to auto-generate schedule for course {new_id}: {e}")

            # Notify all gym clients about the new course
            if gym_id:
                try:
                    trainer_name = trainer.username if trainer else "Your trainer"
                    self._notify_clients_of_new_course(db, gym_id, course, trainer_name)
                except Exception as e:
                    logger.warning(f"Failed to send course notifications: {e}")

            return course_dict
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
            if "days_of_week" in updates:
                course.days_of_week_json = json.dumps(updates["days_of_week"]) if updates["days_of_week"] else None
            if "day_of_week" in updates:
                course.day_of_week = updates["day_of_week"]
            if "time_slot" in updates:
                course.time_slot = updates["time_slot"]
            if "duration" in updates and updates["duration"] is not None:
                course.duration = updates["duration"]
            if "is_shared" in updates and updates["is_shared"] is not None:
                course.is_shared = updates["is_shared"]
            if "course_type" in updates:
                course.course_type = updates["course_type"]
            if "cover_image_url" in updates:
                course.cover_image_url = updates["cover_image_url"]
            if "trailer_url" in updates:
                course.trailer_url = updates["trailer_url"]

            # Track if schedule-related fields changed
            schedule_changed = any(k in updates for k in ["days_of_week", "day_of_week", "time_slot", "duration", "name"])

            course.updated_at = datetime.utcnow().isoformat()
            db.commit()
            db.refresh(course)
            logger.info(f"Course updated: {course_id}")

            # Regenerate schedule if schedule-related fields changed
            course_dict = self._course_to_dict(course)
            if schedule_changed:
                try:
                    schedule_result = self.update_course_schedule(course_id, trainer_id)
                    course_dict["schedule_updated"] = True
                    course_dict["schedule_deleted"] = schedule_result.get("deleted", 0)
                    course_dict["schedule_created"] = schedule_result.get("created", 0)
                except Exception as e:
                    logger.warning(f"Failed to update schedule for course {course_id}: {e}")

            return course_dict
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to update course: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to update course: {str(e)}")
        finally:
            db.close()

    def delete_course(self, course_id: str, trainer_id: str) -> dict:
        """Delete a course, its lessons, and associated schedule entries (owner only)."""
        db = get_db_session()
        try:
            course = db.query(CourseORM).filter(CourseORM.id == course_id).first()
            if not course:
                raise HTTPException(status_code=404, detail="Course not found")

            if course.owner_id != trainer_id:
                raise HTTPException(status_code=403, detail="Only course owner can delete")

            # Delete associated trainer schedule entries
            trainer_schedule_deleted = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.course_id == course_id
            ).delete()

            # Delete associated client schedule entries
            client_schedule_deleted = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.course_id == course_id
            ).delete()

            # Delete associated lessons
            db.query(CourseLessonORM).filter(CourseLessonORM.course_id == course_id).delete()
            db.delete(course)
            db.commit()
            logger.info(f"Course deleted: {course_id} (removed {trainer_schedule_deleted} trainer + {client_schedule_deleted} client entries)")
            return {"status": "success", "message": "Course deleted", "schedule_entries_removed": trainer_schedule_deleted, "client_entries_removed": client_schedule_deleted}
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

    # --- SCHEDULE GENERATION ---

    def generate_course_schedule(self, course_id: str, trainer_id: str, weeks_ahead: int = None) -> dict:
        """
        Generate recurring schedule entries for a course based on its days_of_week and time_slot.
        Creates entries for the next N weeks (default 4).
        Returns count of created entries.
        """
        if weeks_ahead is None:
            weeks_ahead = COURSE_SCHEDULE_WEEKS_AHEAD

        db = get_db_session()
        try:
            course = db.query(CourseORM).filter(CourseORM.id == course_id).first()
            if not course:
                raise HTTPException(status_code=404, detail="Course not found")

            # Get days of week from course
            days_of_week = []
            if course.days_of_week_json:
                days_of_week = json.loads(course.days_of_week_json)
            elif course.day_of_week is not None:
                days_of_week = [course.day_of_week]

            if not days_of_week:
                return {"status": "success", "created": 0, "message": "No days specified for course"}

            time_slot = course.time_slot or "9:00 AM"
            duration = course.duration or 60

            # Calculate dates for the next N weeks
            today = datetime.now().date()
            created_count = 0

            for week in range(weeks_ahead):
                for day_num in days_of_week:
                    # Calculate the date for this day of week
                    # day_num: 0=Monday, 6=Sunday (Python weekday convention)
                    days_until = (day_num - today.weekday()) % 7
                    if week == 0 and days_until == 0:
                        # Include today if it matches
                        target_date = today
                    else:
                        days_until = days_until + (week * 7)
                        if week == 0 and days_until < 0:
                            days_until += 7
                        target_date = today + timedelta(days=days_until)

                    date_str = target_date.isoformat()

                    # Check if entry already exists for this course on this date
                    existing = db.query(TrainerScheduleORM).filter(
                        TrainerScheduleORM.course_id == course_id,
                        TrainerScheduleORM.date == date_str,
                        TrainerScheduleORM.trainer_id == trainer_id
                    ).first()

                    if existing:
                        continue  # Skip, already scheduled

                    # Create trainer schedule entry
                    new_entry = TrainerScheduleORM(
                        trainer_id=trainer_id,
                        date=date_str,
                        time=time_slot,
                        title=course.name,
                        subtitle="Group Course",
                        type="course",
                        duration=duration,
                        course_id=course_id
                    )
                    db.add(new_entry)
                    created_count += 1

            # Also create client schedule entries for all clients at the gym
            client_entries_created = 0
            if course.gym_id:
                # Get all clients at this gym
                clients = db.query(ClientProfileORM).filter(
                    ClientProfileORM.gym_id == course.gym_id
                ).all()

                for client in clients:
                    for week in range(weeks_ahead):
                        for day_num in days_of_week:
                            days_until = (day_num - today.weekday()) % 7
                            if week == 0 and days_until == 0:
                                target_date = today
                            else:
                                days_until = days_until + (week * 7)
                                if week == 0 and days_until < 0:
                                    days_until += 7
                                target_date = today + timedelta(days=days_until)

                            date_str = target_date.isoformat()

                            # Check if client entry already exists
                            existing_client = db.query(ClientScheduleORM).filter(
                                ClientScheduleORM.course_id == course_id,
                                ClientScheduleORM.date == date_str,
                                ClientScheduleORM.client_id == client.id
                            ).first()

                            if existing_client:
                                continue

                            # Create client schedule entry
                            client_entry = ClientScheduleORM(
                                client_id=client.id,
                                date=date_str,
                                title=f"{course.name} @ {time_slot}",
                                type="course",
                                completed=False,
                                course_id=course_id,
                                details=json.dumps({"duration": duration, "trainer_id": trainer_id})
                            )
                            db.add(client_entry)
                            client_entries_created += 1

            db.commit()
            logger.info(f"Generated {created_count} trainer entries and {client_entries_created} client entries for course {course_id}")
            return {"status": "success", "created": created_count, "client_entries": client_entries_created}

        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to generate course schedule: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to generate schedule: {str(e)}")
        finally:
            db.close()

    def update_course_schedule(self, course_id: str, trainer_id: str) -> dict:
        """
        Update schedule entries when course details change.
        Removes future non-completed entries and regenerates them.
        """
        db = get_db_session()
        try:
            today = datetime.now().date().isoformat()

            # Delete future non-completed trainer entries for this course
            deleted_trainer = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.course_id == course_id,
                TrainerScheduleORM.trainer_id == trainer_id,
                TrainerScheduleORM.date >= today,
                TrainerScheduleORM.completed == False
            ).delete()

            # Delete future non-completed client entries for this course
            deleted_client = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.course_id == course_id,
                ClientScheduleORM.date >= today,
                ClientScheduleORM.completed == False
            ).delete()

            db.commit()
            logger.info(f"Deleted {deleted_trainer} trainer and {deleted_client} client entries for course {course_id}")

            # Regenerate schedule
            result = self.generate_course_schedule(course_id, trainer_id)
            return {
                "status": "success",
                "deleted": deleted_trainer,
                "deleted_client": deleted_client,
                "created": result.get("created", 0),
                "client_entries": result.get("client_entries", 0)
            }

        except Exception as e:
            db.rollback()
            logger.error(f"Failed to update course schedule: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to update schedule: {str(e)}")
        finally:
            db.close()

    def delete_course_schedule(self, course_id: str, trainer_id: str) -> dict:
        """Delete all schedule entries for a course (when course is deleted)."""
        db = get_db_session()
        try:
            # Delete trainer entries
            deleted_trainer = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.course_id == course_id,
                TrainerScheduleORM.trainer_id == trainer_id
            ).delete()

            # Delete client entries
            deleted_client = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.course_id == course_id
            ).delete()

            db.commit()
            logger.info(f"Deleted {deleted_trainer} trainer and {deleted_client} client entries for course {course_id}")
            return {"status": "success", "deleted": deleted_trainer, "deleted_client": deleted_client}
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to delete course schedule: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to delete course schedule: {str(e)}")
        finally:
            db.close()

    # --- HELPER METHODS ---

    def _course_to_dict(self, course: CourseORM) -> dict:
        # Parse days_of_week with fallback to single day_of_week
        days = None
        if hasattr(course, 'days_of_week_json') and course.days_of_week_json:
            days = json.loads(course.days_of_week_json)
        elif course.day_of_week is not None:
            days = [course.day_of_week]

        return {
            "id": course.id,
            "name": course.name,
            "description": course.description,
            "exercises": json.loads(course.exercises_json) if course.exercises_json else [],
            "music_links": json.loads(course.music_links_json) if course.music_links_json else [],
            "day_of_week": course.day_of_week,
            "days_of_week": days,
            "time_slot": course.time_slot,
            "duration": course.duration,
            "owner_id": course.owner_id,
            "gym_id": course.gym_id,
            "is_shared": course.is_shared,
            "course_type": getattr(course, 'course_type', None),
            "cover_image_url": getattr(course, 'cover_image_url', None),
            "trailer_url": getattr(course, 'trailer_url', None),
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

    def _notify_clients_of_new_course(self, db, gym_id: str, course: CourseORM, trainer_name: str):
        """Send notifications to all clients of the gym about a new course."""
        try:
            # Get all clients at this gym
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()

            # Build course info for notification
            time_info = f" @ {course.time_slot}" if course.time_slot else ""

            for client in clients:
                notification = NotificationORM(
                    user_id=client.id,
                    type="course",
                    title="🆕 New Course Available!",
                    message=f"{trainer_name} added a new course: {course.name}{time_info}",
                    data=json.dumps({
                        "course_id": course.id,
                        "course_name": course.name,
                        "trainer_name": trainer_name
                    }),
                    read=False,
                    created_at=datetime.utcnow().isoformat()
                )
                db.add(notification)

            db.commit()
            logger.info(f"Sent new course notifications to {len(clients)} clients for course {course.id}")

        except Exception as e:
            logger.error(f"Error sending course notifications: {e}")

    # --- CLIENT-FACING METHODS ---

    def get_trainer_courses_for_client(self, trainer_id: str) -> list:
        """Get all courses offered by a specific trainer (for clients to browse)."""
        db = get_db_session()
        try:
            # Get trainer's username for display
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            trainer_name = trainer.username if trainer else "Trainer"

            # Get all courses owned by this trainer
            courses = db.query(CourseORM).filter(CourseORM.owner_id == trainer_id).all()

            result = []
            for course in courses:
                course_dict = self._course_to_dict(course)
                course_dict["trainer_name"] = trainer_name
                # Get upcoming lesson count
                today = datetime.now().date().isoformat()
                upcoming_lessons = db.query(CourseLessonORM).filter(
                    CourseLessonORM.course_id == course.id,
                    CourseLessonORM.date >= today,
                    CourseLessonORM.completed == False
                ).count()
                course_dict["upcoming_lessons"] = upcoming_lessons
                result.append(course_dict)

            return result
        finally:
            db.close()

    def get_gym_courses_for_client(self, client_id: str) -> list:
        """Get all courses available at the client's gym."""
        db = get_db_session()
        try:
            # Get the client's gym_id
            client_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if not client_profile or not client_profile.gym_id:
                return []

            gym_id = client_profile.gym_id

            # Get all courses at this gym (owned by trainers at this gym)
            courses = db.query(CourseORM).filter(CourseORM.gym_id == gym_id).all()

            result = []
            today = datetime.now().date().isoformat()

            for course in courses:
                course_dict = self._course_to_dict(course)

                # Get trainer name for each course
                trainer = db.query(UserORM).filter(UserORM.id == course.owner_id).first()
                course_dict["trainer_name"] = trainer.username if trainer else "Trainer"

                # Get upcoming lesson count
                upcoming_lessons = db.query(CourseLessonORM).filter(
                    CourseLessonORM.course_id == course.id,
                    CourseLessonORM.date >= today,
                    CourseLessonORM.completed == False
                ).count()
                course_dict["upcoming_lessons"] = upcoming_lessons
                result.append(course_dict)

            return result
        finally:
            db.close()


# Singleton instance
course_service = CourseService()


def get_course_service() -> CourseService:
    """Dependency injection helper."""
    return course_service
