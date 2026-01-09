from sqlalchemy import Column, Integer, String
from database import Base

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

