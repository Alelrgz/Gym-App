"""
Schedule Routes - API endpoints for trainer events, client schedules, and workout completion.
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from models_orm import UserORM
from service_modules.schedule_service import ScheduleService, get_schedule_service
from services import UserService

router = APIRouter()


# Client schedule routes
@router.get("/api/client/schedule")
async def get_client_schedule(
    date: str = None,
    service: ScheduleService = Depends(get_schedule_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get client's schedule for a given date."""
    return service.get_client_schedule(current_user.id, date)


@router.get("/api/client/{client_id}/history")
async def get_client_history(
    client_id: str,
    exercise_name: str = None,
    service: ScheduleService = Depends(get_schedule_service)
):
    """Get historical performance data for a client's exercises."""
    try:
        # Ensure trainer has access to this client (skip auth for prototype)
        return service.get_client_exercise_history(client_id, exercise_name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/client/schedule/complete")
async def complete_schedule_item(
    payload: dict,
    service: ScheduleService = Depends(get_schedule_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Mark a client's schedule item as complete and save performance data."""
    # payload: { "date": "YYYY-MM-DD", "item_id": "...", "exercises": [...] }
    return service.complete_schedule_item(payload, current_user.id)


@router.put("/api/client/schedule/update_set")
async def update_completed_workout(
    payload: dict,
    service: ScheduleService = Depends(get_schedule_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update a single set in a completed workout."""
    return service.update_completed_workout(payload, current_user.id)


# Trainer schedule routes
@router.post("/api/trainer/schedule/complete")
async def complete_trainer_schedule_item(
    payload: dict,
    service: ScheduleService = Depends(get_schedule_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Mark a trainer's personal workout schedule item as complete."""
    # payload: { "date": "YYYY-MM-DD", "exercises": [...] }
    return service.complete_trainer_schedule_item(payload, current_user.id)


@router.post("/api/trainer/events")
async def add_trainer_event(
    event_data: dict,
    service: ScheduleService = Depends(get_schedule_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Add an event to trainer's schedule."""
    return service.add_trainer_event(event_data, current_user.id)


@router.put("/api/trainer/events/{event_id}")
async def update_trainer_event(
    event_id: str,
    updates: dict,
    service: ScheduleService = Depends(get_schedule_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update a trainer event (time, date, duration, etc)."""
    return service.update_trainer_event(event_id, updates, current_user.id)


@router.delete("/api/trainer/events/{event_id}")
async def delete_trainer_event(
    event_id: str,
    service: ScheduleService = Depends(get_schedule_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Remove an event from trainer's schedule."""
    return service.remove_trainer_event(event_id, current_user.id)


@router.post("/api/trainer/events/{event_id}/toggle_complete")
async def toggle_trainer_event_completion(
    event_id: str,
    service: ScheduleService = Depends(get_schedule_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Toggle completion status of a trainer event."""
    return service.toggle_trainer_event_completion(event_id, current_user.id)
