"""
Routes package - organized API routes.

This package provides modular route definitions.
Import the combined router for use in main.py.
"""
from fastapi import APIRouter

from .workout_routes import router as workout_router
from .exercise_routes import router as exercise_router
from .notes_routes import router as notes_router

# Combined router that includes all sub-routers
combined_router = APIRouter()
combined_router.include_router(workout_router, tags=["workouts"])
combined_router.include_router(exercise_router, tags=["exercises"])
combined_router.include_router(notes_router, tags=["notes"])

__all__ = ['combined_router', 'workout_router', 'exercise_router', 'notes_router']
