from sqlalchemy import Column, Integer, String, Boolean, Float, ForeignKey
from database import Base
from datetime import datetime

# --- CORE MODELS ---

class UserORM(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True, nullable=True)
    hashed_password = Column(String)
    role = Column(String) # client, trainer, owner
    is_active = Column(Boolean, default=True)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())

# --- EXERCISE & WORKOUT LIBRARY (Global + Personal) ---

class ExerciseORM(Base):
    __tablename__ = "exercises"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, index=True)
    muscle = Column(String)
    type = Column(String)
    video_id = Column(String)
    # If owner_id is NULL, it's a global exercise. If set, it belongs to that trainer.
    owner_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)

class WorkoutORM(Base):
    __tablename__ = "workouts"

    id = Column(String, primary_key=True, index=True)
    title = Column(String, index=True)
    duration = Column(String)
    difficulty = Column(String)
    
    # Store exercises as JSON string for flexibility (Schema: list of dicts)
    # Long term: normalized WorkoutExercise table
    exercises_json = Column(String) 
    
    owner_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)

class WeeklySplitORM(Base):
    __tablename__ = "weekly_splits"
    
    id = Column(String, primary_key=True, index=True)
    name = Column(String)
    description = Column(String)
    days_per_week = Column(Integer)
    schedule_json = Column(String) # Store schedule as JSON
    owner_id = Column(String, ForeignKey("users.id"), index=True)

# --- CLIENT DATA (Formerly in per-client DBs) ---

class ClientProfileORM(Base):
    __tablename__ = "client_profile"

    # One-to-One with User, so PK is the same as User ID
    id = Column(String, ForeignKey("users.id"), primary_key=True, index=True)
    name = Column(String)
    email = Column(String, nullable=True) 
    streak = Column(Integer, default=0)
    gems = Column(Integer, default=0)
    health_score = Column(Integer, default=0)
    plan = Column(String, nullable=True)
    status = Column(String, nullable=True)
    last_seen = Column(String, nullable=True)
    
    # Simple assignment logic for now
    trainer_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)
    
    is_premium = Column(Boolean, default=False)

class ClientScheduleORM(Base):
    __tablename__ = "client_schedule"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    # Vital for shared DB:
    client_id = Column(String, ForeignKey("users.id"), index=True) 
    
    date = Column(String, index=True) # ISO format YYYY-MM-DD
    title = Column(String)
    type = Column(String) # workout, rest, etc.
    completed = Column(Boolean, default=False)
    workout_id = Column(String, nullable=True)
    details = Column(String, nullable=True)

class ClientDietSettingsORM(Base):
    __tablename__ = "client_diet_settings"

    id = Column(String, ForeignKey("users.id"), primary_key=True, index=True) # client_id
    
    calories_target = Column(Integer, default=2000)
    protein_target = Column(Integer, default=150)
    carbs_target = Column(Integer, default=200)
    fat_target = Column(Integer, default=70)
    hydration_target = Column(Integer, default=2500)
    consistency_target = Column(Integer, default=80)

    # Cache current values
    calories_current = Column(Integer, default=0)
    protein_current = Column(Integer, default=0)
    carbs_current = Column(Integer, default=0)
    fat_current = Column(Integer, default=0)
    hydration_current = Column(Integer, default=0)

class ClientDietLogORM(Base):
    __tablename__ = "client_diet_log"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)
    
    date = Column(String, index=True) 
    meal_type = Column(String) 
    meal_name = Column(String)
    calories = Column(Integer)
    time = Column(String)

class ClientExerciseLogORM(Base):
    __tablename__ = "client_exercise_log"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)
    
    date = Column(String, index=True)
    workout_id = Column(String, nullable=True)
    exercise_name = Column(String, index=True)
    set_number = Column(Integer)
    reps = Column(Integer)
    weight = Column(Float)
    metric_type = Column(String, default="weight_reps") 

class TrainerScheduleORM(Base):
    __tablename__ = "trainer_schedule"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    trainer_id = Column(String, ForeignKey("users.id"), index=True)
    
    date = Column(String, index=True) # YYYY-MM-DD
    time = Column(String) # HH:MM AM/PM
    title = Column(String)
    subtitle = Column(String, nullable=True)
    type = Column(String) # consultation, class, etc 

