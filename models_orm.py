from sqlalchemy import Column, Integer, String, Boolean
from database import Base
from datetime import datetime

class ExerciseORM(Base):
    __tablename__ = "exercises"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, index=True)
    muscle = Column(String)
    type = Column(String)
    video_id = Column(String)
    owner_id = Column(String, index=True, nullable=True) # NULL = Global, Value = Personal

class WorkoutORM(Base):
    __tablename__ = "workouts"

    id = Column(String, primary_key=True, index=True)
    title = Column(String, index=True)
    duration = Column(String)
    difficulty = Column(String)
    exercises_json = Column(String) # Store exercises as JSON string
    owner_id = Column(String, index=True, nullable=True) # NULL = Global, Value = Personal

class WeeklySplitORM(Base):
    __tablename__ = "weekly_splits"
    id = Column(String, primary_key=True, index=True)
    name = Column(String)
    description = Column(String)
    days_per_week = Column(Integer)
    schedule_json = Column(String) # Store schedule as JSON
    owner_id = Column(String, index=True)

class UserORM(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True, nullable=True)
    hashed_password = Column(String)
    role = Column(String) # client, trainer, owner
    is_active = Column(Boolean, default=True)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())

