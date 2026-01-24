"""
Notification Routes - API endpoints for user notifications.
"""
from fastapi import APIRouter, Depends
from auth import get_current_user
from service_modules.notification_service import NotificationService, get_notification_service
from models_orm import UserORM

router = APIRouter()


@router.get("/api/notifications")
async def get_notifications(
    unread_only: bool = False,
    limit: int = 50,
    user = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service)
):
    """Get notifications for the current user."""
    return service.get_user_notifications(user.id, unread_only, limit)


@router.get("/api/notifications/unread-count")
async def get_unread_count(
    user = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service)
):
    """Get count of unread notifications."""
    count = service.get_unread_count(user.id)
    return {"unread_count": count}


@router.post("/api/notifications/{notification_id}/read")
async def mark_as_read(
    notification_id: int,
    user = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service)
):
    """Mark a notification as read."""
    return service.mark_as_read(notification_id, user.id)


@router.post("/api/notifications/read-all")
async def mark_all_as_read(
    user = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service)
):
    """Mark all notifications as read."""
    return service.mark_all_as_read(user.id)


@router.delete("/api/notifications/{notification_id}")
async def delete_notification(
    notification_id: int,
    user = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service)
):
    """Delete a notification."""
    return service.delete_notification(notification_id, user.id)
