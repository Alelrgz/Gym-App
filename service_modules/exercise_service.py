"""
Exercise Service - handles exercise CRUD operations.
"""
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

            return list(exercise_map.values())
        finally:
            db.close()

    def create_exercise(self, exercise: dict, trainer_id: str) -> dict:
        """Create a new personal exercise."""
        db = get_db_session()
        try:
            new_id = str(uuid.uuid4())
            video_id = exercise.get("video_id") or "InclineDBPress"

            db_ex = ExerciseORM(
                id=new_id,
                name=exercise["name"],
                muscle=exercise["muscle"],
                type=exercise["type"],
                video_id=video_id,
                owner_id=trainer_id
            )
            db.add(db_ex)
            db.commit()
            db.refresh(db_ex)
            return db_ex
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

            # If trainer owns it, update directly
            if ex.owner_id == trainer_id:
                for key, value in updates.items():
                    if hasattr(ex, key) and value is not None:
                        setattr(ex, key, value)
                db.commit()
                db.refresh(ex)
                return ex

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
                        if hasattr(existing_fork, key) and value is not None:
                            setattr(existing_fork, key, value)
                    db.commit()
                    db.refresh(existing_fork)
                    return existing_fork
                else:
                    # Create new fork
                    new_id = str(uuid.uuid4())
                    new_ex = ExerciseORM(
                        id=new_id,
                        name=updates.get("name", ex.name),
                        muscle=updates.get("muscle", ex.muscle),
                        type=updates.get("type", ex.type),
                        video_id=updates.get("video_id", ex.video_id),
                        owner_id=trainer_id
                    )
                    db.add(new_ex)
                    db.commit()
                    db.refresh(new_ex)
                    return new_ex

            raise HTTPException(status_code=403, detail="Cannot edit exercise (Permission denied)")
        finally:
            db.close()


# Singleton instance
exercise_service = ExerciseService()

def get_exercise_service() -> ExerciseService:
    """Dependency injection helper."""
    return exercise_service
