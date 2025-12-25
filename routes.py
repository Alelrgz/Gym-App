from fastapi import APIRouter, Depends
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment
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

@router.post("/api/trainer/assign_workout")
async def assign_workout(assignment: WorkoutAssignment, service: UserService = Depends(get_user_service)) -> dict:
    return service.assign_workout(assignment)
