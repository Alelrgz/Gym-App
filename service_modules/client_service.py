"""
Client Service - handles client profile management, data retrieval, and premium status.
"""
from .base import (
    HTTPException, uuid, json, logging, date, datetime, timedelta,
    get_db_session, UserORM, ClientProfileORM, ClientScheduleORM,
    ClientDietSettingsORM, ClientDietLogORM, ClientExerciseLogORM,
    DailyQuestCompletionORM, ClientDailyDietSummaryORM, WeightHistoryORM
)
from models import ClientData, ClientProfileUpdate
from data import CLIENT_DATA, EXERCISE_LIBRARY

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
                        hydration_current=hydration.get("current", 0),
                        last_reset_date=date.today().isoformat()
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
                    hydration_current=0,
                    last_reset_date=date.today().isoformat()
                )
                db.add(diet_settings)
                db.commit()
                db.refresh(diet_settings)

            # --- DAILY RESET CHECK ---
            # Reset current values if it's a new day
            today_str = date.today().isoformat()
            if diet_settings and hasattr(diet_settings, 'last_reset_date'):
                if diet_settings.last_reset_date and diet_settings.last_reset_date != today_str:
                    # SAVE yesterday's data to daily summary BEFORE resetting
                    yesterday_date = diet_settings.last_reset_date

                    # Only save if there's meaningful data (calories > 0)
                    if diet_settings.calories_current > 0:
                        # Check if summary already exists
                        existing_summary = db.query(ClientDailyDietSummaryORM).filter(
                            ClientDailyDietSummaryORM.client_id == client_id,
                            ClientDailyDietSummaryORM.date == yesterday_date
                        ).first()

                        if not existing_summary:
                            yesterday_summary = ClientDailyDietSummaryORM(
                                client_id=client_id,
                                date=yesterday_date,
                                total_calories=diet_settings.calories_current,
                                total_protein=diet_settings.protein_current,
                                total_carbs=diet_settings.carbs_current,
                                total_fat=diet_settings.fat_current,
                                total_hydration=diet_settings.hydration_current,
                                target_calories=diet_settings.calories_target,
                                target_protein=diet_settings.protein_target,
                                target_carbs=diet_settings.carbs_target,
                                target_fat=diet_settings.fat_target
                            )
                            db.add(yesterday_summary)
                            logger.info(f"Saved daily diet summary for {client_id} on {yesterday_date}: {diet_settings.calories_current} kcal")

                    logger.info(f"New day detected for {client_id}. Resetting daily macros. Last reset: {diet_settings.last_reset_date}, Today: {today_str}")
                    diet_settings.calories_current = 0
                    diet_settings.protein_current = 0
                    diet_settings.carbs_current = 0
                    diet_settings.fat_current = 0
                    diet_settings.hydration_current = 0
                    diet_settings.last_reset_date = today_str
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

                logger.debug(f"Health Score Calc - Cals: {diet_settings.calories_current}/{diet_settings.calories_target} -> {s_cals}")
                logger.debug(f"Health Score Calc - Prot: {diet_settings.protein_current}/{diet_settings.protein_target} -> {s_prot}")

                # Weighted Average
                # Cals: 45%, Protein: 35%, Carbs: 10%, Fat: 10%
                health_score = (s_cals * 0.45) + (s_prot * 0.35) + (s_carb * 0.1) + (s_fat * 0.1)
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
                    # Weekly health scores (Mon-Sun) for consistency chart
                    "weekly_health_scores": self._get_weekly_health_scores(client_id, db, diet_settings)
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
            logger.info(f"Checking completed workout: today_event={today_event is not None}, completed={today_event.get('completed') if today_event else 'N/A'}, has_details={bool(today_event.get('details')) if today_event else 'N/A'}, todays_workout={todays_workout is not None}")
            if today_event and today_event.get("completed") and today_event.get("details"):
                 try:
                    details_content = today_event["details"]
                    logger.info(f"Loading workout details for completed workout, content length: {len(details_content)}")
                    parsed_details = json.loads(details_content)

                    if isinstance(parsed_details, list):
                        # Legacy format: details is just the exercises array
                        logger.info("Parsed as legacy format (list)")
                        if todays_workout:
                            todays_workout["exercises"] = parsed_details
                    elif isinstance(parsed_details, dict):
                        # New format: { exercises: [...], coop: { partner, partner_exercises } }
                        logger.info(f"Parsed as new format (dict), has coop: {'coop' in parsed_details}")
                        if todays_workout:
                            if "exercises" in parsed_details:
                                todays_workout["exercises"] = parsed_details["exercises"]
                            # Include CO-OP details in the response
                            todays_workout["details"] = details_content
                            logger.info(f"Set todays_workout details, has coop in details: {'coop' in details_content}")
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
                weight=profile.weight,
                todays_workout=todays_workout,
                daily_quests=daily_quests,
                progress=progress_data if progress_data else None,
                calendar=calendar_data
            )
        finally:
            db.close()

    def _calculate_client_streak(self, client_id: str, db) -> int:
        """Calculate client's DAY streak - consecutive days with ALL scheduled workouts completed."""
        streak = 0
        try:
            today = datetime.now().date()
            current_date = today
            days_checked = 0
            consecutive_empty = 0  # Track consecutive days with no workouts

            logger.debug(f"[DAY_STREAK] Starting day streak calculation for client {client_id}, today={today}")

            # Go backwards day by day
            while days_checked < 365:
                date_str = current_date.isoformat()
                is_today = current_date == today

                # Get all scheduled workouts for this day
                scheduled_workouts = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.client_id == client_id,
                    ClientScheduleORM.date == date_str,
                    ClientScheduleORM.type == "workout"
                ).all()

                total_scheduled = len(scheduled_workouts)
                completed_count = sum(1 for w in scheduled_workouts if w.completed)

                logger.debug(f"[DAY_STREAK] {date_str}: {completed_count}/{total_scheduled} completed")

                if total_scheduled == 0:
                    # No workouts scheduled - allow rest days but break after 3+ consecutive empty days
                    consecutive_empty += 1
                    if consecutive_empty > 3:
                        logger.debug(f"[DAY_STREAK] {consecutive_empty} consecutive empty days, breaking streak")
                        break
                    logger.debug(f"[DAY_STREAK] No workouts scheduled, skipping day ({consecutive_empty} empty)")
                elif completed_count == total_scheduled:
                    # All scheduled workouts completed - count this day
                    consecutive_empty = 0  # Reset empty counter
                    streak += 1
                    logger.debug(f"[DAY_STREAK] All workouts completed! Streak = {streak}")
                else:
                    # Not all workouts completed
                    if is_today:
                        # Today - don't break yet, still time to complete
                        logger.debug(f"[DAY_STREAK] Today incomplete but day not over yet")
                    else:
                        # Past day with incomplete workouts - break streak
                        logger.debug(f"[DAY_STREAK] Past day incomplete, breaking streak")
                        break

                # Move to previous day
                current_date = current_date - timedelta(days=1)
                days_checked += 1

            logger.debug(f"[DAY_STREAK] Final calculated day streak = {streak}")
        except Exception as e:
            logger.error(f"[DAY_STREAK] Error calculating day streak: {e}", exc_info=True)
            streak = 0

        return streak

    def _generate_daily_quests(self, client_id: str, db, today_event, diet_settings, today_logs) -> list:
        """Generate dynamic daily quests based on client's actual progress."""
        today_str = date.today().isoformat()

        # Get any manual quest completions for today
        manual_completions = db.query(DailyQuestCompletionORM).filter(
            DailyQuestCompletionORM.client_id == client_id,
            DailyQuestCompletionORM.date == today_str,
            DailyQuestCompletionORM.completed == True
        ).all()
        manual_complete_indices = {mc.quest_index for mc in manual_completions}

        quests = []

        # Quest 0: Complete Today's Workout
        workout_completed = today_event and today_event.get("completed", False) if today_event else False
        quests.append({
            "text": "Complete today's workout",
            "xp": 50,
            "completed": workout_completed or (0 in manual_complete_indices)
        })

        # Quest 1: Log at least 3 meals
        meals_logged = len(today_logs) if today_logs else 0
        quests.append({
            "text": f"Log 3 meals ({meals_logged}/3)",
            "xp": 30,
            "completed": meals_logged >= 3 or (1 in manual_complete_indices)
        })

        # Quest 2: Hit calorie target (within 10%)
        if diet_settings:
            calories_current = diet_settings.calories_current
            calories_target = diet_settings.calories_target
            within_range = abs(calories_current - calories_target) <= (calories_target * 0.1)
            quests.append({
                "text": f"Hit calorie target ({calories_current}/{calories_target})",
                "xp": 40,
                "completed": (within_range and calories_current > 0) or (2 in manual_complete_indices)
            })

        # Quest 3: Meet protein goal
        if diet_settings:
            protein_current = diet_settings.protein_current
            protein_target = diet_settings.protein_target
            quests.append({
                "text": f"Meet protein goal ({protein_current}g/{protein_target}g)",
                "xp": 35,
                "completed": protein_current >= protein_target or (3 in manual_complete_indices)
            })

        return quests

    def _get_weekly_health_scores(self, client_id: str, db, diet_settings) -> list:
        """Calculate health scores for each day of the current week (Mon-Sun)."""
        today = date.today()
        # Get Monday of current week (weekday() returns 0 for Monday)
        monday = today - timedelta(days=today.weekday())

        weekly_scores = []

        # Get targets from diet settings (or use defaults)
        cal_target = diet_settings.calories_target if diet_settings else 2000
        prot_target = diet_settings.protein_target if diet_settings else 150
        carb_target = diet_settings.carbs_target if diet_settings else 200
        fat_target = diet_settings.fat_target if diet_settings else 70

        def calc_score(current, target):
            if target == 0:
                return 0
            ratio = current / target
            if ratio > 1:
                # Penalize going over (mirror the deficit penalty)
                return max(0, 100 - abs(ratio - 1) * 100)
            return ratio * 100

        for i in range(7):  # Monday to Sunday
            day = monday + timedelta(days=i)
            day_str = day.isoformat()

            # Skip future days
            if day > today:
                weekly_scores.append(0)
                continue

            # For TODAY: use real-time values from diet_settings
            if day == today and diet_settings:
                cals = diet_settings.calories_current or 0
                prot = diet_settings.protein_current or 0
                carbs = diet_settings.carbs_current or 0
                fat = diet_settings.fat_current or 0

                if cals > 0:  # Only calculate if there's any data
                    s_cals = calc_score(cals, cal_target)
                    s_prot = calc_score(prot, prot_target)
                    s_carb = calc_score(carbs, carb_target)
                    s_fat = calc_score(fat, fat_target)
                    health_score = (s_cals * 0.45) + (s_prot * 0.35) + (s_carb * 0.1) + (s_fat * 0.1)
                    weekly_scores.append(int(health_score))
                else:
                    weekly_scores.append(0)
                continue

            # For PAST days: use daily summaries
            summary = db.query(ClientDailyDietSummaryORM).filter(
                ClientDailyDietSummaryORM.client_id == client_id,
                ClientDailyDietSummaryORM.date == day_str
            ).first()

            if not summary or summary.total_calories == 0:
                weekly_scores.append(0)
                continue

            s_cals = calc_score(summary.total_calories, cal_target)
            s_prot = calc_score(summary.total_protein, prot_target)
            s_carb = calc_score(summary.total_carbs, carb_target)
            s_fat = calc_score(summary.total_fat, fat_target)

            health_score = (s_cals * 0.45) + (s_prot * 0.35) + (s_carb * 0.1) + (s_fat * 0.1)
            weekly_scores.append(int(health_score))

        return weekly_scores

    def update_client_profile(self, profile_update: ClientProfileUpdate, client_id: str) -> dict:
        """Update a client's profile information."""
        db = get_db_session()
        try:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if not profile:
                raise HTTPException(status_code=404, detail="Client PROFILE not found (update)")

            if profile_update.name is not None:
                profile.name = profile_update.name
                # Also sync UserORM.username so display name is consistent
                user = db.query(UserORM).filter(UserORM.id == client_id).first()
                if user:
                    user.username = profile_update.name
            if profile_update.email is not None:
                profile.email = profile_update.email
            if profile_update.weight is not None:
                profile.weight = profile_update.weight

                # Calculate body composition if body_fat_pct provided
                body_fat_pct = getattr(profile_update, 'body_fat_pct', None)
                fat_mass = None
                lean_mass = None

                if body_fat_pct is not None:
                    profile.body_fat_pct = body_fat_pct
                    fat_mass = round(profile_update.weight * body_fat_pct / 100, 1)
                    lean_mass = round(profile_update.weight - fat_mass, 1)
                    profile.fat_mass = fat_mass
                    profile.lean_mass = lean_mass

                # Also log to weight history with body composition
                weight_entry = WeightHistoryORM(
                    client_id=client_id,
                    weight=profile_update.weight,
                    body_fat_pct=body_fat_pct,
                    fat_mass=fat_mass,
                    lean_mass=lean_mass,
                    recorded_at=datetime.now().isoformat()
                )
                db.add(weight_entry)

            db.commit()
            return {"status": "success", "message": "Profile updated"}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update profile: {str(e)}")
        finally:
            db.close()

    def get_weight_history(self, client_id: str, period: str = "month") -> dict:
        """Get client's weight history for charting."""
        db = get_db_session()
        try:
            # Determine date range based on period
            now = datetime.now()
            if period == "week":
                start_date = now - timedelta(days=7)
            elif period == "month":
                start_date = now - timedelta(days=30)
            elif period == "year":
                start_date = now - timedelta(days=365)
            else:
                start_date = now - timedelta(days=30)

            # Get weight entries
            entries = db.query(WeightHistoryORM).filter(
                WeightHistoryORM.client_id == client_id,
                WeightHistoryORM.recorded_at >= start_date.isoformat()
            ).order_by(WeightHistoryORM.recorded_at.asc()).all()

            # Format for chart with body composition
            # For year view, aggregate by month; for month, by day; for week, show all entries
            raw_data = []
            for entry in entries:
                recorded = datetime.fromisoformat(entry.recorded_at)
                raw_data.append({
                    "recorded": recorded,
                    "date": recorded.strftime("%Y-%m-%d"),
                    "weight": round(entry.weight, 1),
                    "body_fat_pct": round(entry.body_fat_pct, 1) if entry.body_fat_pct else None,
                    "fat_mass": round(entry.fat_mass, 1) if entry.fat_mass else None,
                    "lean_mass": round(entry.lean_mass, 1) if entry.lean_mass else None,
                })

            data = []
            if period == "year" and raw_data:
                # Aggregate by month — use latest entry per month
                from collections import OrderedDict
                months = OrderedDict()
                for d in raw_data:
                    key = d["recorded"].strftime("%Y-%m")
                    months[key] = d  # last entry wins
                for key, d in months.items():
                    data.append({
                        "date": d["date"],
                        "weight": d["weight"],
                        "body_fat_pct": d["body_fat_pct"],
                        "fat_mass": d["fat_mass"],
                        "lean_mass": d["lean_mass"],
                        "label": d["recorded"].strftime("%b %y")
                    })
            elif period == "month" and raw_data:
                # Aggregate by day — use latest entry per day
                from collections import OrderedDict
                days = OrderedDict()
                for d in raw_data:
                    key = d["date"]
                    days[key] = d
                for key, d in days.items():
                    data.append({
                        "date": d["date"],
                        "weight": d["weight"],
                        "body_fat_pct": d["body_fat_pct"],
                        "fat_mass": d["fat_mass"],
                        "lean_mass": d["lean_mass"],
                        "label": d["recorded"].strftime("%d %b")
                    })
            else:
                # Week: show all entries
                for d in raw_data:
                    data.append({
                        "date": d["date"],
                        "weight": d["weight"],
                        "body_fat_pct": d["body_fat_pct"],
                        "fat_mass": d["fat_mass"],
                        "lean_mass": d["lean_mass"],
                        "label": d["recorded"].strftime("%d %b %H:%M") if len(raw_data) > 7 else d["recorded"].strftime("%a %d")
                    })

            # Helper to calculate stats for a metric
            def calc_stats(values):
                valid = [v for v in values if v is not None]
                if not valid:
                    return {"start": None, "current": None, "change": None, "min": None, "max": None}
                return {
                    "start": valid[0],
                    "current": valid[-1],
                    "change": round(valid[-1] - valid[0], 1),
                    "min": min(valid),
                    "max": max(valid)
                }

            # Calculate stats for each metric
            weight_stats = calc_stats([d["weight"] for d in data])
            weight_stats["trend"] = "up" if (weight_stats["change"] or 0) > 0 else "down" if (weight_stats["change"] or 0) < 0 else "stable"

            body_fat_stats = calc_stats([d["body_fat_pct"] for d in data])
            lean_mass_stats = calc_stats([d["lean_mass"] for d in data])

            return {
                "period": period,
                "data": data,
                "stats": {
                    "weight": weight_stats,
                    "body_fat_pct": body_fat_stats,
                    "lean_mass": lean_mass_stats
                }
            }
        except Exception as e:
            logger.error(f"Error getting weight history: {e}")
            return {"period": period, "data": [], "stats": {}}
        finally:
            db.close()

    def _get_exercise_category(self, exercise_name: str) -> str:
        """Map exercise name to category (upper_body, lower_body, cardio)."""
        # Build exercise name to muscle mapping from EXERCISE_LIBRARY
        exercise_muscle_map = {ex['name'].lower(): ex['muscle'] for ex in EXERCISE_LIBRARY}

        # Define muscle groups per category
        UPPER_BODY_MUSCLES = {'chest', 'back', 'shoulders', 'biceps', 'triceps'}
        LOWER_BODY_MUSCLES = {'legs', 'quads', 'hamstrings', 'glutes', 'calves'}
        CARDIO_MUSCLES = {'cardio', 'abs'}

        # Try exact match first
        name_lower = exercise_name.lower()
        muscle = exercise_muscle_map.get(name_lower)

        if not muscle:
            # Try fuzzy match - check if any exercise name is contained
            for ex_name, ex_muscle in exercise_muscle_map.items():
                if ex_name in name_lower or name_lower in ex_name:
                    muscle = ex_muscle
                    break

        if not muscle:
            # Guess from common keywords
            keywords_upper = ['press', 'curl', 'row', 'pull', 'push', 'fly', 'raise', 'dip', 'tricep', 'bicep', 'chest', 'back', 'shoulder']
            keywords_lower = ['squat', 'lunge', 'leg', 'calf', 'deadlift', 'rdl', 'glute', 'ham']
            keywords_cardio = ['run', 'sprint', 'hiit', 'cardio', 'bike', 'row', 'jump', 'plank', 'crunch', 'twist', 'abs']

            for kw in keywords_lower:
                if kw in name_lower:
                    return 'lower_body'
            for kw in keywords_cardio:
                if kw in name_lower:
                    return 'cardio'
            for kw in keywords_upper:
                if kw in name_lower:
                    return 'upper_body'

            return 'upper_body'  # Default to upper body

        muscle_lower = muscle.lower()
        if muscle_lower in UPPER_BODY_MUSCLES:
            return 'upper_body'
        elif muscle_lower in LOWER_BODY_MUSCLES:
            return 'lower_body'
        elif muscle_lower in CARDIO_MUSCLES:
            return 'cardio'
        else:
            return 'upper_body'  # Default

    def get_strength_progress(self, client_id: str, period: str = "month") -> dict:
        """Calculate strength progress over time for charting, broken down by category."""
        db = get_db_session()
        try:
            from sqlalchemy import func, or_

            # Determine date range based on period
            now = datetime.now()
            if period == "week":
                start_date = now - timedelta(days=7)
            elif period == "month":
                start_date = now - timedelta(days=30)
            elif period == "year":
                start_date = now - timedelta(days=365)
            else:
                start_date = now - timedelta(days=30)

            # Get all exercise logs (weight, duration, distance)
            logs = db.query(
                ClientExerciseLogORM.date,
                ClientExerciseLogORM.exercise_name,
                func.max(ClientExerciseLogORM.weight).label('max_weight'),
                func.max(ClientExerciseLogORM.duration).label('max_duration'),
                func.max(ClientExerciseLogORM.distance).label('max_distance')
            ).filter(
                ClientExerciseLogORM.client_id == client_id,
                ClientExerciseLogORM.date >= start_date.strftime("%Y-%m-%d"),
                or_(
                    ClientExerciseLogORM.weight > 0,
                    ClientExerciseLogORM.duration > 0,
                    ClientExerciseLogORM.distance > 0
                )
            ).group_by(
                ClientExerciseLogORM.date,
                ClientExerciseLogORM.exercise_name
            ).order_by(
                ClientExerciseLogORM.date
            ).all()

            empty_result = {
                "progress": 0,
                "trend": "stable",
                "data": [],
                "categories": {
                    "upper_body": {"progress": 0, "trend": "stable", "data": []},
                    "lower_body": {"progress": 0, "trend": "stable", "data": []},
                    "cardio": {"progress": 0, "trend": "stable", "data": []}
                }
            }

            if not logs:
                return empty_result

            # Group by category and date
            # For upper/lower body: use weight
            # For cardio: use duration + distance (cardio score)
            category_date_data = {
                'upper_body': {},
                'lower_body': {},
                'cardio': {}
            }
            all_dates = set()

            for log in logs:
                category = self._get_exercise_category(log.exercise_name)

                if category == 'cardio':
                    # For cardio: calculate a "cardio score" from duration and distance
                    # Score = duration (mins) + distance (km) * 5 (weighted to balance)
                    duration = log.max_duration or 0
                    distance = log.max_distance or 0
                    cardio_score = duration + (distance * 5)  # 5km ~ 25-30 min jog

                    if cardio_score > 0:
                        if log.date not in category_date_data['cardio']:
                            category_date_data['cardio'][log.date] = []
                        category_date_data['cardio'][log.date].append(cardio_score)
                        all_dates.add(log.date)
                else:
                    # For upper/lower body: use weight
                    if log.max_weight and log.max_weight > 0:
                        if log.date not in category_date_data[category]:
                            category_date_data[category][log.date] = []
                        category_date_data[category][log.date].append(log.max_weight)
                        all_dates.add(log.date)

            sorted_dates = sorted(all_dates)

            def calculate_category_progress(date_data: dict, metric_name: str = "strength") -> dict:
                """Calculate progress for a single category."""
                if not date_data:
                    return {"progress": 0, "trend": "stable", "data": []}

                category_dates = sorted(date_data.keys())
                if not category_dates:
                    return {"progress": 0, "trend": "stable", "data": []}

                # Get baseline (first day's average)
                baseline = sum(date_data[category_dates[0]]) / len(date_data[category_dates[0]])
                if baseline == 0:
                    baseline = 1

                data_points = []
                for date_str in sorted_dates:  # Use all dates for alignment
                    if date_str in date_data:
                        daily_avg = sum(date_data[date_str]) / len(date_data[date_str])
                        pct_change = ((daily_avg - baseline) / baseline) * 100
                    else:
                        # No data for this category on this date - use null for gaps
                        pct_change = None

                    parsed_date = datetime.strptime(date_str, "%Y-%m-%d")
                    data_points.append({
                        "date": date_str,
                        "strength": round(pct_change, 1) if pct_change is not None else None,
                        "label": parsed_date.strftime("%d %b") if period != "year" else parsed_date.strftime("%b %y")
                    })

                # Calculate overall progress (last valid vs first)
                valid_points = [p for p in data_points if p["strength"] is not None]
                if len(valid_points) >= 2:
                    overall_progress = valid_points[-1]["strength"]
                elif len(valid_points) == 1:
                    overall_progress = valid_points[0]["strength"]
                else:
                    overall_progress = 0

                # Determine trend
                if overall_progress > 2:
                    trend = "up"
                elif overall_progress < -2:
                    trend = "down"
                else:
                    trend = "stable"

                return {
                    "progress": round(overall_progress, 1),
                    "trend": trend,
                    "data": data_points
                }

            # Calculate progress for each category
            categories = {
                "upper_body": calculate_category_progress(category_date_data['upper_body']),
                "lower_body": calculate_category_progress(category_date_data['lower_body']),
                "cardio": calculate_category_progress(category_date_data['cardio'])
            }

            # Calculate overall progress (average of categories with data)
            active_categories = [c for c in categories.values() if c["data"] and any(p["strength"] is not None for p in c["data"])]
            if active_categories:
                overall_progress = sum(c["progress"] for c in active_categories) / len(active_categories)
            else:
                overall_progress = 0

            # Overall trend
            if overall_progress > 2:
                overall_trend = "up"
            elif overall_progress < -2:
                overall_trend = "down"
            else:
                overall_trend = "stable"

            # Also build legacy combined data for backwards compatibility
            all_date_data = {}
            for log in logs:
                if log.max_weight and log.max_weight > 0:
                    if log.date not in all_date_data:
                        all_date_data[log.date] = []
                    all_date_data[log.date].append(log.max_weight)

            legacy_result = calculate_category_progress(all_date_data) if all_date_data else {"data": []}

            # Fetch strength goals set by trainer
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            goals = {
                "upper": profile.strength_goal_upper if profile else None,
                "lower": profile.strength_goal_lower if profile else None,
                "cardio": profile.strength_goal_cardio if profile else None
            }

            return {
                "progress": round(overall_progress, 1),
                "trend": overall_trend,
                "data": legacy_result["data"],  # Legacy combined data
                "categories": categories,
                "goals": goals
            }
        except Exception as e:
            logger.error(f"Error calculating strength progress: {e}")
            return {
                "progress": 0,
                "trend": "stable",
                "data": [],
                "categories": {
                    "upper_body": {"progress": 0, "trend": "stable", "data": []},
                    "lower_body": {"progress": 0, "trend": "stable", "data": []},
                    "cardio": {"progress": 0, "trend": "stable", "data": []}
                },
                "goals": {"upper": None, "lower": None, "cardio": None}
            }
        finally:
            db.close()

    def get_exercise_details(self, client_id: str, category: str = "upper_body", period: str = "month") -> dict:
        """Get detailed exercise history for a specific category with actual values."""
        db = get_db_session()
        try:
            from sqlalchemy import func, or_

            logger.info(f"[ExerciseDetails] client_id={client_id}, category={category}, period={period}")

            # Determine date range
            now = datetime.now()
            if period == "week":
                start_date = now - timedelta(days=7)
            elif period == "month":
                start_date = now - timedelta(days=30)
            elif period == "year":
                start_date = now - timedelta(days=365)
            else:
                start_date = now - timedelta(days=30)

            logger.info(f"[ExerciseDetails] Date range: {start_date.strftime('%Y-%m-%d')} to {now.strftime('%Y-%m-%d')}")

            # Get all exercise logs for the period
            logs = db.query(
                ClientExerciseLogORM.date,
                ClientExerciseLogORM.exercise_name,
                func.max(ClientExerciseLogORM.weight).label('max_weight'),
                func.max(ClientExerciseLogORM.reps).label('max_reps'),
                func.max(ClientExerciseLogORM.duration).label('max_duration'),
                func.max(ClientExerciseLogORM.distance).label('max_distance')
            ).filter(
                ClientExerciseLogORM.client_id == client_id,
                ClientExerciseLogORM.date >= start_date.strftime("%Y-%m-%d"),
                or_(
                    ClientExerciseLogORM.weight > 0,
                    ClientExerciseLogORM.duration > 0,
                    ClientExerciseLogORM.distance > 0
                )
            ).group_by(
                ClientExerciseLogORM.date,
                ClientExerciseLogORM.exercise_name
            ).order_by(
                ClientExerciseLogORM.date
            ).all()

            logger.info(f"[ExerciseDetails] Found {len(logs) if logs else 0} log entries")

            if not logs:
                return {"exercises": [], "category": category, "debug": {"client_id": client_id, "logs_found": 0}}

            # Filter by category and group by exercise
            exercise_data = {}

            for log in logs:
                ex_category = self._get_exercise_category(log.exercise_name)
                logger.debug(f"[ExerciseDetails] Exercise '{log.exercise_name}' -> category '{ex_category}' (requested: '{category}')")
                if ex_category != category:
                    continue

                ex_name = log.exercise_name
                if ex_name not in exercise_data:
                    exercise_data[ex_name] = {
                        "name": ex_name,
                        "category": category,
                        "history": [],
                        "current": None,
                        "best": None,
                        "progress_pct": 0
                    }

                # Parse date
                parsed_date = datetime.strptime(log.date, "%Y-%m-%d")
                date_label = parsed_date.strftime("%d %b")

                if category == "cardio":
                    # Cardio: track duration and distance
                    duration = log.max_duration or 0
                    distance = log.max_distance or 0
                    entry = {
                        "date": log.date,
                        "label": date_label,
                        "duration": round(duration, 1),
                        "distance": round(distance, 2),
                        "display": f"{int(duration)}min" + (f" / {distance:.1f}km" if distance > 0 else "")
                    }
                    exercise_data[ex_name]["history"].append(entry)

                    # Track best (longest duration)
                    if not exercise_data[ex_name]["best"] or duration > exercise_data[ex_name]["best"]["duration"]:
                        exercise_data[ex_name]["best"] = entry
                else:
                    # Upper/Lower body: track weight and reps
                    weight = log.max_weight or 0
                    reps = log.max_reps or 0
                    entry = {
                        "date": log.date,
                        "label": date_label,
                        "weight": round(weight, 1),
                        "reps": int(reps),
                        "display": f"{weight:.1f}kg" + (f" x{int(reps)}" if reps > 0 else "")
                    }
                    exercise_data[ex_name]["history"].append(entry)

                    # Track best (heaviest weight)
                    if not exercise_data[ex_name]["best"] or weight > exercise_data[ex_name]["best"]["weight"]:
                        exercise_data[ex_name]["best"] = entry

            # Calculate progress for each exercise
            for ex_name, data in exercise_data.items():
                if len(data["history"]) >= 1:
                    data["current"] = data["history"][-1]

                if len(data["history"]) >= 2:
                    first = data["history"][0]
                    last = data["history"][-1]

                    if category == "cardio":
                        first_val = first["duration"] + (first["distance"] * 5)
                        last_val = last["duration"] + (last["distance"] * 5)
                    else:
                        first_val = first["weight"]
                        last_val = last["weight"]

                    if first_val > 0:
                        data["progress_pct"] = round(((last_val - first_val) / first_val) * 100, 1)

            # Convert to list and sort by most recent activity
            exercises = list(exercise_data.values())
            exercises.sort(key=lambda x: x["history"][-1]["date"] if x["history"] else "", reverse=True)

            logger.info(f"[ExerciseDetails] Returning {len(exercises)} exercises for category {category}")
            return {
                "category": category,
                "exercises": exercises,
                "debug": {"client_id": client_id, "total_logs": len(logs), "matched_exercises": len(exercises)}
            }
        except Exception as e:
            logger.error(f"Error getting exercise details: {e}")
            return {"exercises": [], "category": category, "debug": {"error": str(e)}}
        finally:
            db.close()

    def get_diet_consistency(self, client_id: str, period: str = "month") -> dict:
        """Get client's diet consistency data for charting."""
        db = get_db_session()
        try:
            from sqlalchemy import func

            # Determine date range
            now = datetime.now()
            if period == "week":
                start_date = now - timedelta(days=7)
            elif period == "month":
                start_date = now - timedelta(days=30)
            elif period == "year":
                start_date = now - timedelta(days=365)
            else:
                start_date = now - timedelta(days=30)

            # Get daily diet summaries
            summaries = db.query(ClientDailyDietSummaryORM).filter(
                ClientDailyDietSummaryORM.client_id == client_id,
                ClientDailyDietSummaryORM.date >= start_date.strftime("%Y-%m-%d")
            ).order_by(ClientDailyDietSummaryORM.date).all()

            data = []
            total_score = 0
            for summary in summaries:
                score = summary.health_score or 0
                total_score += score
                data.append({
                    "date": summary.date,
                    "score": score,
                    "calories": summary.total_cals or 0,
                    "protein": summary.total_protein or 0,
                    "carbs": summary.total_carbs or 0,
                    "fat": summary.total_fat or 0
                })

            # Calculate average and streak
            avg_score = round(total_score / len(data), 1) if data else 0

            # Calculate current streak (consecutive days with score >= 70)
            streak = 0
            for entry in reversed(data):
                if entry["score"] >= 70:
                    streak += 1
                else:
                    break

            return {
                "data": data,
                "average_score": avg_score,
                "current_streak": streak,
                "total_days": len(data)
            }
        except Exception as e:
            logger.error(f"Error getting diet consistency: {e}")
            return {"data": [], "average_score": 0, "current_streak": 0, "total_days": 0}
        finally:
            db.close()

    def get_week_streak_data(self, client_id: str) -> dict:
        """Get client's day streak data with last 14 days visualization."""
        db = get_db_session()
        try:
            today = datetime.now().date()

            days_data = []

            # Check last 14 days (from oldest to newest)
            for i in range(13, -1, -1):
                day = today - timedelta(days=i)
                date_str = day.isoformat()
                is_today = i == 0

                # Get all scheduled workouts for this day
                scheduled_workouts = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.client_id == client_id,
                    ClientScheduleORM.date == date_str,
                    ClientScheduleORM.type == "workout"
                ).all()

                total_scheduled = len(scheduled_workouts)
                completed_count = sum(1 for w in scheduled_workouts if w.completed)

                # Day is completed only if there were workouts scheduled AND all are done
                day_completed = (total_scheduled > 0) and (completed_count == total_scheduled)

                days_data.append({
                    "date": date_str,
                    "day_name": day.strftime("%a"),
                    "completed": day_completed,
                    "is_today": is_today,
                    "total": total_scheduled,
                    "done": completed_count
                })

            # Calculate current streak
            streak = self._calculate_client_streak(client_id, db)

            return {
                "current_streak": streak,
                "days": days_data
            }
        except Exception as e:
            logger.error(f"Error getting week streak data: {e}")
            return {"current_streak": 0, "weeks": []}
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

    def toggle_quest_completion(self, client_id: str, quest_index: int) -> dict:
        """Toggle a daily quest's completion status."""
        db = get_db_session()
        try:
            today_str = date.today().isoformat()

            # Check if there's an existing completion record
            existing = db.query(DailyQuestCompletionORM).filter(
                DailyQuestCompletionORM.client_id == client_id,
                DailyQuestCompletionORM.date == today_str,
                DailyQuestCompletionORM.quest_index == quest_index
            ).first()

            if existing:
                # Toggle the existing record
                existing.completed = not existing.completed
                existing.completed_at = datetime.now().isoformat() if existing.completed else None
                new_status = existing.completed
            else:
                # Create new completion record
                new_completion = DailyQuestCompletionORM(
                    client_id=client_id,
                    date=today_str,
                    quest_index=quest_index,
                    completed=True,
                    completed_at=datetime.now().isoformat()
                )
                db.add(new_completion)
                new_status = True

            # Update gems based on completion status
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if profile:
                # Gem rewards based on quest index (matching XP values)
                xp_rewards = {0: 50, 1: 30, 2: 40, 3: 35}
                gem_amount = xp_rewards.get(quest_index, 25)
                if new_status:
                    # Award gems when completing
                    profile.gems = (profile.gems or 0) + gem_amount
                else:
                    # Remove gems when uncompleting (prevent exploit)
                    profile.gems = max(0, (profile.gems or 0) - gem_amount)

            db.commit()

            return {
                "success": True,
                "quest_index": quest_index,
                "completed": new_status,
                "message": f"Quest {'completed' if new_status else 'uncompleted'}"
            }
        except Exception as e:
            db.rollback()
            logger.error(f"Error toggling quest: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to toggle quest: {str(e)}")
        finally:
            db.close()


# Singleton instance
client_service = ClientService()

def get_client_service() -> ClientService:
    """Dependency injection helper."""
    return client_service
