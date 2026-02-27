"""
Nutritionist Routes - API endpoints for nutritionist dashboard, client body management, and appointments.
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from auth import get_current_user
from models import (
    AddBodyCompositionRequest, SetWeightGoalRequest, AssignDietRequest,
    UpdateClientHealthDataRequest,
    BookNutritionistAppointmentRequest, SetAvailabilityRequest,
    UpdateAvailabilityRequest, CancelAppointmentRequest,
    SetWeeklyMealPlanRequest
)
from models_orm import UserORM, NutritionistAppointmentORM, WeeklyMealPlanORM
from database import get_db_session
from service_modules.nutritionist_service import NutritionistService, get_nutritionist_service
from service_modules.diet_service import DietService, get_diet_service
from service_modules.client_service import ClientService, get_client_service
from service_modules.nutritionist_appointment_service import (
    NutritionistAppointmentService, get_nutritionist_appointment_service
)

router = APIRouter()


def _require_nutritionist(user: UserORM):
    if user.role != "nutritionist":
        raise HTTPException(status_code=403, detail="Only nutritionists can access this endpoint")


# ==================== DASHBOARD ====================

@router.get("/api/nutritionist/data")
async def get_nutritionist_data(
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.get_nutritionist(current_user.id)


@router.get("/api/nutritionist/client/{client_id}")
async def get_client_detail(
    client_id: str,
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.get_client_detail(client_id)


# ==================== BODY COMPOSITION ====================

@router.post("/api/nutritionist/client/body-composition")
async def add_body_composition(
    request: AddBodyCompositionRequest,
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.add_body_composition(
        current_user.id, request.client_id,
        request.weight, request.body_fat_pct,
        request.fat_mass, request.lean_mass
    )


@router.post("/api/nutritionist/client/weight-goal")
async def set_weight_goal(
    request: SetWeightGoalRequest,
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.set_weight_goal(current_user.id, request.client_id, request.weight_goal)


# ==================== HEALTH DATA ====================

@router.post("/api/nutritionist/client/health-data")
async def update_client_health_data(
    request: UpdateClientHealthDataRequest,
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.update_client_health_data(current_user.id, request)


# ==================== DIET ====================

@router.post("/api/nutritionist/assign_diet")
async def nutritionist_assign_diet(
    diet_req: AssignDietRequest,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.assign_diet(diet_req)


@router.post("/api/nutritionist/diet")
async def nutritionist_update_diet(
    diet_data: dict,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    client_id = diet_data.get("client_id")
    if not client_id:
        raise HTTPException(status_code=400, detail="Missing client_id")
    return service.update_client_diet(client_id, diet_data)


# ==================== WEEKLY MEAL PLAN ====================

@router.post("/api/nutritionist/client/{client_id}/weekly-meal-plan")
async def set_client_weekly_meal_plan(
    client_id: str,
    data: SetWeeklyMealPlanRequest,
    current_user: UserORM = Depends(get_current_user)
):
    """Set/replace the meal plan for a specific day of the week."""
    _require_nutritionist(current_user)
    from datetime import datetime
    db = get_db_session()
    try:
        # Delete existing meals for this day
        db.query(WeeklyMealPlanORM).filter(
            WeeklyMealPlanORM.client_id == client_id,
            WeeklyMealPlanORM.day_of_week == data.day_of_week
        ).delete()

        # Insert new meals
        for meal in data.meals:
            entry = WeeklyMealPlanORM(
                client_id=client_id,
                assigned_by=current_user.id,
                day_of_week=data.day_of_week,
                meal_type=meal.meal_type,
                meal_name=meal.meal_name,
                description=meal.description,
                calories=meal.calories,
                protein=meal.protein,
                carbs=meal.carbs,
                fat=meal.fat,
                alternative_index=meal.alternative_index,
                updated_at=datetime.utcnow().isoformat()
            )
            db.add(entry)

        db.commit()
        return {"status": "success", "message": f"Piano pasti aggiornato per giorno {data.day_of_week}"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@router.get("/api/nutritionist/client/{client_id}/weekly-meal-plan")
async def get_client_weekly_meal_plan(
    client_id: str,
    current_user: UserORM = Depends(get_current_user)
):
    """Get a client's full weekly meal plan."""
    _require_nutritionist(current_user)
    db = get_db_session()
    try:
        entries = db.query(WeeklyMealPlanORM).filter(
            WeeklyMealPlanORM.client_id == client_id
        ).order_by(WeeklyMealPlanORM.day_of_week).all()

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

        for day in plan:
            plan[day].sort(key=lambda m: (
                meal_order.index(m['meal_type']) if m['meal_type'] in meal_order else 99,
                m.get('alternative_index', 0)
            ))

        return {"status": "success", "plan": plan}
    finally:
        db.close()


# ==================== CLIENT CHART DATA ====================

@router.get("/api/nutritionist/client/{client_id}/weight-history")
async def get_client_weight_history(
    client_id: str,
    period: str = "month",
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.get_weight_history(client_id, period)


@router.get("/api/nutritionist/client/{client_id}/diet-consistency")
async def get_client_diet_consistency(
    client_id: str,
    period: str = "month",
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.get_diet_consistency(client_id, period)


# ==================== NUTRITIONIST AVAILABILITY ====================

@router.post("/api/nutritionist/availability")
async def set_availability(
    data: UpdateAvailabilityRequest,
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return appt_service.set_availability(current_user.id, data.availability)


@router.get("/api/nutritionist/availability")
async def get_availability(
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return appt_service.get_availability(current_user.id)


# ==================== NUTRITIONIST SESSION RATE ====================

@router.get("/api/nutritionist/session-rate")
async def get_session_rate(user=Depends(get_current_user)):
    _require_nutritionist(user)
    return {"session_rate": getattr(user, 'session_rate', None)}


@router.post("/api/nutritionist/session-rate")
async def set_session_rate(data: dict, user=Depends(get_current_user)):
    _require_nutritionist(user)
    rate = data.get("session_rate")
    if rate is not None and rate < 0:
        raise HTTPException(status_code=400, detail="Rate cannot be negative")
    db = get_db_session()
    try:
        nutri = db.query(UserORM).filter(UserORM.id == user.id).first()
        nutri.session_rate = float(rate) if rate is not None else None
        db.commit()
        return {"status": "success", "session_rate": nutri.session_rate}
    finally:
        db.close()


# ==================== NUTRITIONIST APPOINTMENTS ====================

@router.get("/api/nutritionist/appointments")
async def get_appointments(
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return appt_service.get_nutritionist_appointments(current_user.id)


@router.post("/api/nutritionist/appointments/{appointment_id}/complete")
async def complete_appointment(
    appointment_id: str,
    data: dict = None,
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    notes = data.get("notes") if data else None
    return appt_service.complete_appointment(appointment_id, current_user.id, notes)


# ==================== CLIENT-FACING NUTRITIONIST ENDPOINTS ====================

@router.get("/api/client/nutritionists/{nutritionist_id}/availability")
async def get_nutritionist_availability_for_client(
    nutritionist_id: str,
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service),
    user=Depends(get_current_user)
):
    return appt_service.get_availability(nutritionist_id)


@router.get("/api/client/nutritionists/{nutritionist_id}/available-slots")
async def get_nutritionist_available_slots(
    nutritionist_id: str,
    date: str = None,
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service),
    user=Depends(get_current_user)
):
    if not date:
        raise HTTPException(status_code=400, detail="date parameter required")
    return appt_service.get_available_slots(nutritionist_id, date)


@router.get("/api/client/nutritionists/{nutritionist_id}/session-rate")
async def get_nutritionist_rate_for_client(
    nutritionist_id: str,
    user=Depends(get_current_user)
):
    db = get_db_session()
    try:
        nutri = db.query(UserORM).filter(UserORM.id == nutritionist_id).first()
        if not nutri:
            raise HTTPException(status_code=404, detail="Nutritionist not found")
        return {
            "nutritionist_id": nutritionist_id,
            "session_rate": getattr(nutri, 'session_rate', None),
            "nutritionist_name": nutri.username
        }
    finally:
        db.close()


@router.post("/api/client/nutrition-appointments")
async def book_nutrition_appointment(
    request: BookNutritionistAppointmentRequest,
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service),
    user=Depends(get_current_user)
):
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can book appointments")
    return appt_service.book_appointment(user.id, request)


@router.get("/api/client/nutrition-appointments")
async def get_my_nutrition_appointments(
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service),
    user=Depends(get_current_user)
):
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view appointments")
    return appt_service.get_client_appointments(user.id)


@router.post("/api/client/nutrition-appointments/{appointment_id}/cancel")
async def cancel_nutrition_appointment(
    appointment_id: str,
    request: CancelAppointmentRequest = CancelAppointmentRequest(),
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service),
    user=Depends(get_current_user)
):
    return appt_service.cancel_appointment(appointment_id, user.id, request)


# ==================== NUTRITION APPOINTMENT PAYMENT ====================

@router.post("/api/client/nutrition-checkout-session")
async def create_nutrition_checkout_session(
    data: dict,
    request: Request,
    user=Depends(get_current_user)
):
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can create payments")

    import stripe
    import os

    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key or stripe.api_key.startswith("your_"):
        raise HTTPException(status_code=400, detail="Stripe is not configured")

    nutritionist_id = data.get("nutritionist_id")
    duration = data.get("duration", 60)
    appt_date = data.get("date")
    start_time = data.get("start_time")
    notes = data.get("notes", "")

    if not nutritionist_id or not appt_date or not start_time:
        raise HTTPException(status_code=400, detail="nutritionist_id, date, and start_time are required")

    db = get_db_session()
    try:
        nutri = db.query(UserORM).filter(UserORM.id == nutritionist_id).first()
        if not nutri:
            raise HTTPException(status_code=404, detail="Nutritionist not found")

        rate = getattr(nutri, 'session_rate', None)
        if not rate or rate <= 0:
            raise HTTPException(status_code=400, detail="Nutritionist has no session rate configured")

        price = round(rate * (duration / 60), 2)
        amount_cents = max(int(price * 100), 50)

        base_url = str(request.base_url).rstrip("/")
        success_url = f"{base_url}/api/client/nutrition-checkout-success?session_id={{CHECKOUT_SESSION_ID}}"
        cancel_url = f"{base_url}/?role=client&booking_canceled=true"

        checkout_session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            mode="payment",
            line_items=[{
                "price_data": {
                    "currency": "eur",
                    "product_data": {
                        "name": f"Consulenza Nutrizionale con {nutri.username} ({duration} min)",
                    },
                    "unit_amount": amount_cents,
                },
                "quantity": 1,
            }],
            metadata={
                "type": "nutrition_appointment",
                "client_id": user.id,
                "nutritionist_id": nutritionist_id,
                "date": appt_date,
                "start_time": start_time,
                "duration": str(duration),
                "notes": (notes or "")[:500],
                "nutritionist_name": nutri.username,
            },
            success_url=success_url,
            cancel_url=cancel_url,
        )

        return {"checkout_url": checkout_session.url}

    except Exception as e:
        if "Stripe" in type(e).__name__:
            raise HTTPException(status_code=400, detail=f"Payment setup failed: {str(e)}")
        raise
    finally:
        db.close()


@router.get("/api/client/nutrition-checkout-success")
async def nutrition_checkout_success(
    session_id: str,
    appt_service: NutritionistAppointmentService = Depends(get_nutritionist_appointment_service)
):
    import stripe
    import os

    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")

    try:
        checkout_session = stripe.checkout.Session.retrieve(session_id)
    except Exception:
        return RedirectResponse(url="/?role=client&booking_error=payment_verification_failed")

    if checkout_session.payment_status != "paid":
        return RedirectResponse(url="/?role=client&booking_error=payment_not_completed")

    meta = checkout_session.metadata

    # Idempotency check
    db = get_db_session()
    try:
        existing = db.query(NutritionistAppointmentORM).filter(
            NutritionistAppointmentORM.stripe_payment_intent_id == checkout_session.payment_intent
        ).first()
        if existing:
            return RedirectResponse(url="/?role=client&booking_success=true")
    finally:
        db.close()

    booking_request = BookNutritionistAppointmentRequest(
        nutritionist_id=meta.get("nutritionist_id"),
        date=meta.get("date"),
        start_time=meta.get("start_time"),
        duration=int(meta.get("duration", 60)),
        notes=meta.get("notes") or None,
        payment_method="card",
        stripe_payment_intent_id=checkout_session.payment_intent,
    )

    try:
        appt_service.book_appointment(meta.get("client_id"), booking_request)
    except HTTPException as e:
        return RedirectResponse(url=f"/?role=client&booking_error={e.detail}")

    return RedirectResponse(url="/?role=client&booking_success=true")
