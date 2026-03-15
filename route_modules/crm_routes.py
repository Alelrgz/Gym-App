"""
CRM Routes - API endpoints for CRM analytics and client management.
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from gym_context import get_gym_context
from service_modules.crm_service import get_crm_service, CRMService
import logging

logger = logging.getLogger("gym_app")
router = APIRouter()


@router.get("/api/owner/crm/pipeline")
async def get_pipeline(
    user = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: CRMService = Depends(get_crm_service)
):
    """Get client pipeline/funnel data."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    return service.get_client_pipeline(gym_id)


@router.get("/api/owner/crm/at-risk")
async def get_at_risk_clients(
    limit: int = 20,
    user = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: CRMService = Depends(get_crm_service)
):
    """Get list of at-risk clients needing attention."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    return service.get_at_risk_clients(gym_id, limit)


@router.get("/api/owner/crm/analytics")
async def get_analytics(
    period: str = "month",
    user = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: CRMService = Depends(get_crm_service)
):
    """Get retention analytics and metrics."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    return service.get_retention_analytics(gym_id, period)


@router.get("/api/owner/crm/interactions")
async def get_interactions(
    client_id: str = None,
    limit: int = 50,
    user = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: CRMService = Depends(get_crm_service)
):
    """Get recent client interactions/activities."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    return service.get_client_interactions(gym_id, client_id, limit)


@router.get("/api/owner/crm/pipeline-clients")
async def get_pipeline_clients(
    status: str = "active",
    limit: int = 50,
    user = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: CRMService = Depends(get_crm_service)
):
    """Get detailed client list for a specific pipeline status."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    if status not in ("new", "active", "at_risk", "churning"):
        raise HTTPException(status_code=400, detail="Invalid status. Must be: new, active, at_risk, churning")
    return service.get_pipeline_clients(gym_id, status, limit)


@router.get("/api/owner/crm/ex-clients")
async def get_ex_clients(
    limit: int = 50,
    user = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: CRMService = Depends(get_crm_service)
):
    """Get list of former clients with canceled/expired subscriptions."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    return service.get_ex_clients(gym_id, limit)


@router.post("/api/owner/crm/whatsapp-link")
async def generate_whatsapp_link(
    payload: dict,
    user = Depends(get_current_user)
):
    """Generate a wa.me click-to-chat link with pre-filled message."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")

    import re
    from urllib.parse import quote

    phone = payload.get("phone", "").strip()
    message = payload.get("message", "").strip()

    if not phone:
        raise HTTPException(status_code=400, detail="Phone number is required")

    # Clean phone number
    phone_clean = re.sub(r'[\s\-\(\)]', '', phone)
    if not phone_clean.startswith('+'):
        if phone_clean.startswith('0'):
            phone_clean = '+39' + phone_clean[1:]
        else:
            phone_clean = '+39' + phone_clean

    phone_for_link = phone_clean.lstrip('+')
    link = f"https://wa.me/{phone_for_link}"
    if message:
        link += f"?text={quote(message)}"

    return {"whatsapp_link": link, "phone": phone_clean}


@router.get("/api/owner/activity-feed")
async def get_activity_feed(
    limit: int = 20,
    user = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: CRMService = Depends(get_crm_service)
):
    """Get activity feed for dashboard."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access activity feed")
    return service.get_activity_feed(gym_id, limit)
