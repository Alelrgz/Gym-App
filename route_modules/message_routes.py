"""
Message Routes - API endpoints for messaging between trainers and clients.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional, List
import uuid, os
from auth import get_current_user
from models_orm import UserORM, ClientProfileORM
from database import get_db_session
from service_modules.message_service import MessageService, get_message_service
from service_modules.upload_helper import save_file, ALLOWED_VIDEO_EXTENSIONS, ALLOWED_AUDIO_EXTENSIONS, MAX_VIDEO_SIZE, MAX_AUDIO_SIZE, MAX_IMAGE_SIZE
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


@router.get("/api/owner/gym-users")
async def get_owner_gym_users(user: UserORM = Depends(get_current_user)):
    """Get all users in the owner's gym for the message new-chat picker."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")
    db = get_db_session()
    try:
        staff_users = db.query(UserORM).filter(
            UserORM.gym_owner_id == user.id,
            UserORM.role.in_(["trainer", "staff", "nutritionist"])
        ).all()
        client_ids = [r[0] for r in db.query(ClientProfileORM.id).filter(ClientProfileORM.gym_id == user.id).all()]
        clients = db.query(UserORM).filter(UserORM.id.in_(client_ids)).all() if client_ids else []
        result = []
        for u in staff_users + clients:
            result.append({
                "id": u.id,
                "name": u.username,
                "role": u.role,
                "profile_picture": u.profile_picture
            })
        return result
    finally:
        db.close()


@router.post("/api/messages/upload-media")
async def upload_media_message(
    receiver_id: str = Form(...),
    file: UploadFile = File(...),
    duration: Optional[float] = Form(None),
    user: UserORM = Depends(get_current_user),
    service: MessageService = Depends(get_message_service)
):
    """Upload a media file (image/video/voice) and send it as a message."""
    mime = (file.content_type or "").lower()
    ext = (file.filename or "").rsplit(".", 1)[-1].lower() if "." in (file.filename or "") else ""

    # Determine media type
    if mime.startswith("image/"):
        media_type = "image"
        folder = "chat_images"
        max_size = MAX_IMAGE_SIZE
    elif mime.startswith("video/"):
        media_type = "video"
        folder = "chat_videos"
        max_size = MAX_VIDEO_SIZE
    elif mime.startswith("audio/") or ext in ALLOWED_AUDIO_EXTENSIONS:
        media_type = "voice"
        folder = "chat_audio"
        max_size = MAX_AUDIO_SIZE
    else:
        raise HTTPException(status_code=400, detail="Unsupported media type")

    content = await file.read()
    if len(content) > max_size:
        raise HTTPException(status_code=413, detail=f"File too large (max {max_size // 1024 // 1024}MB)")

    filename = f"{uuid.uuid4()}.{ext or 'bin'}"
    file_url = await save_file(content, folder, filename, upload_type=media_type)

    result = service.send_message(
        sender_id=user.id,
        receiver_id=receiver_id,
        content="",
        media_type=media_type,
        file_url=file_url,
        file_size=len(content),
        mime_type=mime,
        duration=duration,
    )

    await manager.send_to_user(receiver_id, {
        "type": "new_message",
        "message": result,
        "sender_name": user.username
    })

    return {"conversation_id": result.get("conversation_id"), "message": result}
