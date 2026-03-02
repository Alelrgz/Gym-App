"""
Client Import Routes - CSV upload endpoint for bulk client creation.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from auth import get_current_user
from models_orm import UserORM
from service_modules.client_import_service import get_client_import_service, ClientImportService
import logging

logger = logging.getLogger("gym_app")

router = APIRouter(tags=["Client Import"])

MAX_CSV_SIZE = 5 * 1024 * 1024  # 5MB


@router.post("/api/owner/import-clients")
async def import_clients_csv(
    file: UploadFile = File(...),
    user: UserORM = Depends(get_current_user),
    service: ClientImportService = Depends(get_client_import_service)
):
    """Import clients from CSV file. Owner only."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can import clients")

    if not file.filename or not file.filename.lower().endswith('.csv'):
        raise HTTPException(status_code=400, detail="Only .csv files are accepted")

    content = await file.read()
    if len(content) > MAX_CSV_SIZE:
        raise HTTPException(status_code=400, detail="File too large. Maximum 5MB.")
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="File is empty")

    result = service.process_csv(content, owner_id=user.id)

    logger.info(
        f"Client import by owner {user.id}: "
        f"{result['created']} created, {result['skipped']} skipped, "
        f"{len(result['errors'])} errors"
    )

    return {
        "success": True,
        "created": result["created"],
        "skipped": result["skipped"],
        "errors": result["errors"],
        "created_clients": result["created_clients"]
    }
