"""
Client Service - handles client profile management, data retrieval, and premium status.
"""
from .base import (
    HTTPException, uuid, json, logging, date, datetime, timedelta,
    get_db_session, UserORM, ClientProfileORM, ClientScheduleORM,
    ClientDietSettingsORM, ClientDietLogORM, ClientExerciseLogORM
)
from models import ClientData, ClientProfileUpdate
from data import CLIENT_DATA

logger = logging.getLogger("gym_app")


class ClientService:
    """Service for managing client profiles and data."""

    def get_client(self, client_id: str, get_workout_details_fn=None) -> ClientData:
        """Get complete client data including profile, schedule, diet, and today's workout."""
        db = get_db_session()
        try:
            logger.debug(f"get_client called for {client_id}")

            # Get User for username
            user = db.query(UserORM).filter(UserORM.id == client_id).first()
            if not user:
                raise HTTPException(status_code=404, detail="User not found")

            # 1. Get Profile
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()

            # MIGRATION / SEEDING LOGIC
            if not profile:
                logger.info(f"ClientProfile {client_id} not found. Seeding from memory/defaults...")
                # Try to find in memory CLIENT_DATA (backward compatibility/mocking)
                mem_user = CLIENT_DATA.get(client_id, {
                    "name": None,
                    "streak": 0,
                    "gems": 0,
                    "health_score": 0
                })

                # Fetch User to get username
                user_orm = db.query(UserORM).filter(UserORM.id == client_id).first()
                default_name = user_orm.username if user_orm else "New User"
                logger.debug(f"client_id={client_id}, user_orm={user_orm}, username={user_orm.username if user_orm else 'None'}, default_name={default_name}")
                logger.debug(f"mem_user name={mem_user.get('name')}")

                # Create Profile in Unified DB
                profile = ClientProfileORM(
                    id=client_id, # PK is client_id (1-to-1 with User)
                    name=mem_user.get("name") if mem_user.get("name") and mem_user.get("name") != "New User" else default_name,
                    streak=mem_user["streak"],
                    gems=mem_user["gems"],
                    health_score=mem_user.get("health_score", 0),
                    plan="Hypertrophy",
                    status="On Track",
                    last_seen="Today"
                )
                db.add(profile)

                # Seed Calendar from mock data
                if "calendar" in mem_user and "events" in mem_user["calendar"]:
                    for event in mem_user["calendar"]["events"]:
                        db_event = ClientScheduleORM(
                            client_id=client_id, # Link to client
                            date=event["date"],
                            title=event["title"],
                            type=event["type"],
                            completed=event.get("completed", False),
                            workout_id=event.get("workout_id"),
                            details=event.get("details", "")
                        )
                        db.add(db_event)

                # Seed Diet
                if "progress" in mem_user:
                    prog = mem_user["progress"]
                    macros = prog.get("macros", {})
                    hydration = prog.get("hydration", {})

                    diet = ClientDietSettingsORM(
                        id=client_id,
                        calories_target=macros.get("calories", {}).get("target", 2000),
                        protein_target=macros.get("protein", {}).get("target", 150),
                        carbs_target=macros.get("carbs", {}).get("target", 200),
                        fat_target=macros.get("fat", {}).get("target", 70),
                        hydration_target=hydration.get("target", 2500),
                        consistency_target=prog.get("consistency_target", 80),
                        calories_current=macros.get("calories", {}).get("current", 0),
                        protein_current=macros.get("protein", {}).get("current", 0),
                        carbs_current=macros.get("carbs", {}).get("current", 0),
                        fat_current=macros.get("fat", {}).get("current", 0),
                        hydration_current=hydration.get("current", 0)
                    )
                    db.add(diet)

                db.commit()
                db.refresh(profile)

            # --- FETCH DATA ---

            # 2. Get Diet / Progress
            diet_settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()

            if not diet_settings:
                # Create default settings if missing
                diet_settings = ClientDietSettingsORM(
                    id=client_id,
                    calories_target=2000,
                    protein_target=150,
                    carbs_target=200,
                    fat_target=70,
                    hydration_target=2000,
                    consistency_target=80,
                    calories_current=0,
                    protein_current=0,
                    carbs_current=0,
                    fat_current=0,
                    hydration_current=0
                )
                db.add(diet_settings)
                db.commit()
                db.refresh(diet_settings)

            # --- DYNAMIC HEALTH SCORE CALCULATION ---
            if diet_settings:
                def calc_score(current, target):
                    if target == 0: return 0
                    # Cap at 100%
                    return min(100, (current / target) * 100)

                s_cals = calc_score(diet_settings.calories_current, diet_settings.calories_target)
                s_prot = calc_score(diet_settings.protein_current, diet_settings.protein_target)
                s_carb = calc_score(diet_settings.carbs_current, diet_settings.carbs_target)
                s_fat = calc_score(diet_settings.fat_current, diet_settings.fat_target)
                s_hydro = calc_score(diet_settings.hydration_current, diet_settings.hydration_target)

                logger.debug(f"Health Score Calc - Cals: {diet_settings.calories_current}/{diet_settings.calories_target} -> {s_cals}")
                logger.debug(f"Health Score Calc - Prot: {diet_settings.protein_current}/{diet_settings.protein_target} -> {s_prot}")
                logger.debug(f"Health Score Calc - Hydro: {diet_settings.hydration_current}/{diet_settings.hydration_target} -> {s_hydro}")

                # Weighted Average
                # Cals: 40%, Protein: 30%, Hydration: 10%, Carbs: 10%, Fat: 10%
                health_score = (s_cals * 0.4) + (s_prot * 0.3) + (s_hydro * 0.1) + (s_carb * 0.1) + (s_fat * 0.1)
                logger.debug(f"Total Health Score: {health_score}")

                # Update Profile
                profile.health_score = int(health_score)
                db.commit() # Save the new score

            progress_data = None
            if diet_settings:
                progress_data = {
                    "photos": [
                        "https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?w=150&h=200&fit=crop",
                        "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=150&h=200&fit=crop"
                    ],
                    "macros": {
                        "calories": {"current": diet_settings.calories_current, "target": diet_settings.calories_target},
                        "protein": {"current": diet_settings.protein_current, "target": diet_settings.protein_target},
                        "carbs": {"current": diet_settings.carbs_current, "target": diet_settings.carbs_target},
                        "fat": {"current": diet_settings.fat_current, "target": diet_settings.fat_target}
                    },
                    "hydration": {"current": diet_settings.hydration_current, "target": diet_settings.hydration_target},
                    "consistency_target": diet_settings.consistency_target,
                    # Mock history and logs for now (could fetch from DietLogORM)
                    "weekly_history": [1800, 2100, 1950, 2200, 2000, 1850, 1450]
                }

                # Fetch real diet logs
                today_logs = db.query(ClientDietLogORM).filter(
                    ClientDietLogORM.client_id == client_id,
                    ClientDietLogORM.date == date.today().isoformat()
                ).all()

                diet_log_map = {}
                for log in today_logs:
                    if log.meal_type not in diet_log_map:
                        diet_log_map[log.meal_type] = []
                    diet_log_map[log.meal_type].append({
                        "meal": log.meal_name,
                        "cals": log.calories,
                        "time": log.time
                    })

                progress_data["diet_log"] = diet_log_map

            # 3. Get Calendar / Schedule
            events_orm = db.query(ClientScheduleORM).filter(ClientScheduleORM.client_id == client_id).all()
            events = []
            for e in events_orm:
                events.append({
                    "id": e.id,
                    "date": e.date,
                    "title": e.title or "Untitled",
                    "type": e.type or "event",
                    "completed": e.completed,
                    "workout_id": e.workout_id,
                    "details": e.details or ""
                })

            calendar_data = {
                "current_month": "October 2023", # Dynamic in real app
                "events": events
            }

            # Construct ClientData
            todays_workout = None
            today_str = date.today().isoformat()

            # Check if there is a workout event today
            today_event = next((e for e in events if e["date"] == today_str and e["type"] == "workout"), None)

            if today_event and today_event.get("workout_id") and get_workout_details_fn:
                try:
                    # Use passed function to get workout details
                    todays_workout = get_workout_details_fn(today_event["workout_id"], db_session=db)

                    if todays_workout:
                        # Inject completion status
                        todays_workout["completed"] = today_event.get("completed", False)

                        # --- INJECT PERFORMANCE LOGS ---
                        logs = db.query(ClientExerciseLogORM).filter(
                            ClientExerciseLogORM.client_id == client_id,
                            ClientExerciseLogORM.date == today_str,
                            ClientExerciseLogORM.workout_id == today_event["workout_id"]
                        ).all()

                        if logs:
                            logs_by_ex = {}
                            for log in logs:
                                if log.exercise_name not in logs_by_ex:
                                    logs_by_ex[log.exercise_name] = {}
                                logs_by_ex[log.exercise_name][log.set_number] = log

                            for ex in todays_workout["exercises"]:
                                ex_name = ex.get("name")
                                if ex_name in logs_by_ex:
                                    ex_logs = logs_by_ex[ex_name]
                                    num_sets = ex.get("sets", 3)
                                    performance = []
                                    for i in range(1, num_sets + 1):
                                        if i in ex_logs:
                                            log = ex_logs[i]
                                            performance.append({
                                                "reps": log.reps,
                                                "weight": log.weight,
                                                "completed": True
                                            })
                                        else:
                                            # Pre-fill with last known weight for this exercise/set
                                            last_log = db.query(ClientExerciseLogORM).filter(
                                                ClientExerciseLogORM.client_id == client_id,
                                                ClientExerciseLogORM.exercise_name == ex_name,
                                                ClientExerciseLogORM.set_number == i + 1
                                            ).order_by(ClientExerciseLogORM.date.desc(), ClientExerciseLogORM.id.desc()).first()

                                            last_weight = last_log.weight if last_log else ""

                                            performance.append({
                                                "reps": "",
                                                "weight": last_weight,
                                                "completed": False
                                            })
                                    ex["performance"] = performance
                except Exception as e:
                    logger.warning(f"Could not fetch details for workout {today_event['workout_id']}: {e}")

            # PRIORITIZE SNAPSHOT FROM DB IF COMPLETED
            if today_event and today_event.get("completed") and today_event.get("details"):
                 try:
                    details_content = today_event["details"]
                    if details_content.startswith("["): # JSON snapshot
                        saved_exercises = json.loads(details_content)
                        if todays_workout:
                            todays_workout["exercises"] = saved_exercises
                 except Exception as e:
                     logger.error(f"Error loading saved workout snapshot: {e}")

            # --- CALCULATE STREAK ---
            streak = self._calculate_client_streak(client_id, db)

            # --- GENERATE DAILY QUESTS ---
            daily_quests = self._generate_daily_quests(
                client_id=client_id,
                db=db,
                today_event=today_event,
                diet_settings=diet_settings,
                today_logs=today_logs if diet_settings else []
            )

            return ClientData(
                id=client_id,
                username=user.username,
                name=profile.name or "Unknown User",
                email=profile.email,
                streak=streak,
                gems=profile.gems,
                health_score=profile.health_score,
                todays_workout=todays_workout,
                daily_quests=daily_quests,
                progress=progress_data if progress_data else None,
                calendar=calendar_data
            )
        finally:
            db.close()

    def _calculate_client_streak(self, client_id: str, db) -> int:
        """Calculate client's workout streak based on completed scheduled workouts."""
        streak = 0
        try:
            today = datetime.now().date()
            current_date = today

            logger.debug(f"[CLIENT_STREAK] Starting streak calculation for client {client_id}, today={today}")

            # Go backwards from today, counting consecutive days
            while True:
                date_str = current_date.isoformat()

                # Check if there's a workout scheduled for this day
                day_event = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.client_id == client_id,
                    ClientScheduleORM.date == date_str,
                    ClientScheduleORM.type == "workout"
                ).first()

                logger.debug(f"[CLIENT_STREAK] {date_str}: day_event={day_event is not None}, completed={day_event.completed if day_event else 'N/A'}")

                if day_event:
                    # There's a workout scheduled for this day
                    if day_event.completed:
                        # Workout completed, continue streak
                        streak += 1
                        logger.debug(f"[CLIENT_STREAK] {date_str}: Completed! Streak now = {streak}")
                    else:
                        # Workout not completed
                        if current_date < today:
                            # Past day with incomplete workout - break streak
                            logger.debug(f"[CLIENT_STREAK] {date_str}: Past day not completed, breaking streak")
                            break
                        else:
                            # Today's workout not done yet - don't count but don't break
                            logger.debug(f"[CLIENT_STREAK] {date_str}: Today not completed yet, not counting")
                            pass
                else:
                    # No workout scheduled (rest day) - continue counting
                    logger.debug(f"[CLIENT_STREAK] {date_str}: Rest day, continuing")

                # Move to previous day
                current_date = current_date - timedelta(days=1)

                # Safety limit: don't go back more than 365 days
                if (today - current_date).days > 365:
                    logger.debug(f"[CLIENT_STREAK] Reached 365 day limit, stopping. Final streak = {streak}")
                    break

            logger.debug(f"[CLIENT_STREAK] Final calculated streak = {streak}")
        except Exception as e:
            logger.error(f"[CLIENT_STREAK] Error calculating client streak: {e}", exc_info=True)
            streak = 0

        return streak

    def _generate_daily_quests(self, client_id: str, db, today_event, diet_settings, today_logs) -> list:
        """Generate dynamic daily quests based on client's actual progress."""
        quests = []

        # Quest 1: Complete Today's Workout
        workout_completed = today_event and today_event.get("completed", False) if today_event else False
        quests.append({
            "text": "Complete today's workout",
            "xp": 50,
            "completed": workout_completed
        })

        # Quest 2: Log at least 3 meals
        meals_logged = len(today_logs) if today_logs else 0
        quests.append({
            "text": f"Log 3 meals ({meals_logged}/3)",
            "xp": 30,
            "completed": meals_logged >= 3
        })

        # Quest 3: Hit calorie target (within 10%)
        if diet_settings:
            calories_current = diet_settings.calories_current
            calories_target = diet_settings.calories_target
            within_range = abs(calories_current - calories_target) <= (calories_target * 0.1)
            quests.append({
                "text": f"Hit calorie target ({calories_current}/{calories_target})",
                "xp": 40,
                "completed": within_range and calories_current > 0
            })

        # Quest 4: Meet protein goal
        if diet_settings:
            protein_current = diet_settings.protein_current
            protein_target = diet_settings.protein_target
            quests.append({
                "text": f"Meet protein goal ({protein_current}g/{protein_target}g)",
                "xp": 35,
                "completed": protein_current >= protein_target
            })

        return quests

    def update_client_profile(self, profile_update: ClientProfileUpdate, client_id: str) -> dict:
        """Update a client's profile information."""
        db = get_db_session()
        try:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if not profile:
                raise HTTPException(status_code=404, detail="Client PROFILE not found (update)")

            if profile_update.name is not None:
                profile.name = profile_update.name
            if profile_update.email is not None:
                profile.email = profile_update.email

            db.commit()
            return {"status": "success", "message": "Profile updated"}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update profile: {str(e)}")
        finally:
            db.close()

    def toggle_premium_status(self, client_id: str) -> dict:
        """Toggle premium status for a client."""
        logger.debug(f"Entering toggle_premium_status for {client_id}")
        try:
            db = get_db_session()
        except Exception as e:
            logger.critical(f"CRITICAL ERROR creating DB session: {e}")
            raise HTTPException(status_code=500, detail="Database Connection Failed")

        try:
            logger.debug(f"Toggling premium for {client_id}")
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()

            if not profile:
                # Create default profile if missing (Lazy Init)
                logger.debug(f"Profile missing for {client_id}, creating new one.")
                user = db.query(UserORM).filter(UserORM.id == client_id).first()
                if not user:
                    logger.debug(f"User {client_id} not found in UserORM table.")
                    raise HTTPException(status_code=404, detail="User not found")

                profile = ClientProfileORM(
                    id=client_id,
                    name=user.username,
                    streak=0,
                    gems=0,
                    health_score=0,
                    plan="Standard",
                    status="Active",
                    last_seen="Never",
                    is_premium=False
                )
                db.add(profile)
                db.commit() # Commit to get ID
                db.refresh(profile)

            # Toggle
            current_status = profile.is_premium
            profile.is_premium = not current_status
            db.commit()
            db.refresh(profile)

            logger.debug(f"Premium status changed from {current_status} to {profile.is_premium}")

            return {
                "status": "success",
                "client_id": client_id,
                "is_premium": profile.is_premium,
                "message": f"User is now {'PREMIUM' if profile.is_premium else 'STANDARD'}"
            }
        except Exception as e:
            import traceback
            error_details = traceback.format_exc()
            logger.error(f"ERROR toggling premium: {e}\n{error_details}")
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")
        finally:
            db.close()


# Singleton instance
client_service = ClientService()

def get_client_service() -> ClientService:
    """Dependency injection helper."""
    return client_service
