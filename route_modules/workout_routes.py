"""
Workout Routes - API endpoints for workout management.
"""
from fastapi import APIRouter, Depends, HTTPException, Body
from auth import get_current_user
from models_orm import UserORM, WeeklySplitORM
from service_modules.workout_service import WorkoutService, get_workout_service
from database import get_db_session
import json, uuid

router = APIRouter()


def require_trainer(user: UserORM):
    if user.role not in ("trainer", "owner"):
        raise HTTPException(status_code=403, detail="Only trainers can access this endpoint")


@router.get("/api/trainer/workouts")
async def get_workouts(
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all workouts accessible to the current trainer."""
    require_trainer(current_user)
    return service.get_workouts(current_user.id)


@router.post("/api/trainer/workouts")
async def create_workout(
    workout: dict,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Create a new workout."""
    require_trainer(current_user)
    return service.create_workout(workout, current_user.id)


@router.put("/api/trainer/workouts/{workout_id}")
async def update_workout(
    workout_id: str,
    workout: dict,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update an existing workout."""
    require_trainer(current_user)
    return service.update_workout(workout_id, workout, current_user.id)


@router.delete("/api/trainer/workouts/{workout_id}")
async def delete_workout(
    workout_id: str,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Delete a workout."""
    require_trainer(current_user)
    return service.delete_workout(workout_id, current_user.id)


@router.post("/api/trainer/assign_workout")
async def assign_workout(
    assignment: dict,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Assign a workout to a client."""
    require_trainer(current_user)
    return service.assign_workout(assignment)


# ── Client workout endpoints ──────────────────────────────────

@router.post("/api/client/workout/create")
async def client_create_workout(
    workout: dict,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Client creates a personal workout and assigns it to today."""
    result = service.create_workout(workout, current_user.id)
    # Auto-assign to today
    from datetime import date
    service.assign_workout({
        "client_id": current_user.id,
        "workout_id": result["id"],
        "date": date.today().isoformat(),
    })
    return result


@router.put("/api/client/workout/{workout_id}")
async def client_update_workout(
    workout_id: str,
    workout: dict,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Client updates their own workout."""
    return service.update_workout(workout_id, workout, current_user.id)


@router.get("/api/client/workouts")
async def client_list_workouts(
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """List all workouts owned by this client, plus their split."""
    result = service.get_client_workouts(current_user.id)
    # Also include client splits
    db = get_db_session()
    try:
        splits = db.query(WeeklySplitORM).filter(WeeklySplitORM.owner_id == current_user.id).all()
        result["splits"] = [{
            "id": s.id,
            "name": s.name,
            "days_per_week": s.days_per_week,
            "schedule": json.loads(s.schedule_json) if s.schedule_json else {},
        } for s in splits]
    finally:
        db.close()
    return result


@router.delete("/api/client/workout/{workout_id}")
async def client_delete_workout(
    workout_id: str,
    service: WorkoutService = Depends(get_workout_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Client deletes their own workout."""
    return service.delete_client_workout(workout_id, current_user.id)


@router.get("/api/client/splits")
async def get_client_splits(current_user: UserORM = Depends(get_current_user)):
    """Get all client's personal weekly splits."""
    db = get_db_session()
    try:
        splits = db.query(WeeklySplitORM).filter(WeeklySplitORM.owner_id == current_user.id).all()
        return {
            "splits": [{
                "id": s.id,
                "name": s.name,
                "days_per_week": s.days_per_week,
                "schedule": json.loads(s.schedule_json) if s.schedule_json else {},
            } for s in splits]
        }
    finally:
        db.close()


@router.post("/api/client/split")
async def create_client_split(
    data: dict = Body(...),
    current_user: UserORM = Depends(get_current_user)
):
    """Create a new client split."""
    db = get_db_session()
    try:
        schedule = data.get("schedule", {})
        name = data.get("name", "La Mia Split")
        split = WeeklySplitORM(
            id=str(uuid.uuid4()),
            name=name,
            days_per_week=len([v for v in schedule.values() if v]),
            schedule_json=json.dumps(schedule),
            owner_id=current_user.id,
        )
        db.add(split)
        db.commit()
        return {"status": "success", "id": split.id}
    finally:
        db.close()


@router.put("/api/client/split/{split_id}")
async def update_client_split(
    split_id: str,
    data: dict = Body(...),
    current_user: UserORM = Depends(get_current_user)
):
    """Update a client split."""
    db = get_db_session()
    try:
        split = db.query(WeeklySplitORM).filter(
            WeeklySplitORM.id == split_id,
            WeeklySplitORM.owner_id == current_user.id
        ).first()
        if not split:
            raise HTTPException(status_code=404, detail="Split not found")
        if "name" in data:
            split.name = data["name"]
        if "schedule" in data:
            split.schedule_json = json.dumps(data["schedule"])
            split.days_per_week = len([v for v in data["schedule"].values() if v])
        db.commit()
        return {"status": "success"}
    finally:
        db.close()


@router.delete("/api/client/split/{split_id}")
async def delete_client_split(
    split_id: str,
    current_user: UserORM = Depends(get_current_user)
):
    """Delete a client split."""
    db = get_db_session()
    try:
        split = db.query(WeeklySplitORM).filter(
            WeeklySplitORM.id == split_id,
            WeeklySplitORM.owner_id == current_user.id
        ).first()
        if not split:
            raise HTTPException(status_code=404, detail="Split not found")
        db.delete(split)
        db.commit()
        return {"status": "success"}
    finally:
        db.close()
