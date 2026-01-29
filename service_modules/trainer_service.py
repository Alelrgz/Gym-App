"""
Trainer Service - handles trainer data retrieval, client roster, and streak calculation.
"""
from .base import (
    HTTPException, json, logging, date, datetime, timedelta,
    get_db_session, UserORM, ClientProfileORM, ClientScheduleORM,
    TrainerScheduleORM, WorkoutORM
)
from models import TrainerData
from data import TRAINER_DATA

logger = logging.getLogger("gym_app")


class TrainerService:
    """Service for managing trainer data and operations."""

    def get_trainer(self, trainer_id: str, get_workouts_fn=None, get_splits_fn=None) -> TrainerData:
        """Get complete trainer data including clients, schedule, and streak."""
        db = get_db_session()
        try:
            # Get trainer's gym (gym_owner_id)
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            gym_id = trainer.gym_owner_id if trainer else None

            # Get all clients from the same gym
            if gym_id:
                client_profiles = db.query(ClientProfileORM).filter(ClientProfileORM.gym_id == gym_id).all()
            else:
                # Fallback: if trainer has no gym, show clients assigned to this trainer
                client_profiles = db.query(ClientProfileORM).filter(ClientProfileORM.trainer_id == trainer_id).all()

            client_ids = [p.id for p in client_profiles]
            clients_orm = db.query(UserORM).filter(UserORM.id.in_(client_ids)).all() if client_ids else []

            clients = []
            active_count = 0
            at_risk_count = 0
            today = date.today()

            # Fetch Trainer Schedule
            schedule_orm = db.query(TrainerScheduleORM).filter(TrainerScheduleORM.trainer_id == trainer_id).all()
            schedule = []
            for s in schedule_orm:
                schedule.append({
                    "id": str(s.id),
                    "date": s.date,
                    "time": s.time,
                    "title": s.title,
                    "subtitle": s.subtitle or "",
                    "type": s.type,
                    "duration": s.duration if s.duration else 60,
                    "completed": s.completed
                })

            # Create a lookup for profiles
            profile_lookup = {p.id: p for p in client_profiles}

            for c in clients_orm:
                # Fetch profile from lookup
                profile = profile_lookup.get(c.id)

                # Check Last Workout Date
                last_workout = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.client_id == c.id,
                    ClientScheduleORM.type == "workout",
                    ClientScheduleORM.completed == True
                ).order_by(ClientScheduleORM.date.desc()).first()

                last_active_date = None
                days_inactive = 0

                if last_workout:
                    try:
                        last_active_date = datetime.strptime(last_workout.date, "%Y-%m-%d").date()
                        days_inactive = (today - last_active_date).days
                    except:
                        days_inactive = 99 # Error parsing date
                else:
                    days_inactive = 99 # No workouts ever

                # Determine Status
                status = "Active"
                if days_inactive > 5:
                    status = "At Risk"

                # Update counters
                if status == "At Risk":
                    at_risk_count += 1
                else:
                    active_count += 1

                clients.append({
                    "id": c.id,
                    "name": profile.name if profile and profile.name else c.username,
                    "status": status,
                    "last_seen": f"{days_inactive} days ago" if days_inactive < 99 else "Never",
                    "plan": profile.plan if profile and profile.plan else "Standard",
                    "is_premium": profile.is_premium if profile else False
                })

            # --- FETCH MY WORKOUT (TRAINER) ---
            todays_workout = None
            try:
                today_str = datetime.now().strftime("%Y-%m-%d")
                my_event = db.query(TrainerScheduleORM).filter(
                    TrainerScheduleORM.trainer_id == trainer_id,
                    TrainerScheduleORM.date == today_str,
                    TrainerScheduleORM.workout_id != None
                ).first()

                if my_event:
                    w_orm = db.query(WorkoutORM).filter(WorkoutORM.id == my_event.workout_id).first()
                    if w_orm:
                        exercises = []
                        if w_orm.exercises_json:
                            try:
                                exercises = json.loads(w_orm.exercises_json)
                            except:
                                pass

                        todays_workout = {
                            "id": w_orm.id,
                            "title": w_orm.title,
                            "duration": w_orm.duration,
                            "difficulty": w_orm.difficulty,
                            "exercises": exercises,
                            "completed": my_event.completed
                        }

                        # PRIORITIZE SNAPSHOT FROM DB IF COMPLETED (like client)
                        if my_event.completed and my_event.details:
                            try:
                                saved_exercises = json.loads(my_event.details)
                                todays_workout["exercises"] = saved_exercises
                            except Exception as e:
                                logger.error(f"Error loading saved trainer workout snapshot: {e}")
            except Exception as e:
                logger.error(f"Error fetching trainer workout: {e}")

            # --- CALCULATE STREAK ---
            streak = self._calculate_trainer_streak(trainer_id, db)

            video_library = TRAINER_DATA["video_library"]
            return TrainerData(
                id=trainer_id,
                clients=clients,
                video_library=video_library,
                active_clients=active_count,
                at_risk_clients=at_risk_count,
                schedule=schedule,
                todays_workout=todays_workout,
                workouts=get_workouts_fn(trainer_id) if get_workouts_fn else [],
                splits=get_splits_fn(trainer_id) if get_splits_fn else [],
                streak=streak
            )
        finally:
            db.close()

    def _calculate_trainer_streak(self, trainer_id: str, db) -> int:
        """Calculate trainer's workout streak based on completed scheduled workouts."""
        streak = 0
        try:
            today = datetime.now().date()
            current_date = today

            logger.debug(f"[STREAK] Starting streak calculation for trainer {trainer_id}, today={today}")

            # Go backwards from today, counting consecutive days
            while True:
                date_str = current_date.isoformat()

                # Check if there's a workout scheduled for this day
                day_event = db.query(TrainerScheduleORM).filter(
                    TrainerScheduleORM.trainer_id == trainer_id,
                    TrainerScheduleORM.date == date_str,
                    TrainerScheduleORM.workout_id != None
                ).first()

                logger.debug(f"[STREAK] {date_str}: day_event={day_event is not None}, completed={day_event.completed if day_event else 'N/A'}")

                if day_event:
                    # There's a workout scheduled for this day
                    if day_event.completed:
                        # Workout completed, continue streak
                        streak += 1
                        logger.debug(f"[STREAK] {date_str}: Completed! Streak now = {streak}")
                    else:
                        # Workout not completed
                        if current_date < today:
                            # Past day with incomplete workout - break streak
                            logger.debug(f"[STREAK] {date_str}: Past day not completed, breaking streak")
                            break
                        else:
                            # Today's workout not done yet - don't count but don't break
                            logger.debug(f"[STREAK] {date_str}: Today not completed yet, not counting")
                            pass
                else:
                    # No workout scheduled (rest day)
                    logger.debug(f"[STREAK] {date_str}: Rest day, continuing")

                # Move to previous day
                current_date = current_date - timedelta(days=1)

                # Safety limit: don't go back more than 365 days
                if (today - current_date).days > 365:
                    logger.debug(f"[STREAK] Reached 365 day limit, stopping. Final streak = {streak}")
                    break

            logger.debug(f"[STREAK] Final calculated streak = {streak}")
        except Exception as e:
            logger.error(f"[STREAK] Error calculating trainer streak: {e}", exc_info=True)
            streak = 0

        return streak


# Singleton instance
trainer_service = TrainerService()

def get_trainer_service() -> TrainerService:
    """Dependency injection helper."""
    return trainer_service
