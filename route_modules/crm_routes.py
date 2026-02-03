"""
CRM Routes - API endpoints for CRM analytics and client management.
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from service_modules.crm_service import get_crm_service, CRMService
import logging

logger = logging.getLogger("gym_app")
router = APIRouter()


@router.get("/api/owner/crm/pipeline")
async def get_pipeline(
    user = Depends(get_current_user),
    service: CRMService = Depends(get_crm_service)
):
    """Get client pipeline/funnel data."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    return service.get_client_pipeline(user.id)


@router.get("/api/owner/crm/at-risk")
async def get_at_risk_clients(
    limit: int = 20,
    user = Depends(get_current_user),
    service: CRMService = Depends(get_crm_service)
):
    """Get list of at-risk clients needing attention."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    return service.get_at_risk_clients(user.id, limit)


@router.get("/api/owner/crm/analytics")
async def get_analytics(
    period: str = "month",
    user = Depends(get_current_user),
    service: CRMService = Depends(get_crm_service)
):
    """Get retention analytics and metrics."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    return service.get_retention_analytics(user.id, period)


@router.get("/api/owner/crm/interactions")
async def get_interactions(
    client_id: str = None,
    limit: int = 50,
    user = Depends(get_current_user),
    service: CRMService = Depends(get_crm_service)
):
    """Get recent client interactions/activities."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access CRM")
    return service.get_client_interactions(user.id, client_id, limit)


@router.get("/api/owner/activity-feed")
async def get_activity_feed(
    limit: int = 20,
    user = Depends(get_current_user),
    service: CRMService = Depends(get_crm_service)
):
    """Get activity feed for dashboard."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access activity feed")
    return service.get_activity_feed(user.id, limit)
