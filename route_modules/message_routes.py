"""
Message Routes - API endpoints for messaging between trainers and clients.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from auth import get_current_user
from models_orm import UserORM
from service_modules.message_service import MessageService, get_message_service
from sockets import manager

router = APIRouter(tags=["Messages"])


class SendMessageRequest(BaseModel):
    receiver_id: str
    content: str


class MessageResponse(BaseModel):
    id: str
    sender_id: str
    sender_role: str
    content: str
    is_read: bool
    read_at: Optional[str] = None
    created_at: str


class ConversationResponse(BaseModel):
    id: str
    other_user_id: str
    other_user_name: str
    other_user_role: str
    other_user_profile_picture: Optional[str] = None
    last_message_preview: Optional[str] = None
    last_message_at: Optional[str] = None
    unread_count: int
    created_at: str


@router.get("/api/messages/conversations", response_model=List[ConversationResponse])
async def get_conversations(
    user: UserORM = Depends(get_current_user),
    service: MessageService = Depends(get_message_service)
):
    """Get all conversations for the current user."""
    return service.get_conversations(user.id)


@router.get("/api/messages/conversation/{conversation_id}")
async def get_messages(
    conversation_id: str,
    limit: int = 50,
    before: Optional[str] = None,
    user: UserORM = Depends(get_current_user),
    service: MessageService = Depends(get_message_service)
):
    """Get messages in a conversation."""
    messages = service.get_messages(user.id, conversation_id, limit, before)
    return {"messages": messages}


@router.post("/api/messages/send")
async def send_message(
    request: SendMessageRequest,
    user: UserORM = Depends(get_current_user),
    service: MessageService = Depends(get_message_service)
):
    """Send a message to another user."""
    if not request.content or not request.content.strip():
        raise HTTPException(status_code=400, detail="Message content cannot be empty")
    result = service.send_message(user.id, request.receiver_id, request.content)

    # Send real-time notification to receiver via WebSocket
    await manager.send_to_user(request.receiver_id, {
        "type": "new_message",
        "message": result,
        "sender_name": user.username
    })

    return {
        "conversation_id": result.get("conversation_id"),
        "message": result
    }


@router.post("/api/messages/conversation/{conversation_id}/read")
async def mark_messages_read(
    conversation_id: str,
    user: UserORM = Depends(get_current_user),
    service: MessageService = Depends(get_message_service)
):
    """Mark all messages in a conversation as read."""
    return service.mark_messages_read(user.id, conversation_id)


@router.get("/api/messages/unread-count")
async def get_unread_count(
    user: UserORM = Depends(get_current_user),
    service: MessageService = Depends(get_message_service)
):
    """Get total unread message count."""
    return {"unread_count": service.get_unread_count(user.id)}
