from fastapi import APIRouter, Depends, Header
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment, ExerciseTemplate, AssignDietRequest
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

@router.get("/api/client/schedule")
async def get_client_schedule(
    date: str = None, 
    service: UserService = Depends(get_user_service)
):
    return service.get_client_schedule(date)

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
    service: UserService = Depends(get_user_service)
):
    # payload: { "date": "YYYY-MM-DD", "item_id": "..." }
    return service.complete_schedule_item(payload)

@router.put("/api/client/schedule/complete")
async def update_completed_workout(
    payload: dict,
    service: UserService = Depends(get_user_service)
):
    return service.update_completed_workout(payload)

from models import ClientProfileUpdate
@router.put("/api/client/profile")
async def update_client_profile(
    profile_update: ClientProfileUpdate,
    service: UserService = Depends(get_user_service)
):
    return service.update_client_profile(profile_update)

@router.get("/api/trainer/data", response_model=TrainerData)
async def get_trainer_data(service: UserService = Depends(get_user_service)):
    return service.get_trainer()

@router.get("/api/trainer/client/{client_id}", response_model=ClientData)
async def get_client_for_trainer(client_id: str, service: UserService = Depends(get_user_service)):
    return service.get_client(client_id)

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

@router.put("/api/trainer/workouts/{workout_id}")
async def update_workout(
    workout_id: str,
    workout: dict,
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.update_workout(workout_id, workout, trainer_id)

@router.post("/api/trainer/assign_workout")
async def assign_workout(assignment: dict, service: UserService = Depends(get_user_service)):
    return service.assign_workout(assignment)

@router.post("/api/trainer/diet")
async def update_diet(diet_data: dict, service: UserService = Depends(get_user_service)):
    # Expects { "client_id": "...", "macros": {...}, "hydration_target": 2500, "consistency_target": 80 }
    client_id = diet_data.get("client_id")
    if not client_id:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Missing client_id")
    return service.update_client_diet(client_id, diet_data)

@router.post("/api/trainer/assign_diet")
async def assign_diet(diet_req: AssignDietRequest, service: UserService = Depends(get_user_service)):
    return service.assign_diet(diet_req)

@router.get("/api/trainer/splits")
async def get_splits(
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.get_splits(trainer_id)

@router.post("/api/trainer/splits")
async def create_split(
    split_data: dict,
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.create_split(split_data, trainer_id)

@router.post("/api/trainer/assign_split")
async def assign_split(
    assignment: dict,
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.assign_split(assignment, trainer_id)

@router.put("/api/trainer/splits/{split_id}")
async def update_split(
    split_id: str,
    split_data: dict,
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.update_split(split_id, split_data, trainer_id)

@router.delete("/api/trainer/splits/{split_id}")
async def delete_split(
    split_id: str,
    service: UserService = Depends(get_user_service),
    trainer_id: str = Header("trainer_default", alias="x-trainer-id")
):
    return service.delete_split(split_id, trainer_id)


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
