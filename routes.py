from fastapi import APIRouter, Depends, Header, HTTPException, status, File, UploadFile
from fastapi.security import OAuth2PasswordRequestForm
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment, ExerciseTemplate, AssignDietRequest
from services import GymService, UserService, LeaderboardService
from auth import create_access_token, get_current_user
from models_orm import UserORM

# Import modular routes
from route_modules.workout_routes import router as workout_router
from route_modules.split_routes import router as split_router
from route_modules.exercise_routes import router as exercise_router
from route_modules.notes_routes import router as notes_router
from route_modules.diet_routes import router as diet_router

router = APIRouter()
# Include modular routers
router.include_router(workout_router)
router.include_router(split_router)
router.include_router(exercise_router)
router.include_router(notes_router)
router.include_router(diet_router)
# Trigger reload v9 - modular workout + split + exercise + notes + diet routes

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
async def login(form_data: OAuth2PasswordRequestForm = Depends(), service: UserService = Depends(get_user_service)):
    user = service.authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token = create_access_token(data={"sub": user.username, "role": user.role})
    return {"access_token": access_token, "token_type": "bearer", "role": user.role, "username": user.username}

@router.post("/api/auth/register")
async def register(
    user_data: dict, 
    service: UserService = Depends(get_user_service)
):
    return service.register_user(user_data)

@router.get("/api/config/{gym_id}", response_model=GymConfig)
async def get_gym_config(gym_id: str, service: GymService = Depends(get_gym_service)):
    return service.get_gym(gym_id)

@router.get("/api/client/data", response_model=ClientData)
async def get_client_data(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_client(current_user.id)

@router.get("/api/client/schedule")
async def get_client_schedule(
    date: str = None, 
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_client_schedule(current_user.id, date)

@router.get("/api/client/{client_id}/history")
async def get_client_history(client_id: str, exercise_name: str = None):
    try:
        user_service = UserService()
        # Ensure trainer has access to this client (skip auth for prototype)
        return user_service.get_client_exercise_history(client_id, exercise_name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/api/client/schedule/complete")
async def complete_schedule_item(
    payload: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    # payload: { "date": "YYYY-MM-DD", "item_id": "..." }
    return service.complete_schedule_item(payload, current_user.id)

@router.post("/api/trainer/schedule/complete")
async def complete_trainer_schedule_item(
    payload: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    # payload: { "date": "YYYY-MM-DD" }
    return service.complete_trainer_schedule_item(payload, current_user.id)


@router.put("/api/client/schedule/update_set")
async def update_completed_workout(
    payload: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.update_completed_workout(payload, current_user.id)

from models import ClientProfileUpdate
@router.put("/api/client/profile")
async def update_client_profile(
    profile_update: ClientProfileUpdate,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.update_client_profile(profile_update, current_user.id)

# Diet routes moved to route_modules/diet_routes.py

@router.get("/api/trainer/data", response_model=TrainerData)
async def get_trainer_data(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    with open("server_debug.log", "a") as f:
        f.write(f"DEBUG: ROUTE HIT: get_trainer_data for {current_user.username}\n")
    return service.get_trainer(current_user.id)

@router.get("/api/trainer/client/{client_id}", response_model=ClientData)
async def get_client_for_trainer(
    client_id: str, 
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_client(client_id)

@router.post("/api/trainer/client/{client_id}/toggle_premium")
async def toggle_client_premium(
    client_id: str,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    with open("server_debug.log", "a") as f:
        f.write(f"ROUTE HIT: toggle_client_premium for {client_id}. User: {current_user.username}\n")
    return service.toggle_premium_status(client_id)

@router.post("/api/trainer/events")
async def add_trainer_event(
    event_data: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.add_trainer_event(event_data, current_user.id)

@router.delete("/api/trainer/events/{event_id}")
async def delete_trainer_event(
    event_id: str,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.remove_trainer_event(event_id, current_user.id)

@router.post("/api/trainer/events/{event_id}/toggle_complete")
async def toggle_trainer_event_completion(
    event_id: str,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.toggle_trainer_event_completion(event_id, current_user.id)


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
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_owner()

@router.get("/api/leaderboard/data", response_model=LeaderboardData)
async def get_leaderboard_data(
    service: LeaderboardService = Depends(get_leaderboard_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_leaderboard()



# Exercise routes moved to route_modules/exercise_routes.py
# Workout routes moved to route_modules/workout_routes.py
# Diet routes moved to route_modules/diet_routes.py
# Split routes moved to route_modules/split_routes.py


# Notes routes moved to route_modules/notes_routes.py


import shutil
import os
import uuid

@router.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    upload_dir = "static/uploads"
    os.makedirs(upload_dir, exist_ok=True)
    
    # Generate unique filename
    file_ext = os.path.splitext(file.filename)[1]
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(upload_dir, unique_filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    return {"url": f"/static/uploads/{unique_filename}", "filename": unique_filename}

# Force reload: v2
