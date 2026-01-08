from fastapi import APIRouter, Depends, Header
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment, ExerciseTemplate
from services import GymService, UserService, LeaderboardService

router = APIRouter()

# --- DEPENDENCIES ---
def get_gym_service() -> GymService:
    return GymService()

def get_user_service() -> UserService:
    return UserService()

def get_leaderboard_service() -> LeaderboardService:
    return LeaderboardService()

# --- ROUTES ---
@router.get("/api/config/{gym_id}", response_model=GymConfig)
async def get_gym_config(gym_id: str, service: GymService = Depends(get_gym_service)):
    return service.get_gym(gym_id)

@router.get("/api/client/data", response_model=ClientData)
async def get_client_data(service: UserService = Depends(get_user_service)):
    return service.get_client()

@router.get("/api/trainer/data", response_model=TrainerData)
async def get_trainer_data(service: UserService = Depends(get_user_service)):
    return service.get_trainer()

@router.get("/api/owner/data", response_model=OwnerData)
async def get_owner_data(service: UserService = Depends(get_user_service)):
    return service.get_owner()

@router.get("/api/leaderboard/data", response_model=LeaderboardData)
async def get_leaderboard_data(service: LeaderboardService = Depends(get_leaderboard_service)):
    return service.get_leaderboard()



@router.get("/api/trainer/exercises")
async def get_exercises(
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.get_exercises(trainer_id)

@router.post("/api/trainer/exercises")
async def create_exercise(
    exercise: ExerciseTemplate, 
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    # Convert Pydantic model to dict for service layer
    return service.create_exercise(exercise.model_dump(), trainer_id)

@router.put("/api/trainer/exercises/{exercise_id}")
async def update_exercise(
    exercise_id: str,
    exercise: ExerciseTemplate,
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.update_exercise(exercise_id, exercise.model_dump(exclude_unset=True), trainer_id)

@router.get("/api/trainer/workouts")
async def get_workouts(
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.get_workouts(trainer_id)

@router.post("/api/trainer/workouts")
async def create_workout(
    workout: dict, 
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.create_workout(workout, trainer_id)

@router.post("/api/trainer/assign_workout")
async def assign_workout(assignment: dict, service: UserService = Depends(get_user_service)):
    return service.assign_workout(assignment)

from fastapi import File, UploadFile
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
