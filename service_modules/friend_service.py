"""
Friend Service - handles friend requests, friendships, and friend-exclusive data sharing.
"""
from .base import (
    HTTPException, json, logging, datetime, timedelta,
    get_db_session, UserORM, ClientProfileORM, WeightHistoryORM,
    ClientDailyDietSummaryORM, ClientExerciseLogORM, FriendshipORM,
    ClientScheduleORM
)

logger = logging.getLogger("gym_app")


class FriendService:
    """Service for managing friendships between gym members."""

    def _normalize_friendship(self, user_a: str, user_b: str) -> tuple:
        """Return user IDs in normalized order (smaller first) to prevent duplicates."""
        return (user_a, user_b) if user_a < user_b else (user_b, user_a)

    def are_friends(self, user_a: str, user_b: str) -> bool:
        """Check if two users are friends."""
        if user_a == user_b:
            return False
        db = get_db_session()
        try:
            user1_id, user2_id = self._normalize_friendship(user_a, user_b)
            friendship = db.query(FriendshipORM).filter(
                FriendshipORM.user1_id == user1_id,
                FriendshipORM.user2_id == user2_id,
                FriendshipORM.status == "accepted"
            ).first()
            return friendship is not None
        finally:
            db.close()

    def send_friend_request(self, from_user_id: str, to_user_id: str, message: str = None) -> dict:
        """Send a friend request to another user."""
        if from_user_id == to_user_id:
            raise HTTPException(status_code=400, detail="Cannot send friend request to yourself")

        db = get_db_session()
        try:
            # Validate both users are clients in the same gym
            from_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == from_user_id).first()
            to_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == to_user_id).first()

            if not from_profile or not to_profile:
                raise HTTPException(status_code=404, detail="User not found")

            if from_profile.gym_id != to_profile.gym_id:
                raise HTTPException(status_code=400, detail="Can only send friend requests to members of your gym")

            # Check for existing friendship or pending request
            user1_id, user2_id = self._normalize_friendship(from_user_id, to_user_id)
            existing = db.query(FriendshipORM).filter(
                FriendshipORM.user1_id == user1_id,
                FriendshipORM.user2_id == user2_id
            ).first()

            if existing:
                if existing.status == "accepted":
                    raise HTTPException(status_code=400, detail="Already friends")
                elif existing.status == "pending":
                    if existing.initiated_by == from_user_id:
                        raise HTTPException(status_code=400, detail="Friend request already sent")
                    else:
                        # They sent us a request - auto-accept
                        existing.status = "accepted"
                        existing.accepted_at = datetime.utcnow().isoformat()
                        db.commit()
                        return {"status": "accepted", "message": "Friend request accepted (they had sent you one)"}
                elif existing.status == "declined":
                    # Allow re-requesting after decline
                    existing.status = "pending"
                    existing.initiated_by = from_user_id
                    existing.message = message
                    existing.created_at = datetime.utcnow().isoformat()
                    existing.accepted_at = None
                    db.commit()
                    return {"status": "pending", "message": "Friend request sent"}

            # Create new friendship request
            friendship = FriendshipORM(
                user1_id=user1_id,
                user2_id=user2_id,
                status="pending",
                initiated_by=from_user_id,
                message=message,
                created_at=datetime.utcnow().isoformat()
            )
            db.add(friendship)
            db.commit()

            return {"status": "pending", "message": "Friend request sent"}
        finally:
            db.close()

    def respond_to_request(self, user_id: str, request_id: int, accept: bool) -> dict:
        """Accept or decline a friend request."""
        db = get_db_session()
        try:
            friendship = db.query(FriendshipORM).filter(FriendshipORM.id == request_id).first()

            if not friendship:
                raise HTTPException(status_code=404, detail="Friend request not found")

            # Verify user is the recipient (not the one who sent it)
            if friendship.initiated_by == user_id:
                raise HTTPException(status_code=400, detail="Cannot respond to your own request")

            # Verify user is part of this friendship
            if user_id not in [friendship.user1_id, friendship.user2_id]:
                raise HTTPException(status_code=403, detail="Not authorized")

            if friendship.status != "pending":
                raise HTTPException(status_code=400, detail="Request already processed")

            if accept:
                friendship.status = "accepted"
                friendship.accepted_at = datetime.utcnow().isoformat()
                message = "Friend request accepted"
            else:
                friendship.status = "declined"
                message = "Friend request declined"

            db.commit()
            return {"status": friendship.status, "message": message}
        finally:
            db.close()

    def cancel_request(self, user_id: str, request_id: int) -> dict:
        """Cancel a sent friend request."""
        db = get_db_session()
        try:
            friendship = db.query(FriendshipORM).filter(FriendshipORM.id == request_id).first()

            if not friendship:
                raise HTTPException(status_code=404, detail="Friend request not found")

            # Only the sender can cancel
            if friendship.initiated_by != user_id:
                raise HTTPException(status_code=403, detail="Can only cancel your own requests")

            if friendship.status != "pending":
                raise HTTPException(status_code=400, detail="Can only cancel pending requests")

            db.delete(friendship)
            db.commit()
            return {"message": "Friend request cancelled"}
        finally:
            db.close()

    def remove_friend(self, user_id: str, friend_id: str) -> dict:
        """Remove a friend (unfriend)."""
        db = get_db_session()
        try:
            user1_id, user2_id = self._normalize_friendship(user_id, friend_id)
            friendship = db.query(FriendshipORM).filter(
                FriendshipORM.user1_id == user1_id,
                FriendshipORM.user2_id == user2_id,
                FriendshipORM.status == "accepted"
            ).first()

            if not friendship:
                raise HTTPException(status_code=404, detail="Friendship not found")

            db.delete(friendship)
            db.commit()
            return {"message": "Friend removed"}
        finally:
            db.close()

    def get_friends_list(self, user_id: str) -> list:
        """Get user's friends list with basic info."""
        db = get_db_session()
        try:
            # Find all accepted friendships where user is either user1 or user2
            friendships = db.query(FriendshipORM).filter(
                FriendshipORM.status == "accepted",
                (FriendshipORM.user1_id == user_id) | (FriendshipORM.user2_id == user_id)
            ).all()

            friends = []
            for f in friendships:
                friend_id = f.user2_id if f.user1_id == user_id else f.user1_id

                # Get friend's user info
                user = db.query(UserORM).filter(UserORM.id == friend_id).first()
                profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == friend_id).first()

                if user and profile:
                    friends.append({
                        "id": friend_id,
                        "username": user.username,
                        "profile_picture": user.profile_picture,
                        "streak": profile.streak or 0,
                        "gems": profile.gems or 0,
                        "health_score": profile.health_score or 0,
                        "friends_since": f.accepted_at
                    })

            return friends
        finally:
            db.close()

    def get_incoming_requests(self, user_id: str) -> list:
        """Get pending friend requests received."""
        db = get_db_session()
        try:
            # Find pending requests where user is recipient (not initiator)
            friendships = db.query(FriendshipORM).filter(
                FriendshipORM.status == "pending",
                FriendshipORM.initiated_by != user_id,
                (FriendshipORM.user1_id == user_id) | (FriendshipORM.user2_id == user_id)
            ).all()

            requests = []
            for f in friendships:
                sender_id = f.initiated_by
                user = db.query(UserORM).filter(UserORM.id == sender_id).first()

                if user:
                    requests.append({
                        "id": f.id,
                        "user_id": sender_id,
                        "username": user.username,
                        "profile_picture": user.profile_picture,
                        "message": f.message,
                        "created_at": f.created_at
                    })

            return requests
        finally:
            db.close()

    def get_outgoing_requests(self, user_id: str) -> list:
        """Get pending friend requests sent."""
        db = get_db_session()
        try:
            friendships = db.query(FriendshipORM).filter(
                FriendshipORM.status == "pending",
                FriendshipORM.initiated_by == user_id
            ).all()

            requests = []
            for f in friendships:
                # Find the other user
                recipient_id = f.user2_id if f.user1_id == user_id else f.user1_id
                user = db.query(UserORM).filter(UserORM.id == recipient_id).first()

                if user:
                    requests.append({
                        "id": f.id,
                        "user_id": recipient_id,
                        "username": user.username,
                        "profile_picture": user.profile_picture,
                        "message": f.message,
                        "created_at": f.created_at
                    })

            return requests
        finally:
            db.close()

    def get_friendship_status(self, user_id: str, other_user_id: str) -> dict:
        """Get the friendship status between two users."""
        if user_id == other_user_id:
            return {"status": "self"}

        db = get_db_session()
        try:
            user1_id, user2_id = self._normalize_friendship(user_id, other_user_id)
            friendship = db.query(FriendshipORM).filter(
                FriendshipORM.user1_id == user1_id,
                FriendshipORM.user2_id == user2_id
            ).first()

            if not friendship:
                return {"status": "none", "request_id": None}

            if friendship.status == "accepted":
                return {"status": "friends", "request_id": friendship.id, "since": friendship.accepted_at}
            elif friendship.status == "pending":
                if friendship.initiated_by == user_id:
                    return {"status": "pending_outgoing", "request_id": friendship.id}
                else:
                    return {"status": "pending_incoming", "request_id": friendship.id, "message": friendship.message}
            else:  # declined
                return {"status": "none", "request_id": None}
        finally:
            db.close()

    def get_friend_progress(self, user_id: str, friend_id: str) -> dict:
        """Get detailed progress data for a friend (visible only to friends)."""
        # Verify they are actually friends
        if not self.are_friends(user_id, friend_id):
            raise HTTPException(status_code=403, detail="Not friends - cannot view progress")

        db = get_db_session()
        try:
            # Get friend's basic info
            user = db.query(UserORM).filter(UserORM.id == friend_id).first()
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == friend_id).first()

            if not user or not profile:
                raise HTTPException(status_code=404, detail="Friend not found")

            # Get weight history (last 30 days)
            thirty_days_ago = (datetime.utcnow() - timedelta(days=30)).date().isoformat()
            weight_history = db.query(WeightHistoryORM).filter(
                WeightHistoryORM.client_id == friend_id,
                WeightHistoryORM.date >= thirty_days_ago
            ).order_by(WeightHistoryORM.date.asc()).all()

            # Get health scores (last 7 days)
            seven_days_ago = (datetime.utcnow() - timedelta(days=7)).date().isoformat()
            diet_summaries = db.query(ClientDailyDietSummaryORM).filter(
                ClientDailyDietSummaryORM.client_id == friend_id,
                ClientDailyDietSummaryORM.date >= seven_days_ago
            ).order_by(ClientDailyDietSummaryORM.date.asc()).all()

            # Get strength progress (max weight for key exercises over time)
            exercise_logs = db.query(ClientExerciseLogORM).filter(
                ClientExerciseLogORM.client_id == friend_id,
                ClientExerciseLogORM.date >= thirty_days_ago
            ).order_by(ClientExerciseLogORM.date.asc()).all()

            # Process strength data - group by exercise and find max weights
            strength_data = {}
            for log in exercise_logs:
                if log.exercise_name not in strength_data:
                    strength_data[log.exercise_name] = []
                strength_data[log.exercise_name].append({
                    "date": log.date,
                    "weight": log.weight,
                    "reps": log.reps
                })

            return {
                "user_id": friend_id,
                "username": user.username,
                "profile_picture": user.profile_picture,
                "streak": profile.streak or 0,
                "gems": profile.gems or 0,
                "health_score": profile.health_score or 0,
                "weight_history": [
                    {"date": w.date, "weight": w.weight}
                    for w in weight_history
                ],
                "weekly_health_scores": [
                    {"date": d.date, "score": d.health_score or 0}
                    for d in diet_summaries
                ],
                "strength_progress": strength_data,
                "current_weight": profile.weight
            }
        finally:
            db.close()

    def get_friend_workout(self, user_id: str, friend_id: str, date_str: str) -> dict:
        """Get a friend's completed workout for a specific date (for CO-OP viewing)."""
        # Verify they are actually friends
        if not self.are_friends(user_id, friend_id):
            raise HTTPException(status_code=403, detail="Not friends - cannot view workout")

        db = get_db_session()
        try:
            # Get friend's user info
            friend_user = db.query(UserORM).filter(UserORM.id == friend_id).first()
            if not friend_user:
                raise HTTPException(status_code=404, detail="Friend not found")

            # Get friend's workout for the date
            schedule_item = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == friend_id,
                ClientScheduleORM.date == date_str,
                ClientScheduleORM.type == "workout"
            ).first()

            if not schedule_item:
                return {
                    "found": False,
                    "message": f"{friend_user.username} doesn't have a workout for this date"
                }

            if not schedule_item.completed:
                return {
                    "found": False,
                    "message": f"{friend_user.username}'s workout is not completed yet"
                }

            # Parse the workout details
            exercises = []
            if schedule_item.details:
                try:
                    details = json.loads(schedule_item.details)
                    # Handle both old format (array) and new format (object with exercises)
                    if isinstance(details, list):
                        exercises = details
                    elif isinstance(details, dict) and "exercises" in details:
                        exercises = details["exercises"]
                except Exception as e:
                    logger.error(f"Error parsing workout details: {e}")

            return {
                "found": True,
                "friend": {
                    "id": friend_id,
                    "username": friend_user.username,
                    "profile_picture": friend_user.profile_picture
                },
                "workout": {
                    "title": schedule_item.title,
                    "date": date_str,
                    "completed": True,
                    "exercises": exercises
                }
            }
        finally:
            db.close()


# Singleton instance
friend_service = FriendService()


def get_friend_service() -> FriendService:
    """Dependency injection helper."""
    return friend_service
