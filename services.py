from fastapi import HTTPException
import uuid
import json
import logging
from datetime import date, datetime, timedelta

from data import GYMS_DB, CLIENT_DATA, TRAINER_DATA, OWNER_DATA, LEADERBOARD_DATA, EXERCISE_LIBRARY, WORKOUTS_DB, SPLITS_DB
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment, AssignDietRequest, ClientProfileUpdate, ExerciseTemplate
from database import get_db_session, Base, engine
from models_orm import ExerciseORM, WorkoutORM, WeeklySplitORM, UserORM, ClientProfileORM, ClientScheduleORM, ClientDietSettingsORM, ClientExerciseLogORM, ClientDietLogORM
from auth import verify_password, get_password_hash

# Create tables (ensures unified DB is initialized)
Base.metadata.create_all(bind=engine)

logger = logging.getLogger("gym_app")

# Seed global database with exercises only
def seed_global_database():
    db = get_db_session()
    try:
        # Check table existence/count safely
        if db.query(ExerciseORM).count() == 0:
            print("Seeding global database with default exercises...")
            for ex in EXERCISE_LIBRARY:
                db_ex = ExerciseORM(
                    id=ex["id"],
                    name=ex["name"],
                    muscle=ex["muscle"],
                    type=ex["type"],
                    video_id=ex["video_id"],
                    owner_id=None # Global
                )
                db.add(db_ex)
            db.commit()
    except Exception as e:
        print(f"Seeding Warning: {e}")
    finally:
        db.close()

seed_global_database()

class GymService:
    def get_gym(self, gym_id: str) -> GymConfig:
        gym = GYMS_DB.get(gym_id)
        if not gym:
            raise HTTPException(status_code=404, detail="Gym not found")
        return GymConfig(**gym)

class UserService:
    def authenticate_user(self, username, password):
        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.username == username).first()
            if not user:
                return False
            if not verify_password(password, user.hashed_password):
                return False
            return user
        finally:
            db.close()

    def register_user(self, user_data: dict):
        print(f"DEBUG: register_user called for {user_data.get('username')}")
        db = get_db_session()
        try:
            # Handle empty email as None
            email = user_data.get("email")
            if email == "":
                email = None
            
            # Check if user exists
            query = db.query(UserORM).filter(UserORM.username == user_data["username"])
            if email:
                query = db.query(UserORM).filter(
                    (UserORM.username == user_data["username"]) | 
                    (UserORM.email == email)
                )
            
            existing_user = query.first()
            
            if existing_user:
                raise HTTPException(status_code=400, detail="Username or email already registered")
            
            hashed_pw = get_password_hash(user_data["password"])
            
            new_user = UserORM(
                id=str(uuid.uuid4()),
                username=user_data["username"],
                email=email,
                hashed_password=hashed_pw,
                role=user_data.get("role", "client"),
                is_active=True
            )
            
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            
            return {"status": "success", "message": "User registered successfully", "user_id": new_user.id}
        except HTTPException as he:
            raise he
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")
        finally:
            db.close()

    def get_client(self, client_id: str) -> ClientData:
        db = get_db_session()
        try:
            print(f"DEBUG: get_client called for {client_id}")
            # 1. Get Profile
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            
            # MIGRATION / SEEDING LOGIC
            if not profile:
                print(f"ClientProfile {client_id} not found. Seeding from memory/defaults...")
                # Try to find in memory CLIENT_DATA (backward compatibility/mocking)
                mem_user = CLIENT_DATA.get(client_id, {
                    "name": "New User",
                    "streak": 0,
                    "gems": 0,
                    "health_score": 0
                })

                # Create Profile in Unified DB
                profile = ClientProfileORM(
                    id=client_id, # PK is client_id (1-to-1 with User)
                    name=mem_user["name"],
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

                print(f"DEBUG: Health Score Calc - Cals: {diet_settings.calories_current}/{diet_settings.calories_target} -> {s_cals}")
                print(f"DEBUG: Health Score Calc - Prot: {diet_settings.protein_current}/{diet_settings.protein_target} -> {s_prot}")
                print(f"DEBUG: Health Score Calc - Hydro: {diet_settings.hydration_current}/{diet_settings.hydration_target} -> {s_hydro}")

                # Weighted Average
                # Cals: 40%, Protein: 30%, Hydration: 10%, Carbs: 10%, Fat: 10%
                health_score = (s_cals * 0.4) + (s_prot * 0.3) + (s_hydro * 0.1) + (s_carb * 0.1) + (s_fat * 0.1)
                print(f"DEBUG: Total Health Score: {health_score}")
                
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
            
            if today_event and today_event.get("workout_id"):
                try:
                    # Determine trainer for this client to sync correct videos (optional optimization)
                    # For now just pass None or try to infer context
                    # Just verify the workout is accessible
                    todays_workout = self.get_workout_details(today_event["workout_id"], db_session=db) # Pass session reused
                    
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
                    print(f"Warning: Could not fetch details for workout {today_event['workout_id']}: {e}")

            # PRIORITIZE SNAPSHOT FROM DB IF COMPLETED
            if today_event and today_event.get("completed") and today_event.get("details"):
                 try:
                    details_content = today_event["details"]
                    if details_content.startswith("["): # JSON snapshot
                        saved_exercises = json.loads(details_content)
                        if todays_workout:
                            todays_workout["exercises"] = saved_exercises
                 except Exception as e:
                     print(f"Error loading saved workout snapshot: {e}")

            return ClientData(
                name=profile.name or "Unknown User",
                email=profile.email,
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

    def get_client_schedule(self, client_id: str, date_str: str = None) -> dict:
        if not date_str:
            date_str = date.today().isoformat()
            
        db = get_db_session()
        try:
            events = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == client_id,
                ClientScheduleORM.date == date_str
            ).all()
            
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

    def complete_schedule_item(self, payload: dict, client_id: str) -> dict:
        date_str = payload.get("date")
        item_id = payload.get("item_id")
        
        db = get_db_session()
        try:
            # If we have ID, use it with client_id ownership check
            if item_id:
                item = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.id == item_id,
                    ClientScheduleORM.client_id == client_id # Security check
                ).first()
            else:
                # Fallback
                item = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.client_id == client_id,
                    ClientScheduleORM.date == date_str, 
                    ClientScheduleORM.type == "workout"
                ).first()
                
            if not item:
                raise HTTPException(status_code=404, detail="Schedule item not found")
                
            item.completed = True
            
            # Save Exercise Logs
            exercises = payload.get("exercises", [])
            if exercises:
                today_iso = date_str
                
                for ex in exercises:
                    ex_name = ex.get("name")
                    perf_list = ex.get("performance", [])
                    
                    for i, perf in enumerate(perf_list):
                        if perf.get("completed"):
                            log = ClientExerciseLogORM(
                                client_id=client_id,
                                date=today_iso,
                                workout_id=item.workout_id,
                                exercise_name=ex_name,
                                set_number=i + 1,
                                reps=int(perf.get("reps", 0) or 0),
                                weight=float(perf.get("weight", 0) or 0),
                                metric_type="weight_reps"
                            )
                            db.add(log)
            
            # Save detailed snapshot
            item.details = json.dumps(exercises)
            
            db.commit()
            return {"status": "success", "message": "Workout completed!"}
        finally:
            db.close()

    def update_completed_workout(self, payload: dict, client_id: str) -> dict:
        date_str = payload.get("date")
        workout_id = payload.get("workout_id")
        
        exercise_name = payload.get("exercise_name")
        set_number = int(payload.get("set_number"))
        reps = payload.get("reps") 
        weight = payload.get("weight")
        
        db = get_db_session()
        try:
            # 1. Update Log
            log = db.query(ClientExerciseLogORM).filter(
                ClientExerciseLogORM.client_id == client_id,
                ClientExerciseLogORM.date == date_str,
                ClientExerciseLogORM.workout_id == workout_id,
                ClientExerciseLogORM.exercise_name == exercise_name,
                ClientExerciseLogORM.set_number == set_number
            ).first()
            
            if log:
                log.reps = int(reps) if reps else 0
                log.weight = float(weight) if weight else 0.0
            else:
                log = ClientExerciseLogORM(
                    client_id=client_id,
                    date=date_str,
                    workout_id=workout_id,
                    exercise_name=exercise_name,
                    set_number=set_number,
                    reps=int(reps) if reps else 0,
                    weight=float(weight) if weight else 0.0,
                    metric_type="weight_reps"
                )
                db.add(log)
                
            # 2. Update Snapshot
            item = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == client_id,
                ClientScheduleORM.date == date_str,
                ClientScheduleORM.workout_id == workout_id,
                ClientScheduleORM.type == "workout"
            ).first()
            
            if item and item.details:
                try:
                    exercises = json.loads(item.details)
                    for ex in exercises:
                        if ex.get("name") == exercise_name:
                            perf_list = ex.get("performance", [])
                            while len(perf_list) < set_number:
                                perf_list.append({"reps": "", "weight": "", "completed": False})
                                
                            perf_list[set_number - 1]["reps"] = reps
                            perf_list[set_number - 1]["weight"] = weight
                            perf_list[set_number - 1]["completed"] = True
                            break
                    
                    item.details = json.dumps(exercises)
                except Exception as e:
                    print(f"Error updating snapshot: {e}")
            
            db.commit()
            return {"status": "success"}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update set: {str(e)}")
        finally:
            db.close()

    def get_client_exercise_history(self, client_id: str, exercise_name: str = None) -> list:
        from sqlalchemy import func
        
        db = get_db_session()
        try:
            query = db.query(
                ClientExerciseLogORM.date,
                func.max(ClientExerciseLogORM.weight).label('max_weight'),
                func.sum(ClientExerciseLogORM.reps).label('total_reps'),
                func.count(ClientExerciseLogORM.id).label('sets')
            ).filter(ClientExerciseLogORM.client_id == client_id)
            
            if exercise_name:
                query = query.filter(ClientExerciseLogORM.exercise_name == exercise_name)
                
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

    def update_client_profile(self, profile_update: ClientProfileUpdate, client_id: str) -> dict:
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

    def scan_meal(self, file_bytes: bytes) -> dict:
        import google.generativeai as genai
        import os
        import json
        
        api_key = os.environ.get("GEMINI_API_KEY")
        print(f"DEBUG: scan_meal called. API Key present: {bool(api_key)}")
        
        if not api_key:
            print("Warning: GEMINI_API_KEY not found, using mock.")
            # Mock AI Analysis Fallback
            import random
            foods = [
                {"name": "Grilled Chicken Salad", "cals": 450, "protein": 40, "carbs": 15, "fat": 20},
                {"name": "Avocado Toast", "cals": 350, "protein": 12, "carbs": 45, "fat": 18},
                {"name": "Protein Oatmeal", "cals": 380, "protein": 25, "carbs": 50, "fat": 6},
                {"name": "Salmon & Rice", "cals": 550, "protein": 35, "carbs": 60, "fat": 22},
                {"name": "Greek Yogurt Parfait", "cals": 280, "protein": 20, "carbs": 30, "fat": 5}
            ]
            result = random.choice(foods)
            return {"status": "success", "data": result}

        try:
            genai.configure(api_key=api_key)
            # Try Gemini 2.0 Flash Lite - often has better availability/quota
            model_name = 'gemini-2.0-flash-lite-preview-02-05'
            print(f"DEBUG: Initializing Gemini with model: {model_name}")
            model = genai.GenerativeModel(model_name)
            
            prompt = """
            Analyze this food image and estimate the nutritional content.
            Return ONLY a raw JSON object with these keys:
            - name: A short descriptive name of the meal
            - cals: Total calories (integer)
            - protein: Protein in grams (integer)
            - carbs: Carbs in grams (integer)
            - fat: Fat in grams (integer)
            
            Example: {"name": "Chicken Salad", "cals": 450, "protein": 40, "carbs": 10, "fat": 20}
            """
            
            response = model.generate_content([
                prompt,
                {
                    "mime_type": "image/jpeg", 
                    "data": file_bytes
                }
            ])
            
            text = response.text
            # Clean up markdown code blocks if present
            if text.startswith("```json"):
                text = text[7:]
            elif text.startswith("```"):
                text = text[3:]
            if text.endswith("```"):
                text = text[:-3]
                
            data = json.loads(text.strip())
            
            return {
                "status": "success",
                "data": data
            }
            
        except Exception as e:
            print(f"Gemini Error: {e}")
            print("Falling back to mock data due to API error.")
            
            # Mock Data Fallback
            import random
            foods = [
                {"name": "Grilled Chicken Salad", "cals": 450, "protein": 40, "carbs": 15, "fat": 20},
                {"name": "Avocado Toast", "cals": 350, "protein": 12, "carbs": 45, "fat": 18},
                {"name": "Protein Oatmeal", "cals": 380, "protein": 25, "carbs": 50, "fat": 6},
                {"name": "Salmon & Rice", "cals": 550, "protein": 35, "carbs": 60, "fat": 22},
                {"name": "Greek Yogurt Parfait", "cals": 280, "protein": 20, "carbs": 30, "fat": 5}
            ]
            result = random.choice(foods)
            
            return {
                "status": "success",
                "data": result,
                "message": "⚠️ AI Quota Exceeded. Using simulated data."
            }

    def log_meal(self, client_id: str, meal_data: dict) -> dict:
        db = get_db_session()
        try:
            log = ClientDietLogORM(
                client_id=client_id,
                date=date.today().isoformat(),
                meal_type=meal_data.get("meal_type", "Snack"),
                meal_name=meal_data.get("name"),
                calories=meal_data.get("cals"),
                time=datetime.now().strftime("%H:%M")
            )
            db.add(log)
            
            # Update current macros
            settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
            if settings:
                settings.calories_current += meal_data.get("cals", 0)
                settings.protein_current += meal_data.get("protein", 0)
                settings.carbs_current += meal_data.get("carbs", 0)
                settings.fat_current += meal_data.get("fat", 0)
            
            db.commit()
            return {"status": "success", "message": "Meal logged"}
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to log meal: {str(e)}")
        finally:
            db.close()

    def get_trainer(self, trainer_id: str) -> TrainerData:
        db = get_db_session()
        try:
            clients_orm = db.query(UserORM).filter(UserORM.role == "client").all()
            
            clients = []
            active_count = 0
            at_risk_count = 0
            today = date.today()

            for c in clients_orm:
                # Fetch profile
                profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == c.id).first()
                
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
                
                # Override if manually set to something specific? 
                # For now, let's trust the calculated status as primary, 
                # unless profile says "Injured" or something else we haven't implemented.
                # Let's write back to profile for persistence? 
                # It's better to calculate distinct status on read to be always up to date.
                
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
                    "plan": profile.plan if profile else "Standard"
                })
            
            video_library = TRAINER_DATA["video_library"]
            return TrainerData(
                clients=clients, 
                video_library=video_library,
                active_clients=active_count,
                at_risk_clients=at_risk_count
            )
        finally:
            db.close()

    def get_owner(self) -> OwnerData:
        return OwnerData(**OWNER_DATA)

    def get_exercises(self, trainer_id: str) -> list:
        db = get_db_session()
        try:
            # Fetch Global (owner_id is None) AND Personal (owner_id == trainer_id)
            exercises = db.query(ExerciseORM).filter(
                (ExerciseORM.owner_id == None) | (ExerciseORM.owner_id == trainer_id)
            ).all()
            
            # Deduplication Logic: Personal overrides Global if names match?
            # Unified DB approach: Just return everything usually, or handle overriding.
            # Let's use name map to let Personal override Global if needed.
            
            exercise_map = {}
            # Sort so Personal comes last (to override) or handle explicitly
            # Let's iterate and prioritize.
             
            for ex in exercises:
                # If it's global, add it.
                if ex.owner_id is None:
                     exercise_map[ex.name] = ex
                else:
                    # It's personal. Always overwrite.
                    exercise_map[ex.name] = ex
                    
            return list(exercise_map.values())
        finally:
            db.close()

    def create_exercise(self, exercise: dict, trainer_id: str) -> dict:
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
                owner_id=trainer_id # Personal exercise
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

    def get_workouts(self, trainer_id: str) -> list:
        db = get_db_session()
        try:
            workouts = db.query(WorkoutORM).filter(
                (WorkoutORM.owner_id == None) | (WorkoutORM.owner_id == trainer_id)
            ).all()
            
            # Map logic to override globals
            workout_map = {}
            for w in workouts:
                # Basic map logic
                w_data = {
                    "id": w.id,
                    "title": w.title,
                    "duration": w.duration,
                    "difficulty": w.difficulty,
                    "exercises": json.loads(w.exercises_json)
                }
                
                if w.owner_id is None:
                    workout_map[w.id] = w_data
                else: 
                    # If this is a shadown/fork, it might have same ID? 
                    # Usually local IDs are unique UUIDs. 
                    # In current logic, they are mixed. 
                    workout_map[w.id] = w_data
                    
            return list(workout_map.values())
        finally:
            db.close()

    def get_workout_details(self, workout_id: str, context_trainer_id: str = None, db_session = None) -> dict:
        # Allow passing session to avoid reopening
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
                # Fetch trainer exercises to override video IDs
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
        db = get_db_session()
        try:
            workout = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()
            
            if not workout:
                # Check for global shadow creation
                if workout_id in WORKOUTS_DB:
                    # Shadow it
                    global_w = WORKOUTS_DB[workout_id]
                    workout = WorkoutORM(
                        id=workout_id, # Keep ID
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
                # Fork/Shadow logic could go here if trying to edit another trainer's workout
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

    def assign_workout(self, assignment: dict) -> dict:
        client_id = assignment.get("client_id")
        workout_id = assignment.get("workout_id")
        date_str = assignment.get("date")
        
        db = get_db_session()
        try:
            # Resolve workout logic (Unified DB lookup)
            workout_orm = db.query(WorkoutORM).filter(WorkoutORM.id == workout_id).first()
            
            if not workout_orm:
                # Fallback check memory
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
                ClientScheduleORM.date == date_str,
                ClientScheduleORM.type == "workout"
            ).delete()
            
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

    def update_client_diet(self, client_id: str, diet_data: dict) -> dict:
        db = get_db_session()
        try:
            settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
            if not settings:
                settings = ClientDietSettingsORM(id=client_id)
                db.add(settings)
            
            if "macros" in diet_data:
                macros = diet_data["macros"]
                if "calories" in macros: settings.calories_target = macros["calories"].get("target", settings.calories_target)
                if "protein" in macros: settings.protein_target = macros["protein"].get("target", settings.protein_target)
                if "carbs" in macros: settings.carbs_target = macros["carbs"].get("target", settings.carbs_target)
                if "fat" in macros: settings.fat_target = macros["fat"].get("target", settings.fat_target)
                
            if "hydration_target" in diet_data:
                settings.hydration_target = diet_data["hydration_target"]
            if "consistency_target" in diet_data:
                settings.consistency_target = diet_data["consistency_target"]
                
            db.commit()
            return {"status": "success"}
        finally:
            db.close()

    def assign_diet(self, diet_data: AssignDietRequest) -> dict:
        client_id = diet_data.client_id
        db = get_db_session()
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
            return {"status": "success"}
        finally:
            db.close()

    def create_split(self, split_data: dict, trainer_id: str) -> dict:
        print(f"DEBUG: create_split called with: {split_data}")
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

    def get_splits(self, trainer_id: str) -> list:
        db = get_db_session()
        try:
            # Get Global + Personal
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

    def update_split(self, split_id: str, updates: dict, trainer_id: str) -> dict:
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
        client_id = assignment.get("client_id")
        split_id = assignment.get("split_id")
        start_date_str = assignment.get("start_date")
        
        db = get_db_session()
        try:
            # 1. Fetch Split (DB or Memory)
            split_schedule = None
            split_orm = db.query(WeeklySplitORM).filter(WeeklySplitORM.id == split_id).first()
            if split_orm:
                split_schedule = json.loads(split_orm.schedule_json)
            elif split_id in SPLITS_DB:
                split_schedule = SPLITS_DB[split_id]["schedule"]
            else:
                raise HTTPException(status_code=404, detail="Split not found")
                
            # 2. Assign
            start_date = datetime.strptime(start_date_str, "%Y-%m-%d").date()
            weekday_map = {0: "Monday", 1: "Tuesday", 2: "Wednesday", 3: "Thursday", 4: "Friday", 5: "Saturday", 6: "Sunday"}
            
            logs = []
            for day_offset in range(28): # 4 Weeks
                current_date = start_date + timedelta(days=day_offset)
                day_name = weekday_map[current_date.weekday()]
                
                workout_id = split_schedule.get(day_name)
                if workout_id and workout_id != "rest":
                    # Delegate to assign_workout
                     try:
                        self.assign_workout({
                            "client_id": client_id,
                            "workout_id": workout_id,
                            "date": current_date.isoformat()
                        })
                        logs.append(f"Assigned {workout_id} to {current_date}")
                     except Exception as e:
                         logs.append(f"Failed to assign {workout_id}: {e}")
            
            return {"status": "success", "message": "Split assigned", "logs": logs}
        finally:
            db.close()

class LeaderboardService:
    def get_leaderboard(self) -> LeaderboardData:
        return LeaderboardData(**LEADERBOARD_DATA)
