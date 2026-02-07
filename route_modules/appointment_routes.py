"""
Appointment Routes - API endpoints for trainer availability and 1-on-1 booking
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from auth import get_current_user
from service_modules.appointment_service import get_appointment_service, AppointmentService
from models import (
    BookAppointmentRequest, UpdateAvailabilityRequest,
    CancelAppointmentRequest
)
from database import get_db_session
from models_orm import UserORM, AppointmentORM

router = APIRouter()


# --- TRAINER ENDPOINTS (Availability Management) ---

@router.post("/api/trainer/availability")
async def set_availability(
    request: UpdateAvailabilityRequest,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Set trainer's weekly availability for appointments."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can set availability")

    return service.set_trainer_availability(user.id, request.availability)


@router.get("/api/trainer/availability")
async def get_my_availability(
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Get trainer's current availability schedule."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can view their availability")

    return service.get_trainer_availability(user.id)


@router.get("/api/trainer/session-types")
async def get_session_types(
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Get trainer's custom session types."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can view their session types")

    return service.get_trainer_session_types(user.id)


@router.post("/api/trainer/session-types")
async def set_session_types(
    request: dict,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Set trainer's custom session types."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can set session types")

    session_types = request.get("session_types", [])
    return service.set_trainer_session_types(user.id, session_types)


@router.get("/api/client/trainer/{trainer_id}/session-types")
async def get_trainer_session_types_for_client(
    trainer_id: str,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Get a trainer's session types (for clients booking)."""
    return service.get_trainer_session_types(trainer_id)


@router.get("/api/trainer/available-slots")
async def get_my_available_slots(
    date: str,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Get trainer's own available slots for a specific date."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can view their slots")

    return service.get_available_slots(user.id, date)


@router.get("/api/trainer/appointments")
async def get_trainer_appointments(
    include_past: bool = False,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Get all appointments for the trainer."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can view their appointments")

    return service.get_trainer_appointments(user.id, include_past)


@router.post("/api/trainer/appointments/{appointment_id}/complete")
async def complete_appointment(
    appointment_id: str,
    trainer_notes: str = None,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Mark an appointment as completed."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can complete appointments")

    return service.complete_appointment(appointment_id, user.id, trainer_notes)


@router.post("/api/trainer/book-appointment")
async def trainer_book_appointment(
    request: BookAppointmentRequest,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Allow trainer to book an appointment with a client."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can book appointments for clients")

    # Use trainer's ID instead of client_id for the trainer_id field
    # The request.trainer_id field will actually contain the client_id when called by trainer
    return service.book_appointment_as_trainer(user.id, request)


# --- CLIENT ENDPOINTS (Booking Management) ---

@router.get("/api/client/gym-trainers")
async def get_gym_trainers(
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Get all trainers in the client's gym."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view gym trainers")

    return service.get_gym_trainers(user.id)


@router.get("/api/client/trainers/{trainer_id}/availability")
async def get_trainer_availability(
    trainer_id: str,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Get a trainer's weekly availability schedule (for booking)."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view trainer availability")

    return service.get_trainer_availability(trainer_id)


@router.get("/api/client/trainers/{trainer_id}/available-slots")
async def get_available_slots(
    trainer_id: str,
    date: str,  # YYYY-MM-DD
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Get available time slots for a trainer on a specific date."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view available slots")

    return service.get_available_slots(trainer_id, date)


@router.post("/api/client/appointments")
async def book_appointment(
    request: BookAppointmentRequest,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Book a 1-on-1 appointment with a trainer."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can book appointments")

    return service.book_appointment(user.id, request)


@router.get("/api/client/appointments")
async def get_my_appointments(
    include_past: bool = False,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Get all appointments for the client."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view their appointments")

    return service.get_client_appointments(user.id, include_past)


@router.post("/api/appointments/{appointment_id}/cancel")
async def cancel_appointment(
    appointment_id: str,
    request: CancelAppointmentRequest,
    user = Depends(get_current_user),
    service: AppointmentService = Depends(get_appointment_service)
):
    """Cancel an appointment (both clients and trainers can cancel)."""
    return service.cancel_appointment(appointment_id, user.id, request)


# --- TRAINER SESSION RATE ---

@router.get("/api/trainer/session-rate")
async def get_session_rate(
    user = Depends(get_current_user)
):
    """Get trainer's hourly session rate."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can view their rate")

    return {"session_rate": getattr(user, 'session_rate', None)}


@router.post("/api/trainer/session-rate")
async def set_session_rate(
    data: dict,
    user = Depends(get_current_user)
):
    """Set trainer's hourly session rate."""
    if user.role != "trainer":
        raise HTTPException(status_code=403, detail="Only trainers can set their rate")

    rate = data.get("session_rate")
    if rate is not None and rate < 0:
        raise HTTPException(status_code=400, detail="Rate cannot be negative")

    db = get_db_session()
    try:
        trainer = db.query(UserORM).filter(UserORM.id == user.id).first()
        trainer.session_rate = float(rate) if rate is not None else None
        db.commit()
        return {"status": "success", "session_rate": trainer.session_rate}
    finally:
        db.close()


@router.get("/api/client/trainers/{trainer_id}/session-rate")
async def get_trainer_rate_for_client(
    trainer_id: str,
    user = Depends(get_current_user)
):
    """Get a trainer's session rate (for clients viewing pricing)."""
    db = get_db_session()
    try:
        trainer = db.query(UserORM).filter(
            UserORM.id == trainer_id,
            UserORM.role == "trainer"
        ).first()
        if not trainer:
            raise HTTPException(status_code=404, detail="Trainer not found")

        return {
            "trainer_id": trainer_id,
            "session_rate": getattr(trainer, 'session_rate', None),
            "trainer_name": trainer.username
        }
    finally:
        db.close()


# --- APPOINTMENT PAYMENT ---

@router.post("/api/client/appointment-payment-intent")
async def create_appointment_payment_intent(
    data: dict,
    user = Depends(get_current_user)
):
    """Create a Stripe PaymentIntent for a 1-on-1 session booking."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can create appointment payments")

    import stripe
    import os

    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key or stripe.api_key.startswith("your_"):
        raise HTTPException(status_code=400, detail="Stripe is not configured")

    trainer_id = data.get("trainer_id")
    duration = data.get("duration", 60)

    if not trainer_id:
        raise HTTPException(status_code=400, detail="trainer_id is required")

    db = get_db_session()
    try:
        trainer = db.query(UserORM).filter(
            UserORM.id == trainer_id,
            UserORM.role == "trainer"
        ).first()

        if not trainer:
            raise HTTPException(status_code=404, detail="Trainer not found")

        session_rate = getattr(trainer, 'session_rate', None)
        if not session_rate or session_rate <= 0:
            raise HTTPException(status_code=400, detail="Trainer has no session rate configured")

        # Calculate price based on duration
        price = round(session_rate * (duration / 60), 2)
        amount_cents = int(price * 100)

        if amount_cents < 50:
            amount_cents = 50

        intent = stripe.PaymentIntent.create(
            amount=amount_cents,
            currency="usd",
            metadata={
                "type": "appointment",
                "trainer_id": trainer_id,
                "client_id": user.id,
                "duration": str(duration),
                "trainer_name": trainer.username
            },
            description=f"1-on-1 session with {trainer.username} ({duration} min)"
        )

        return {
            "client_secret": intent.client_secret,
            "amount": price,
            "currency": "USD"
        }

    except stripe.StripeError as e:
        raise HTTPException(status_code=400, detail=f"Payment setup failed: {str(e)}")
    finally:
        db.close()


@router.post("/api/client/appointment-checkout-session")
async def create_appointment_checkout_session(
    data: dict,
    request: Request,
    user = Depends(get_current_user)
):
    """Create a Stripe Checkout Session for a 1-on-1 session booking."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can create appointment payments")

    import stripe
    import os

    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key or stripe.api_key.startswith("your_"):
        raise HTTPException(status_code=400, detail="Stripe is not configured")

    trainer_id = data.get("trainer_id")
    duration = data.get("duration", 60)
    date = data.get("date")
    start_time = data.get("start_time")
    notes = data.get("notes", "")

    if not trainer_id or not date or not start_time:
        raise HTTPException(status_code=400, detail="trainer_id, date, and start_time are required")

    db = get_db_session()
    try:
        trainer = db.query(UserORM).filter(
            UserORM.id == trainer_id,
            UserORM.role == "trainer"
        ).first()

        if not trainer:
            raise HTTPException(status_code=404, detail="Trainer not found")

        session_rate = getattr(trainer, 'session_rate', None)
        if not session_rate or session_rate <= 0:
            raise HTTPException(status_code=400, detail="Trainer has no session rate configured")

        price = round(session_rate * (duration / 60), 2)
        amount_cents = int(price * 100)
        if amount_cents < 50:
            amount_cents = 50

        base_url = str(request.base_url).rstrip("/")
        success_url = f"{base_url}/api/client/appointment-checkout-success?session_id={{CHECKOUT_SESSION_ID}}"
        cancel_url = f"{base_url}/?role=client&booking_canceled=true"

        checkout_session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            mode="payment",
            line_items=[{
                "price_data": {
                    "currency": "usd",
                    "product_data": {
                        "name": f"1-on-1 Session with {trainer.username} ({duration} min)",
                    },
                    "unit_amount": amount_cents,
                },
                "quantity": 1,
            }],
            metadata={
                "type": "appointment",
                "client_id": user.id,
                "trainer_id": trainer_id,
                "date": date,
                "start_time": start_time,
                "duration": str(duration),
                "notes": (notes or "")[:500],
                "trainer_name": trainer.username,
            },
            success_url=success_url,
            cancel_url=cancel_url,
        )

        return {"checkout_url": checkout_session.url}

    except stripe.StripeError as e:
        raise HTTPException(status_code=400, detail=f"Payment setup failed: {str(e)}")
    finally:
        db.close()


@router.get("/api/client/appointment-checkout-success")
async def appointment_checkout_success(
    session_id: str,
    service: AppointmentService = Depends(get_appointment_service)
):
    """Handle redirect from Stripe Checkout — create the appointment."""
    import stripe
    import os

    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")

    try:
        checkout_session = stripe.checkout.Session.retrieve(session_id)
    except stripe.StripeError:
        return RedirectResponse(url="/?role=client&booking_error=payment_verification_failed")

    if checkout_session.payment_status != "paid":
        return RedirectResponse(url="/?role=client&booking_error=payment_not_completed")

    meta = checkout_session.metadata

    # Idempotency: check if appointment already created for this payment
    db = get_db_session()
    try:
        existing = db.query(AppointmentORM).filter(
            AppointmentORM.stripe_payment_intent_id == checkout_session.payment_intent
        ).first()
        if existing:
            return RedirectResponse(url="/?role=client&booking_success=true")
    finally:
        db.close()

    booking_request = BookAppointmentRequest(
        trainer_id=meta.get("trainer_id"),
        date=meta.get("date"),
        start_time=meta.get("start_time"),
        duration=int(meta.get("duration", 60)),
        notes=meta.get("notes") or None,
        payment_method="card",
        stripe_payment_intent_id=checkout_session.payment_intent,
    )

    try:
        service.book_appointment(meta.get("client_id"), booking_request)
    except HTTPException as e:
        return RedirectResponse(url=f"/?role=client&booking_error={e.detail}")

    return RedirectResponse(url="/?role=client&booking_success=true")
