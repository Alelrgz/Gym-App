"""
Community Service - Business logic for social feed, posts, likes, comments.
"""
from sqlalchemy.orm import Session
from sqlalchemy import desc
from models_orm import (
    UserORM, CommunityPostORM, CommunityLikeORM,
    CommunityCommentORM, CommunityCommentLikeORM,
)
from database import get_db_session
from datetime import datetime
from fastapi import HTTPException
import uuid


class CommunityService:
    def __init__(self, db: Session):
        self.db = db

    def _get_gym_id(self, user_id: str) -> str:
        user = self.db.query(UserORM).filter(UserORM.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        if user.role == "owner":
            return user.id
        return user.gym_owner_id or user.id

    def _post_to_dict(self, post: CommunityPostORM, user_id: str) -> dict:
        author = self.db.query(UserORM).filter(UserORM.id == post.author_id).first()

        liked = self.db.query(CommunityLikeORM).filter(
            CommunityLikeORM.post_id == post.id,
            CommunityLikeORM.user_id == user_id,
        ).first() is not None

        # Get first comment preview
        first_comment = self.db.query(CommunityCommentORM).filter(
            CommunityCommentORM.post_id == post.id,
            CommunityCommentORM.is_deleted == False,
        ).order_by(CommunityCommentORM.created_at).first()

        first_comment_preview = None
        if first_comment:
            comment_author = self.db.query(UserORM).filter(
                UserORM.id == first_comment.author_id
            ).first()
            first_comment_preview = {
                "id": first_comment.id,
                "author_username": comment_author.username if comment_author else "Unknown",
                "author_profile_picture": comment_author.profile_picture if comment_author else None,
                "content": first_comment.content,
                "created_at": first_comment.created_at,
            }

        return {
            "id": post.id,
            "author_id": post.author_id,
            "author_username": author.username if author else "Unknown",
            "author_profile_picture": author.profile_picture if author else None,
            "author_role": author.role if author else None,
            "gym_id": post.gym_id,
            "post_type": post.post_type,
            "content": post.content,
            "image_url": post.image_url,
            "event_title": post.event_title,
            "event_date": post.event_date,
            "event_time": post.event_time,
            "event_location": post.event_location,
            "quest_xp_reward": post.quest_xp_reward,
            "quest_deadline": post.quest_deadline,
            "is_pinned": post.is_pinned,
            "like_count": post.like_count or 0,
            "comment_count": post.comment_count or 0,
            "repost_count": post.repost_count or 0,
            "liked_by_me": liked,
            "first_comment": first_comment_preview,
            "created_at": post.created_at,
            "updated_at": post.updated_at,
        }

    def get_feed(self, user_id: str, cursor: str = None, limit: int = 20) -> dict:
        gym_id = self._get_gym_id(user_id)

        query = self.db.query(CommunityPostORM).filter(
            CommunityPostORM.gym_id == gym_id,
            CommunityPostORM.is_deleted == False,
        )

        if cursor:
            query = query.filter(CommunityPostORM.created_at < cursor)

        # Pinned first, then by date
        posts = query.order_by(
            desc(CommunityPostORM.is_pinned),
            desc(CommunityPostORM.created_at),
        ).limit(limit + 1).all()

        has_more = len(posts) > limit
        posts = posts[:limit]

        next_cursor = posts[-1].created_at if has_more and posts else None

        return {
            "posts": [self._post_to_dict(p, user_id) for p in posts],
            "next_cursor": next_cursor,
            "has_more": has_more,
        }

    def create_post(self, author_id: str, post_type: str, content: str = None,
                     image_url: str = None, event_title: str = None,
                     event_date: str = None, event_time: str = None,
                     event_location: str = None, quest_xp_reward: int = None,
                     quest_deadline: str = None) -> dict:
        gym_id = self._get_gym_id(author_id)
        now = datetime.utcnow().isoformat()

        post = CommunityPostORM(
            id=str(uuid.uuid4()),
            author_id=author_id,
            gym_id=gym_id,
            post_type=post_type or "text",
            content=content,
            image_url=image_url,
            event_title=event_title,
            event_date=event_date,
            event_time=event_time,
            event_location=event_location,
            quest_xp_reward=quest_xp_reward,
            quest_deadline=quest_deadline,
            is_pinned=False,
            is_deleted=False,
            like_count=0,
            comment_count=0,
            repost_count=0,
            created_at=now,
            updated_at=now,
        )
        self.db.add(post)
        self.db.commit()
        self.db.refresh(post)
        return self._post_to_dict(post, author_id)

    def delete_post(self, post_id: str, user_id: str) -> dict:
        post = self.db.query(CommunityPostORM).filter(
            CommunityPostORM.id == post_id
        ).first()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")

        user = self.db.query(UserORM).filter(UserORM.id == user_id).first()
        if post.author_id != user_id and (not user or user.role not in ("owner", "staff")):
            raise HTTPException(status_code=403, detail="Not authorized")

        post.is_deleted = True
        self.db.commit()
        return {"status": "deleted"}

    def toggle_like(self, post_id: str, user_id: str) -> dict:
        post = self.db.query(CommunityPostORM).filter(
            CommunityPostORM.id == post_id,
            CommunityPostORM.is_deleted == False,
        ).first()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")

        existing = self.db.query(CommunityLikeORM).filter(
            CommunityLikeORM.post_id == post_id,
            CommunityLikeORM.user_id == user_id,
        ).first()

        if existing:
            self.db.delete(existing)
            post.like_count = max(0, (post.like_count or 0) - 1)
            liked = False
        else:
            like = CommunityLikeORM(
                post_id=post_id,
                user_id=user_id,
                created_at=datetime.utcnow().isoformat(),
            )
            self.db.add(like)
            post.like_count = (post.like_count or 0) + 1
            liked = True

        self.db.commit()
        return {"liked": liked, "like_count": post.like_count}

    def get_comments(self, post_id: str, user_id: str, cursor: str = None, limit: int = 20) -> dict:
        query = self.db.query(CommunityCommentORM).filter(
            CommunityCommentORM.post_id == post_id,
            CommunityCommentORM.is_deleted == False,
        )

        if cursor:
            query = query.filter(CommunityCommentORM.created_at < cursor)

        comments = query.order_by(desc(CommunityCommentORM.created_at)).limit(limit + 1).all()

        has_more = len(comments) > limit
        comments = comments[:limit]
        next_cursor = comments[-1].created_at if has_more and comments else None

        result = []
        for c in comments:
            author = self.db.query(UserORM).filter(UserORM.id == c.author_id).first()
            liked = self.db.query(CommunityCommentLikeORM).filter(
                CommunityCommentLikeORM.comment_id == c.id,
                CommunityCommentLikeORM.user_id == user_id,
            ).first() is not None

            result.append({
                "id": c.id,
                "post_id": c.post_id,
                "author_id": c.author_id,
                "author_username": author.username if author else "Unknown",
                "author_profile_picture": author.profile_picture if author else None,
                "content": c.content,
                "parent_comment_id": c.parent_comment_id,
                "like_count": c.like_count or 0,
                "liked_by_me": liked,
                "created_at": c.created_at,
            })

        return {
            "comments": result,
            "next_cursor": next_cursor,
            "has_more": has_more,
        }

    def add_comment(self, post_id: str, user_id: str, content: str, parent_comment_id: int = None) -> dict:
        post = self.db.query(CommunityPostORM).filter(
            CommunityPostORM.id == post_id,
            CommunityPostORM.is_deleted == False,
        ).first()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")

        now = datetime.utcnow().isoformat()
        comment = CommunityCommentORM(
            post_id=post_id,
            author_id=user_id,
            content=content,
            parent_comment_id=parent_comment_id,
            like_count=0,
            is_deleted=False,
            created_at=now,
            updated_at=now,
        )
        self.db.add(comment)
        post.comment_count = (post.comment_count or 0) + 1
        self.db.commit()
        self.db.refresh(comment)

        author = self.db.query(UserORM).filter(UserORM.id == user_id).first()
        return {
            "id": comment.id,
            "post_id": comment.post_id,
            "author_id": comment.author_id,
            "author_username": author.username if author else "Unknown",
            "author_profile_picture": author.profile_picture if author else None,
            "content": comment.content,
            "parent_comment_id": comment.parent_comment_id,
            "like_count": 0,
            "liked_by_me": False,
            "created_at": comment.created_at,
        }

    def delete_comment(self, comment_id: int, user_id: str) -> dict:
        comment = self.db.query(CommunityCommentORM).filter(
            CommunityCommentORM.id == comment_id
        ).first()
        if not comment:
            raise HTTPException(status_code=404, detail="Comment not found")

        user = self.db.query(UserORM).filter(UserORM.id == user_id).first()
        if comment.author_id != user_id and (not user or user.role not in ("owner", "staff")):
            raise HTTPException(status_code=403, detail="Not authorized")

        comment.is_deleted = True
        post = self.db.query(CommunityPostORM).filter(
            CommunityPostORM.id == comment.post_id
        ).first()
        if post:
            post.comment_count = max(0, (post.comment_count or 0) - 1)
        self.db.commit()
        return {"status": "deleted"}

    def toggle_comment_like(self, comment_id: int, user_id: str) -> dict:
        comment = self.db.query(CommunityCommentORM).filter(
            CommunityCommentORM.id == comment_id,
            CommunityCommentORM.is_deleted == False,
        ).first()
        if not comment:
            raise HTTPException(status_code=404, detail="Comment not found")

        existing = self.db.query(CommunityCommentLikeORM).filter(
            CommunityCommentLikeORM.comment_id == comment_id,
            CommunityCommentLikeORM.user_id == user_id,
        ).first()

        if existing:
            self.db.delete(existing)
            comment.like_count = max(0, (comment.like_count or 0) - 1)
            liked = False
        else:
            like = CommunityCommentLikeORM(
                comment_id=comment_id,
                user_id=user_id,
                created_at=datetime.utcnow().isoformat(),
            )
            self.db.add(like)
            comment.like_count = (comment.like_count or 0) + 1
            liked = True

        self.db.commit()
        return {"liked": liked, "like_count": comment.like_count}

    def pin_post(self, post_id: str, user_id: str) -> dict:
        user = self.db.query(UserORM).filter(UserORM.id == user_id).first()
        if not user or user.role != "owner":
            raise HTTPException(status_code=403, detail="Only gym owners can pin posts")

        post = self.db.query(CommunityPostORM).filter(
            CommunityPostORM.id == post_id,
            CommunityPostORM.is_deleted == False,
        ).first()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")

        post.is_pinned = not post.is_pinned
        self.db.commit()
        return {"pinned": post.is_pinned}


def get_community_service():
    db = get_db_session()
    try:
        yield CommunityService(db)
    finally:
        db.close()
