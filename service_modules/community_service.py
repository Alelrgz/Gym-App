"""
Community Service - handles social feed, posts, likes, comments.
"""
from typing import Optional
from .base import (
    HTTPException, uuid, json, logging, datetime,
    get_db_session, UserORM, ClientProfileORM, ClientScheduleORM, NotificationORM,
    CommunityPostORM, CommunityEventParticipantORM, CommunityLikeORM, CommunityCommentORM, CommunityCommentLikeORM
)

logger = logging.getLogger("gym_app")


class CommunityService:
    """Service for the gym community social feed."""

    def _get_user_gym_id(self, user_id: str, db) -> Optional[str]:
        """Resolve the gym_id for any user role."""
        user = db.query(UserORM).filter(UserORM.id == user_id).first()
        if not user:
            return None
        if user.role == "owner":
            return user.id
        if user.role == "trainer":
            return user.gym_owner_id
        # client
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user_id).first()
        return profile.gym_id if profile else None

    def _post_to_dict(self, post: CommunityPostORM, author: UserORM, is_liked: bool, is_participating: bool = False) -> dict:
        """Convert a post ORM + author to a response dict."""
        return {
            "id": post.id,
            "author_id": post.author_id,
            "author_username": author.username if author else "Unknown",
            "author_profile_picture": author.profile_picture if author else None,
            "author_role": author.role if author else "client",
            "gym_id": post.gym_id,
            "post_type": post.post_type,
            "content": post.content,
            "image_url": post.image_url,
            "event_title": post.event_title,
            "event_date": post.event_date,
            "event_time": post.event_time,
            "event_location": post.event_location,
            "max_participants": post.max_participants,
            "participant_count": post.participant_count or 0,
            "quest_xp_reward": post.quest_xp_reward,
            "quest_deadline": post.quest_deadline,
            "is_pinned": post.is_pinned,
            "like_count": post.like_count,
            "comment_count": post.comment_count,
            "repost_count": post.repost_count,
            "is_liked_by_me": is_liked,
            "is_participating": is_participating,
            "created_at": post.created_at,
        }

    def get_feed(self, user_id: str, cursor: Optional[str] = None, limit: int = 20) -> dict:
        """Get the community feed for the user's gym."""
        db = get_db_session()
        try:
            gym_id = self._get_user_gym_id(user_id, db)
            if not gym_id:
                return {"posts": [], "next_cursor": None, "has_more": False}

            query = db.query(CommunityPostORM).filter(
                CommunityPostORM.gym_id == gym_id,
                CommunityPostORM.is_deleted == False,
            )

            if cursor:
                query = query.filter(CommunityPostORM.created_at < cursor)

            # Pinned first, then by date
            posts = query.order_by(
                CommunityPostORM.is_pinned.desc(),
                CommunityPostORM.created_at.desc()
            ).limit(limit + 1).all()

            has_more = len(posts) > limit
            posts = posts[:limit]

            # Batch fetch authors
            author_ids = list({p.author_id for p in posts})
            authors = {u.id: u for u in db.query(UserORM).filter(UserORM.id.in_(author_ids)).all()} if author_ids else {}

            # Batch fetch likes
            post_ids = [p.id for p in posts]
            liked_ids = set()
            if post_ids:
                likes = db.query(CommunityLikeORM.post_id).filter(
                    CommunityLikeORM.post_id.in_(post_ids),
                    CommunityLikeORM.user_id == user_id
                ).all()
                liked_ids = {l.post_id for l in likes}

            # Batch fetch event participation status
            participating_ids = set()
            if post_ids:
                participations = db.query(CommunityEventParticipantORM.post_id).filter(
                    CommunityEventParticipantORM.post_id.in_(post_ids),
                    CommunityEventParticipantORM.user_id == user_id
                ).all()
                participating_ids = {p.post_id for p in participations}

            # Batch fetch first comment for each post
            first_comments = {}
            if post_ids:
                from sqlalchemy import func
                # Subquery: max id (latest) per post
                sub = db.query(
                    CommunityCommentORM.post_id,
                    func.max(CommunityCommentORM.id).label("max_id")
                ).filter(
                    CommunityCommentORM.post_id.in_(post_ids),
                    CommunityCommentORM.is_deleted == False,
                ).group_by(CommunityCommentORM.post_id).subquery()

                latest = db.query(CommunityCommentORM).join(
                    sub, CommunityCommentORM.id == sub.c.max_id
                ).all()

                # Fetch comment authors
                comment_author_ids = list({c.author_id for c in latest})
                comment_authors = {u.id: u for u in db.query(UserORM).filter(UserORM.id.in_(comment_author_ids)).all()} if comment_author_ids else {}

                for c in latest:
                    a = comment_authors.get(c.author_id)
                    first_comments[c.post_id] = {
                        "author_username": a.username if a else "Unknown",
                        "author_profile_picture": a.profile_picture if a else None,
                        "content": c.content,
                    }

            result = []
            for p in posts:
                d = self._post_to_dict(p, authors.get(p.author_id), p.id in liked_ids, p.id in participating_ids)
                d["first_comment"] = first_comments.get(p.id)
                result.append(d)

            next_cursor = posts[-1].created_at if has_more and posts else None

            return {"posts": result, "next_cursor": next_cursor, "has_more": has_more}
        finally:
            db.close()

    def create_post(
        self, author_id: str, post_type: str, content: Optional[str] = None,
        image_url: Optional[str] = None, event_title: Optional[str] = None,
        event_date: Optional[str] = None, event_time: Optional[str] = None,
        event_location: Optional[str] = None, max_participants: Optional[int] = None,
        quest_xp_reward: Optional[int] = None, quest_deadline: Optional[str] = None
    ) -> dict:
        """Create a new community post."""
        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.id == author_id).first()
            if not user:
                raise HTTPException(status_code=404, detail="User not found")

            gym_id = self._get_user_gym_id(author_id, db)
            if not gym_id:
                raise HTTPException(status_code=400, detail="User not associated with a gym")

            # Only owner/trainer can create events/quests
            if post_type in ("event", "quest") and user.role not in ("owner", "trainer"):
                raise HTTPException(status_code=403, detail="Only trainers and owners can create events/quests")

            post = CommunityPostORM(
                id=str(uuid.uuid4()),
                author_id=author_id,
                gym_id=gym_id,
                post_type=post_type,
                content=content,
                image_url=image_url,
                event_title=event_title,
                event_date=event_date,
                event_time=event_time,
                event_location=event_location,
                max_participants=max_participants,
                quest_xp_reward=quest_xp_reward,
                quest_deadline=quest_deadline,
            )
            db.add(post)
            db.commit()
            db.refresh(post)

            return self._post_to_dict(post, user, False)
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error creating post: {e}")
            raise HTTPException(status_code=500, detail="Failed to create post")
        finally:
            db.close()

    def delete_post(self, post_id: str, user_id: str) -> dict:
        """Soft delete a post. Author or gym owner can delete."""
        db = get_db_session()
        try:
            post = db.query(CommunityPostORM).filter(CommunityPostORM.id == post_id).first()
            if not post:
                raise HTTPException(status_code=404, detail="Post not found")

            # Check permissions: author or gym owner
            user = db.query(UserORM).filter(UserORM.id == user_id).first()
            is_author = post.author_id == user_id
            is_owner = user and user.role == "owner" and post.gym_id == user.id

            if not is_author and not is_owner:
                raise HTTPException(status_code=403, detail="Not authorized to delete this post")

            post.is_deleted = True
            post.updated_at = datetime.utcnow().isoformat()
            db.commit()
            return {"status": "deleted"}
        finally:
            db.close()

    def toggle_like(self, post_id: str, user_id: str) -> dict:
        """Toggle like on a post. Returns new state."""
        db = get_db_session()
        try:
            post = db.query(CommunityPostORM).filter(
                CommunityPostORM.id == post_id,
                CommunityPostORM.is_deleted == False
            ).first()
            if not post:
                raise HTTPException(status_code=404, detail="Post not found")

            existing = db.query(CommunityLikeORM).filter(
                CommunityLikeORM.post_id == post_id,
                CommunityLikeORM.user_id == user_id
            ).first()

            if existing:
                db.delete(existing)
                post.like_count = max(0, post.like_count - 1)
                liked = False
            else:
                db.add(CommunityLikeORM(post_id=post_id, user_id=user_id))
                post.like_count = post.like_count + 1
                liked = True

                # Notify post author (if not self-like)
                if post.author_id != user_id:
                    liker = db.query(UserORM).filter(UserORM.id == user_id).first()
                    db.add(NotificationORM(
                        user_id=post.author_id,
                        type="community_like",
                        title="Nuovo like",
                        message=f"{liker.username if liker else 'Qualcuno'} ha messo like al tuo post",
                        data=json.dumps({"post_id": post_id}),
                    ))

            db.commit()
            return {"liked": liked, "like_count": post.like_count}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error toggling like: {e}")
            raise HTTPException(status_code=500, detail="Failed to toggle like")
        finally:
            db.close()

    def get_comments(self, post_id: str, user_id: str, cursor: Optional[str] = None, limit: int = 20) -> dict:
        """Get comments for a post."""
        db = get_db_session()
        try:
            query = db.query(CommunityCommentORM).filter(
                CommunityCommentORM.post_id == post_id,
                CommunityCommentORM.is_deleted == False,
            )

            if cursor:
                query = query.filter(CommunityCommentORM.created_at < cursor)

            comments = query.order_by(CommunityCommentORM.created_at.desc()).limit(limit + 1).all()

            has_more = len(comments) > limit
            comments = comments[:limit]

            author_ids = list({c.author_id for c in comments})
            authors = {u.id: u for u in db.query(UserORM).filter(UserORM.id.in_(author_ids)).all()} if author_ids else {}

            # Check which comments the user liked
            comment_ids = [c.id for c in comments]
            liked_ids = set()
            if comment_ids:
                likes = db.query(CommunityCommentLikeORM.comment_id).filter(
                    CommunityCommentLikeORM.comment_id.in_(comment_ids),
                    CommunityCommentLikeORM.user_id == user_id
                ).all()
                liked_ids = {l.comment_id for l in likes}

            result = []
            for c in comments:
                author = authors.get(c.author_id)
                result.append({
                    "id": c.id,
                    "post_id": c.post_id,
                    "author_id": c.author_id,
                    "author_username": author.username if author else "Unknown",
                    "author_profile_picture": author.profile_picture if author else None,
                    "author_role": author.role if author else "client",
                    "content": c.content,
                    "parent_comment_id": c.parent_comment_id,
                    "like_count": c.like_count,
                    "is_liked_by_me": c.id in liked_ids,
                    "created_at": c.created_at,
                })

            next_cursor = comments[-1].created_at if has_more and comments else None
            return {"comments": result, "next_cursor": next_cursor, "has_more": has_more}
        finally:
            db.close()

    def add_comment(self, post_id: str, user_id: str, content: str, parent_comment_id: Optional[int] = None) -> dict:
        """Add a comment to a post."""
        db = get_db_session()
        try:
            post = db.query(CommunityPostORM).filter(
                CommunityPostORM.id == post_id,
                CommunityPostORM.is_deleted == False
            ).first()
            if not post:
                raise HTTPException(status_code=404, detail="Post not found")

            comment = CommunityCommentORM(
                post_id=post_id,
                author_id=user_id,
                content=content,
                parent_comment_id=parent_comment_id,
            )
            db.add(comment)
            post.comment_count = post.comment_count + 1

            # Notify post author
            if post.author_id != user_id:
                commenter = db.query(UserORM).filter(UserORM.id == user_id).first()
                db.add(NotificationORM(
                    user_id=post.author_id,
                    type="community_comment",
                    title="Nuovo commento",
                    message=f"{commenter.username if commenter else 'Qualcuno'} ha commentato il tuo post",
                    data=json.dumps({"post_id": post_id}),
                ))

            db.commit()
            db.refresh(comment)

            author = db.query(UserORM).filter(UserORM.id == user_id).first()
            return {
                "id": comment.id,
                "post_id": comment.post_id,
                "author_id": comment.author_id,
                "author_username": author.username if author else "Unknown",
                "author_profile_picture": author.profile_picture if author else None,
                "author_role": author.role if author else "client",
                "content": comment.content,
                "parent_comment_id": comment.parent_comment_id,
                "like_count": 0,
                "is_liked_by_me": False,
                "created_at": comment.created_at,
                "comment_count": post.comment_count,
            }
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error adding comment: {e}")
            raise HTTPException(status_code=500, detail="Failed to add comment")
        finally:
            db.close()

    def delete_comment(self, comment_id: int, user_id: str) -> dict:
        """Soft delete a comment."""
        db = get_db_session()
        try:
            comment = db.query(CommunityCommentORM).filter(CommunityCommentORM.id == comment_id).first()
            if not comment:
                raise HTTPException(status_code=404, detail="Comment not found")

            post = db.query(CommunityPostORM).filter(CommunityPostORM.id == comment.post_id).first()
            user = db.query(UserORM).filter(UserORM.id == user_id).first()
            is_author = comment.author_id == user_id
            is_owner = user and user.role == "owner" and post and post.gym_id == user.id

            if not is_author and not is_owner:
                raise HTTPException(status_code=403, detail="Not authorized")

            comment.is_deleted = True
            if post:
                post.comment_count = max(0, post.comment_count - 1)
            db.commit()
            return {"status": "deleted"}
        finally:
            db.close()

    def toggle_comment_like(self, comment_id: int, user_id: str) -> dict:
        """Toggle like on a comment."""
        db = get_db_session()
        try:
            comment = db.query(CommunityCommentORM).filter(
                CommunityCommentORM.id == comment_id,
                CommunityCommentORM.is_deleted == False
            ).first()
            if not comment:
                raise HTTPException(status_code=404, detail="Comment not found")

            existing = db.query(CommunityCommentLikeORM).filter(
                CommunityCommentLikeORM.comment_id == comment_id,
                CommunityCommentLikeORM.user_id == user_id
            ).first()

            if existing:
                db.delete(existing)
                comment.like_count = max(0, comment.like_count - 1)
                liked = False
            else:
                db.add(CommunityCommentLikeORM(comment_id=comment_id, user_id=user_id))
                comment.like_count = comment.like_count + 1
                liked = True

            db.commit()
            return {"liked": liked, "like_count": comment.like_count}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error toggling comment like: {e}")
            raise HTTPException(status_code=500, detail="Failed")
        finally:
            db.close()

    def pin_post(self, post_id: str, user_id: str) -> dict:
        """Pin/unpin a post. Owner only."""
        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.id == user_id).first()
            if not user or user.role != "owner":
                raise HTTPException(status_code=403, detail="Only gym owners can pin posts")

            post = db.query(CommunityPostORM).filter(CommunityPostORM.id == post_id).first()
            if not post:
                raise HTTPException(status_code=404, detail="Post not found")
            if post.gym_id != user.id:
                raise HTTPException(status_code=403, detail="Not your gym")

            post.is_pinned = not post.is_pinned
            post.updated_at = datetime.utcnow().isoformat()
            db.commit()
            return {"is_pinned": post.is_pinned}
        finally:
            db.close()


    def toggle_event_participation(self, post_id: str, user_id: str) -> dict:
        """Toggle participation in a community event. Adds/removes calendar entry + notification."""
        db = get_db_session()
        try:
            post = db.query(CommunityPostORM).filter(
                CommunityPostORM.id == post_id,
                CommunityPostORM.is_deleted == False,
                CommunityPostORM.post_type == "event"
            ).first()
            if not post:
                raise HTTPException(status_code=404, detail="Event not found")

            existing = db.query(CommunityEventParticipantORM).filter(
                CommunityEventParticipantORM.post_id == post_id,
                CommunityEventParticipantORM.user_id == user_id
            ).first()

            if existing:
                # LEAVE event
                db.delete(existing)
                post.participant_count = max(0, (post.participant_count or 0) - 1)
                participating = False

                # Remove from calendar
                db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.client_id == user_id,
                    ClientScheduleORM.type == "community_event",
                    ClientScheduleORM.title.contains(post_id[:8])
                ).delete(synchronize_session=False)
            else:
                # JOIN event
                if post.max_participants and (post.participant_count or 0) >= post.max_participants:
                    raise HTTPException(status_code=400, detail="Event is full")

                db.add(CommunityEventParticipantORM(post_id=post_id, user_id=user_id))
                post.participant_count = (post.participant_count or 0) + 1
                participating = True

                # Add to user's calendar
                title = post.event_title or "Evento Community"
                if post.event_time:
                    title += f" alle {post.event_time}"
                db.add(ClientScheduleORM(
                    client_id=user_id,
                    date=post.event_date or datetime.utcnow().strftime("%Y-%m-%d"),
                    title=f"{title} [{post_id[:8]}]",
                    type="community_event",
                    completed=False,
                ))

                # Notify event author
                if post.author_id != user_id:
                    joiner = db.query(UserORM).filter(UserORM.id == user_id).first()
                    db.add(NotificationORM(
                        user_id=post.author_id,
                        type="event_participation",
                        title="Nuovo partecipante",
                        message=f"{joiner.username if joiner else 'Qualcuno'} parteciperà al tuo evento",
                        data=json.dumps({"post_id": post_id}),
                    ))

            db.commit()
            return {"participating": participating, "participant_count": post.participant_count}
        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error toggling event participation: {e}")
            raise HTTPException(status_code=500, detail="Failed to toggle participation")
        finally:
            db.close()


# Singleton
_community_service = CommunityService()


def get_community_service() -> CommunityService:
    return _community_service
