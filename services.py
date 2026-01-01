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

    def assign_workout(self, assignment: WorkoutAssignment) -> dict:
        # Mock logic: Update the client's workout based on type
        client = CLIENT_DATA["user_123"]
        
        new_workout = {
            "title": f"Coach Assigned: {assignment.workout_type}",
            "duration": "60 min",
            "difficulty": "Hard",
            "exercises": []
        }

        if assignment.workout_type == "Push":
            new_workout["exercises"] = [
                {"name": "Incline DB Press", "sets": 4, "reps": "8-10", "rest": 90, "video_id": "InclineDBPress"},
                {"name": "Seated Shoulder Press", "sets": 4, "reps": "8-10", "rest": 90, "video_id": "SeatedShoulderPress"},
                {"name": "Machine Chest Fly", "sets": 3, "reps": "10-12", "rest": 60, "video_id": "MachineFly"},
                {"name": "Tricep Rope Pushdown", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown"}
            ]
        elif assignment.workout_type == "Pull":
             new_workout["exercises"] = [
                {"name": "Lat Pulldown", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown"}, # Placeholder
                {"name": "Cable Row", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown"}
            ]
        elif assignment.workout_type == "Legs":
             new_workout["exercises"] = [
                {"name": "Squat", "sets": 4, "reps": "5-8", "rest": 120, "video_id": "InclineDBPress"}, # Placeholder
                {"name": "Leg Extension", "sets": 3, "reps": "12-15", "rest": 60, "video_id": "InclineDBPress"}
            ]
        elif assignment.workout_type == "Cardio":
             new_workout["exercises"] = [
                {"name": "Treadmill Run", "sets": 1, "reps": "30 min", "rest": 0, "video_id": "InclineDBPress"} # Placeholder
            ]
        
        client["todays_workout"] = new_workout
        return {"status": "success", "message": f"Assigned {assignment.workout_type} to {assignment.client_name}"}

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
        
        # Merge and return
        return list(global_exercises) + list(personal_exercises)

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
        db = SessionLocal()
        try:
            # Find the exercise
            ex = db.query(ExerciseORM).filter(ExerciseORM.id == exercise_id).first()
            if not ex:
                raise HTTPException(status_code=404, detail="Exercise not found")

            # Check ownership
            if ex.owner_id == trainer_id:
                # Direct Update
                for key, value in updates.items():
                    if hasattr(ex, key) and value is not None:
                        setattr(ex, key, value)
                db.commit()
                db.refresh(ex)
                return ex
            elif ex.owner_id is None:
                # Forking (Copy-on-Write)
                # Create a new personal copy with updates
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
                    owner_id=trainer_id # Personal Scope
                )
                db.add(new_ex)
                db.commit()
                db.refresh(new_ex)
                return new_ex
            else:
                # Trying to edit someone else's personal exercise? Should not happen if get is filtered correctly.
                raise HTTPException(status_code=403, detail="Cannot edit another trainer's exercise")
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update exercise: {str(e)}")
        finally:
            db.close()

    def get_workouts(self, trainer_id: str) -> list:
        # Get workouts from trainer's personal database only
        db = get_trainer_session(trainer_id)
        try:
            import json
            workouts = db.query(WorkoutORM).all()
            
            # Convert to dict format with parsed exercises
            result = []
            for w in workouts:
                result.append({
                    "id": w.id,
                    "title": w.title,
                    "duration": w.duration,
                    "difficulty": w.difficulty,
                    "exercises": json.loads(w.exercises_json)
                })
            return result
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

    def assign_workout(self, assignment: dict) -> dict:
        from data import CLIENT_DATA, WORKOUTS_DB
        
        client_id = assignment.get("client_id")
        workout_id = assignment.get("workout_id")
        date_str = assignment.get("date")

        # In a real app, validate IDs
        if client_id not in CLIENT_DATA:
            return {"error": "Client not found"}
        
        workout = WORKOUTS_DB.get(workout_id)
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
        
        CLIENT_DATA[client_id]["calendar"]["events"].append(new_event)
        return {"status": "success", "event": new_event}

class LeaderboardService:
    def get_leaderboard(self) -> LeaderboardData:
        return LeaderboardData(**LEADERBOARD_DATA)
