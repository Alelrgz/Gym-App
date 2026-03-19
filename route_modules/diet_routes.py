"""
Diet Routes - API endpoints for diet management, meal scanning, and logging.
"""
from fastapi import APIRouter, Depends, File, UploadFile, HTTPException, Query, Request
from sqlalchemy.orm import Session
from auth import get_current_user
from database import get_db, get_db_session
from authorization import authorize_client_access
from models import AssignDietRequest, SelfAssignDietRequest, SetWeeklyMealPlanRequest, ClientAddMealRequest
from models_orm import UserORM, WeeklyMealPlanORM, ClientDietLogORM, ClientDietSettingsORM, WeightHistoryORM, ClientProfileORM
from service_modules.diet_service import DietService, get_diet_service
from datetime import datetime, date

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
    request: Request,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update a client's diet settings (macros, hydration, consistency)."""
    client_id = diet_data.get("client_id")
    if not client_id:
        raise HTTPException(status_code=400, detail="Missing client_id")
    authorize_client_access(current_user, client_id, "diet", "update",
                            "/api/trainer/diet", db, request)
    return service.update_client_diet(client_id, diet_data)


@router.post("/api/trainer/assign_diet")
async def assign_diet(
    diet_req: AssignDietRequest,
    request: Request,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Assign a complete diet plan to a client."""
    authorize_client_access(current_user, diet_req.client_id, "diet", "update",
                            "/api/trainer/assign_diet", db, request)
    return service.assign_diet(diet_req)


# ==================== CLIENT SELF-ASSIGN DIET ====================

@router.post("/api/client/diet/self-assign")
async def self_assign_diet(
    req: SelfAssignDietRequest,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Let a client set their own diet targets (only if no nutritionist assigned)."""
    db = get_db_session()
    try:
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == current_user.id).first()
        if profile and profile.nutritionist_id:
            raise HTTPException(status_code=403, detail="Hai un nutrizionista assegnato. Contattalo per modificare la dieta.")
    finally:
        db.close()

    diet_req = AssignDietRequest(
        client_id=current_user.id,
        calories=req.calories,
        protein=req.protein,
        carbs=req.carbs,
        fat=req.fat,
        hydration_target=req.hydration_target,
        consistency_target=req.consistency_target,
    )
    return service.assign_diet(diet_req)


# ==================== CLIENT MEAL PLAN MANAGEMENT ====================

@router.post("/api/client/weekly-meal-plan/add")
async def client_add_meal_to_plan(
    req: ClientAddMealRequest,
    current_user: UserORM = Depends(get_current_user)
):
    """Add a meal to the client's own weekly plan."""
    db = get_db_session()
    try:
        # Block if has nutritionist
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == current_user.id).first()
        if profile and profile.nutritionist_id:
            raise HTTPException(status_code=403, detail="Hai un nutrizionista assegnato.")

        entry = WeeklyMealPlanORM(
            client_id=current_user.id,
            assigned_by=current_user.id,
            day_of_week=req.day_of_week,
            meal_type=req.meal_type,
            meal_name=req.meal_name,
            description=req.description,
            calories=req.calories,
            protein=req.protein,
            carbs=req.carbs,
            fat=req.fat,
            updated_at=datetime.utcnow().isoformat()
        )
        db.add(entry)
        db.commit()
        return {"status": "success", "id": entry.id}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.delete("/api/client/weekly-meal-plan/{meal_id}")
async def client_delete_meal_from_plan(
    meal_id: int,
    current_user: UserORM = Depends(get_current_user)
):
    """Delete a meal from the client's own weekly plan."""
    db = get_db_session()
    try:
        entry = db.query(WeeklyMealPlanORM).filter(
            WeeklyMealPlanORM.id == meal_id,
            WeeklyMealPlanORM.client_id == current_user.id
        ).first()
        if not entry:
            raise HTTPException(status_code=404, detail="Pasto non trovato")
        db.delete(entry)
        db.commit()
        return {"status": "success"}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


# ==================== HYDRATION ====================

@router.post("/api/client/add-water")
async def add_water(
    current_user: UserORM = Depends(get_current_user)
):
    """Add 250ml of water to today's hydration."""
    db = get_db_session()
    try:
        today_str = date.today().isoformat()
        settings = db.query(ClientDietSettingsORM).filter(
            ClientDietSettingsORM.id == current_user.id
        ).first()

        if not settings:
            settings = ClientDietSettingsORM(
                id=current_user.id,
                last_reset_date=today_str,
                hydration_current=0,
                hydration_target=2500,
            )
            db.add(settings)

        # Reset if new day
        if settings.last_reset_date and settings.last_reset_date != today_str:
            settings.hydration_current = 0
            settings.last_reset_date = today_str

        # Cap at 10L
        if (settings.hydration_current or 0) >= 10000:
            return {"status": "error", "message": "Daily limit reached (10000ml)"}

        settings.hydration_current = (settings.hydration_current or 0) + 250
        db.commit()

        return {
            "status": "success",
            "current": settings.hydration_current,
            "target": settings.hydration_target or 2500,
        }
    finally:
        db.close()


# ==================== WEIGHT LOGGING ====================

@router.post("/api/client/log-weight")
async def log_weight(
    weight: float = Query(..., gt=0, lt=500),
    current_user: UserORM = Depends(get_current_user)
):
    """Log a weight entry for the client."""
    db = get_db_session()
    try:
        entry = WeightHistoryORM(
            client_id=current_user.id,
            weight=weight,
            recorded_at=datetime.now().isoformat()
        )
        db.add(entry)

        # Update current weight on profile
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == current_user.id).first()
        if profile:
            profile.weight = weight

        db.commit()
        return {"status": "success", "weight": weight}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.post("/api/client/weight-goal")
async def set_weight_goal(
    weight_goal: float = Query(..., gt=0, lt=500),
    current_user: UserORM = Depends(get_current_user)
):
    """Set weight goal for the client."""
    db = get_db_session()
    try:
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == current_user.id).first()
        if profile:
            profile.weight_goal = weight_goal
            db.commit()
            return {"status": "success", "weight_goal": weight_goal}
        raise HTTPException(status_code=404, detail="Profile not found")
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


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
