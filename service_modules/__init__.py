"""
Services package - organized service modules.

This package provides modular services while maintaining backward compatibility
with the existing monolithic services.py imports.
"""
from .base import *
from .workout_service import WorkoutService, workout_service, get_workout_service

__all__ = [
    'WorkoutService',
    'workout_service',
    'get_workout_service',
]
