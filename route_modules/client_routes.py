"""
Client Routes - API endpoints for client profile management and data retrieval.
"""
from fastapi import APIRouter, Depends
from auth import get_current_user
from models import ClientData, ClientProfileUpdate
from models_orm import UserORM
from service_modules.client_service import ClientService, get_client_service
from service_modules.workout_service import get_workout_service

router = APIRouter()


@router.get("/api/client/data", response_model=ClientData)
async def get_client_data(
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get client's own data (current user)."""
    workout_service = get_workout_service()
    return service.get_client(
        current_user.id,
        get_workout_details_fn=workout_service.get_workout_details
    )


@router.get("/api/trainer/client/{client_id}", response_model=ClientData)
async def get_client_for_trainer(
    client_id: str,
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get a specific client's data (trainer access)."""
    workout_service = get_workout_service()
    return service.get_client(
        client_id,
        get_workout_details_fn=workout_service.get_workout_details
    )


@router.put("/api/client/profile")
async def update_client_profile(
    profile_update: ClientProfileUpdate,
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update a client's profile information."""
    return service.update_client_profile(profile_update, current_user.id)


@router.post("/api/trainer/client/{client_id}/toggle_premium")
async def toggle_client_premium(
    client_id: str,
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Toggle premium status for a client (trainer access)."""
    return service.toggle_premium_status(client_id)
