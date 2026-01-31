"""
Friend Routes - API endpoints for friend system.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional
from auth import get_current_user
from models_orm import UserORM
from service_modules.friend_service import FriendService, get_friend_service

router = APIRouter()


class FriendRequestCreate(BaseModel):
    to_user_id: str
    message: Optional[str] = None


class FriendRequestResponse(BaseModel):
    request_id: int
    accept: bool


# === FRIENDS LIST ===

@router.get("/api/friends")
async def get_friends_list(
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get current user's friends list."""
    return service.get_friends_list(current_user.id)


@router.delete("/api/friends/{friend_id}")
async def remove_friend(
    friend_id: str,
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Remove a friend."""
    return service.remove_friend(current_user.id, friend_id)


# === FRIEND REQUESTS ===

@router.post("/api/friends/request")
async def send_friend_request(
    request: FriendRequestCreate,
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Send a friend request to another gym member."""
    return service.send_friend_request(
        current_user.id, request.to_user_id, request.message
    )


@router.post("/api/friends/request/respond")
async def respond_to_friend_request(
    response: FriendRequestResponse,
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Accept or decline a friend request."""
    return service.respond_to_request(
        current_user.id, response.request_id, response.accept
    )


@router.delete("/api/friends/request/{request_id}")
async def cancel_friend_request(
    request_id: int,
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Cancel a sent friend request."""
    return service.cancel_request(current_user.id, request_id)


# === REQUESTS MANAGEMENT ===

@router.get("/api/friends/requests/incoming")
async def get_incoming_requests(
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get pending incoming friend requests."""
    return service.get_incoming_requests(current_user.id)


@router.get("/api/friends/requests/outgoing")
async def get_outgoing_requests(
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get pending outgoing friend requests."""
    return service.get_outgoing_requests(current_user.id)


# === FRIEND PROGRESS (GRAPHS) ===

@router.get("/api/friends/{friend_id}/progress")
async def get_friend_progress(
    friend_id: str,
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get detailed progress data for a friend (visible only to friends)."""
    return service.get_friend_progress(current_user.id, friend_id)


@router.get("/api/friends/{friend_id}/workout")
async def get_friend_workout(
    friend_id: str,
    date: str,  # YYYY-MM-DD format
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get a friend's completed workout for a specific date (CO-OP viewing)."""
    return service.get_friend_workout(current_user.id, friend_id, date)


# === FRIENDSHIP STATUS ===

@router.get("/api/friends/status/{user_id}")
async def get_friendship_status(
    user_id: str,
    service: FriendService = Depends(get_friend_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get friendship status with another user."""
    return service.get_friendship_status(current_user.id, user_id)
