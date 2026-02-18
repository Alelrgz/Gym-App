from fastapi import HTTPException
import uuid
import json
import logging
from datetime import date, datetime, timedelta

from data import GYMS_DB, CLIENT_DATA, TRAINER_DATA, OWNER_DATA, LEADERBOARD_DATA, EXERCISE_LIBRARY, WORKOUTS_DB, SPLITS_DB
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment, AssignDietRequest, ClientProfileUpdate, ExerciseTemplate
from database import get_db_session, Base, engine
from models_orm import ExerciseORM, WorkoutORM, WeeklySplitORM, UserORM, ClientProfileORM, ClientScheduleORM, ClientDietSettingsORM, ClientExerciseLogORM, ClientDietLogORM, TrainerScheduleORM
from auth import verify_password, get_password_hash

# Import modular services for delegation
from service_modules.workout_service import workout_service as _workout_service
from service_modules.split_service import split_service as _split_service
from service_modules.exercise_service import exercise_service as _exercise_service
from service_modules.notes_service import notes_service as _notes_service
from service_modules.diet_service import diet_service as _diet_service
from service_modules.schedule_service import schedule_service as _schedule_service
from service_modules.client_service import client_service as _client_service

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

# Seed course exercises for group fitness classes
def seed_course_exercises():
    db = get_db_session()
    try:
        # Check if we already have course exercises
        existing_course_exercises = db.query(ExerciseORM).filter(ExerciseORM.type == "Course").count()
        if existing_course_exercises > 0:
            return  # Already seeded

        print("Seeding course exercises...")

        COURSE_EXERCISES = [
            # YOGA (5 exercises)
            {"name": "Sun Salutation", "category": "yoga", "description": "Classic flowing sequence connecting breath with movement", "duration": 120, "difficulty": "beginner", "steps": ["Mountain pose", "Reach arms overhead", "Forward fold", "Halfway lift", "Plank", "Chaturanga", "Upward dog", "Downward dog", "Step forward", "Return to mountain"]},
            {"name": "Warrior I", "category": "yoga", "description": "Standing pose building strength and focus", "duration": 60, "difficulty": "beginner", "steps": ["Start in mountain pose", "Step one foot back", "Bend front knee to 90°", "Raise arms overhead", "Square hips forward", "Hold and breathe"]},
            {"name": "Warrior II", "category": "yoga", "description": "Open hip standing pose for leg strength", "duration": 60, "difficulty": "beginner", "steps": ["From Warrior I, open hips to side", "Extend arms parallel to floor", "Gaze over front hand", "Keep front knee over ankle", "Hold and breathe"]},
            {"name": "Tree Pose", "category": "yoga", "description": "Balance pose improving focus and stability", "duration": 45, "difficulty": "beginner", "steps": ["Stand on one leg", "Place other foot on inner thigh or calf", "Bring hands to heart center", "Optional: raise arms overhead", "Focus gaze on fixed point"]},
            {"name": "Child's Pose", "category": "yoga", "description": "Restorative resting pose", "duration": 60, "difficulty": "beginner", "steps": ["Kneel on floor", "Sit back on heels", "Fold forward, arms extended", "Rest forehead on mat", "Breathe deeply and relax"]},

            # PILATES (5 exercises)
            {"name": "The Hundred", "category": "pilates", "description": "Core activation exercise pumping arms while holding position", "duration": 90, "difficulty": "intermediate", "steps": ["Lie on back", "Lift head and shoulders", "Extend legs to 45°", "Pump arms up and down", "Breathe in for 5 pumps, out for 5", "Complete 100 pumps"]},
            {"name": "Roll Up", "category": "pilates", "description": "Articulating spine roll from lying to sitting", "duration": 60, "difficulty": "intermediate", "steps": ["Lie flat, arms overhead", "Inhale, lift arms to ceiling", "Exhale, curl up vertebra by vertebra", "Reach toward toes", "Inhale at top", "Exhale, roll back down slowly"]},
            {"name": "Single Leg Circle", "category": "pilates", "description": "Hip mobility while stabilizing the core", "duration": 60, "difficulty": "beginner", "steps": ["Lie on back", "Extend one leg to ceiling", "Circle leg across body", "Down, around, and back up", "Keep hips stable", "5 circles each direction"]},
            {"name": "Plank to Pike", "category": "pilates", "description": "Dynamic core exercise transitioning between positions", "duration": 45, "difficulty": "intermediate", "steps": ["Start in plank position", "Engage core strongly", "Pike hips up toward ceiling", "Keep legs straight", "Return to plank", "Repeat with control"]},
            {"name": "Swimming", "category": "pilates", "description": "Back extension with alternating arm and leg lifts", "duration": 60, "difficulty": "intermediate", "steps": ["Lie face down", "Extend arms forward", "Lift chest slightly", "Flutter opposite arm and leg", "Keep core engaged", "Breathe steadily"]},

            # STRETCH (5 exercises)
            {"name": "Standing Quad Stretch", "category": "stretch", "description": "Stretches front of thigh", "duration": 30, "difficulty": "beginner", "steps": ["Stand on one leg", "Grab opposite ankle behind you", "Pull heel toward glute", "Keep knees together", "Hold, then switch sides"]},
            {"name": "Seated Forward Fold", "category": "stretch", "description": "Hamstring and lower back stretch", "duration": 45, "difficulty": "beginner", "steps": ["Sit with legs extended", "Inhale, lengthen spine", "Exhale, fold forward from hips", "Reach for toes or shins", "Relax head and neck"]},
            {"name": "Figure Four Stretch", "category": "stretch", "description": "Deep hip and glute stretch", "duration": 45, "difficulty": "beginner", "steps": ["Lie on back", "Cross ankle over opposite knee", "Thread hands behind thigh", "Pull toward chest", "Keep head relaxed on floor"]},
            {"name": "Cat-Cow Stretch", "category": "stretch", "description": "Spinal mobility and flexibility", "duration": 60, "difficulty": "beginner", "steps": ["Start on hands and knees", "Inhale, arch back (cow)", "Look up, drop belly", "Exhale, round spine (cat)", "Tuck chin to chest", "Flow between positions"]},
            {"name": "Chest Opener Stretch", "category": "stretch", "description": "Opens chest and shoulders", "duration": 30, "difficulty": "beginner", "steps": ["Stand or sit tall", "Clasp hands behind back", "Straighten arms", "Lift hands away from body", "Open chest, squeeze shoulder blades"]},

            # CARDIO (5 exercises)
            {"name": "High Knees", "category": "cardio", "description": "Running in place with exaggerated knee lift", "duration": 45, "difficulty": "beginner", "steps": ["Stand with feet hip-width", "Run in place", "Drive knees up to hip height", "Pump arms in opposition", "Stay on balls of feet"]},
            {"name": "Jumping Jacks", "category": "cardio", "description": "Classic full-body cardio movement", "duration": 45, "difficulty": "beginner", "steps": ["Stand with feet together", "Jump feet out wide", "Simultaneously raise arms overhead", "Jump feet back together", "Lower arms to sides", "Repeat rhythmically"]},
            {"name": "Burpees", "category": "cardio", "description": "Full-body explosive exercise", "duration": 60, "difficulty": "advanced", "steps": ["Stand tall", "Squat down, hands to floor", "Jump feet back to plank", "Optional: add push-up", "Jump feet to hands", "Explode up with jump"]},
            {"name": "Mountain Climbers", "category": "cardio", "description": "Plank-based cardio targeting core", "duration": 45, "difficulty": "intermediate", "steps": ["Start in plank position", "Drive one knee to chest", "Quickly switch legs", "Keep hips level", "Maintain fast pace", "Keep core tight"]},
            {"name": "Star Jumps", "category": "cardio", "description": "Explosive jumping forming star shape", "duration": 45, "difficulty": "intermediate", "steps": ["Start in squat position", "Explode upward", "Spread arms and legs wide", "Form star shape at peak", "Land softly in squat", "Repeat immediately"]},

            # WARMUP (5 exercises)
            {"name": "Arm Circles", "category": "warmup", "description": "Shoulder mobility warmup", "duration": 30, "difficulty": "beginner", "steps": ["Stand with arms extended", "Make small circles forward", "Gradually increase size", "Reverse direction", "Continue for 30 seconds"]},
            {"name": "Leg Swings", "category": "warmup", "description": "Dynamic hip mobility", "duration": 30, "difficulty": "beginner", "steps": ["Hold wall for balance", "Swing leg forward and back", "Keep leg straight", "Control the movement", "10 swings each leg"]},
            {"name": "Torso Twists", "category": "warmup", "description": "Spinal rotation warmup", "duration": 30, "difficulty": "beginner", "steps": ["Stand with feet shoulder-width", "Place hands on hips", "Rotate torso left and right", "Keep hips facing forward", "Move smoothly"]},
            {"name": "Ankle Rotations", "category": "warmup", "description": "Ankle mobility and warmup", "duration": 20, "difficulty": "beginner", "steps": ["Lift one foot off ground", "Rotate ankle clockwise", "Then counterclockwise", "10 rotations each direction", "Switch feet"]},
            {"name": "Hip Circles", "category": "warmup", "description": "Hip joint mobility warmup", "duration": 30, "difficulty": "beginner", "steps": ["Stand on one leg", "Lift knee to hip height", "Draw circles with knee", "5 circles each direction", "Switch legs"]},

            # COOLDOWN (5 exercises)
            {"name": "Standing Side Stretch", "category": "cooldown", "description": "Gentle lateral body stretch", "duration": 30, "difficulty": "beginner", "steps": ["Stand with feet together", "Raise one arm overhead", "Lean to opposite side", "Feel stretch along side body", "Hold and breathe, switch sides"]},
            {"name": "Neck Rolls", "category": "cooldown", "description": "Gentle neck tension release", "duration": 30, "difficulty": "beginner", "steps": ["Drop chin to chest", "Slowly roll head to one side", "Continue around to back", "Complete full circle", "Reverse direction"]},
            {"name": "Supine Twist", "category": "cooldown", "description": "Lying spinal twist for relaxation", "duration": 45, "difficulty": "beginner", "steps": ["Lie on back", "Hug one knee to chest", "Guide knee across body", "Extend opposite arm", "Look away from knee", "Breathe and relax"]},
            {"name": "Corpse Pose", "category": "cooldown", "description": "Final relaxation pose", "duration": 120, "difficulty": "beginner", "steps": ["Lie flat on back", "Arms at sides, palms up", "Feet fall open naturally", "Close eyes", "Release all tension", "Focus on breath"]},
            {"name": "Seated Meditation", "category": "cooldown", "description": "Mindful breathing to end session", "duration": 90, "difficulty": "beginner", "steps": ["Sit comfortably", "Close eyes or soft gaze down", "Rest hands on knees", "Focus on natural breath", "Let thoughts pass", "Return to breath"]},
        ]

        for ex in COURSE_EXERCISES:
            db_ex = ExerciseORM(
                id=str(uuid.uuid4()),
                name=ex["name"],
                muscle=ex["category"],  # Category stored in muscle field
                type="Course",
                video_id=None,
                owner_id=None,  # Global course exercises
                description=ex["description"],
                default_duration=ex["duration"],
                difficulty=ex["difficulty"],
                steps_json=json.dumps(ex["steps"])
            )
            db.add(db_ex)

        db.commit()
        print(f"Seeded {len(COURSE_EXERCISES)} course exercises")
    except Exception as e:
        print(f"Course exercises seeding warning: {e}")
    finally:
        db.close()

seed_course_exercises()

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
        """Delegate to ClientService."""
        return _client_service.get_client(client_id, get_workout_details_fn=self.get_workout_details)

    def get_client_schedule(self, client_id: str, date_str: str = None) -> dict:
        """Delegate to ScheduleService."""
        return _schedule_service.get_client_schedule(client_id, date_str)

    def complete_schedule_item(self, payload: dict, client_id: str) -> dict:
        """Delegate to ScheduleService."""
        return _schedule_service.complete_schedule_item(payload, client_id)

    def complete_trainer_schedule_item(self, payload: dict, trainer_id: str) -> dict:
        """Delegate to ScheduleService."""
        return _schedule_service.complete_trainer_schedule_item(payload, trainer_id)

    def update_completed_workout(self, payload: dict, client_id: str) -> dict:
        """Delegate to ScheduleService."""
        return _schedule_service.update_completed_workout(payload, client_id)

    def get_client_exercise_history(self, client_id: str, exercise_name: str = None) -> list:
        """Delegate to ScheduleService."""
        return _schedule_service.get_client_exercise_history(client_id, exercise_name)

    def update_client_profile(self, profile_update: ClientProfileUpdate, client_id: str) -> dict:
        """Delegate to ClientService."""
        return _client_service.update_client_profile(profile_update, client_id)

    def toggle_premium_status(self, client_id: str) -> dict:
        """Delegate to ClientService."""
        return _client_service.toggle_premium_status(client_id)

    def scan_meal(self, file_bytes: bytes) -> dict:
        """Delegate to DietService."""
        return _diet_service.scan_meal(file_bytes)

    def log_meal(self, client_id: str, meal_data: dict) -> dict:
        """Delegate to DietService."""
        return _diet_service.log_meal(client_id, meal_data)

    def get_trainer(self, trainer_id: str) -> TrainerData:
        db = get_db_session()
        try:
            # Get the trainer to find which gym they belong to
            trainer = db.query(UserORM).filter(UserORM.id == trainer_id).first()
            gym_owner_id = trainer.gym_owner_id if trainer else None

            # Get ALL clients in this gym (not just assigned to this trainer)
            # Clients are linked to gym via their profile's gym_id
            if gym_owner_id:
                clients_orm = db.query(UserORM).join(
                    ClientProfileORM, UserORM.id == ClientProfileORM.id
                ).filter(
                    UserORM.role == "client",
                    ClientProfileORM.gym_id == gym_owner_id
                ).all()
            else:
                clients_orm = []

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
                    "duration": s.duration if s.duration else 60,  # Include duration
                    "completed": s.completed,
                    "course_id": s.course_id  # Link to course for group classes
                })

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

                # Client is "PRO" for this trainer if they selected this trainer as their personal trainer
                is_my_client = profile.trainer_id == trainer_id if profile else False

                # Get assigned split name and expiry
                assigned_split_name = None
                split_expiry = None
                if profile and profile.current_split_id:
                    split_orm = db.query(WeeklySplitORM).filter(WeeklySplitORM.id == profile.current_split_id).first()
                    if split_orm:
                        assigned_split_name = split_orm.name
                    split_expiry = profile.split_expiry_date

                clients.append({
                    "id": c.id,
                    "name": profile.name if profile and profile.name else c.username,
                    "status": status,
                    "last_seen": f"{days_inactive} days ago" if days_inactive < 99 else "Never",
                    "plan": profile.plan if profile and profile.plan else "Standard",
                    "is_premium": is_my_client,
                    "profile_picture": c.profile_picture,
                    "assigned_split": assigned_split_name,
                    "plan_expiry": split_expiry,
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
                                print(f"Error loading saved trainer workout snapshot: {e}")
            except Exception:
                pass

            # --- CALCULATE STREAK ---
            streak = 0
            try:
                today = datetime.now().date()
                current_date = today

                # Go backwards from today, counting consecutive days
                while True:
                    date_str = current_date.isoformat()

                    # Check if there's a workout scheduled for this day
                    day_event = db.query(TrainerScheduleORM).filter(
                        TrainerScheduleORM.trainer_id == trainer_id,
                        TrainerScheduleORM.date == date_str,
                        TrainerScheduleORM.workout_id != None
                    ).first()

                    if day_event:
                        # There's a workout scheduled for this day
                        if day_event.completed:
                            streak += 1
                        else:
                            if current_date < today:
                                break
                    # No workout scheduled (rest day) - continue

                    # Move to previous day
                    current_date = current_date - timedelta(days=1)

                    # Safety limit: don't go back more than 365 days
                    if (today - current_date).days > 365:
                        break
            except Exception:
                streak = 0

            video_library = TRAINER_DATA["video_library"]
            return TrainerData(
                id=trainer_id,
                name=trainer.username if trainer else None,
                profile_picture=trainer.profile_picture if trainer else None,
                specialties=trainer.specialties if trainer else None,
                clients=clients,
                video_library=video_library,
                active_clients=active_count,
                at_risk_clients=at_risk_count,
                schedule=schedule,
                todays_workout=todays_workout,
                workouts=self.get_workouts(trainer_id),
                splits=self.get_splits(trainer_id),
                streak=streak
            )
        finally:
            db.close()

    def get_owner(self) -> OwnerData:
        return OwnerData(**OWNER_DATA)

    def get_exercises(self, trainer_id: str) -> list:
        """Delegate to ExerciseService."""
        return _exercise_service.get_exercises(trainer_id)

    def create_exercise(self, exercise: dict, trainer_id: str) -> dict:
        """Delegate to ExerciseService."""
        return _exercise_service.create_exercise(exercise, trainer_id)

    def update_exercise(self, exercise_id: str, updates: dict, trainer_id: str) -> dict:
        """Delegate to ExerciseService."""
        return _exercise_service.update_exercise(exercise_id, updates, trainer_id)

    def get_workouts(self, trainer_id: str) -> list:
        """Delegate to WorkoutService."""
        return _workout_service.get_workouts(trainer_id)

    def get_workout_details(self, workout_id: str, context_trainer_id: str = None, db_session=None) -> dict:
        """Delegate to WorkoutService."""
        return _workout_service.get_workout_details(workout_id, context_trainer_id, db_session)

    def create_workout(self, workout: dict, trainer_id: str) -> dict:
        """Delegate to WorkoutService."""
        return _workout_service.create_workout(workout, trainer_id)

    def update_workout(self, workout_id: str, updates: dict, trainer_id: str) -> dict:
        """Delegate to WorkoutService."""
        return _workout_service.update_workout(workout_id, updates, trainer_id)

    def delete_workout(self, workout_id: str, trainer_id: str) -> dict:
        """Delegate to WorkoutService."""
        return _workout_service.delete_workout(workout_id, trainer_id)

    def assign_workout(self, assignment: dict) -> dict:
        """Delegate to WorkoutService."""
        return _workout_service.assign_workout(assignment)

    def update_client_diet(self, client_id: str, diet_data: dict) -> dict:
        """Delegate to DietService."""
        return _diet_service.update_client_diet(client_id, diet_data)

    def assign_diet(self, diet_data: AssignDietRequest) -> dict:
        """Delegate to DietService."""
        return _diet_service.assign_diet(diet_data)

    def create_split(self, split_data: dict, trainer_id: str) -> dict:
        """Delegate to SplitService."""
        return _split_service.create_split(split_data, trainer_id)

    def get_splits(self, trainer_id: str) -> list:
        """Delegate to SplitService."""
        return _split_service.get_splits(trainer_id)

    def update_split(self, split_id: str, updates: dict, trainer_id: str) -> dict:
        """Delegate to SplitService."""
        return _split_service.update_split(split_id, updates, trainer_id)

    def delete_split(self, split_id: str, trainer_id: str) -> dict:
        """Delegate to SplitService."""
        return _split_service.delete_split(split_id, trainer_id)

    def assign_split(self, assignment: dict, trainer_id: str) -> dict:
        """Delegate to SplitService."""
        return _split_service.assign_split(assignment, trainer_id)

    # Helper functions for schedule conflict detection
    # Time utility methods now handled by ScheduleService
    def _parse_time(self, time_str: str):
        """Delegate to ScheduleService."""
        return _schedule_service._parse_time(time_str)

    def _add_minutes_to_time(self, time_obj, minutes: int):
        """Delegate to ScheduleService."""
        return _schedule_service._add_minutes_to_time(time_obj, minutes)

    def _times_overlap(self, start1, end1, start2, end2):
        """Delegate to ScheduleService."""
        return _schedule_service._times_overlap(start1, end1, start2, end2)

    def _check_schedule_conflict(self, trainer_id: str, date: str, time: str, duration: int, db, exclude_event_id=None):
        """Delegate to ScheduleService."""
        return _schedule_service._check_schedule_conflict(trainer_id, date, time, duration, db, exclude_event_id)

    def add_trainer_event(self, event_data: dict, trainer_id: str):
        """Delegate to ScheduleService."""
        return _schedule_service.add_trainer_event(event_data, trainer_id)

    def remove_trainer_event(self, event_id: str, trainer_id: str):
        """Delegate to ScheduleService."""
        return _schedule_service.remove_trainer_event(event_id, trainer_id)

    def toggle_trainer_event_completion(self, event_id: str, trainer_id: str) -> dict:
        """Delegate to ScheduleService."""
        return _schedule_service.toggle_trainer_event_completion(event_id, trainer_id)

    # --- TRAINER NOTES CRUD (delegated to NotesService) ---
    def save_trainer_note(self, trainer_id: str, title: str, content: str) -> dict:
        """Delegate to NotesService."""
        return _notes_service.save_trainer_note(trainer_id, title, content)

    def get_trainer_notes(self, trainer_id: str) -> list:
        """Delegate to NotesService."""
        return _notes_service.get_trainer_notes(trainer_id)

    def update_trainer_note(self, note_id: str, trainer_id: str, title: str, content: str) -> dict:
        """Delegate to NotesService."""
        return _notes_service.update_trainer_note(note_id, trainer_id, title, content)

    def delete_trainer_note(self, note_id: str, trainer_id: str) -> dict:
        """Delegate to NotesService."""
        return _notes_service.delete_trainer_note(note_id, trainer_id)

    def update_spotify_tokens(self, user_id: str, access_token: str = None, refresh_token: str = None, expires_at: str = None) -> bool:
        """Update user's Spotify OAuth tokens."""
        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.id == user_id).first()
            if not user:
                return False

            user.spotify_access_token = access_token
            user.spotify_refresh_token = refresh_token
            user.spotify_token_expires_at = expires_at

            db.commit()
            return True
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to update Spotify tokens: {e}")
            return False
        finally:
            db.close()

LEAGUE_TIERS = [
    {"name": "Bronze",   "level": 1, "min_gems": 0,    "color": "#D97706"},
    {"name": "Silver",   "level": 2, "min_gems": 500,  "color": "#9CA3AF"},
    {"name": "Gold",     "level": 3, "min_gems": 1500, "color": "#FACC15"},
    {"name": "Sapphire", "level": 4, "min_gems": 3500, "color": "#3B82F6"},
    {"name": "Diamond",  "level": 5, "min_gems": 7000, "color": "#67E8F9"},
]

class LeaderboardService:
    def _get_league_tier(self, gems: int) -> dict:
        """Determine league tier based on gem count."""
        tier = LEAGUE_TIERS[0]
        for t in LEAGUE_TIERS:
            if gems >= t["min_gems"]:
                tier = t
        return tier

    def get_leaderboard(self, current_user_id: str) -> LeaderboardData:
        """Get leaderboard data for users in the same gym as the current user."""
        db = get_db_session()
        try:
            # Get current user's profile to find their gym
            current_profile = db.query(ClientProfileORM).filter(
                ClientProfileORM.id == current_user_id
            ).first()

            # Compute league info
            user_gems = (current_profile.gems or 0) if current_profile else 0
            current_tier = self._get_league_tier(user_gems)

            # Next Monday 00:00 UTC for weekly reset
            today = date.today()
            days_until_monday = (7 - today.weekday()) % 7
            if days_until_monday == 0:
                days_until_monday = 7
            next_monday = datetime.combine(today + timedelta(days=days_until_monday), datetime.min.time())

            league_info = {
                "current_tier": current_tier,
                "all_tiers": LEAGUE_TIERS,
                "advance_count": 10,
                "weekly_reset_iso": next_monday.isoformat()
            }

            if not current_profile or not current_profile.gym_id:
                return LeaderboardData(
                    users=[],
                    weekly_challenge={
                        "title": "Weekly Workout Challenge",
                        "description": "Complete 5 workouts this week",
                        "progress": 0,
                        "target": 5,
                        "reward_gems": 200
                    },
                    league=league_info
                )

            gym_id = current_profile.gym_id

            # Get all clients in the same gym
            gym_profiles = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()

            # Build user list with their data
            users_data = []
            for profile in gym_profiles:
                user = db.query(UserORM).filter(UserORM.id == profile.id).first()
                if user:
                    users_data.append({
                        "user_id": profile.id,
                        "name": user.username,
                        "streak": profile.streak or 0,
                        "gems": profile.gems or 0,
                        "health_score": profile.health_score or 0,
                        "isCurrentUser": profile.id == current_user_id,
                        "profile_picture": user.profile_picture,
                        "privacy_mode": profile.privacy_mode or "public"
                    })

            # Sort by gems (descending) and assign ranks
            users_data.sort(key=lambda x: x["gems"], reverse=True)

            leaderboard_users = []
            for i, user_data in enumerate(users_data):
                leaderboard_users.append({
                    "name": user_data["name"],
                    "streak": user_data["streak"],
                    "gems": user_data["gems"],
                    "health_score": user_data["health_score"],
                    "rank": i + 1,
                    "isCurrentUser": user_data["isCurrentUser"],
                    "user_id": user_data["user_id"],
                    "profile_picture": user_data["profile_picture"],
                    "privacy_mode": user_data["privacy_mode"]
                })

            # Calculate weekly challenge progress (completed workouts this week)
            week_start = today - timedelta(days=today.weekday())  # Monday

            weekly_workouts = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == current_user_id,
                ClientScheduleORM.date >= week_start.isoformat(),
                ClientScheduleORM.completed == True
            ).count()

            weekly_challenge = {
                "title": "Weekly Workout Challenge",
                "description": "Complete 5 workouts this week",
                "progress": weekly_workouts,
                "target": 5,
                "reward_gems": 200
            }

            return LeaderboardData(
                users=leaderboard_users,
                weekly_challenge=weekly_challenge,
                league=league_info
            )

        finally:
            db.close()

def get_user_service():
    return UserService()
