"""
Split Service - handles weekly split CRUD and assignment operations.
"""
from .base import (
    HTTPException, uuid, json, logging, datetime, timedelta,
    get_db_session, WeeklySplitORM, WorkoutORM, UserORM,
    TrainerScheduleORM, ClientScheduleORM
)
from data import SPLITS_DB

logger = logging.getLogger("gym_app")


class SplitService:
    """Service for managing weekly splits."""

    def __init__(self, workout_service=None):
        """Initialize with optional workout service for assignment delegation."""
        self._workout_service = workout_service

    def get_splits(self, trainer_id: str) -> list:
        """Get all splits accessible to a trainer (global + personal)."""
        db = get_db_session()
        try:
            splits = db.query(WeeklySplitORM).filter(
                (WeeklySplitORM.owner_id == None) | (WeeklySplitORM.owner_id == trainer_id)
            ).all()

            results = []
            for s in splits:
                results.append({
                    "id": s.id,
                    "name": s.name,
                    "description": s.description,
                    "days_per_week": s.days_per_week,
                    "schedule": json.loads(s.schedule_json)
                })
            return results
        finally:
            db.close()

    def create_split(self, split_data: dict, trainer_id: str) -> dict:
        """Create a new weekly split."""
        db = get_db_session()
        try:
            new_id = str(uuid.uuid4())
            db_split = WeeklySplitORM(
                id=new_id,
                name=split_data["name"],
                description=split_data.get("description", ""),
                days_per_week=split_data.get("days_per_week", 7),
                schedule_json=json.dumps(split_data["schedule"]),
                owner_id=trainer_id
            )
            db.add(db_split)
            db.commit()
            db.refresh(db_split)
            return {
                "id": db_split.id,
                "name": db_split.name,
                "description": db_split.description,
                "days_per_week": db_split.days_per_week,
                "schedule": json.loads(db_split.schedule_json)
            }
        except Exception as e:
            print(f"ERROR in create_split: {e}")
            import traceback
            traceback.print_exc()
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to create split: {str(e)}")
        finally:
            db.close()

    def update_split(self, split_id: str, updates: dict, trainer_id: str) -> dict:
        """Update an existing split or create a shadow copy of a global one."""
        db = get_db_session()
        try:
            split = db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()

            if not split:
                # Check memory for global split
                if split_id in SPLITS_DB:
                    # Shadow it
                    global_s = SPLITS_DB[split_id]
                    split = WeeklySplitORM(
                        id=split_id,
                        name=updates.get("name", global_s["name"]),
                        description=updates.get("description", global_s.get("description", "")),
                        days_per_week=updates.get("days_per_week", global_s["days_per_week"]),
                        schedule_json=json.dumps(updates.get("schedule", global_s["schedule"])),
                        owner_id=trainer_id
                    )
                    db.add(split)
                    db.commit()
                    db.refresh(split)
                    return {
                        "id": split.id,
                        "name": split.name,
                        "description": split.description,
                        "days_per_week": split.days_per_week,
                        "schedule": json.loads(split.schedule_json)
                    }
                raise HTTPException(status_code=404, detail="Split not found")

            if split.owner_id != trainer_id and split.owner_id is not None:
                raise HTTPException(status_code=403, detail="Cannot edit this split")

            if "name" in updates: split.name = updates["name"]
            if "description" in updates: split.description = updates["description"]
            if "days_per_week" in updates: split.days_per_week = updates["days_per_week"]
            if "schedule" in updates: split.schedule_json = json.dumps(updates["schedule"])

            db.commit()
            db.refresh(split)
            return {
                "id": split.id,
                "name": split.name,
                "description": split.description,
                "days_per_week": split.days_per_week,
                "schedule": json.loads(split.schedule_json)
            }
        finally:
            db.close()

    def delete_split(self, split_id: str, trainer_id: str) -> dict:
        """Delete a split owned by the trainer."""
        db = get_db_session()
        try:
            split = db.query(WeeklySplitORM).filter(
                WeeklySplitORM.id == split_id,
                WeeklySplitORM.owner_id == trainer_id
            ).first()

            if not split:
                # If it's global, we can't delete it
                if split_id in SPLITS_DB:
                    raise HTTPException(status_code=403, detail="Cannot delete global split")
                raise HTTPException(status_code=404, detail="Split not found or not owned by you")

            db.delete(split)
            db.commit()
            return {"status": "success", "message": "Split deleted"}
        finally:
            db.close()

    def assign_split(self, assignment: dict, trainer_id: str) -> dict:
        """Assign a split to a client or trainer's own schedule for 4 weeks."""
        client_id = assignment.get("client_id")
        split_id = assignment.get("split_id")
        start_date_str = assignment.get("start_date")

        db = get_db_session()
        try:
            # Check if trainer is assigning to themselves
            is_self_assignment = (client_id == trainer_id)

            # 1. Fetch Split (DB or Memory)
            split_schedule = None
            split_orm = db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()
            if split_orm:
                split_schedule = json.loads(split_orm.schedule_json)
            elif split_id in SPLITS_DB:
                split_schedule = SPLITS_DB[split_id]["schedule"]
            else:
                raise HTTPException(status_code=404, detail="Split not found")

            # 2. Normalize Schedule to Map { "Monday": "workout_id" }
            schedule_map = {}
            if isinstance(split_schedule, list):
                for item in split_schedule:
                    if isinstance(item, dict):
                        day = item.get("day")
                        wid = item.get("workout_id")
                        if day and wid:
                            schedule_map[day] = wid
            elif isinstance(split_schedule, dict):
                schedule_map = split_schedule
            else:
                print(f"Warning: Unknown schedule format: {type(split_schedule)}")

            # 3. Assign - default start_date to today if not provided
            if start_date_str:
                start_date = datetime.strptime(start_date_str, "%Y-%m-%d").date()
            else:
                start_date = datetime.utcnow().date()
            weekday_map = {0: "Monday", 1: "Tuesday", 2: "Wednesday", 3: "Thursday", 4: "Friday", 5: "Saturday", 6: "Sunday"}

            logs = []
            success_count = 0
            fail_count = 0

            # Validate user exists
            user = db.query(UserORM).filter(UserORM.id == client_id).first()
            if not user:
                raise HTTPException(status_code=404, detail="User not found")

            for day_offset in range(28):  # 4 Weeks
                current_date = start_date + timedelta(days=day_offset)
                day_name = weekday_map[current_date.weekday()]

                # Lookup in normalized map
                workout_id = schedule_map.get(day_name)

                # If workout_id is dict (legacy edge case), extract id
                if isinstance(workout_id, dict):
                    workout_id = workout_id.get("id")

                if workout_id and workout_id != "rest":
                    try:
                        if is_self_assignment:
                            # Assign to trainer's own schedule (TrainerScheduleORM)
                            existing_workouts = db.query(TrainerScheduleORM).filter(
                                TrainerScheduleORM.trainer_id == trainer_id,
                                TrainerScheduleORM.date == current_date.isoformat(),
                                TrainerScheduleORM.workout_id != None
                            ).all()

                            for existing in existing_workouts:
                                db.delete(existing)

                            # Get workout title for the event
                            workout = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()
                            workout_title = workout.title if workout else "Workout"

                            # Create new trainer event
                            new_event = TrainerScheduleORM(
                                trainer_id=trainer_id,
                                date=current_date.isoformat(),
                                time="08:00",
                                title=workout_title,
                                subtitle="From Split",
                                type="workout",
                                duration=60,
                                workout_id=workout_id
                            )
                            db.add(new_event)
                            db.commit()

                            logs.append(f"Assigned {workout_title} to {current_date}")
                        else:
                            # Assign to client schedule (ClientScheduleORM)
                            if self._workout_service:
                                self._workout_service.assign_workout({
                                    "client_id": client_id,
                                    "workout_id": workout_id,
                                    "date": current_date.isoformat()
                                })
                            else:
                                # Fallback: direct assignment
                                self._assign_workout_to_client(db, client_id, workout_id, current_date.isoformat())
                            logs.append(f"Assigned {workout_id} to {current_date}")

                        success_count += 1
                    except Exception as e:
                        print(f"Assign Error for {current_date}: {e}")
                        logs.append(f"Failed to assign {workout_id} on {current_date}: {str(e)}")
                        fail_count += 1

            if success_count == 0 and fail_count > 0:
                raise HTTPException(status_code=400, detail=f"Failed to assign any workouts. Errors: {logs[:3]}...")

            return {
                "status": "success",
                "message": f"Split assigned. {success_count} workouts scheduled. {fail_count} failed.",
                "logs": logs,
                "warnings": fail_count > 0
            }
        finally:
            db.close()

    def _assign_workout_to_client(self, db, client_id: str, workout_id: str, date_str: str):
        """Internal helper to assign a workout to a client's schedule."""
        from data import WORKOUTS_DB

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

        # Clean existing
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


# Singleton instance
split_service = SplitService()

def get_split_service() -> SplitService:
    """Dependency injection helper."""
    return split_service
