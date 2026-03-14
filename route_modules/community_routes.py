"""
Community Routes - Social feed, posts, likes, comments.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from auth import get_current_user
from models import CommunityPostCreate, CommunityCommentCreate
from models_orm import UserORM
from service_modules.community_service import CommunityService, get_community_service
from service_modules.upload_helper import save_file, _optimize_image, ALLOWED_IMAGE_EXTENSIONS, MAX_IMAGE_SIZE
import uuid
import os

router = APIRouter()


def _allowed_image(filename: str) -> bool:
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    return ext in ALLOWED_IMAGE_EXTENSIONS


@router.get("/api/community/feed")
async def get_community_feed(
    cursor: str = Query(None),
    limit: int = Query(20, ge=1, le=50),
    current_user: UserORM = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service),
):
    """Get the community feed for the user's gym."""
    return service.get_feed(current_user.id, cursor=cursor, limit=limit)


@router.post("/api/community/posts")
async def create_community_post(
    post_type: str = Form("text"),
    content: str = Form(None),
    event_title: str = Form(None),
    event_date: str = Form(None),
    event_time: str = Form(None),
    event_location: str = Form(None),
    quest_xp_reward: int = Form(None),
    quest_deadline: str = Form(None),
    image: UploadFile = File(None),
    current_user: UserORM = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service),
):
    """Create a new community post (supports image upload)."""
    image_url = None

    if image and image.filename:
        if not _allowed_image(image.filename):
            raise HTTPException(status_code=400, detail="Invalid image type")
        raw = await image.read()
        if len(raw) > MAX_IMAGE_SIZE:
            raise HTTPException(status_code=400, detail="Image too large (max 5MB)")

        # Optimize image
        try:
            optimized, ext = _optimize_image(raw, max_size=(1200, 1200), crop_square=False)
        except Exception:
            optimized, ext = raw, os.path.splitext(image.filename)[1].lstrip(".")

        filename = f"{uuid.uuid4().hex}.{ext}"
        image_url = await save_file(optimized, "community", filename)

        if post_type == "text":
            post_type = "image"

    return service.create_post(
        author_id=current_user.id,
        post_type=post_type,
        content=content,
        image_url=image_url,
        event_title=event_title,
        event_date=event_date,
        event_time=event_time,
        event_location=event_location,
        quest_xp_reward=quest_xp_reward,
        quest_deadline=quest_deadline,
    )


@router.delete("/api/community/posts/{post_id}")
async def delete_community_post(
    post_id: str,
    current_user: UserORM = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service),
):
    """Delete a community post."""
    return service.delete_post(post_id, current_user.id)


@router.post("/api/community/posts/{post_id}/like")
async def toggle_post_like(
    post_id: str,
    current_user: UserORM = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service),
):
    """Toggle like on a post."""
    return service.toggle_like(post_id, current_user.id)


@router.get("/api/community/posts/{post_id}/comments")
async def get_post_comments(
    post_id: str,
    cursor: str = Query(None),
    limit: int = Query(20, ge=1, le=50),
    current_user: UserORM = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service),
):
    """Get comments for a post."""
    return service.get_comments(post_id, current_user.id, cursor=cursor, limit=limit)


@router.post("/api/community/posts/{post_id}/comments")
async def add_post_comment(
    post_id: str,
    data: CommunityCommentCreate,
    current_user: UserORM = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service),
):
    """Add a comment to a post."""
    return service.add_comment(post_id, current_user.id, data.content, data.parent_comment_id)


@router.delete("/api/community/comments/{comment_id}")
async def delete_comment(
    comment_id: int,
    current_user: UserORM = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service),
):
    """Delete a comment."""
    return service.delete_comment(comment_id, current_user.id)


@router.post("/api/community/comments/{comment_id}/like")
async def toggle_comment_like(
    comment_id: int,
    current_user: UserORM = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service),
):
    """Toggle like on a comment."""
    return service.toggle_comment_like(comment_id, current_user.id)


@router.post("/api/community/posts/{post_id}/pin")
async def pin_post(
    post_id: str,
    current_user: UserORM = Depends(get_current_user),
    service: CommunityService = Depends(get_community_service),
):
    """Pin/unpin a post (owner only)."""
    return service.pin_post(post_id, current_user.id)
