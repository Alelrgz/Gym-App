"""
Notes Service - handles trainer notes CRUD operations.
"""
from .base import (
    HTTPException, uuid, logging, datetime,
    get_db_session, TrainerNoteORM
)

logger = logging.getLogger("gym_app")


class NotesService:
    """Service for managing trainer notes."""

    def save_trainer_note(self, trainer_id: str, title: str, content: str) -> dict:
        """Create a new trainer note."""
        db = get_db_session()
        try:
            new_id = str(uuid.uuid4())
            now = datetime.utcnow().isoformat()
            note = TrainerNoteORM(
                id=new_id,
                trainer_id=trainer_id,
                title=title,
                content=content,
                created_at=now,
                updated_at=now
            )
            db.add(note)
            db.commit()
            db.refresh(note)
            return {
                "id": note.id,
                "title": note.title,
                "content": note.content,
                "created_at": note.created_at,
                "updated_at": note.updated_at
            }
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to save note: {str(e)}")
        finally:
            db.close()

    def get_trainer_notes(self, trainer_id: str) -> list:
        """Get all notes for a trainer."""
        db = get_db_session()
        try:
            notes = db.query(TrainerNoteORM).filter(
                TrainerNoteORM.trainer_id == trainer_id
            ).order_by(TrainerNoteORM.updated_at.desc()).all()

            return [{
                "id": n.id,
                "title": n.title,
                "content": n.content,
                "created_at": n.created_at,
                "updated_at": n.updated_at
            } for n in notes]
        finally:
            db.close()

    def update_trainer_note(self, note_id: str, trainer_id: str, title: str, content: str) -> dict:
        """Update an existing note."""
        db = get_db_session()
        try:
            note = db.query(TrainerNoteORM).filter(
                TrainerNoteORM.id == note_id,
                TrainerNoteORM.trainer_id == trainer_id
            ).first()

            if not note:
                raise HTTPException(status_code=404, detail="Note not found")

            note.title = title
            note.content = content
            note.updated_at = datetime.utcnow().isoformat()

            db.commit()
            db.refresh(note)
            return {
                "id": note.id,
                "title": note.title,
                "content": note.content,
                "created_at": note.created_at,
                "updated_at": note.updated_at
            }
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to update note: {str(e)}")
        finally:
            db.close()

    def delete_trainer_note(self, note_id: str, trainer_id: str) -> dict:
        """Delete a note."""
        db = get_db_session()
        try:
            note = db.query(TrainerNoteORM).filter(
                TrainerNoteORM.id == note_id,
                TrainerNoteORM.trainer_id == trainer_id
            ).first()

            if not note:
                raise HTTPException(status_code=404, detail="Note not found")

            db.delete(note)
            db.commit()
            return {"status": "success", "message": "Note deleted"}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to delete note: {str(e)}")
        finally:
            db.close()


# Singleton instance
notes_service = NotesService()

def get_notes_service() -> NotesService:
    """Dependency injection helper."""
    return notes_service
