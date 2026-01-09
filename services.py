from fastapi import HTTPException
import uuid
from data import GYMS_DB, CLIENT_DATA, TRAINER_DATA, OWNER_DATA, LEADERBOARD_DATA, EXERCISE_LIBRARY
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment, AssignDietRequest
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
            
            # 2. Fetch Schedule
            events = db.query(ClientScheduleORM).all()
            calendar_data = {
                "events": [
                    {
                        "date": e.date,
                        "title": e.title,
                        "type": e.type,
                        "completed": e.completed,
                        "details": e.details
                    } for e in events
                ]
            }
            
            # 3. Fetch Diet
            diet_settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
            progress_data = {}
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
                    # Mock history and logs for now as they are complex to migrate fully in one go
                    "weekly_history": [1800, 2100, 1950, 2200, 2000, 1850, 1450], 
                    "diet_log": {
                        "Breakfast": [{"meal": "Oatmeal", "cals": 350, "time": "08:00"}],
                        "Lunch": [{"meal": "Chicken Salad", "cals": 450, "time": "12:30"}]
                    }
                }

            # Construct ClientData
            # We need to reconstruct the todays_workout if applicable
            todays_workout = None
            from datetime import date
            today_str = date.today().isoformat()
            
            # Check if there is a workout event today
            today_event = next((e for e in events if e.date == today_str and e.type == "workout"), None)
            if today_event:
                # In a real app we would fetch the full workout details. 
                # For now, we'll just mock it or try to find it if we had the ID.
                # Since we only stored title/details in schedule, we might miss full exercise list.
                # This is a limitation of the current migration. 
                # We will leave it as None or basic info for now.
                pass

            return ClientData(
                name=profile.name,
                streak=profile.streak,
                gems=profile.gems,
                health_score=profile.health_score,
                todays_workout=CLIENT_DATA.get(client_id, {}).get("todays_workout"), # Fallback to memory for complex object for now
                daily_quests=CLIENT_DATA.get(client_id, {}).get("daily_quests", []), # Fallback
                progress=progress_data if progress_data else None,
                calendar=calendar_data
            )
        finally:
            db.close()

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
            splits = db.query(WeeklySplitORM).all()
            return [
                {
                    "id": s.id,
                    "name": s.name,
                    "description": s.description,
                    "days_per_week": s.days_per_week,
                    "schedule": json.loads(s.schedule_json)
                } for s in splits
            ]
        finally:
            db.close()

    def assign_split(self, assignment: dict) -> dict:
        # assignment: { client_id, split_id, start_date }
        from datetime import date, timedelta, datetime
        
        client_id = assignment.get("client_id")
        split_id = assignment.get("split_id")
        start_date_str = assignment.get("start_date")
        
        # Fetch Split
        # For simplicity, we assume the split is in the default trainer DB for now, 
        # or we need to know which trainer owns it. 
        # In this prototype, we'll check the default trainer DB.
        trainer_db = get_trainer_session("trainer_default")
        try:
            import json
            split_orm = trainer_db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()
            if not split_orm:
                raise HTTPException(status_code=404, detail="Split not found")
            
            split_schedule = json.loads(split_orm.schedule_json)
            days_per_week = split_orm.days_per_week
        finally:
            trainer_db.close()

        # Assign for 4 weeks
        start_date = datetime.strptime(start_date_str, "%Y-%m-%d").date()
        
        # We need to map "Day 1" to the start date, "Day 2" to start date + 1, etc.
        # But usually splits are cyclical. 
        # If it's a 3 day split, does it repeat every 3 days? Or is it 3 days a week?
        # "Weekly Split" implies it fits into a week. 
        # Let's assume the schedule keys are "Day 1", "Day 2", ... "Day 7" (max).
        # And we map them to Monday=Day 1, Tuesday=Day 2, etc.
        # OR we just map them sequentially from the start date.
        # Let's go with Sequential for flexibility: Day 1 is Start Date, Day 2 is Start Date + 1.
        # And it repeats every 7 days? Or every `days_per_week`?
        # User asked for "3-4-5-6 day split". Usually means a weekly cycle.
        # So we will map Day 1..N to the first N days of the week starting from `start_date`.
        
        for week in range(4): # 4 Weeks
            current_week_start = start_date + timedelta(weeks=week)
            
            for day_num in range(1, days_per_week + 1):
                day_key = f"Day {day_num}"
                workout_id = split_schedule.get(day_key)
                
                if workout_id:
                    # Calculate date for this day
                    # Day 1 = current_week_start
                    # Day 2 = current_week_start + 1 day
                    target_date = current_week_start + timedelta(days=day_num - 1)
                    
                    # Assign the workout
                    self.assign_workout({
                        "client_id": client_id,
                        "workout_id": workout_id,
                        "date": target_date.isoformat()
                    })
                    
        return {"status": "success", "message": "Split assigned for 4 weeks"}

class LeaderboardService:
    def get_leaderboard(self) -> LeaderboardData:
        return LeaderboardData(**LEADERBOARD_DATA)
