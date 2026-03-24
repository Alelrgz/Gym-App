from fastapi import APIRouter, Depends, Header, HTTPException, status, File, UploadFile, Request
from typing import Optional
from fastapi.security import OAuth2PasswordRequestForm
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment, ExerciseTemplate, AssignDietRequest
from services import GymService, UserService, LeaderboardService
from datetime import timedelta
from auth import create_access_token, get_current_user
from database import get_db
from models_orm import UserORM
import logging

logger = logging.getLogger("gym_app")

# Rate limiting for API auth endpoints
try:
    from slowapi import Limiter
    from slowapi.util import get_remote_address
    _limiter = Limiter(key_func=get_remote_address)
except ImportError:
    _limiter = None

def _rate_limit_auth(limit_str):
    """Apply rate limiting to auth endpoints."""
    def decorator(func):
        if _limiter:
            return _limiter.limit(limit_str)(func)
        return func
    return decorator

# Import modular routes
from route_modules.workout_routes import router as workout_router
from route_modules.split_routes import router as split_router
from route_modules.exercise_routes import router as exercise_router
from route_modules.notes_routes import router as notes_router
from route_modules.diet_routes import router as diet_router
from route_modules.schedule_routes import router as schedule_router
from route_modules.client_routes import router as client_router
from route_modules.subscription_routes import router as subscription_router
from route_modules.appointment_routes import router as appointment_router
from route_modules.notification_routes import router as notification_router
from route_modules.course_routes import router as course_router
from route_modules.friend_routes import router as friend_router
from route_modules.facility_routes import router as facility_router
from route_modules.nutritionist_routes import router as nutritionist_router
from route_modules.gym_routes import router as gym_router
# Gym assignment routes are now defined directly in main.py
# from route_modules.gym_assignment_routes import router as gym_assignment_router

router = APIRouter()
# Include modular routers
router.include_router(workout_router)
router.include_router(split_router)
router.include_router(exercise_router)
router.include_router(notes_router)
router.include_router(diet_router)
router.include_router(schedule_router)
router.include_router(client_router)
router.include_router(subscription_router)
router.include_router(appointment_router)
router.include_router(notification_router)
router.include_router(course_router)
router.include_router(friend_router)
router.include_router(facility_router)
router.include_router(nutritionist_router)
router.include_router(gym_router)
# router.include_router(gym_assignment_router)
# Trigger reload v14 - added gym/trainer assignment system

# --- DEPENDENCIES ---
def get_gym_service() -> GymService:
    return GymService()

def get_user_service() -> UserService:
    return UserService()

def get_leaderboard_service() -> LeaderboardService:
    return LeaderboardService()

# --- ROUTES ---
@router.get("/api/ping")
async def ping():
    return {"pong": True}

@router.post("/api/auth/login")
@_rate_limit_auth("10/minute")
async def login(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), service: UserService = Depends(get_user_service)):
    user = service.authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    # Generate a unique session ID for single-device enforcement
    import secrets as _secrets
    session_id = _secrets.token_urlsafe(16)

    # Store session ID on user — invalidates any previous session
    db = next(get_db())
    try:
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            db_user.active_session_id = session_id
            db.commit()
    finally:
        db.close()

    access_token = create_access_token(
        data={"sub": user.username, "role": user.role, "sid": session_id},
        expires_delta=timedelta(hours=8)
    )

    # Include gym list for owners
    gyms = []
    if user.role == "owner":
        from models_orm import GymORM
        db = next(get_db())
        try:
            gym_rows = db.query(GymORM).filter(
                GymORM.owner_id == user.id,
                GymORM.is_active == True
            ).order_by(GymORM.created_at).all()
            gyms = [{"id": g.id, "name": g.name or user.username, "logo": g.logo} for g in gym_rows]
        finally:
            db.close()

    return {
        "access_token": access_token, "token_type": "bearer",
        "role": user.role, "username": user.username, "user_id": user.id,
        "gyms": gyms,
    }

@router.post("/api/auth/register")
@_rate_limit_auth("5/minute")
async def register(
    request: Request,
    user_data: dict,
    service: UserService = Depends(get_user_service)
):
    # Block client self-registration — clients are created by staff/owner only
    role = user_data.get("role", "client")
    if role == "client":
        raise HTTPException(status_code=403, detail="La registrazione clienti è disabilitata. Contatta la tua palestra.")
    return service.register_user(user_data)

@router.get("/api/config/{gym_id}", response_model=GymConfig)
async def get_gym_config(gym_id: str, service: GymService = Depends(get_gym_service)):
    return service.get_gym(gym_id)

# Client routes moved to route_modules/client_routes.py
# - /api/client/data (get client's own data)
# - /api/client/profile (update profile)
# - /api/trainer/client/{client_id} (get client data for trainer)
# - /api/trainer/client/{client_id}/toggle_premium (toggle premium)

# Schedule routes moved to route_modules/schedule_routes.py

# Diet routes moved to route_modules/diet_routes.py

@router.get("/api/trainer/data", response_model=TrainerData)
async def get_trainer_data(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_trainer(current_user.id)

# Trainer event routes moved to route_modules/schedule_routes.py


@router.get("/api/trainer/clients")
async def get_trainer_clients(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    data = service.get_trainer(current_user.id)
    return data.clients

@router.get("/api/owner/data", response_model=OwnerData)
async def get_owner_data(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user),
    x_gym_id: Optional[str] = Header(None)
):
    from gym_context import resolve_gym_id
    gym_id = resolve_gym_id(current_user, x_gym_id)
    return service.get_owner(owner_id=gym_id)

@router.get("/api/leaderboard/data", response_model=LeaderboardData)
async def get_leaderboard_data(
    service: LeaderboardService = Depends(get_leaderboard_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_leaderboard(current_user.id)



# Exercise routes moved to route_modules/exercise_routes.py
# Workout routes moved to route_modules/workout_routes.py
# Diet routes moved to route_modules/diet_routes.py
# Split routes moved to route_modules/split_routes.py


# Notes routes moved to route_modules/notes_routes.py


import shutil
import os
import uuid
from service_modules.storage_service import upload_file as storage_upload, get_storage_info

UPLOAD_ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.pdf'}
MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10MB

@router.post("/api/upload")
async def upload_file_endpoint(
    file: UploadFile = File(...),
    upload_type: str = "general",
    current_user: UserORM = Depends(get_current_user)
):
    """Upload a file (requires authentication). Uses Cloudinary in production, local in development."""
    # Validate file extension
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in UPLOAD_ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"File type not allowed. Allowed: {', '.join(UPLOAD_ALLOWED_EXTENSIONS)}")

    # Read and validate file size
    content = await file.read()
    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=400, detail="File too large. Maximum size is 10MB")

    # Validate upload_type
    valid_types = {"general", "profile", "certificate", "document"}
    if upload_type not in valid_types:
        upload_type = "general"

    # Upload using storage service (Cloudinary or local)
    success, url_or_error, public_id = await storage_upload(
        file_content=content,
        filename=file.filename,
        upload_type=upload_type,
        user_id=current_user.id
    )

    if not success:
        raise HTTPException(status_code=500, detail=url_or_error)

    return {
        "url": url_or_error,
        "filename": file.filename,
        "public_id": public_id,
        "storage": get_storage_info()["provider"]
    }

# Force reload: v2
# Trigger reload v16 - friend routes
