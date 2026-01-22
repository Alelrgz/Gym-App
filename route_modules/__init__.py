"""
Routes package - organized API routes.

This package provides modular route definitions.
Import the combined router for use in main.py.
"""
from fastapi import APIRouter

from .workout_routes import router as workout_router
from .exercise_routes import router as exercise_router
from .notes_routes import router as notes_router
from .diet_routes import router as diet_router
from .schedule_routes import router as schedule_router
from .client_routes import router as client_router

# Combined router that includes all sub-routers
combined_router = APIRouter()
combined_router.include_router(workout_router, tags=["workouts"])
combined_router.include_router(exercise_router, tags=["exercises"])
combined_router.include_router(notes_router, tags=["notes"])
combined_router.include_router(diet_router, tags=["diet"])
combined_router.include_router(schedule_router, tags=["schedule"])
combined_router.include_router(client_router, tags=["clients"])

__all__ = ['combined_router', 'workout_router', 'exercise_router', 'notes_router', 'diet_router', 'schedule_router', 'client_router']
