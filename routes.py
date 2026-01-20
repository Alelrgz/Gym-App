from fastapi import APIRouter, Depends, Header, HTTPException, status, File, UploadFile
from fastapi.security import OAuth2PasswordRequestForm
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment, ExerciseTemplate, AssignDietRequest
from services import GymService, UserService, LeaderboardService
from auth import create_access_token, get_current_user
from models_orm import UserORM

router = APIRouter()
# Trigger reload v4

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

@router.post("/api/client/diet/scan")
async def scan_meal(
    file: UploadFile = File(...),
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    # Read file bytes
    content = await file.read()
    return service.scan_meal(content)

@router.post("/api/client/diet/log")
async def log_meal(
    meal_data: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.log_meal(current_user.id, meal_data)

@router.get("/api/trainer/data", response_model=TrainerData)
async def get_trainer_data(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
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



@router.get("/api/trainer/exercises")
async def get_exercises(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_exercises(current_user.id)

@router.post("/api/trainer/exercises")
async def create_exercise(
    exercise: ExerciseTemplate, 
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    # Convert Pydantic model to dict for service layer
    return service.create_exercise(exercise.model_dump(), current_user.id)

@router.put("/api/trainer/exercises/{exercise_id}")
async def update_exercise(
    exercise_id: str,
    exercise: ExerciseTemplate,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.update_exercise(exercise_id, exercise.model_dump(exclude_unset=True), current_user.id)

@router.get("/api/trainer/workouts")
async def get_workouts(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_workouts(current_user.id)

@router.post("/api/trainer/workouts")
async def create_workout(
    workout: dict, 
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.create_workout(workout, current_user.id)

@router.put("/api/trainer/workouts/{workout_id}")
async def update_workout(
    workout_id: str,
    workout: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.update_workout(workout_id, workout, current_user.id)

@router.post("/api/trainer/assign_workout")
async def assign_workout(
    assignment: dict, 
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.assign_workout(assignment)

@router.post("/api/trainer/diet")
async def update_diet(
    diet_data: dict, 
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    # Expects { "client_id": "...", "macros": {...}, "hydration_target": 2500, "consistency_target": 80 }
    client_id = diet_data.get("client_id")
    if not client_id:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Missing client_id")
    return service.update_client_diet(client_id, diet_data)

@router.post("/api/trainer/assign_diet")
async def assign_diet(
    diet_req: AssignDietRequest, 
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.assign_diet(diet_req)

@router.get("/api/trainer/splits")
async def get_splits(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_splits(current_user.id)

@router.post("/api/trainer/splits")
async def create_split(
    split_data: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.create_split(split_data, current_user.id)

@router.post("/api/trainer/assign_split")
async def assign_split(
    assignment: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.assign_split(assignment, current_user.id)

@router.put("/api/trainer/splits/{split_id}")
async def update_split(
    split_id: str,
    split_data: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.update_split(split_id, split_data, current_user.id)

@router.delete("/api/trainer/splits/{split_id}")
async def delete_split(
    split_id: str,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.delete_split(split_id, current_user.id)



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
