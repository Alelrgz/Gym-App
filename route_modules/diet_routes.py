"""
Diet Routes - API endpoints for diet management, meal scanning, and logging.
"""
from fastapi import APIRouter, Depends, File, UploadFile
from auth import get_current_user
from models import AssignDietRequest
from models_orm import UserORM
from service_modules.diet_service import DietService, get_diet_service

router = APIRouter()


@router.post("/api/client/diet/scan")
async def scan_meal(
    file: UploadFile = File(...),
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Scan a meal image using AI to estimate nutritional content."""
    # Read file bytes
    content = await file.read()
    return service.scan_meal(content)


@router.post("/api/client/diet/log")
async def log_meal(
    meal_data: dict,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Log a meal for the current client."""
    return service.log_meal(current_user.id, meal_data)


@router.post("/api/trainer/diet")
async def update_diet(
    diet_data: dict,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update a client's diet settings (macros, hydration, consistency)."""
    # Expects { "client_id": "...", "macros": {...}, "hydration_target": 2500, "consistency_target": 80 }
    client_id = diet_data.get("client_id")
    if not client_id:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Missing client_id")
    return service.update_client_diet(client_id, diet_data)


@router.post("/api/trainer/assign_diet")
async def assign_diet(
    diet_req: AssignDietRequest,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Assign a complete diet plan to a client."""
    return service.assign_diet(diet_req)
