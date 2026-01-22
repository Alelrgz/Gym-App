"""
Workout Service - handles workout CRUD operations.
"""
from .base import (
    HTTPException, uuid, json, logging,
    get_db_session, WorkoutORM, ClientScheduleORM
)
from data import WORKOUTS_DB

logger = logging.getLogger("gym_app")


class WorkoutService:
    """Service for managing workouts."""

    def get_workouts(self, trainer_id: str) -> list:
        """Get all workouts accessible to a trainer (global + personal)."""
        db = get_db_session()
        try:
            workouts = db.query(WorkoutORM).filter(
                (WorkoutORM.owner_id == None) | (WorkoutORM.owner_id == trainer_id)
            ).all()

            workout_map = {}
            for w in workouts:
                w_data = {
                    "id": w.id,
                    "title": w.title,
                    "duration": w.duration,
                    "difficulty": w.difficulty,
                    "exercises": json.loads(w.exercises_json)
                }
                workout_map[w.id] = w_data

            return list(workout_map.values())
        finally:
            db.close()

    def get_workout_details(self, workout_id: str, context_trainer_id: str = None, db_session=None) -> dict:
        """Get detailed workout information with optional trainer context for video IDs."""
        from .base import ExerciseORM

        db = db_session if db_session else get_db_session()
        should_close = db_session is None

        try:
            w_orm = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()
            if not w_orm:
                # Fallback to WORKOUTS_DB memory if not in DB (backward compat)
                if workout_id in WORKOUTS_DB:
                    return WORKOUTS_DB[workout_id].copy()
                return None

            workout = {
                "id": w_orm.id,
                "title": w_orm.title,
                "duration": w_orm.duration,
                "difficulty": w_orm.difficulty,
                "exercises": json.loads(w_orm.exercises_json)
            }

            # Sync video IDs if context available
            if context_trainer_id:
                trainer_exercises = db.query(ExerciseORM).filter(
                    (ExerciseORM.owner_id == None) | (ExerciseORM.owner_id == context_trainer_id)
                ).all()
                ex_map = {ex.name: ex.video_id for ex in trainer_exercises}

                for ex in workout["exercises"]:
                    if ex.get("name") in ex_map:
                        ex["video_id"] = ex_map[ex["name"]]

            return workout
        finally:
            if should_close:
                db.close()

    def create_workout(self, workout: dict, trainer_id: str) -> dict:
        """Create a new workout owned by the trainer."""
        db = get_db_session()
        try:
            new_id = str(uuid.uuid4())
            db_workout = WorkoutORM(
                id=new_id,
                title=workout["title"],
                duration=workout["duration"],
                difficulty=workout["difficulty"],
                exercises_json=json.dumps(workout["exercises"]),
                owner_id=trainer_id
            )
            db.add(db_workout)
            db.commit()
            db.refresh(db_workout)

            return {
                "id": db_workout.id,
                "title": db_workout.title,
                "duration": db_workout.duration,
                "difficulty": db_workout.difficulty,
                "exercises": json.loads(db_workout.exercises_json)
            }
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to create workout: {str(e)}")
        finally:
            db.close()

    def update_workout(self, workout_id: str, updates: dict, trainer_id: str) -> dict:
        """Update an existing workout or create a shadow copy of a global one."""
        db = get_db_session()
        try:
            workout = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()

            if not workout:
                # Check for global shadow creation
                if workout_id in WORKOUTS_DB:
                    global_w = WORKOUTS_DB[workout_id]
                    workout = WorkoutORM(
                        id=workout_id,
                        title=updates.get("title", global_w["title"]),
                        duration=updates.get("duration", global_w["duration"]),
                        difficulty=updates.get("difficulty", global_w["difficulty"]),
                        exercises_json=json.dumps(updates.get("exercises", global_w["exercises"])),
                        owner_id=trainer_id
                    )
                    db.add(workout)
                    db.commit()
                    db.refresh(workout)
                    return {
                        "id": workout.id,
                        "title": workout.title,
                        "duration": workout.duration,
                        "difficulty": workout.difficulty,
                        "exercises": json.loads(workout.exercises_json)
                    }
                raise HTTPException(status_code=404, detail="Workout not found")

            # Check ownership
            if workout.owner_id != trainer_id and workout.owner_id is not None:
                raise HTTPException(status_code=403, detail="Cannot edit this workout")

            # Update
            if "title" in updates: workout.title = updates["title"]
            if "duration" in updates: workout.duration = updates["duration"]
            if "difficulty" in updates: workout.difficulty = updates["difficulty"]
            if "exercises" in updates: workout.exercises_json = json.dumps(updates["exercises"])

            db.commit()
            db.refresh(workout)
            return {
                "id": workout.id,
                "title": workout.title,
                "duration": workout.duration,
                "difficulty": workout.difficulty,
                "exercises": json.loads(workout.exercises_json)
            }
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update workout: {str(e)}")
        finally:
            db.close()

    def delete_workout(self, workout_id: str, trainer_id: str) -> dict:
        """Delete a workout owned by the trainer."""
        db = get_db_session()
        try:
            workout = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()

            if not workout:
                raise HTTPException(status_code=404, detail="Workout not found")

            # Check ownership
            if workout.owner_id != trainer_id and workout.owner_id is not None:
                raise HTTPException(status_code=403, detail="Cannot delete this workout")

            db.delete(workout)
            db.commit()
            return {"status": "success", "message": "Workout deleted"}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to delete workout: {str(e)}")
        finally:
            db.close()

    def assign_workout(self, assignment: dict) -> dict:
        """Assign a workout to a client's schedule."""
        client_id = assignment.get("client_id")
        workout_id = assignment.get("workout_id")
        date_str = assignment.get("date")

        db = get_db_session()
        try:
            # Resolve workout
            workout_orm = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()

            if not workout_orm:
                if workout_id in WORKOUTS_DB:
                    workout_data = WORKOUTS_DB[workout_id]
                    title = workout_data["title"]
                    difficulty = workout_data["difficulty"]
                else:
                    raise HTTPException(status_code=404, detail="Workout not found")
            else:
                title = workout_orm.title
                difficulty = workout_orm.difficulty

            # Clean existing - Delete ALL events for this day to prevent conflicts
            db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == client_id,
                ClientScheduleORM.date == date_str
            ).delete(synchronize_session=False)

            # Assign
            new_event = ClientScheduleORM(
                client_id=client_id,
                date=date_str,
                title=title,
                type="workout",
                completed=False,
                workout_id=workout_id,
                details=difficulty
            )
            db.add(new_event)
            db.commit()
            db.refresh(new_event)

            return {"status": "success"}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to assign workout: {str(e)}")
        finally:
            db.close()


# Singleton instance for easy import
workout_service = WorkoutService()

def get_workout_service() -> WorkoutService:
    """Dependency injection helper."""
    return workout_service
