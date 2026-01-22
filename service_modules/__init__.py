"""
Services package - organized service modules.

This package provides modular services while maintaining backward compatibility
with the existing monolithic services.py imports.
"""
from .base import *
from .workout_service import WorkoutService, workout_service, get_workout_service
from .split_service import SplitService, split_service, get_split_service
from .exercise_service import ExerciseService, exercise_service, get_exercise_service
from .notes_service import NotesService, notes_service, get_notes_service
from .diet_service import DietService, diet_service, get_diet_service
from .schedule_service import ScheduleService, schedule_service, get_schedule_service

__all__ = [
    'WorkoutService',
    'workout_service',
    'get_workout_service',
    'SplitService',
    'split_service',
    'get_split_service',
    'ExerciseService',
    'exercise_service',
    'get_exercise_service',
    'NotesService',
    'notes_service',
    'get_notes_service',
    'DietService',
    'diet_service',
    'get_diet_service',
    'ScheduleService',
    'schedule_service',
    'get_schedule_service',
]
