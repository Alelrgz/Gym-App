"""
Message Service - handles messaging between trainers and clients, and between clients.
"""
from .base import (
    HTTPException, uuid, json, logging,
    get_db_session, UserORM, ClientProfileORM
)
from models_orm import ConversationORM, MessageORM, ChatRequestORM
from datetime import datetime
from typing import List, Optional

logger = logging.getLogger("gym_app")


class MessageService:
    """Service for managing messages between trainers and clients."""

    def get_or_create_conversation(self, user1_id: str, user2_id: str, conversation_type: str = "trainer_client") -> ConversationORM:
        """Get existing conversation or create a new one."""
        db = get_db_session()
        try:
            if conversation_type == "trainer_client":
                # Legacy trainer-client conversation
                conversation = db.query(ConversationORM).filter(
                    ConversationORM.trainer_id == user1_id,
                    ConversationORM.client_id == user2_id
                ).first()

                if not conversation:
                    conversation = ConversationORM(
                        id=str(uuid.uuid4()),
                        trainer_id=user1_id,
                        client_id=user2_id,
                        conversation_type="trainer_client",
                        created_at=datetime.utcnow().isoformat()
                    )
                    db.add(conversation)
                    db.commit()
                    db.refresh(conversation)
                    logger.info(f"Created new conversation between trainer {user1_id} and client {user2_id}")
            else:
                # Client-to-client conversation - normalize order for consistent lookups
                sorted_ids = sorted([user1_id, user2_id])
                conversation = db.query(ConversationORM).filter(
                    ConversationORM.user1_id == sorted_ids[0],
                    ConversationORM.user2_id == sorted_ids[1],
                    ConversationORM.conversation_type == "client_client"
                ).first()

                if not conversation:
                    conversation = ConversationORM(
                        id=str(uuid.uuid4()),
                        user1_id=sorted_ids[0],
                        user2_id=sorted_ids[1],
                        conversation_type="client_client",
                        created_at=datetime.utcnow().isoformat()
                    )
                    db.add(conversation)
                    db.commit()
                    db.refresh(conversation)
                    logger.info(f"Created new client-to-client conversation between {sorted_ids[0]} and {sorted_ids[1]}")

            return conversation
        finally:
            db.close()

    def can_message(self, user_id: str, other_user_id: str) -> bool:
        """Check if two users can message each other."""
        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.id == user_id).first()
            other = db.query(UserORM).filter(UserORM.id == other_user_id).first()

            if not user or not other:
                logger.warning(f"can_message: User not found - user_id={user_id}, other_user_id={other_user_id}")
                return False

            # Case 1: Trainer <-> Client messaging
            if user.role == "trainer" and other.role == "client":
                trainer_id, client_id = user_id, other_user_id
                profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
                if profile and profile.trainer_id == trainer_id:
                    return True
            elif user.role == "client" and other.role == "trainer":
                trainer_id, client_id = other_user_id, user_id
                profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
                if profile and profile.trainer_id == trainer_id:
                    return True

            # Case 2: Client <-> Client messaging (with privacy check)
            if user.role == "client" and other.role == "client":
                # Check if both are in the same gym
                user_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user_id).first()
                other_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == other_user_id).first()

                if not user_profile or not other_profile:
                    logger.warning(f"can_message: Profile not found - user={user_id}, other={other_user_id}")
                    return False

                if user_profile.gym_id != other_profile.gym_id:
                    logger.warning(f"can_message: Different gyms - user gym={user_profile.gym_id}, other gym={other_profile.gym_id}")
                    return False  # Not in the same gym

                # Check if there's an existing conversation (if so, allow reply)
                # Check both client_client format AND any trainer_client format
                sorted_ids = sorted([user_id, other_user_id])
                existing_conversation = db.query(ConversationORM).filter(
                    (
                        # Client-client format
                        (ConversationORM.user1_id == sorted_ids[0]) &
                        (ConversationORM.user2_id == sorted_ids[1])
                    ) | (
                        # Trainer-client format (either direction)
                        (ConversationORM.trainer_id == user_id) & (ConversationORM.client_id == other_user_id)
                    ) | (
                        (ConversationORM.trainer_id == other_user_id) & (ConversationORM.client_id == user_id)
                    )
                ).first()

                if existing_conversation:
                    # Already have a conversation - both can reply
                    logger.info(f"can_message: Existing conversation found, allowing reply")
                    return True

                # Check privacy modes:
                # - "public": anyone can message
                # - "private": need accepted chat request
                # - "staff_only": only trainers/owners can message (clients blocked)

                if other_profile.privacy_mode == "staff_only":
                    # Staff only mode - clients cannot message at all
                    logger.warning(f"can_message: User {other_user_id} is staff_only, blocking client {user_id}")
                    return False

                if not other_profile.privacy_mode or other_profile.privacy_mode == "public":
                    return True

                # Other is private - check for accepted chat request (either direction)
                accepted = db.query(ChatRequestORM).filter(
                    ((ChatRequestORM.from_user_id == user_id) & (ChatRequestORM.to_user_id == other_user_id)) |
                    ((ChatRequestORM.from_user_id == other_user_id) & (ChatRequestORM.to_user_id == user_id)),
                    ChatRequestORM.status == "accepted"
                ).first()

                if accepted:
                    return True

                logger.warning(f"can_message: No permission - user={user_id} cannot message private user={other_user_id}")

            return False
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
                    detail="You cannot message this user"
                )

            # Get sender and receiver info
            sender = db.query(UserORM).filter(UserORM.id == sender_id).first()
            receiver = db.query(UserORM).filter(UserORM.id == receiver_id).first()
            if not sender:
                raise HTTPException(status_code=404, detail="Sender not found")
            if not receiver:
                raise HTTPException(status_code=404, detail="Receiver not found")

            # Determine conversation type
            is_client_client = sender.role == "client" and receiver.role == "client"

            if is_client_client:
                # Client-to-client conversation
                sorted_ids = sorted([sender_id, receiver_id])
                conversation = db.query(ConversationORM).filter(
                    ConversationORM.user1_id == sorted_ids[0],
                    ConversationORM.user2_id == sorted_ids[1],
                    ConversationORM.conversation_type == "client_client"
                ).first()

                if not conversation:
                    conversation = ConversationORM(
                        id=str(uuid.uuid4()),
                        user1_id=sorted_ids[0],
                        user2_id=sorted_ids[1],
                        conversation_type="client_client",
                        created_at=datetime.utcnow().isoformat()
                    )
                    db.add(conversation)
                    db.flush()
            else:
                # Trainer-client conversation
                if sender.role == "trainer":
                    trainer_id, client_id = sender_id, receiver_id
                else:
                    trainer_id, client_id = receiver_id, sender_id

                conversation = db.query(ConversationORM).filter(
                    ConversationORM.trainer_id == trainer_id,
                    ConversationORM.client_id == client_id
                ).first()

                if not conversation:
                    conversation = ConversationORM(
                        id=str(uuid.uuid4()),
                        trainer_id=trainer_id,
                        client_id=client_id,
                        conversation_type="trainer_client",
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
            if is_client_client:
                # For client-client: increment the other user's unread count
                if sender_id == conversation.user1_id:
                    conversation.user2_unread_count = (conversation.user2_unread_count or 0) + 1
                else:
                    conversation.user1_unread_count = (conversation.user1_unread_count or 0) + 1
            else:
                # For trainer-client
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

            result = []

            if user.role == "trainer":
                # Trainer: get trainer-client conversations
                conversations = db.query(ConversationORM).filter(
                    ConversationORM.trainer_id == user_id
                ).order_by(ConversationORM.last_message_at.desc()).all()

                for conv in conversations:
                    other_id = conv.client_id
                    other_user = db.query(UserORM).filter(UserORM.id == other_id).first()
                    unread = conv.trainer_unread_count or 0

                    result.append({
                        "id": conv.id,
                        "other_user_id": other_id,
                        "other_user_name": other_user.username if other_user else "Unknown",
                        "other_user_role": other_user.role if other_user else "unknown",
                        "last_message_preview": conv.last_message_preview,
                        "last_message_at": conv.last_message_at,
                        "unread_count": unread,
                        "created_at": conv.created_at
                    })
            else:
                # Client: get trainer-client conversations
                trainer_convs = db.query(ConversationORM).filter(
                    ConversationORM.client_id == user_id,
                    ConversationORM.conversation_type == "trainer_client"
                ).all()

                for conv in trainer_convs:
                    other_id = conv.trainer_id
                    other_user = db.query(UserORM).filter(UserORM.id == other_id).first()
                    unread = conv.client_unread_count or 0

                    result.append({
                        "id": conv.id,
                        "other_user_id": other_id,
                        "other_user_name": other_user.username if other_user else "Unknown",
                        "other_user_role": other_user.role if other_user else "unknown",
                        "last_message_preview": conv.last_message_preview,
                        "last_message_at": conv.last_message_at,
                        "unread_count": unread,
                        "created_at": conv.created_at
                    })

                # Client: also get client-client conversations
                client_convs = db.query(ConversationORM).filter(
                    ((ConversationORM.user1_id == user_id) | (ConversationORM.user2_id == user_id)),
                    ConversationORM.conversation_type == "client_client"
                ).all()

                for conv in client_convs:
                    # Determine other user
                    other_id = conv.user2_id if conv.user1_id == user_id else conv.user1_id
                    other_user = db.query(UserORM).filter(UserORM.id == other_id).first()

                    # Determine unread count
                    if conv.user1_id == user_id:
                        unread = conv.user1_unread_count or 0
                    else:
                        unread = conv.user2_unread_count or 0

                    result.append({
                        "id": conv.id,
                        "other_user_id": other_id,
                        "other_user_name": other_user.username if other_user else "Unknown",
                        "other_user_role": other_user.role if other_user else "unknown",
                        "last_message_preview": conv.last_message_preview,
                        "last_message_at": conv.last_message_at,
                        "unread_count": unread,
                        "created_at": conv.created_at
                    })

            # Sort all conversations by last_message_at
            result.sort(key=lambda x: x["last_message_at"] or "", reverse=True)

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

            # Check authorization for both conversation types
            allowed_users = [conversation.trainer_id, conversation.client_id, conversation.user1_id, conversation.user2_id]
            if user_id not in [u for u in allowed_users if u]:
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

            # Check authorization for both conversation types
            allowed_users = [conversation.trainer_id, conversation.client_id, conversation.user1_id, conversation.user2_id]
            if user_id not in [u for u in allowed_users if u]:
                raise HTTPException(status_code=403, detail="Not authorized")

            now = datetime.utcnow().isoformat()

            # Mark all messages NOT from this user as read
            db.query(MessageORM).filter(
                MessageORM.conversation_id == conversation_id,
                MessageORM.sender_id != user_id,
                MessageORM.is_read == False
            ).update({
                "is_read": True,
                "read_at": now
            })

            # Reset unread count for this user
            if conversation.conversation_type == "client_client":
                if user_id == conversation.user1_id:
                    conversation.user1_unread_count = 0
                else:
                    conversation.user2_unread_count = 0
            else:
                user = db.query(UserORM).filter(UserORM.id == user_id).first()
                if user and user.role == "trainer":
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

            total = 0

            if user.role == "trainer":
                # Trainer: only trainer-client conversations
                result = db.query(ConversationORM).filter(
                    ConversationORM.trainer_id == user_id
                ).all()
                total = sum(c.trainer_unread_count or 0 for c in result)
            else:
                # Client: trainer-client + client-client conversations
                trainer_convs = db.query(ConversationORM).filter(
                    ConversationORM.client_id == user_id
                ).all()
                total = sum(c.client_unread_count or 0 for c in trainer_convs)

                # Also count client-client conversations
                client_convs = db.query(ConversationORM).filter(
                    ((ConversationORM.user1_id == user_id) | (ConversationORM.user2_id == user_id)),
                    ConversationORM.conversation_type == "client_client"
                ).all()

                for conv in client_convs:
                    if conv.user1_id == user_id:
                        total += conv.user1_unread_count or 0
                    else:
                        total += conv.user2_unread_count or 0

            return total
        finally:
            db.close()


# Singleton instance
message_service = MessageService()


def get_message_service() -> MessageService:
    """Dependency injection helper."""
    return message_service
