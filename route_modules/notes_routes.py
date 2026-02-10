"""
Notes Routes - API endpoints for trainer notes management.
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from models_orm import UserORM
from service_modules.notes_service import NotesService, get_notes_service

router = APIRouter()


def require_trainer(user: UserORM):
    if user.role not in ("trainer", "owner"):
        raise HTTPException(status_code=403, detail="Only trainers can access this endpoint")


@router.get("/api/trainer/notes")
async def get_trainer_notes(
    service: NotesService = Depends(get_notes_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all notes for the current trainer."""
    require_trainer(current_user)
    return service.get_trainer_notes(current_user.id)


@router.post("/api/trainer/notes")
async def save_trainer_note(
    note_data: dict,
    service: NotesService = Depends(get_notes_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Create a new note."""
    require_trainer(current_user)
    title = note_data.get("title", "Untitled Note")
    content = note_data.get("content", "")
    return service.save_trainer_note(current_user.id, title, content)


@router.put("/api/trainer/notes/{note_id}")
async def update_trainer_note(
    note_id: str,
    note_data: dict,
    service: NotesService = Depends(get_notes_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update an existing note."""
    require_trainer(current_user)
    title = note_data.get("title", "Untitled Note")
    content = note_data.get("content", "")
    return service.update_trainer_note(note_id, current_user.id, title, content)


@router.delete("/api/trainer/notes/{note_id}")
async def delete_trainer_note(
    note_id: str,
    service: NotesService = Depends(get_notes_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Delete a note."""
    require_trainer(current_user)
    return service.delete_trainer_note(note_id, current_user.id)
