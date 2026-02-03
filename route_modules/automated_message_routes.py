"""
Automated Message Routes - API endpoints for managing automated message templates
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from service_modules.automated_message_service import get_automated_message_service, AutomatedMessageService
from service_modules.trigger_check_service import get_trigger_check_service, TriggerCheckService
from pydantic import BaseModel
from typing import List, Optional
import logging

logger = logging.getLogger("gym_app")
router = APIRouter()


# --- Request Models ---

class CreateTemplateRequest(BaseModel):
    name: str
    trigger_type: str  # missed_workout, days_inactive, no_show_appointment
    trigger_config: Optional[dict] = None  # e.g., {"days_threshold": 5}
    subject: Optional[str] = None
    message_template: str
    delivery_methods: List[str] = ["in_app"]
    send_delay_hours: int = 0
    is_enabled: bool = True


class UpdateTemplateRequest(BaseModel):
    name: Optional[str] = None
    trigger_type: Optional[str] = None
    trigger_config: Optional[dict] = None
    subject: Optional[str] = None
    message_template: Optional[str] = None
    delivery_methods: Optional[List[str]] = None
    send_delay_hours: Optional[int] = None
    is_enabled: Optional[bool] = None


# --- Template CRUD Endpoints ---

@router.get("/api/owner/automated-messages")
async def get_templates(
    include_disabled: bool = True,
    user = Depends(get_current_user),
    service: AutomatedMessageService = Depends(get_automated_message_service)
):
    """Get all automated message templates for the owner's gym."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can manage automated messages")

    return service.get_templates(user.id, include_disabled)


@router.post("/api/owner/automated-messages")
async def create_template(
    template_data: CreateTemplateRequest,
    user = Depends(get_current_user),
    service: AutomatedMessageService = Depends(get_automated_message_service)
):
    """Create a new automated message template."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can create automated messages")

    # Validate trigger type
    valid_triggers = ["missed_workout", "days_inactive", "no_show_appointment"]
    if template_data.trigger_type not in valid_triggers:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid trigger type. Must be one of: {', '.join(valid_triggers)}"
        )

    # Validate delivery methods
    valid_methods = ["in_app", "email", "whatsapp"]
    for method in template_data.delivery_methods:
        if method not in valid_methods:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid delivery method: {method}. Must be one of: {', '.join(valid_methods)}"
            )

    return service.create_template(user.id, template_data.model_dump())


@router.get("/api/owner/automated-messages/{template_id}")
async def get_template(
    template_id: str,
    user = Depends(get_current_user),
    service: AutomatedMessageService = Depends(get_automated_message_service)
):
    """Get a specific automated message template."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view automated messages")

    return service.get_template(template_id, user.id)


@router.put("/api/owner/automated-messages/{template_id}")
async def update_template(
    template_id: str,
    updates: UpdateTemplateRequest,
    user = Depends(get_current_user),
    service: AutomatedMessageService = Depends(get_automated_message_service)
):
    """Update an automated message template."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can update automated messages")

    # Filter out None values
    update_data = {k: v for k, v in updates.model_dump().items() if v is not None}

    if not update_data:
        raise HTTPException(status_code=400, detail="No updates provided")

    return service.update_template(template_id, user.id, update_data)


@router.delete("/api/owner/automated-messages/{template_id}")
async def delete_template(
    template_id: str,
    user = Depends(get_current_user),
    service: AutomatedMessageService = Depends(get_automated_message_service)
):
    """Delete an automated message template."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can delete automated messages")

    return service.delete_template(template_id, user.id)


@router.post("/api/owner/automated-messages/{template_id}/toggle")
async def toggle_template(
    template_id: str,
    user = Depends(get_current_user),
    service: AutomatedMessageService = Depends(get_automated_message_service)
):
    """Enable or disable an automated message template."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can toggle automated messages")

    return service.toggle_template(template_id, user.id)


@router.post("/api/owner/automated-messages/{template_id}/preview")
async def preview_template(
    template_id: str,
    sample_client_id: Optional[str] = None,
    user = Depends(get_current_user),
    service: AutomatedMessageService = Depends(get_automated_message_service)
):
    """Preview an automated message with variable substitution."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can preview automated messages")

    return service.preview_message(template_id, user.id, sample_client_id)


# --- Message Log Endpoint ---

@router.get("/api/owner/automated-messages/log")
async def get_message_log(
    limit: int = 50,
    user = Depends(get_current_user),
    service: AutomatedMessageService = Depends(get_automated_message_service)
):
    """Get the log of sent automated messages."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view message logs")

    return service.get_message_log(user.id, limit)


# --- Manual Trigger Endpoint (for testing) ---

@router.post("/api/owner/automated-messages/trigger-check")
async def manual_trigger_check(
    user = Depends(get_current_user),
    trigger_service: TriggerCheckService = Depends(get_trigger_check_service)
):
    """
    Manually trigger a check for all automated message conditions.
    Useful for testing without waiting for the background job.
    """
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can trigger automated message checks")

    return trigger_service.check_all_triggers(user.id)
