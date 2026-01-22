"""
Base service utilities and shared imports.
All services should import from here for common functionality.
"""
from fastapi import HTTPException
import uuid
import json
import logging
from datetime import date, datetime, timedelta

from database import get_db_session, Base, engine
from models_orm import (
    ExerciseORM, WorkoutORM, WeeklySplitORM, UserORM,
    ClientProfileORM, ClientScheduleORM, ClientDietSettingsORM,
    ClientExerciseLogORM, ClientDietLogORM, TrainerScheduleORM,
    TrainerNoteORM
)

# Re-export for convenience
__all__ = [
    'HTTPException', 'uuid', 'json', 'logging', 'date', 'datetime', 'timedelta',
    'get_db_session', 'Base', 'engine',
    'ExerciseORM', 'WorkoutORM', 'WeeklySplitORM', 'UserORM',
    'ClientProfileORM', 'ClientScheduleORM', 'ClientDietSettingsORM',
    'ClientExerciseLogORM', 'ClientDietLogORM', 'TrainerScheduleORM',
    'TrainerNoteORM'
]

logger = logging.getLogger("gym_app")
