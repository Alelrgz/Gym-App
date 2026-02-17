"""
Nutritionist Routes - API endpoints for nutritionist dashboard and client body management.
"""
from fastapi import APIRouter, Depends, HTTPException
from auth import get_current_user
from models import AddBodyCompositionRequest, SetWeightGoalRequest, AssignDietRequest, UpdateClientHealthDataRequest
from models_orm import UserORM
from service_modules.nutritionist_service import NutritionistService, get_nutritionist_service
from service_modules.diet_service import DietService, get_diet_service
from service_modules.client_service import ClientService, get_client_service

router = APIRouter()


def _require_nutritionist(user: UserORM):
    if user.role != "nutritionist":
        raise HTTPException(status_code=403, detail="Only nutritionists can access this endpoint")


# ==================== DASHBOARD ====================

@router.get("/api/nutritionist/data")
async def get_nutritionist_data(
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.get_nutritionist(current_user.id)


@router.get("/api/nutritionist/client/{client_id}")
async def get_client_detail(
    client_id: str,
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.get_client_detail(client_id)


# ==================== BODY COMPOSITION ====================

@router.post("/api/nutritionist/client/body-composition")
async def add_body_composition(
    request: AddBodyCompositionRequest,
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.add_body_composition(
        current_user.id, request.client_id,
        request.weight, request.body_fat_pct,
        request.fat_mass, request.lean_mass
    )


@router.post("/api/nutritionist/client/weight-goal")
async def set_weight_goal(
    request: SetWeightGoalRequest,
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.set_weight_goal(current_user.id, request.client_id, request.weight_goal)


# ==================== HEALTH DATA ====================

@router.post("/api/nutritionist/client/health-data")
async def update_client_health_data(
    request: UpdateClientHealthDataRequest,
    service: NutritionistService = Depends(get_nutritionist_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.update_client_health_data(current_user.id, request)


# ==================== DIET ====================

@router.post("/api/nutritionist/assign_diet")
async def nutritionist_assign_diet(
    diet_req: AssignDietRequest,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.assign_diet(diet_req)


@router.post("/api/nutritionist/diet")
async def nutritionist_update_diet(
    diet_data: dict,
    service: DietService = Depends(get_diet_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    client_id = diet_data.get("client_id")
    if not client_id:
        raise HTTPException(status_code=400, detail="Missing client_id")
    return service.update_client_diet(client_id, diet_data)


# ==================== CLIENT CHART DATA ====================

@router.get("/api/nutritionist/client/{client_id}/weight-history")
async def get_client_weight_history(
    client_id: str,
    period: str = "month",
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.get_weight_history(client_id, period)


@router.get("/api/nutritionist/client/{client_id}/diet-consistency")
async def get_client_diet_consistency(
    client_id: str,
    period: str = "month",
    service: ClientService = Depends(get_client_service),
    current_user: UserORM = Depends(get_current_user)
):
    _require_nutritionist(current_user)
    return service.get_diet_consistency(client_id, period)
