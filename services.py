from fastapi import HTTPException
import uuid
from data import GYMS_DB, CLIENT_DATA, TRAINER_DATA, OWNER_DATA, LEADERBOARD_DATA, EXERCISE_LIBRARY
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment
from database import global_engine, GlobalSessionLocal, get_trainer_session, Base
from models_orm import ExerciseORM, WorkoutORM

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
    def get_client(self) -> ClientData:
        # In a real app, this would take a user_id
        user = CLIENT_DATA.get("user_123")
        if not user:
            raise HTTPException(status_code=404, detail="Client not found")
        return ClientData(**user)



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
        logger.info(f"DEBUG: Global keys: {list(exercise_map.keys())}")
        
        for ex in personal_exercises:
            logger.info(f"DEBUG: Processing personal ex: {ex.name} (ID: {ex.id})")
            if ex.name in exercise_map:
                logger.info(f"DEBUG: Overriding global {ex.name}")
            else:
                logger.info(f"DEBUG: Adding new personal {ex.name}")
            exercise_map[ex.name] = ex
            
        logger.info(f"DEBUG: Final keys: {list(exercise_map.keys())}")
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
        
        client_id = assignment.get("client_id")
        workout_id = assignment.get("workout_id")
        date_str = assignment.get("date")

        # In a real app, validate IDs
        if client_id not in CLIENT_DATA:
            return {"error": "Client not found"}
        
        # Try to find in global DB first, then trainer DB (not implemented here yet, assuming global for now)
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

        # Create event
        new_event = {
            "date": date_str,
            "title": workout["title"],
            "type": "workout",
            "completed": False,
            "details": workout["difficulty"]
        }

        # Add to client's calendar
        if "calendar" not in CLIENT_DATA[client_id]:
            CLIENT_DATA[client_id]["calendar"] = {"events": []}
        
        # Remove existing workout events for that day to avoid duplicates
        CLIENT_DATA[client_id]["calendar"]["events"] = [
            e for e in CLIENT_DATA[client_id]["calendar"]["events"] 
            if e["date"] != date_str or e["type"] != "workout"
        ]
        CLIENT_DATA[client_id]["calendar"]["events"].append(new_event)

        # IF DATE IS TODAY, UPDATE DASHBOARD
        today = date.today().isoformat()
        if date_str == today:
            CLIENT_DATA[client_id]["todays_workout"] = workout
            print(f"Updated todays_workout for {client_id} to {workout['title']}")

        return {"status": "success", "event": new_event}

class LeaderboardService:
    def get_leaderboard(self) -> LeaderboardData:
        return LeaderboardData(**LEADERBOARD_DATA)
