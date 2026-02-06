"""
Split Routes - API endpoints for weekly split management.
"""
from fastapi import APIRouter, Depends
from auth import get_current_user
from models_orm import UserORM
from service_modules.split_service import SplitService, get_split_service

router = APIRouter()


@router.get("/api/trainer/splits")
async def get_splits(
    service: SplitService = Depends(get_split_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all splits accessible to the current trainer."""
    return service.get_splits(current_user.id)


@router.post("/api/trainer/splits")
async def create_split(
    split_data: dict,
    service: SplitService = Depends(get_split_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Create a new weekly split."""
    return service.create_split(split_data, current_user.id)


@router.put("/api/trainer/splits/{split_id}")
async def update_split(
    split_id: str,
    split_data: dict,
    service: SplitService = Depends(get_split_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update an existing split."""
    return service.update_split(split_id, split_data, current_user.id)


@router.delete("/api/trainer/splits/{split_id}")
async def delete_split(
    split_id: str,
    service: SplitService = Depends(get_split_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Delete a split."""
    return service.delete_split(split_id, current_user.id)


@router.post("/api/trainer/assign_split")
async def assign_split(
    assignment: dict,
    service: SplitService = Depends(get_split_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Assign a split to a client or trainer's own schedule."""
    return service.assign_split(assignment, current_user.id)
