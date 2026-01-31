"""
Client Routes - API endpoints for client profile management and data retrieval.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from auth import get_current_user
from models import ClientData, ClientProfileUpdate
from models_orm import UserORM, ClientProfileORM, ChatRequestORM, ClientDietSettingsORM
from service_modules.client_service import ClientService, get_client_service
from service_modules.workout_service import get_workout_service
from database import get_db_session

router = APIRouter()


class QuestToggleRequest(BaseModel):
    quest_index: int


class PrivacyModeRequest(BaseModel):
    mode: str  # "public" or "private"


class ChatRequestCreate(BaseModel):
    to_user_id: str
    message: Optional[str] = None


class ChatRequestResponse(BaseModel):
    request_id: int
    accept: bool


class FitnessGoalRequest(BaseModel):
    fitness_goal: str  # "cut", "maintain", "bulk"


@router.get("/api/client/data", response_model=ClientData)
async def get_client_data(
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get client's own data (current user)."""
    workout_service = get_workout_service()
    return service.get_client(
        current_user.id,
        get_workout_details_fn=workout_service.get_workout_details
    )


@router.get("/api/trainer/client/{client_id}", response_model=ClientData)
async def get_client_for_trainer(
    client_id: str,
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get a specific client's data (trainer access)."""
    workout_service = get_workout_service()
    return service.get_client(
        client_id,
        get_workout_details_fn=workout_service.get_workout_details
    )


@router.put("/api/client/profile")
async def update_client_profile(
    profile_update: ClientProfileUpdate,
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Update a client's profile information."""
    return service.update_client_profile(profile_update, current_user.id)


@router.get("/api/client/weight-history")
async def get_weight_history(
    period: str = "month",  # "week", "month", "year"
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get client's weight history for charting."""
    return service.get_weight_history(current_user.id, period)


@router.get("/api/client/strength-progress")
async def get_strength_progress(
    period: str = "month",  # "week", "month", "year"
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get client's strength progress based on exercise weight increases."""
    return service.get_strength_progress(current_user.id, period)


@router.get("/api/client/exercise-details")
async def get_exercise_details(
    category: str = "upper_body",  # "upper_body", "lower_body", "cardio"
    period: str = "month",
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get detailed exercise history for a specific category."""
    return service.get_exercise_details(current_user.id, category, period)


@router.get("/api/trainer/client/{client_id}/weight-history")
async def get_client_weight_history_for_trainer(
    client_id: str,
    period: str = "month",
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get a client's weight history (trainer access)."""
    return service.get_weight_history(client_id, period)


@router.get("/api/trainer/client/{client_id}/strength-progress")
async def get_client_strength_progress_for_trainer(
    client_id: str,
    period: str = "month",
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get a client's strength progress (trainer access)."""
    return service.get_strength_progress(client_id, period)


@router.get("/api/trainer/client/{client_id}/diet-consistency")
async def get_client_diet_consistency_for_trainer(
    client_id: str,
    period: str = "month",
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get a client's diet consistency data (trainer access)."""
    return service.get_diet_consistency(client_id, period)


@router.get("/api/trainer/client/{client_id}/week-streak")
async def get_client_week_streak_for_trainer(
    client_id: str,
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Get a client's week streak data (trainer access)."""
    return service.get_week_streak_data(client_id)


@router.post("/api/trainer/client/{client_id}/toggle_premium")
async def toggle_client_premium(
    client_id: str,
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Toggle premium status for a client (trainer access)."""
    return service.toggle_premium_status(client_id)


@router.post("/api/client/quest/toggle")
async def toggle_quest_completion(
    request: QuestToggleRequest,
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    """Toggle a daily quest completion status."""
    return service.toggle_quest_completion(current_user.id, request.quest_index)


# ============ PRIVACY SETTINGS ============

@router.get("/api/client/privacy")
async def get_privacy_mode(current_user: UserORM = Depends(get_current_user)):
    """Get current user's privacy mode."""
    if current_user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients have privacy settings")

    db = get_db_session()
    try:
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == current_user.id).first()
        return {"privacy_mode": profile.privacy_mode if profile else "public"}
    finally:
        db.close()


@router.post("/api/client/privacy")
async def set_privacy_mode(
    request: PrivacyModeRequest,
    current_user: UserORM = Depends(get_current_user)
):
    """Set user's privacy mode (public, private, or staff_only)."""
    if current_user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients have privacy settings")

    if request.mode not in ["public", "private", "staff_only"]:
        raise HTTPException(status_code=400, detail="Mode must be 'public', 'private', or 'staff_only'")

    db = get_db_session()
    try:
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == current_user.id).first()
        if not profile:
            raise HTTPException(status_code=404, detail="Client profile not found")

        profile.privacy_mode = request.mode
        db.commit()
        return {"success": True, "privacy_mode": request.mode}
    finally:
        db.close()


# ============ FITNESS GOAL ============

@router.get("/api/client/fitness-goal")
async def get_fitness_goal(current_user: UserORM = Depends(get_current_user)):
    """Get current user's fitness goal and calorie targets."""
    if current_user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients have fitness goals")

    db = get_db_session()
    try:
        settings = db.query(ClientDietSettingsORM).filter(
            ClientDietSettingsORM.id == current_user.id
        ).first()

        if not settings:
            # Create default settings
            settings = ClientDietSettingsORM(
                id=current_user.id,
                fitness_goal="maintain",
                base_calories=2000,
                calories_target=2000
            )
            db.add(settings)
            db.commit()
            db.refresh(settings)

        # Check if client has a trainer assigned
        has_trainer = current_user.trainer_id is not None

        return {
            "fitness_goal": settings.fitness_goal or "maintain",
            "base_calories": settings.base_calories or 2000,
            "calories_target": settings.calories_target,
            "protein_target": settings.protein_target,
            "carbs_target": settings.carbs_target,
            "fat_target": settings.fat_target,
            "has_trainer": has_trainer
        }
    finally:
        db.close()


@router.post("/api/client/fitness-goal")
async def set_fitness_goal(
    request: FitnessGoalRequest,
    current_user: UserORM = Depends(get_current_user)
):
    """Set user's fitness goal and adjust macro targets accordingly."""
    if current_user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients have fitness goals")

    # Block if client has a trainer assigned - trainer manages their nutrition
    if current_user.trainer_id:
        raise HTTPException(status_code=403, detail="Your trainer manages your nutrition plan")

    if request.fitness_goal not in ["cut", "maintain", "bulk"]:
        raise HTTPException(status_code=400, detail="Goal must be 'cut', 'maintain', or 'bulk'")

    db = get_db_session()
    try:
        settings = db.query(ClientDietSettingsORM).filter(
            ClientDietSettingsORM.id == current_user.id
        ).first()

        if not settings:
            settings = ClientDietSettingsORM(
                id=current_user.id,
                base_calories=2000
            )
            db.add(settings)
            db.flush()

        # If base_calories not set, use current target as base
        if not settings.base_calories or settings.base_calories == 0:
            settings.base_calories = settings.calories_target or 2000

        base = settings.base_calories

        # Calculate new targets based on goal
        if request.fitness_goal == "cut":
            # Cut: -500 kcal, high protein (1g/lb target), moderate carbs, lower fat
            new_calories = base - 500
            new_protein = int(base * 0.35 / 4)  # 35% from protein
            new_carbs = int(base * 0.35 / 4)    # 35% from carbs
            new_fat = int(base * 0.30 / 9)      # 30% from fat
        elif request.fitness_goal == "bulk":
            # Bulk: +400 kcal, high protein, higher carbs for energy
            new_calories = base + 400
            new_protein = int(base * 0.30 / 4)  # 30% from protein
            new_carbs = int(base * 0.50 / 4)    # 50% from carbs
            new_fat = int(base * 0.20 / 9)      # 20% from fat
        else:  # maintain
            new_calories = base
            new_protein = int(base * 0.30 / 4)
            new_carbs = int(base * 0.40 / 4)
            new_fat = int(base * 0.30 / 9)

        settings.fitness_goal = request.fitness_goal
        settings.calories_target = new_calories
        settings.protein_target = new_protein
        settings.carbs_target = new_carbs
        settings.fat_target = new_fat

        db.commit()

        return {
            "success": True,
            "fitness_goal": request.fitness_goal,
            "new_calories_target": new_calories,
            "new_protein_target": new_protein,
            "new_carbs_target": new_carbs,
            "new_fat_target": new_fat
        }
    finally:
        db.close()


# ============ CHAT REQUESTS ============

@router.get("/api/client/chat-requests/pending")
async def get_pending_chat_requests(current_user: UserORM = Depends(get_current_user)):
    """Get pending chat requests sent to the current user."""
    db = get_db_session()
    try:
        requests = db.query(ChatRequestORM).filter(
            ChatRequestORM.to_user_id == current_user.id,
            ChatRequestORM.status == "pending"
        ).all()

        result = []
        for req in requests:
            # Get sender info
            sender = db.query(UserORM).filter(UserORM.id == req.from_user_id).first()
            sender_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == req.from_user_id).first()

            result.append({
                "id": req.id,
                "from_user_id": req.from_user_id,
                "from_username": sender.username if sender else "Unknown",
                "from_profile_picture": sender.profile_picture if sender else None,
                "message": req.message,
                "created_at": req.created_at
            })

        return result
    finally:
        db.close()


@router.get("/api/client/chat-requests/sent")
async def get_sent_chat_requests(current_user: UserORM = Depends(get_current_user)):
    """Get chat requests sent by the current user."""
    db = get_db_session()
    try:
        requests = db.query(ChatRequestORM).filter(
            ChatRequestORM.from_user_id == current_user.id
        ).all()

        result = []
        for req in requests:
            # Get recipient info
            recipient = db.query(UserORM).filter(UserORM.id == req.to_user_id).first()

            result.append({
                "id": req.id,
                "to_user_id": req.to_user_id,
                "to_username": recipient.username if recipient else "Unknown",
                "to_profile_picture": recipient.profile_picture if recipient else None,
                "status": req.status,
                "message": req.message,
                "created_at": req.created_at,
                "responded_at": req.responded_at
            })

        return result
    finally:
        db.close()


@router.post("/api/client/chat-requests")
async def send_chat_request(
    request: ChatRequestCreate,
    current_user: UserORM = Depends(get_current_user)
):
    """Send a chat request to another user."""
    if request.to_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot send chat request to yourself")

    db = get_db_session()
    try:
        # Check if target user exists and is a client
        target_user = db.query(UserORM).filter(UserORM.id == request.to_user_id).first()
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")

        # Check target's privacy mode
        target_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == request.to_user_id).first()
        if target_profile and target_profile.privacy_mode == "public":
            # Public user - no request needed, they can chat directly
            return {"success": True, "status": "public", "message": "User is public, you can message them directly"}

        # Check for existing pending request
        existing = db.query(ChatRequestORM).filter(
            ChatRequestORM.from_user_id == current_user.id,
            ChatRequestORM.to_user_id == request.to_user_id,
            ChatRequestORM.status == "pending"
        ).first()

        if existing:
            raise HTTPException(status_code=400, detail="You already have a pending request to this user")

        # Check if already accepted (either direction)
        accepted = db.query(ChatRequestORM).filter(
            ((ChatRequestORM.from_user_id == current_user.id) & (ChatRequestORM.to_user_id == request.to_user_id)) |
            ((ChatRequestORM.from_user_id == request.to_user_id) & (ChatRequestORM.to_user_id == current_user.id)),
            ChatRequestORM.status == "accepted"
        ).first()

        if accepted:
            return {"success": True, "status": "already_accepted", "message": "You can already message this user"}

        # Create new chat request
        new_request = ChatRequestORM(
            from_user_id=current_user.id,
            to_user_id=request.to_user_id,
            message=request.message,
            created_at=datetime.utcnow().isoformat()
        )
        db.add(new_request)
        db.commit()

        return {"success": True, "status": "pending", "request_id": new_request.id}
    finally:
        db.close()


@router.post("/api/client/chat-requests/respond")
async def respond_to_chat_request(
    response: ChatRequestResponse,
    current_user: UserORM = Depends(get_current_user)
):
    """Accept or reject a chat request."""
    db = get_db_session()
    try:
        # Find the request
        chat_request = db.query(ChatRequestORM).filter(
            ChatRequestORM.id == response.request_id,
            ChatRequestORM.to_user_id == current_user.id,
            ChatRequestORM.status == "pending"
        ).first()

        if not chat_request:
            raise HTTPException(status_code=404, detail="Chat request not found or already responded")

        chat_request.status = "accepted" if response.accept else "rejected"
        chat_request.responded_at = datetime.utcnow().isoformat()
        db.commit()

        return {
            "success": True,
            "status": chat_request.status,
            "from_user_id": chat_request.from_user_id
        }
    finally:
        db.close()


@router.get("/api/client/can-message/{user_id}")
async def can_message_user(
    user_id: str,
    current_user: UserORM = Depends(get_current_user)
):
    """Check if current user can message another user."""
    if user_id == current_user.id:
        return {"can_message": False, "reason": "Cannot message yourself"}

    db = get_db_session()
    try:
        target_user = db.query(UserORM).filter(UserORM.id == user_id).first()
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")

        # Trainers and owners are always messageable by their clients
        if target_user.role in ["trainer", "owner"]:
            return {"can_message": True, "reason": "trainer_or_owner"}

        # Check target's privacy mode
        target_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user_id).first()

        # Staff only mode - no client messages allowed at all
        if target_profile and target_profile.privacy_mode == "staff_only":
            return {"can_message": False, "reason": "staff_only", "message": "This user only accepts messages from gym staff"}

        # Public users can be messaged by anyone
        if not target_profile or target_profile.privacy_mode == "public":
            return {"can_message": True, "reason": "public"}

        # Private user - check for accepted request (either direction)
        accepted = db.query(ChatRequestORM).filter(
            ((ChatRequestORM.from_user_id == current_user.id) & (ChatRequestORM.to_user_id == user_id)) |
            ((ChatRequestORM.from_user_id == user_id) & (ChatRequestORM.to_user_id == current_user.id)),
            ChatRequestORM.status == "accepted"
        ).first()

        if accepted:
            return {"can_message": True, "reason": "request_accepted"}

        # Check for pending request
        pending = db.query(ChatRequestORM).filter(
            ChatRequestORM.from_user_id == current_user.id,
            ChatRequestORM.to_user_id == user_id,
            ChatRequestORM.status == "pending"
        ).first()

        if pending:
            return {"can_message": False, "reason": "request_pending", "request_id": pending.id}

        return {"can_message": False, "reason": "private", "needs_request": True}
    finally:
        db.close()


@router.get("/api/client/gym-members")
async def get_gym_members(current_user: UserORM = Depends(get_current_user)):
    """Get other clients in the same gym for social features."""
    from service_modules.friend_service import get_friend_service
    friend_service = get_friend_service()

    db = get_db_session()
    try:
        # Get current user's gym
        my_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == current_user.id).first()
        if not my_profile or not my_profile.gym_id:
            return []

        # Get other clients in the same gym
        other_profiles = db.query(ClientProfileORM).filter(
            ClientProfileORM.gym_id == my_profile.gym_id,
            ClientProfileORM.id != current_user.id
        ).all()

        members = []
        for profile in other_profiles:
            user = db.query(UserORM).filter(UserORM.id == profile.id).first()
            if user:
                # Get friendship status
                friendship = friend_service.get_friendship_status(current_user.id, user.id)
                members.append({
                    "id": user.id,
                    "username": user.username,
                    "profile_picture": user.profile_picture,
                    "privacy_mode": profile.privacy_mode or "public",
                    "friendship_status": friendship["status"]
                })

        return members
    finally:
        db.close()


@router.get("/api/client/member/{member_id}")
async def get_member_profile(
    member_id: str,
    current_user: UserORM = Depends(get_current_user)
):
    """Get a gym member's public profile."""
    from service_modules.friend_service import get_friend_service
    friend_service = get_friend_service()

    if member_id == current_user.id:
        raise HTTPException(status_code=400, detail="Use /api/client/data for your own profile")

    db = get_db_session()
    try:
        # Check if viewer is in same gym as the member
        my_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == current_user.id).first()
        member_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == member_id).first()

        if not my_profile or not member_profile:
            raise HTTPException(status_code=404, detail="Profile not found")

        if my_profile.gym_id != member_profile.gym_id:
            raise HTTPException(status_code=403, detail="You can only view members from your gym")

        # Get user info
        member_user = db.query(UserORM).filter(UserORM.id == member_id).first()
        if not member_user:
            raise HTTPException(status_code=404, detail="User not found")

        # Get friendship status
        friendship = friend_service.get_friendship_status(current_user.id, member_id)
        is_friend = friendship["status"] == "friends"

        return {
            "id": member_user.id,
            "username": member_user.username,
            "profile_picture": member_user.profile_picture,
            "bio": member_user.bio,
            "streak": member_profile.streak or 0,
            "gems": member_profile.gems or 0,
            "health_score": member_profile.health_score or 0,
            "privacy_mode": member_profile.privacy_mode or "public",
            "is_friend": is_friend,
            "friendship_status": friendship["status"],
            "friendship_request_id": friendship.get("request_id")
        }
    finally:
        db.close()
