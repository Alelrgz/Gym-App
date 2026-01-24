"""
Message Service - handles messaging between trainers and their PRO clients.
"""
from .base import (
    HTTPException, uuid, json, logging,
    get_db_session, UserORM, ClientProfileORM
)
from models_orm import ConversationORM, MessageORM
from datetime import datetime
from typing import List, Optional

logger = logging.getLogger("gym_app")


class MessageService:
    """Service for managing messages between trainers and clients."""

    def get_or_create_conversation(self, trainer_id: str, client_id: str) -> ConversationORM:
        """Get existing conversation or create a new one."""
        db = get_db_session()
        try:
            conversation = db.query(ConversationORM).filter(
                ConversationORM.trainer_id == trainer_id,
                ConversationORM.client_id == client_id
            ).first()

            if not conversation:
                conversation = ConversationORM(
                    id=str(uuid.uuid4()),
                    trainer_id=trainer_id,
                    client_id=client_id,
                    created_at=datetime.utcnow().isoformat()
                )
                db.add(conversation)
                db.commit()
                db.refresh(conversation)
                logger.info(f"Created new conversation between trainer {trainer_id} and client {client_id}")

            return conversation
        finally:
            db.close()

    def can_message(self, user_id: str, other_user_id: str) -> bool:
        """Check if two users can message each other (trainer <-> PRO client only)."""
        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.id == user_id).first()
            other = db.query(UserORM).filter(UserORM.id == other_user_id).first()

            if not user or not other:
                return False

            # One must be trainer, one must be client
            if user.role == "trainer" and other.role == "client":
                trainer_id, client_id = user_id, other_user_id
            elif user.role == "client" and other.role == "trainer":
                trainer_id, client_id = other_user_id, user_id
            else:
                return False

            # Check if client has selected this trainer (PRO status)
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if not profile or profile.trainer_id != trainer_id:
                return False

            return True
        finally:
            db.close()

    def send_message(self, sender_id: str, receiver_id: str, content: str) -> dict:
        """Send a message from sender to receiver."""
        db = get_db_session()
        try:
            # Verify messaging is allowed
            if not self.can_message(sender_id, receiver_id):
                raise HTTPException(
                    status_code=403,
                    detail="You can only message your assigned trainer/client"
                )

            # Get sender info
            sender = db.query(UserORM).filter(UserORM.id == sender_id).first()
            if not sender:
                raise HTTPException(status_code=404, detail="Sender not found")

            # Determine trainer and client
            if sender.role == "trainer":
                trainer_id, client_id = sender_id, receiver_id
            else:
                trainer_id, client_id = receiver_id, sender_id

            # Get or create conversation
            conversation = db.query(ConversationORM).filter(
                ConversationORM.trainer_id == trainer_id,
                ConversationORM.client_id == client_id
            ).first()

            if not conversation:
                conversation = ConversationORM(
                    id=str(uuid.uuid4()),
                    trainer_id=trainer_id,
                    client_id=client_id,
                    created_at=datetime.utcnow().isoformat()
                )
                db.add(conversation)
                db.flush()

            # Create message
            now = datetime.utcnow().isoformat()
            message = MessageORM(
                id=str(uuid.uuid4()),
                conversation_id=conversation.id,
                sender_id=sender_id,
                sender_role=sender.role,
                content=content,
                is_read=False,
                created_at=now
            )
            db.add(message)

            # Update conversation metadata
            conversation.last_message_at = now
            conversation.last_message_preview = content[:50] + "..." if len(content) > 50 else content

            # Update unread count for receiver
            if sender.role == "trainer":
                conversation.client_unread_count = (conversation.client_unread_count or 0) + 1
            else:
                conversation.trainer_unread_count = (conversation.trainer_unread_count or 0) + 1

            db.commit()

            logger.info(f"Message sent from {sender_id} to {receiver_id}")

            return {
                "id": message.id,
                "conversation_id": conversation.id,
                "sender_id": sender_id,
                "sender_role": sender.role,
                "content": content,
                "is_read": False,
                "created_at": now
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error sending message: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to send message: {str(e)}")
        finally:
            db.close()

    def get_conversations(self, user_id: str) -> List[dict]:
        """Get all conversations for a user."""
        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.id == user_id).first()
            if not user:
                return []

            if user.role == "trainer":
                conversations = db.query(ConversationORM).filter(
                    ConversationORM.trainer_id == user_id
                ).order_by(ConversationORM.last_message_at.desc()).all()
            else:
                conversations = db.query(ConversationORM).filter(
                    ConversationORM.client_id == user_id
                ).order_by(ConversationORM.last_message_at.desc()).all()

            result = []
            for conv in conversations:
                # Get the other participant
                other_id = conv.client_id if user.role == "trainer" else conv.trainer_id
                other_user = db.query(UserORM).filter(UserORM.id == other_id).first()

                # Get unread count for this user
                unread = conv.trainer_unread_count if user.role == "trainer" else conv.client_unread_count

                result.append({
                    "id": conv.id,
                    "other_user_id": other_id,
                    "other_user_name": other_user.username if other_user else "Unknown",
                    "other_user_role": other_user.role if other_user else "unknown",
                    "last_message_preview": conv.last_message_preview,
                    "last_message_at": conv.last_message_at,
                    "unread_count": unread or 0,
                    "created_at": conv.created_at
                })

            return result
        finally:
            db.close()

    def get_messages(self, user_id: str, conversation_id: str, limit: int = 50, before: str = None) -> List[dict]:
        """Get messages in a conversation."""
        db = get_db_session()
        try:
            # Verify user is part of conversation
            conversation = db.query(ConversationORM).filter(ConversationORM.id == conversation_id).first()
            if not conversation:
                raise HTTPException(status_code=404, detail="Conversation not found")

            if user_id not in [conversation.trainer_id, conversation.client_id]:
                raise HTTPException(status_code=403, detail="Not authorized to view this conversation")

            # Get messages
            query = db.query(MessageORM).filter(MessageORM.conversation_id == conversation_id)

            if before:
                query = query.filter(MessageORM.created_at < before)

            messages = query.order_by(MessageORM.created_at.desc()).limit(limit).all()

            # Reverse to get chronological order
            messages = list(reversed(messages))

            return [
                {
                    "id": m.id,
                    "sender_id": m.sender_id,
                    "sender_role": m.sender_role,
                    "content": m.content,
                    "is_read": m.is_read,
                    "read_at": m.read_at,
                    "created_at": m.created_at
                }
                for m in messages
            ]
        finally:
            db.close()

    def mark_messages_read(self, user_id: str, conversation_id: str) -> dict:
        """Mark all messages in a conversation as read for the user."""
        db = get_db_session()
        try:
            conversation = db.query(ConversationORM).filter(ConversationORM.id == conversation_id).first()
            if not conversation:
                raise HTTPException(status_code=404, detail="Conversation not found")

            if user_id not in [conversation.trainer_id, conversation.client_id]:
                raise HTTPException(status_code=403, detail="Not authorized")

            # Determine user's role
            user = db.query(UserORM).filter(UserORM.id == user_id).first()
            if not user:
                raise HTTPException(status_code=404, detail="User not found")

            # Mark messages from OTHER user as read
            other_role = "client" if user.role == "trainer" else "trainer"
            now = datetime.utcnow().isoformat()

            db.query(MessageORM).filter(
                MessageORM.conversation_id == conversation_id,
                MessageORM.sender_role == other_role,
                MessageORM.is_read == False
            ).update({
                "is_read": True,
                "read_at": now
            })

            # Reset unread count for this user
            if user.role == "trainer":
                conversation.trainer_unread_count = 0
            else:
                conversation.client_unread_count = 0

            db.commit()

            logger.info(f"Marked messages as read for {user_id} in conversation {conversation_id}")

            return {"status": "success", "marked_at": now}

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error marking messages read: {e}")
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    def get_unread_count(self, user_id: str) -> int:
        """Get total unread message count for a user."""
        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.id == user_id).first()
            if not user:
                return 0

            if user.role == "trainer":
                result = db.query(ConversationORM).filter(
                    ConversationORM.trainer_id == user_id
                ).all()
                return sum(c.trainer_unread_count or 0 for c in result)
            else:
                result = db.query(ConversationORM).filter(
                    ConversationORM.client_id == user_id
                ).all()
                return sum(c.client_unread_count or 0 for c in result)
        finally:
            db.close()


# Singleton instance
message_service = MessageService()


def get_message_service() -> MessageService:
    """Dependency injection helper."""
    return message_service
