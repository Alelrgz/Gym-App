"""
Diet Routes - API endpoints for diet management, meal scanning, and logging.
"""
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, Query
from auth import get_current_user
from models import AssignDietRequest, SetWeeklyMealPlanRequest
from models_orm import UserORM, WeeklyMealPlanORM, ClientDietLogORM
from service_modules.diet_service import DietService, get_diet_service
from database import get_db_session
from datetime import datetime

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


@router.get("/api/client/diet/barcode/{barcode}")
async def lookup_barcode(
    barcode: str,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Look up a product by barcode using Open Food Facts."""
    return service.lookup_barcode(barcode)


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


# ==================== WEEKLY MEAL PLAN (Client) ====================

@router.get("/api/client/weekly-meal-plan")
async def get_client_weekly_meal_plan(
    current_user: UserORM = Depends(get_current_user)
):
    """Get the client's full weekly meal plan assigned by nutritionist/trainer."""
    db = get_db_session()
    try:
        entries = db.query(WeeklyMealPlanORM).filter(
            WeeklyMealPlanORM.client_id == current_user.id
        ).order_by(WeeklyMealPlanORM.day_of_week).all()

        # Group by day_of_week
        meal_order = ['colazione', 'spuntino_mattina', 'pranzo', 'spuntino_pomeriggio', 'cena']
        plan = {}
        for entry in entries:
            day = entry.day_of_week
            if day not in plan:
                plan[day] = []
            plan[day].append({
                "id": entry.id,
                "meal_type": entry.meal_type,
                "meal_name": entry.meal_name,
                "description": entry.description,
                "calories": entry.calories,
                "protein": entry.protein,
                "carbs": entry.carbs,
                "fat": entry.fat,
                "alternative_index": entry.alternative_index or 0
            })

        # Sort meals within each day by meal_order, then by alternative_index
        for day in plan:
            plan[day].sort(key=lambda m: (
                meal_order.index(m['meal_type']) if m['meal_type'] in meal_order else 99,
                m.get('alternative_index', 0)
            ))

        return {"status": "success", "plan": plan}
    finally:
        db.close()


@router.get("/api/client/diet-log/{date_str}")
async def get_client_diet_log_for_date(
    date_str: str,
    current_user: UserORM = Depends(get_current_user)
):
    """Get logged meals for a specific date."""
    db = get_db_session()
    try:
        logs = db.query(ClientDietLogORM).filter(
            ClientDietLogORM.client_id == current_user.id,
            ClientDietLogORM.date == date_str
        ).order_by(ClientDietLogORM.time).all()

        return {
            "status": "success",
            "meals": [{
                "id": log.id,
                "meal_type": log.meal_type,
                "meal_name": log.meal_name,
                "calories": log.calories,
                "time": log.time
            } for log in logs]
        }
    finally:
        db.close()
