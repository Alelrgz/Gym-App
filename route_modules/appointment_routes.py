"""
Appointment Routes - API endpoints for trainer availability and 1-on-1 booking
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from service_modules.appointment_service import get_appointment_service, AppointmentService
from models import (
    BookAppointmentRequest, UpdateAvailabilityRequest,
    CancelAppointmentRequest
)

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
