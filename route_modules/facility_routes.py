"""
Facility Routes - API endpoints for facility/field/room management and booking.
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from service_modules.facility_service import FacilityService, get_facility_service

router = APIRouter()


# ==================== OWNER ENDPOINTS ====================

@router.get("/api/owner/activity-types")
async def get_activity_types(
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage activity types")
    return service.get_activity_types(user.id)


@router.post("/api/owner/activity-types")
async def create_activity_type(
    data: dict,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage activity types")
    return service.create_activity_type(user.id, data)


@router.put("/api/owner/activity-types/{type_id}")
async def update_activity_type(
    type_id: str,
    data: dict,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage activity types")
    return service.update_activity_type(type_id, user.id, data)


@router.delete("/api/owner/activity-types/{type_id}")
async def delete_activity_type(
    type_id: str,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage activity types")
    return service.delete_activity_type(type_id, user.id)


@router.get("/api/owner/facilities/{activity_type_id}")
async def get_facilities(
    activity_type_id: str,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage facilities")
    return service.get_facilities(activity_type_id)


@router.post("/api/owner/facilities")
async def create_facility(
    data: dict,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage facilities")
    return service.create_facility(user.id, data)


@router.put("/api/owner/facilities/{facility_id}")
async def update_facility(
    facility_id: str,
    data: dict,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage facilities")
    return service.update_facility(facility_id, user.id, data)


@router.delete("/api/owner/facilities/{facility_id}")
async def delete_facility(
    facility_id: str,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage facilities")
    return service.delete_facility(facility_id, user.id)


@router.get("/api/owner/facilities/{facility_id}/availability")
async def get_facility_availability(
    facility_id: str,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage facilities")
    return service.get_facility_availability(facility_id)


@router.post("/api/owner/facilities/{facility_id}/availability")
async def set_facility_availability(
    facility_id: str,
    data: dict,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can manage facilities")
    return service.set_facility_availability(facility_id, user.id, data.get("availability", []))


@router.get("/api/owner/facility-bookings")
async def get_facility_bookings(
    date_from: str = None,
    date_to: str = None,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only owners can view facility bookings")
    return service.get_facility_bookings(user.id, date_from, date_to)


# ==================== CLIENT ENDPOINTS ====================

@router.get("/api/client/facility/activity-types")
async def client_get_activity_types(
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can browse facilities")
    return service.get_gym_activity_types(user.id)


@router.get("/api/client/facility/facilities/{activity_type_id}")
async def client_get_facilities(
    activity_type_id: str,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can browse facilities")
    return service.get_facilities_for_client(activity_type_id)


@router.get("/api/client/facility/{facility_id}/availability")
async def client_get_facility_availability(
    facility_id: str,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can browse facilities")
    return service.get_facility_availability(facility_id)


@router.get("/api/client/facility/{facility_id}/available-slots")
async def client_get_available_slots(
    facility_id: str,
    date: str,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view available slots")
    return service.get_available_slots(facility_id, date)


@router.post("/api/client/facility/bookings")
async def client_book_facility(
    data: dict,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can book facilities")
    return service.book_facility(user.id, data)


@router.get("/api/client/facility/bookings")
async def client_get_bookings(
    include_past: bool = False,
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view their bookings")
    return service.get_client_bookings(user.id, include_past)


@router.post("/api/client/facility/bookings/{booking_id}/cancel")
async def client_cancel_booking(
    booking_id: str,
    data: dict = {},
    user=Depends(get_current_user),
    service: FacilityService = Depends(get_facility_service)
):
    return service.cancel_booking(booking_id, user.id, data.get("reason"))
