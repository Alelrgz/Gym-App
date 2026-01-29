"""
Exercise Service - handles exercise CRUD operations.
"""
import json
from .base import (
    HTTPException, uuid, logging,
    get_db_session, ExerciseORM
)

logger = logging.getLogger("gym_app")


class ExerciseService:
    """Service for managing exercises."""

    def get_exercises(self, trainer_id: str) -> list:
        """Get all exercises accessible to a trainer (global + personal)."""
        db = get_db_session()
        try:
            # Fetch Global (owner_id is None) AND Personal (owner_id == trainer_id)
            exercises = db.query(ExerciseORM).filter(
                (ExerciseORM.owner_id == None) | (ExerciseORM.owner_id == trainer_id)
            ).all()

            # Deduplication: Personal overrides Global if names match
            exercise_map = {}
            for ex in exercises:
                if ex.owner_id is None:
                    exercise_map[ex.name] = ex
                else:
                    # Personal always overwrites
                    exercise_map[ex.name] = ex

            return [self._exercise_to_dict(ex) for ex in exercise_map.values()]
        finally:
            db.close()

    def _exercise_to_dict(self, ex: ExerciseORM) -> dict:
        """Convert exercise ORM to dict with all fields."""
        return {
            "id": ex.id,
            "name": ex.name,
            "muscle_group": ex.muscle,  # Alias for frontend compatibility
            "muscle": ex.muscle,
            "type": ex.type,
            "video_id": ex.video_id,
            "video_url": ex.video_url,
            "thumbnail_url": ex.thumbnail_url,
            "description": ex.description,
            "default_duration": ex.default_duration or 60,
            "difficulty": ex.difficulty or "intermediate",
            "steps": json.loads(ex.steps_json) if ex.steps_json else [],
            "owner_id": ex.owner_id
        }

    def create_exercise(self, exercise: dict, trainer_id: str) -> dict:
        """Create a new personal exercise."""
        db = get_db_session()
        try:
            new_id = str(uuid.uuid4())
            video_id = exercise.get("video_id") or "InclineDBPress"

            # Handle steps as JSON
            steps = exercise.get("steps", [])
            steps_json = json.dumps(steps) if steps else None

            db_ex = ExerciseORM(
                id=new_id,
                name=exercise["name"],
                muscle=exercise.get("muscle") or exercise.get("muscle_group", "strength"),
                type=exercise.get("type", "Course"),
                video_id=video_id,
                owner_id=trainer_id,
                # Extended fields
                description=exercise.get("description"),
                default_duration=exercise.get("default_duration"),
                difficulty=exercise.get("difficulty"),
                thumbnail_url=exercise.get("thumbnail_url"),
                video_url=exercise.get("video_url"),
                steps_json=steps_json
            )
            db.add(db_ex)
            db.commit()
            db.refresh(db_ex)
            return self._exercise_to_dict(db_ex)
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to create exercise: {str(e)}")
        finally:
            db.close()

    def update_exercise(self, exercise_id: str, updates: dict, trainer_id: str) -> dict:
        """Update an existing exercise or fork a global one."""
        db = get_db_session()
        try:
            ex = db.query(ExerciseORM).filter(ExerciseORM.id == exercise_id).first()
            if not ex:
                raise HTTPException(status_code=404, detail="Exercise not found")

            # Handle steps specially
            if "steps" in updates:
                updates["steps_json"] = json.dumps(updates.pop("steps"))

            # Handle muscle_group alias
            if "muscle_group" in updates:
                updates["muscle"] = updates.pop("muscle_group")

            # If trainer owns it, update directly
            if ex.owner_id == trainer_id:
                for key, value in updates.items():
                    if hasattr(ex, key):
                        setattr(ex, key, value)
                db.commit()
                db.refresh(ex)
                return self._exercise_to_dict(ex)

            # If it's global (owner_id is None), check if we already have a personal fork
            if ex.owner_id is None:
                # Check for existing fork by name
                existing_fork = db.query(ExerciseORM).filter(
                    ExerciseORM.name == ex.name,
                    ExerciseORM.owner_id == trainer_id
                ).first()

                if existing_fork:
                    # Update fork
                    for key, value in updates.items():
                        if hasattr(existing_fork, key):
                            setattr(existing_fork, key, value)
                    db.commit()
                    db.refresh(existing_fork)
                    return self._exercise_to_dict(existing_fork)
                else:
                    # Create new fork with all fields
                    new_id = str(uuid.uuid4())
                    new_ex = ExerciseORM(
                        id=new_id,
                        name=updates.get("name", ex.name),
                        muscle=updates.get("muscle", ex.muscle),
                        type=updates.get("type", ex.type),
                        video_id=updates.get("video_id", ex.video_id),
                        owner_id=trainer_id,
                        description=updates.get("description", ex.description),
                        default_duration=updates.get("default_duration", ex.default_duration),
                        difficulty=updates.get("difficulty", ex.difficulty),
                        thumbnail_url=updates.get("thumbnail_url", ex.thumbnail_url),
                        video_url=updates.get("video_url", ex.video_url),
                        steps_json=updates.get("steps_json", ex.steps_json)
                    )
                    db.add(new_ex)
                    db.commit()
                    db.refresh(new_ex)
                    return self._exercise_to_dict(new_ex)

            raise HTTPException(status_code=403, detail="Cannot edit exercise (Permission denied)")
        finally:
            db.close()

    def delete_exercise(self, exercise_id: str, trainer_id: str) -> dict:
        """Delete a personal exercise."""
        db = get_db_session()
        try:
            ex = db.query(ExerciseORM).filter(ExerciseORM.id == exercise_id).first()
            if not ex:
                raise HTTPException(status_code=404, detail="Exercise not found")

            if ex.owner_id != trainer_id:
                raise HTTPException(status_code=403, detail="Can only delete your own exercises")

            db.delete(ex)
            db.commit()
            return {"status": "success", "message": "Exercise deleted"}
        finally:
            db.close()


# Singleton instance
exercise_service = ExerciseService()

def get_exercise_service() -> ExerciseService:
    """Dependency injection helper."""
    return exercise_service
