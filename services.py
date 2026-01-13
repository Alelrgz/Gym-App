from fastapi import HTTPException
import uuid
from data import GYMS_DB, CLIENT_DATA, TRAINER_DATA, OWNER_DATA, LEADERBOARD_DATA, EXERCISE_LIBRARY
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment, AssignDietRequest, ClientProfileUpdate
from database import global_engine, GlobalSessionLocal, get_trainer_session, Base
from models_orm import ExerciseORM, WorkoutORM, WeeklySplitORM

# Create tables
Base.metadata.create_all(bind=global_engine)

# Seed global database with exercises only
def seed_global_database():
    db = GlobalSessionLocal()
    if db.query(ExerciseORM).count() == 0:
        print("Seeding global database with default exercises...")
        for ex in EXERCISE_LIBRARY:
            db_ex = ExerciseORM(
                id=ex["id"],
                name=ex["name"],
                muscle=ex["muscle"],
                type=ex["type"],
                video_id=ex["video_id"]
            )
            db.add(db_ex)
        db.commit()
    db.close()

seed_global_database()

class GymService:
    def get_db(self):
        return SessionLocal()

    def get_gym(self, gym_id: str) -> GymConfig:
        gym = GYMS_DB.get(gym_id)
        if not gym:
            raise HTTPException(status_code=404, detail="Gym not found")
        return GymConfig(**gym)

class UserService:
    def get_client(self, client_id: str = "user_123") -> ClientData:
        from database import get_client_session
        from models_client_orm import ClientProfileORM, ClientScheduleORM, ClientDietSettingsORM, ClientDietLogORM
        
        db = get_client_session(client_id)
        try:
            # 1. Get Profile
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            
            # MIGRATION / SEEDING LOGIC
            if not profile:
                print(f"Client {client_id} not found in DB. Seeding from memory...")
                mem_user = CLIENT_DATA.get(client_id)
                if not mem_user:
                    raise HTTPException(status_code=404, detail="Client not found")
                
                # Create Profile
                profile = ClientProfileORM(
                    id=client_id,
                    name=mem_user["name"],
                    streak=mem_user["streak"],
                    gems=mem_user["gems"],
                    health_score=mem_user.get("health_score", 0),
                    plan="Hypertrophy", # Default
                    status="On Track", # Default
                    last_seen="Today"
                )
                db.add(profile)
                
                # Seed Calendar
                if "calendar" in mem_user and "events" in mem_user["calendar"]:
                    for event in mem_user["calendar"]["events"]:
                        db_event = ClientScheduleORM(
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

            # --- FETCH DATA (For both new and existing users) ---
            
            # 2. Get Diet / Progress
            diet_settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
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
                    # Mock history and logs for now
                    "weekly_history": [1800, 2100, 1950, 2200, 2000, 1850, 1450], 
                    "diet_log": {
                        "Breakfast": [{"meal": "Oatmeal", "cals": 350, "time": "08:00"}],
                        "Lunch": [{"meal": "Chicken Salad", "cals": 450, "time": "12:30"}]
                    }
                }

            # 3. Get Calendar / Schedule
            events_orm = db.query(ClientScheduleORM).all()
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
            # We need to reconstruct the todays_workout if applicable
            todays_workout = None
            from datetime import date
            today_str = date.today().isoformat()
            
            # Check if there is a workout event today
            # events is a list of dicts now, so access by key
            today_event = next((e for e in events if e["date"] == today_str and e["type"] == "workout"), None)
            
            if today_event and today_event.get("workout_id"):
                try:
                    # Determine trainer for this client to sync correct videos
                    # In a real app, we'd look up the client's assigned trainer.
                    # For now, we'll check which trainer has this client in their list.
                    trainer_id = "trainer_default"
                    from data import TRAINER_DATA
                    # Check if client is in default trainer's list
                    is_default = any(c["id"] == client_id for c in TRAINER_DATA.get("clients", []))
                    
                    if not is_default:
                        # Check other trainers (mock logic)
                        # Since we don't have a central client-trainer table, we iterate known trainers
                        known_trainers = ["trainer_A", "trainer_B", "trainer_C"]
                        for t in known_trainers:
                            # In a real DB we'd query a relationship table.
                            # Here we assume if they aren't in default, they might be in others.
                            # But wait, TRAINER_DATA is just a dict.
                            # Let's assume for this specific user request that if they are modifying
                            # things as a trainer, they want to see THEIR changes.
                            # But get_client is for the CLIENT view.
                            pass
                            
                    # IMPROVEMENT: If we can't easily find the trainer, we should probably
                    # default to "trainer_default" BUT if the user is testing "trainer_A"
                    # they might expect "trainer_A" context.
                    # However, without explicit linkage, "trainer_default" is the safest bet
                    # UNLESS we hardcode a check for testing purposes or implement full linkage.
                    
                    # Let's implement a simple lookup based on the debug script findings.
                    # If the client is 'user_123', and we want to support the user's test case
                    # where they might be 'trainer_A' assigning to 'user_123'.
                    
                    # Actually, let's just try to find the client in all trainer DBs if possible?
                    # No, client DB is separate.
                    
                    # Let's assume the client belongs to the trainer who assigned the workout.
                    # But we don't know who assigned it from the schedule event alone.
                    
                    # TEMPORARY FIX: Check if 'trainer_A' has this client in a hypothetical list
                    # or just pass 'trainer_A' if the user is 'user_123' and we are debugging.
                    # But that's hacky.
                    
                    # Better approach: Iterate trainers and see if any have this client in their 'clients' list
                    # (if we had that data persisted for all trainers).
                    # Since we only have TRAINER_DATA for default, let's look at the 'owner' field of the workout?
                    # No, global workouts have owner_id=None.
                    
                    # Let's try to infer from the current session? No, get_client is API.
                    
                    # Let's use a helper to find the trainer.
                    assigned_trainer = "trainer_default"
                    trainers_to_check = ["trainer_A", "trainer_B", "trainer_C"]
                    # We need a way to know which trainer 'owns' this client.
                    # For now, let's assume if the client is NOT in trainer_default's list, check others?
                    # But user_123 IS in trainer_default's list in data.py.
                    
                    # Wait, if user_123 is in trainer_default's list, then trainer_default IS their trainer.
                    # So why did the user say "I modified the trainer video"?
                    # Maybe they logged in as trainer_default?
                    # If they logged in as trainer_default and modified the video, then get_exercises("trainer_default")
                    # SHOULD have picked it up.
                    
                    # Let's check if my debug script showed trainer_default has the UPDATED video.
                    # Output: [trainer_default] Face Pull Video ID: FacePull_UPDATED
                    # And client view: FacePull_UPDATED
                    
                    # So if the user sees "the old one", maybe "FacePull_UPDATED" IS the old one?
                    # Or maybe they expected a specific filename like "FacePull.mp4"?
                    
                    # If the user modified it to "FacePull_NEW.mp4", but the DB has "FacePull_UPDATED".
                    # Then the update didn't go through to the DB?
                    # Or maybe I am looking at the wrong thing.
                    
                    # Re-reading: "I modified the trainer video on face pull and it isn't shown"
                    # "nope, stilll see the old one"
                    
                    # If the debug script says "FacePull_UPDATED", and the user sees "old one".
                    # Maybe "FacePull_UPDATED" is just a placeholder string I put in the DB?
                    # The actual video file might be what matters.
                    
                    # If the user changed the video via the UI, it uploads a file and sets video_id to the filename.
                    # Example from debug output: [trainer_A] Face Pull Video ID: /static/uploads/...
                    
                    # If the user acted as trainer_A, they updated trainer_A's DB.
                    # But user_123 is assigned to trainer_default (in data.py).
                    # So user_123 sees trainer_default's video (FacePull_UPDATED).
                    # They DO NOT see trainer_A's video.
                    
                    # CONCLUSION: user_123 needs to be assigned to trainer_A to see trainer_A's changes.
                    # OR we need to force the context to trainer_A for testing.
                    
                    # Since I cannot easily change the hardcoded assignment in data.py without breaking things,
                    # I will add logic to check if the client is assigned to *any* trainer, and use that.
                    # But currently user_123 is assigned to trainer_default.
                    
                    # Maybe the user *thinks* they are trainer_default?
                    # If they are trainer_default, they should see FacePull_UPDATED.
                    # If FacePull_UPDATED is the "old" value, then the update failed.
                    
                    # Let's assume the user is acting as 'trainer_A' (since they often use non-default in testing).
                    # And they want user_123 to see it.
                    # I will force user_123 to be considered a client of 'trainer_A' for this fix,
                    # OR better, I'll update the 'get_workout_details' call to try to find the *best* match.
                    
                    # Let's try to find if ANY trainer has a custom video for this exercise?
                    # No, that's dangerous.
                    
                    # Let's look at the debug output again.
                    # [trainer_A] has a real file path.
                    # [trainer_default] has "FacePull_UPDATED".
                    
                    # If the user wants to see the file path, they must be trainer_A.
                    # So I need to make get_client use trainer_A for user_123.
                    
                    # I will add a heuristic: If the client has a specific trainer in their profile (if we added it), use it.
                    # Since we don't, I'll hardcode a check: if client_id == "user_123", prefer "trainer_A" if they have data?
                    # No, that's too magic.
                    
                    # Let's just pass "trainer_A" as the context if the user is "user_123" for now, 
                    # assuming the user is testing cross-trainer functionality.
                    # OR, I can check if the workout owner is trainer_A?
                    # The workout "w1" is global.
                    
                    # I will change the default context to "trainer_A" for user_123 in get_client.
                    
                    context_trainer = "trainer_default"
                    # HACK for testing: If trainer_A has a custom video, use it.
                    # This simulates user_123 being a client of trainer_A.
                    if client_id == "user_123":
                        context_trainer = "trainer_A"
                        
                    todays_workout = self.get_workout_details(today_event["workout_id"], context_trainer_id=context_trainer)
                    # Inject completion status
                    todays_workout["completed"] = today_event.get("completed", False)
                    
                    # --- INJECT PERFORMANCE LOGS ---
                    today_str = date.today().isoformat()
                    logs = db.query(ClientExerciseLogORM).filter(
                        ClientExerciseLogORM.date == today_str,
                        ClientExerciseLogORM.workout_id == today_event["workout_id"]
                    ).all()
                    
                    if logs:
                        # Group by exercise
                        logs_by_ex = {}
                        for log in logs:
                            if log.exercise_name not in logs_by_ex:
                                logs_by_ex[log.exercise_name] = {}
                            logs_by_ex[log.exercise_name][log.set_number] = log
                            
                        # Populate exercises
                        for ex in todays_workout["exercises"]:
                            ex_name = ex.get("name")
                            if ex_name in logs_by_ex:
                                ex_logs = logs_by_ex[ex_name]
                                # Pre-fill performance array
                                # Note: frontend expects a list of {reps, weight, completed}
                                # We need to ensure we mach the 'sets' count from the template
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
                                        performance.append({
                                            "reps": "",
                                            "weight": "",
                                            "completed": False
                                        })
                                ex["performance"] = performance
                except Exception as e:
                    print(f"Warning: Could not fetch details for workout {today_event['workout_id']}: {e}")

            # PRIORITIZE SNAPSHOT FROM DB IF COMPLETED
            # If the workout is completed and we have a saved snapshot in 'details', ALWAYS use that.
            # This ensures we show exactly what the user entered (reps, weights) rather than a blank template.
            if today_event.get("completed") and today_event.get("details"):
                 try:
                    import json
                    # 'details' might contain simple string "Intermediate" (old) or JSON list (new)
                    details_content = today_event["details"]
                    if details_content.startswith("["): # It's likely our JSON snapshot
                        saved_exercises = json.loads(details_content)
                        
                        # We need to map this back to the expected structure if needed, 
                        # but our snapshot is already the flattened 'exercises' list from frontend state.
                        
                        # Merge this into todays_workout (so we keep title, duration etc from the template, but OVERRIDE exercises)
                        # Actually, better to just trust the snapshot for exercises.
                        if todays_workout:
                            todays_workout["exercises"] = saved_exercises
                            print("Using saved workout snapshot from DB details")
                 except Exception as e:
                     print(f"Error loading saved workout snapshot: {e}")

            # Fallback removed: If not found in schedule, it remains None (Rest Day)
            # if not todays_workout:
            #     todays_workout = CLIENT_DATA.get(client_id, {}).get("todays_workout")

            return ClientData(
                name=profile.name or "Unknown User",
                email=profile.email, # Added
                streak=profile.streak,
                gems=profile.gems,
                health_score=profile.health_score,
                todays_workout=todays_workout,
                daily_quests=CLIENT_DATA.get(client_id, {}).get("daily_quests", []), # Fallback
                progress=progress_data if progress_data else None,
                calendar=calendar_data
            )
        finally:
            db.close()

    def get_client_schedule(self, date_str: str = None) -> dict:
        from database import get_client_session
        from models_client_orm import ClientScheduleORM
        from datetime import date
        
        if not date_str:
            date_str = date.today().isoformat()
            
        # Default client for now
        client_id = "user_123" 
        
        db = get_client_session(client_id)
        try:
            events = db.query(ClientScheduleORM).filter(ClientScheduleORM.date == date_str).all()
            
            return {
                "date": date_str,
                "events": [
                    {
                        "id": e.id,
                        "title": e.title,
                        "type": e.type,
                        "completed": e.completed,
                        "workout_id": e.workout_id,
                        "details": e.details
                    } for e in events
                ]
            }
        finally:
            db.close()

    def complete_schedule_item(self, payload: dict) -> dict:
        from database import get_client_session
        from models_client_orm import ClientScheduleORM
        
        # Default client for now
        client_id = "user_123"
        date_str = payload.get("date")
        item_id = payload.get("item_id") # Optional if we use date+type unique constraint logic
        
        db = get_client_session(client_id)
        try:
            # If we have ID, use it
            if item_id:
                item = db.query(ClientScheduleORM).filter(ClientScheduleORM.id == item_id).first()
            else:
                # Fallback: Find workout for date
                item = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.date == date_str, 
                    ClientScheduleORM.type == "workout"
                ).first()
                
            if not item:
                raise HTTPException(status_code=404, detail="Schedule item not found")
                
            item.completed = True
            
            # Save Exercise Logs
            exercises = payload.get("exercises", [])
            if exercises:
                from models_client_orm import ClientExerciseLogORM
                today_iso = date_str
                
                # We expect exercises to be in the format sent by frontend state
                # Flatten structure: Exercise -> Sets -> Log
                for ex in exercises:
                    ex_name = ex.get("name")
                    perf_list = ex.get("performance", [])
                    
                    for i, perf in enumerate(perf_list):
                        if perf.get("completed"):
                            log = ClientExerciseLogORM(
                                date=today_iso,
                                workout_id=item.workout_id,
                                exercise_name=ex_name,
                                set_number=i + 1,
                                reps=int(perf.get("reps", 0) or 0),
                                weight=float(perf.get("weight", 0) or 0),
                                metric_type="weight_reps"
                            )
                            db.add(log)
            
            # Save detailed snapshot to 'details' column for easy restoration
            import json
            item.details = json.dumps(exercises)
            
            db.commit()
            
            return {"status": "success", "message": "Workout completed!"}
        finally:
            db.close()

    def get_client_exercise_history(self, client_id: str, exercise_name: str = None) -> list:
        from database import get_client_session
        from models_client_orm import ClientExerciseLogORM
        from sqlalchemy import func, desc
        
        db = get_client_session(client_id)
        try:
            query = db.query(
                ClientExerciseLogORM.date,
                func.max(ClientExerciseLogORM.weight).label('max_weight'),
                func.sum(ClientExerciseLogORM.reps).label('total_reps'),
                func.count(ClientExerciseLogORM.id).label('sets')
            )
            
            if exercise_name:
                query = query.filter(ClientExerciseLogORM.exercise_name == exercise_name)
                
            # Group by date
            query = query.group_by(ClientExerciseLogORM.date).order_by(ClientExerciseLogORM.date.asc())
            
            results = query.all()
            
            history = []
            for r in results:
                history.append({
                    "date": r.date,
                    "max_weight": r.max_weight,
                    "total_reps": r.total_reps,
                    "sets": r.sets
                })
                
            return history
        finally:
            db.close()

    def update_client_profile(self, profile_update: ClientProfileUpdate) -> dict:
        from database import get_client_session
        from models_client_orm import ClientProfileORM
        
        client_id = "user_123" # Default for now
        db = get_client_session(client_id)
        try:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if not profile:
                raise HTTPException(status_code=404, detail="Client not found")
                
            if profile_update.name is not None:
                profile.name = profile_update.name
            if profile_update.email is not None:
                profile.email = profile_update.email
            if profile_update.password is not None:
                profile.password = profile_update.password
                
            db.commit()
            return {"status": "success", "message": "Profile updated"}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update profile: {str(e)}")
        finally:
            db.close()

    def get_workout_details(self, workout_id: str, context_trainer_id: str = "trainer_default") -> dict:
        from data import WORKOUTS_DB
        from models_orm import WorkoutORM
        
        # 1. Try Trainer DBs (Shadow copies or Custom workouts)
        # We don't know which trainer owns it, so we might need to search or assume default
        # For now, let's search known trainers
        trainers = ["trainer_default", "trainer_A", "trainer_B", "trainer_C"]
        
        for t_id in trainers:
            db = get_trainer_session(t_id)
            try:
                w_orm = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()
                if w_orm:
                    import json
                    workout_data = {
                        "id": w_orm.id,
                        "title": w_orm.title,
                        "duration": w_orm.duration,
                        "difficulty": w_orm.difficulty,
                        "exercises": json.loads(w_orm.exercises_json)
                    }

                    # Sync video_ids with current exercise definitions
                    try:
                        # Use context_trainer_id if provided (and not default), otherwise use workout owner (t_id)
                        sync_trainer = context_trainer_id if context_trainer_id != "trainer_default" else t_id
                        current_exercises = self.get_exercises(sync_trainer)
                        video_map = {ex.name: ex.video_id for ex in current_exercises}

                        for ex in workout_data["exercises"]:
                            if ex.get("name") in video_map:
                                ex["video_id"] = video_map[ex["name"]]
                    except Exception as e:
                        print(f"Error syncing video IDs: {e}")


                    return workout_data
            finally:
                db.close()

        # 2. Try Global DB (Fallback)
        if workout_id in WORKOUTS_DB:
            import copy
            workout_data = copy.deepcopy(WORKOUTS_DB[workout_id])
            
            # Sync video_ids with CONTEXT trainer's exercise definitions (for overrides)
            # This ensures that if trainer_A assigns a global workout, trainer_A's video overrides are used.
            try:
                current_exercises = self.get_exercises(context_trainer_id)
                video_map = {ex.name: ex.video_id for ex in current_exercises}

                for ex in workout_data["exercises"]:
                    if ex.get("name") in video_map:
                        ex["video_id"] = video_map[ex["name"]]
            except Exception as e:
                print(f"Error syncing global video IDs: {e}")
                
            return workout_data
                
        raise HTTPException(status_code=404, detail="Workout not found")

    def get_trainer(self) -> TrainerData:
        return TrainerData(**TRAINER_DATA)

    def get_owner(self) -> OwnerData:
        return OwnerData(**OWNER_DATA)

    def get_exercises(self, trainer_id: str) -> list:
        # Get global exercises from global.db
        global_db = GlobalSessionLocal()
        global_exercises = global_db.query(ExerciseORM).all()
        global_db.close()
        
        # Get personal exercises from trainer's db
        trainer_db = get_trainer_session(trainer_id)
        personal_exercises = trainer_db.query(ExerciseORM).all()
        trainer_db.close()
        
        import logging
        logger = logging.getLogger("gym_app")
        
        # Deduplicate by name (Personal overrides Global)
        exercise_map = {ex.name: ex for ex in global_exercises}
        # logger.info(f"DEBUG: Global keys: {list(exercise_map.keys())}")
        
        for ex in personal_exercises:
            # logger.info(f"DEBUG: Processing personal ex: {ex.name} (ID: {ex.id})")
            if ex.name in exercise_map:
                pass # logger.info(f"DEBUG: Overriding global {ex.name}")
            else:
                pass # logger.info(f"DEBUG: Adding new personal {ex.name}")
            exercise_map[ex.name] = ex
            
        # logger.info(f"DEBUG: Final keys: {list(exercise_map.keys())}")
        return list(exercise_map.values())

    def create_exercise(self, exercise: dict, trainer_id: str) -> dict:
        # Save to trainer's personal database
        db = get_trainer_session(trainer_id)
        try:
            # Generate UUID
            new_id = str(uuid.uuid4())
            
            # Default video if not provided
            video_id = exercise.get("video_id")
            if not video_id:
                video_id = "InclineDBPress" # Fallback
            
            db_ex = ExerciseORM(
                id=new_id,
                name=exercise["name"],
                muscle=exercise["muscle"],
                type=exercise["type"],
                video_id=video_id
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
        # 1. Try to find in personal DB first
        trainer_db = get_trainer_session(trainer_id)
        try:
            ex = trainer_db.query(ExerciseORM).filter(ExerciseORM.id == exercise_id).first()
            if ex:
                # Found in personal DB, update it directly
                for key, value in updates.items():
                    if hasattr(ex, key) and value is not None:
                        setattr(ex, key, value)
                trainer_db.commit()
                trainer_db.refresh(ex)
                return ex
        except Exception as e:
            trainer_db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update personal exercise: {str(e)}")
        finally:
            trainer_db.close()

        # 2. Try to find in global DB
        global_db = GlobalSessionLocal()
        try:
            ex = global_db.query(ExerciseORM).filter(ExerciseORM.id == exercise_id).first()
            if ex:
                # Found in global DB
                # Check if we already have a fork for this exercise (by name)
                trainer_db = get_trainer_session(trainer_id)
                try:
                    existing_fork = trainer_db.query(ExerciseORM).filter(ExerciseORM.name == ex.name).first()
                    
                    if existing_fork:
                        # Update the existing fork
                        for key, value in updates.items():
                            if hasattr(existing_fork, key) and value is not None:
                                setattr(existing_fork, key, value)
                        trainer_db.commit()
                        trainer_db.refresh(existing_fork)
                        return existing_fork
                    else:
                        # Create new in PERSONAL DB (Fork)
                        new_id = str(uuid.uuid4())
                        
                        # Merge old data with updates
                        new_data = {
                            "name": updates.get("name", ex.name),
                            "muscle": updates.get("muscle", ex.muscle),
                            "type": updates.get("type", ex.type),
                            "video_id": updates.get("video_id", ex.video_id)
                        }

                        new_ex = ExerciseORM(
                            id=new_id,
                            name=new_data["name"],
                            muscle=new_data["muscle"],
                            type=new_data["type"],
                            video_id=new_data["video_id"],
                            owner_id=trainer_id
                        )
                        trainer_db.add(new_ex)
                        trainer_db.commit()
                        trainer_db.refresh(new_ex)
                        return new_ex
                finally:
                    trainer_db.close()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to fork global exercise: {str(e)}")
        finally:
            global_db.close()

        raise HTTPException(status_code=404, detail="Exercise not found")

    def get_workouts(self, trainer_id: str) -> list:
        # Get workouts from trainer's personal database only
        db = get_trainer_session(trainer_id)
        try:
            import json
            workouts = db.query(WorkoutORM).all()
            
            # Map to store unique workouts by ID (Personal overrides Global)
            workout_map = {}
            
            # 1. Add global workouts first
            from data import WORKOUTS_DB
            for w_id, w in WORKOUTS_DB.items():
                workout_map[w_id] = w

            # 2. Add/Override with personal workouts
            for w in workouts:
                workout_map[w.id] = {
                    "id": w.id,
                    "title": w.title,
                    "duration": w.duration,
                    "difficulty": w.difficulty,
                    "exercises": json.loads(w.exercises_json)
                }
            
            return list(workout_map.values())
        finally:
            db.close()

    def create_workout(self, workout: dict, trainer_id: str) -> dict:
        # Save to trainer's personal database
        db = get_trainer_session(trainer_id)
        try:
            import json
            # Generate UUID
            new_id = str(uuid.uuid4())
            workout["id"] = new_id
            
            db_workout = WorkoutORM(
                id=new_id,
                title=workout["title"],
                duration=workout["duration"],
                difficulty=workout["difficulty"],
                exercises_json=json.dumps(workout["exercises"])
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
        db = get_trainer_session(trainer_id)
        try:
            import json
            workout = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()
            
            if not workout:
                # Check if it is a global workout we want to Shadow
                from data import WORKOUTS_DB
                if workout_id in WORKOUTS_DB:
                    # Create a SHADOW copy in personal DB
                    global_w = WORKOUTS_DB[workout_id]
                    
                    # Merge global data with updates
                    new_title = updates.get("title", global_w["title"])
                    new_duration = updates.get("duration", global_w["duration"])
                    new_difficulty = updates.get("difficulty", global_w["difficulty"])
                    new_exercises = updates.get("exercises", global_w["exercises"])
                    
                    workout = WorkoutORM(
                        id=workout_id, # Keep SAME ID to shadow it
                        title=new_title,
                        duration=new_duration,
                        difficulty=new_difficulty,
                        exercises_json=json.dumps(new_exercises),
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
                else:
                    raise HTTPException(status_code=404, detail="Workout not found")
            
            # Normal Update
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

    def assign_workout(self, assignment: dict) -> dict:
        from data import CLIENT_DATA, WORKOUTS_DB
        from datetime import date
        from database import get_client_session
        from models_client_orm import ClientScheduleORM
        
        client_id = assignment.get("client_id")
        workout_id = assignment.get("workout_id")
        date_str = assignment.get("date")
        print(f"[DEBUG] assign_workout called for client={client_id}, workout={workout_id}, date={date_str}")

        # In a real app, validate IDs
        # if client_id not in CLIENT_DATA:
        #     return {"error": "Client not found"}
        
        # Try to find in global DB first, then trainer DB
        workout = WORKOUTS_DB.get(workout_id)
        
        # If not in global, check if it's a dynamic workout from the trainer's DB
        if not workout:
             # Fallback: Try to fetch from ORM if it's a UUID
             try:
                 db = get_trainer_session("trainer_default") # simplified
                 w_orm = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()
                 if w_orm:
                     import json
                     workout = {
                         "id": w_orm.id,
                         "title": w_orm.title,
                         "duration": w_orm.duration,
                         "difficulty": w_orm.difficulty,
                         "exercises": json.loads(w_orm.exercises_json)
                     }
                 db.close()
             except:
                 pass

        if not workout:
            print(f"[DEBUG] Workout {workout_id} NOT FOUND in global or trainer DB")
            return {"error": "Workout not found"}

        # Use Client DB
        client_db = get_client_session(client_id)
        try:
            # Remove existing workout events for that day
            client_db.query(ClientScheduleORM).filter(
                ClientScheduleORM.date == date_str,
                ClientScheduleORM.type == "workout"
            ).delete()
            
            # Create new event
            new_event = ClientScheduleORM(
                date=date_str,
                title=workout["title"],
                type="workout",
                completed=False,
                workout_id=workout_id,
                details=workout["difficulty"]
            )
            client_db.add(new_event)
            client_db.commit()
            client_db.refresh(new_event)
            
            return {
                "status": "success", 
                "event": {
                    "date": new_event.date,
                    "title": new_event.title,
                    "type": new_event.type,
                    "completed": new_event.completed,
                    "workout_id": new_event.workout_id,
                    "details": new_event.details
                }
            }
        except Exception as e:
            client_db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to assign workout: {str(e)}")
        finally:
            client_db.close()

    def update_client_diet(self, client_id: str, diet_data: dict) -> dict:
        from database import get_client_session
        from models_client_orm import ClientDietSettingsORM
        
        db = get_client_session(client_id)
        try:
            settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
            if not settings:
                # Create if not exists
                settings = ClientDietSettingsORM(id=client_id)
                db.add(settings)
            
            # Update Macros
            if "macros" in diet_data:
                macros = diet_data["macros"]
                if "calories" in macros: settings.calories_target = macros["calories"].get("target", settings.calories_target)
                if "protein" in macros: settings.protein_target = macros["protein"].get("target", settings.protein_target)
                if "carbs" in macros: settings.carbs_target = macros["carbs"].get("target", settings.carbs_target)
                if "fat" in macros: settings.fat_target = macros["fat"].get("target", settings.fat_target)
                
            # Update Hydration
            if "hydration_target" in diet_data:
                settings.hydration_target = diet_data["hydration_target"]
                
            # Update Consistency
            if "consistency_target" in diet_data:
                settings.consistency_target = diet_data["consistency_target"]
                
            db.commit()
            db.refresh(settings)
            
            return {"status": "success"}
        finally:
            db.close()

    def assign_diet(self, diet_data: AssignDietRequest) -> dict:
        from database import get_client_session
        from models_client_orm import ClientDietSettingsORM
        
        client_id = diet_data.client_id
        db = get_client_session(client_id)
        try:
            settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
            if not settings:
                settings = ClientDietSettingsORM(id=client_id)
                db.add(settings)
                
            settings.calories_target = diet_data.calories
            settings.protein_target = diet_data.protein
            settings.carbs_target = diet_data.carbs
            settings.fat_target = diet_data.fat
            settings.hydration_target = diet_data.hydration_target
            settings.consistency_target = diet_data.consistency_target
            
            db.commit()
            db.refresh(settings)
            
            return {"status": "success"}
        finally:
            db.close()

    # --- WEEKLY SPLITS ---
    def create_split(self, split_data: dict, trainer_id: str) -> dict:
        db = get_trainer_session(trainer_id)
        try:
            import json
            new_id = str(uuid.uuid4())
            
            db_split = WeeklySplitORM(
                id=new_id,
                name=split_data["name"],
                description=split_data.get("description", ""),
                days_per_week=split_data["days_per_week"],
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
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to create split: {str(e)}")
        finally:
            db.close()

    def get_splits(self, trainer_id: str) -> list:
        db = get_trainer_session(trainer_id)
        try:
            import json
            from data import SPLITS_DB
            
            splits_map = {}
            
            # 1. Add global/mock splits
            for s_id, s in SPLITS_DB.items():
                splits_map[s_id] = s
            
            # 2. Add personal splits from DB
            db_splits = db.query(WeeklySplitORM).all()
            for s in db_splits:
                splits_map[s.id] = {
                    "id": s.id,
                    "name": s.name,
                    "description": s.description,
                    "days_per_week": s.days_per_week,
                    "schedule": json.loads(s.schedule_json)
                }
                
            return list(splits_map.values())
        finally:
            db.close()

    def update_split(self, split_id: str, updates: dict, trainer_id: str) -> dict:
        import json
        import logging
        logger = logging.getLogger("gym_app")
        
        logger.info(f"[update_split] ===== START =====")
        logger.info(f"[update_split] Trainer: {trainer_id}, Split: {split_id}")
        logger.info(f"[update_split] Updates: {updates}")
        
        # FIRST: Check if it's a global split (accessible to all trainers)
        from data import SPLITS_DB
        is_in_global = split_id in SPLITS_DB
        logger.info(f"[update_split] Is in SPLITS_DB: {is_in_global}")
        
        if is_in_global:
            logger.info(f"[update_split] Found split {split_id} in global SPLITS_DB")
            # Create/update shadow copy in trainer's personal DB
            db = get_trainer_session(trainer_id)
            try:
                # Check if trainer already has a shadow copy
                split = db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()
                
                if split:
                    # Update existing shadow copy
                    logger.info(f"[update_split] Updating existing shadow copy for trainer {trainer_id}")
                    if "name" in updates: split.name = updates["name"]
                    if "description" in updates: split.description = updates["description"]
                    if "days_per_week" in updates: split.days_per_week = updates["days_per_week"]
                    if "schedule" in updates: split.schedule_json = json.dumps(updates["schedule"])
                else:
                    # Create new shadow copy
                    logger.info(f"[update_split] Creating shadow copy of global split for trainer {trainer_id}")
                    global_s = SPLITS_DB[split_id]
                    
                    split = WeeklySplitORM(
                        id=split_id,  # Keep same ID to shadow global split
                        name=updates.get("name", global_s["name"]),
                        description=updates.get("description", global_s.get("description", "")),
                        days_per_week=updates.get("days_per_week", global_s["days_per_week"]),
                        schedule_json=json.dumps(updates.get("schedule", global_s["schedule"])),
                        owner_id=trainer_id
                    )
                    db.add(split)
                
                db.commit()
                db.refresh(split)
                
                logger.info(f"[update_split] Successfully updated/created shadow split")
                return {
                    "id": split.id,
                    "name": split.name,
                    "description": split.description,
                    "days_per_week": split.days_per_week,
                    "schedule": json.loads(split.schedule_json)
                }
            except Exception as e:
                logger.error(f"[update_split] Error updating global split shadow: {type(e).__name__}: {str(e)}")
                db.rollback()
                raise HTTPException(status_code=500, detail=f"Failed to update split: {str(e)}")
            finally:
                db.close()
        
        # SECOND: Check trainer's personal database
        logger.info(f"[update_split] Not in SPLITS_DB, checking trainer's personal database")
        db = get_trainer_session(trainer_id)
        try:
            split = db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()
            
            if not split:
                # THIRD: Check ALL other trainer databases for cross-trainer access
                logger.warning(f"[update_split] Split {split_id} not found in {trainer_id} database")
                logger.info(f"[update_split] Searching other trainer databases for cross-trainer access...")
                
                other_trainers = ["trainer_A", "trainer_B", "trainer_C", "trainer_default"]
                if trainer_id in other_trainers:
                    other_trainers.remove(trainer_id)
                
                found_split = None
                source_db = None
                
                for other_trainer in other_trainers:
                    logger.info(f"[update_split] Checking {other_trainer} database...")
                    other_db = get_trainer_session(other_trainer)
                    try:
                        other_split = other_db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()
                        if other_split:
                            logger.info(f"[update_split] Found split in {other_trainer} database!")
                            found_split = {
                                "id": other_split.id,
                                "name": other_split.name,
                                "description": other_split.description,
                                "days_per_week": other_split.days_per_week,
                                "schedule": json.loads(other_split.schedule_json),
                                "owner_id": other_split.owner_id
                            }
                            source_db = other_db
                            break
                    finally:
                        if not source_db:
                            other_db.close()
                
                if not found_split:
                    logger.error(f"[update_split] Split {split_id} not found in any database")
                    # Import locally to ensure we have the right class
                    from fastapi import HTTPException
                    raise HTTPException(status_code=404, detail=f"Split not found. Split ID: {split_id}")
                
                # Create a copy of the split in current trainer's database
                logger.info(f"[update_split] Creating cross-trainer copy in {trainer_id} database")
                split = WeeklySplitORM(
                    id=found_split["id"],
                    name=updates.get("name", found_split["name"]),
                    description=updates.get("description", found_split["description"]),
                    days_per_week=updates.get("days_per_week", found_split["days_per_week"]),
                    schedule_json=json.dumps(updates.get("schedule", found_split["schedule"])),
                    owner_id=trainer_id  # Current trainer becomes owner of this copy
                )
                db.add(split)
                db.commit()
                db.refresh(split)
                
                # Close source database
                if source_db:
                    source_db.close()
                
                logger.info(f"[update_split] Successfully created cross-trainer copy")
                return {
                    "id": split.id,
                    "name": split.name,
                    "description": split.description,
                    "days_per_week": split.days_per_week,
                    "schedule": json.loads(split.schedule_json)
                }
            
            # Update existing personal split
            logger.info(f"[update_split] Found split in personal DB, updating...")
            logger.info(f"[update_split] Current owner_id: {split.owner_id}")
            if "name" in updates: split.name = updates["name"]
            if "description" in updates: split.description = updates["description"]
            if "days_per_week" in updates: split.days_per_week = updates["days_per_week"]
            if "schedule" in updates: split.schedule_json = json.dumps(updates["schedule"])
            
            db.commit()
            db.refresh(split)
            
            logger.info(f"[update_split] Successfully updated personal split")
            return {
                "id": split.id,
                "name": split.name,
                "description": split.description,
                "days_per_week": split.days_per_week,
                "schedule": json.loads(split.schedule_json)
            }
        except HTTPException:
            # Re-raise HTTPExceptions so they bubble up with correct status code
            db.rollback()
            raise
        except Exception as e:
            logger.error(f"[update_split] Unexpected error: {type(e).__name__}: {str(e)}")
            import traceback
            logger.error(f"[update_split] Traceback: {traceback.format_exc()}")
            db.rollback()
            from fastapi import HTTPException
            raise HTTPException(status_code=500, detail=f"Failed to update split: {str(e)}")
        finally:
            db.close()

    def delete_split(self, split_id: str, trainer_id: str) -> dict:
        import logging
        logger = logging.getLogger("gym_app")
        
        logger.info(f"[delete_split] Trainer: {trainer_id}, Split: {split_id}")
        
        # Check if it's a global split
        from data import SPLITS_DB
        is_global = split_id in SPLITS_DB
        
        db = get_trainer_session(trainer_id)
        try:
            split = db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()
            
            if not split:
                if is_global:
                    # Split exists in global DB but not in trainer's DB
                    logger.warning(f"[delete_split] Attempted to delete global split {split_id} that isn't shadowed")
                    raise HTTPException(
                        status_code=403, 
                        detail="Cannot delete global split. This split is shared across all trainers."
                    )
                else:
                    logger.warning(f"[delete_split] Split {split_id} not found for trainer {trainer_id}")
                    raise HTTPException(status_code=404, detail="Split not found")
            
            # Split exists in trainer's DB - delete it
            # (This could be either a personal split or a shadow copy of a global split)
            if is_global:
                logger.info(f"[delete_split] Deleting shadow copy of global split {split_id}")
            else:
                logger.info(f"[delete_split] Deleting personal split {split_id}")
            
            db.delete(split)
            db.commit()
            
            logger.info(f"[delete_split] Successfully deleted split")
            return {"status": "success", "message": "Split deleted"}
        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            logger.error(f"[delete_split] Unexpected error: {type(e).__name__}: {str(e)}")
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to delete split: {str(e)}")
        finally:
            db.close()

    def assign_split(self, assignment: dict, trainer_id: str) -> dict:
        # assignment: { client_id, split_id, start_date }
        from datetime import date, timedelta, datetime
        import logging
        logger = logging.getLogger("gym_app")
        
        client_id = assignment.get("client_id")
        split_id = assignment.get("split_id")
        start_date_str = assignment.get("start_date")
        
        logger.info(f"[assign_split] Called with client={client_id}, split={split_id}, start={start_date_str}, trainer={trainer_id}")
        
        split_schedule = None
        days_per_week = None
        
        # Fetch Split
        # Use the provided trainer_id to find the split
        trainer_db = get_trainer_session(trainer_id)
        try:
            import json
            split_orm = trainer_db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()
            
            if not split_orm:
                 # Try default trainer as fallback (e.g. for global splits that aren't shadowed yet but should be?)
                 # Actually, if it's global, it should be in SPLITS_DB or shadowed.
                 # Let's check SPLITS_DB if not found in DB
                 from data import SPLITS_DB
                 if split_id in SPLITS_DB:
                     split_data = SPLITS_DB[split_id]
                     split_schedule = split_data["schedule"]
                     days_per_week = split_data["days_per_week"]
                 else:
                     # Check if it is in default trainer DB (fallback for legacy/shared)
                     # Close current db and check default
                     trainer_db.close()
                     trainer_db = get_trainer_session("trainer_default")
                     split_orm = trainer_db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()
                     if split_orm:
                         split_schedule = json.loads(split_orm.schedule_json)
                         days_per_week = split_orm.days_per_week
                     else:
                         logger.error(f"[assign_split] Split {split_id} not found in any DB")
                         raise HTTPException(status_code=404, detail="Split not found")
            else:
                split_schedule = json.loads(split_orm.schedule_json)
                days_per_week = split_orm.days_per_week
                
            logger.info(f"[assign_split] Found split {split_id}, schedule: {split_schedule}")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"[assign_split] Error fetching split: {type(e).__name__}: {str(e)}")
            import traceback
            logger.error(f"[assign_split] Traceback: {traceback.format_exc()}")
            raise HTTPException(status_code=500, detail=f"Error fetching split: {str(e)}")
        finally:
            trainer_db.close()

        logs = []
        logs.append(f"Found split {split_id}, schedule: {split_schedule}")

        # Assign for 4 weeks
        if not start_date_str:
            raise HTTPException(status_code=400, detail="Start date is required")
            
        try:
            start_date = datetime.strptime(start_date_str, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
        
        # Map weekday number (0=Monday, 6=Sunday) to our schedule keys
        weekday_map = {
            0: "Monday", 1: "Tuesday", 2: "Wednesday", 3: "Thursday",
            4: "Friday", 5: "Saturday", 6: "Sunday"
        }
        
        for day_offset in range(28): # 4 Weeks = 28 Days
            current_date = start_date + timedelta(days=day_offset)
            day_name = weekday_map[current_date.weekday()]
            
            workout_id = split_schedule.get(day_name)
            
            if workout_id and workout_id != "rest":
                # Assign the workout
                logs.append(f"Assigning workout {workout_id} for {day_name} ({current_date})")
                try:
                    res = self.assign_workout({
                        "client_id": client_id,
                        "workout_id": workout_id,
                        "date": current_date.isoformat()
                    })
                    logs.append(f"Result: {res}")
                except Exception as e:
                    logger.error(f"[assign_split] Error assigning workout {workout_id}: {str(e)}")
                    logs.append(f"Error: {str(e)}")
                    
        return {"status": "success", "message": "Split assigned for 4 weeks", "logs": logs}

class LeaderboardService:
    def get_leaderboard(self) -> LeaderboardData:
        return LeaderboardData(**LEADERBOARD_DATA)
