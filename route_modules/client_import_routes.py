"""
Client Import Routes - CSV/Excel upload endpoint for bulk client creation.
Supports automatic platform detection from Golee, BookyWay, Gymdesk, etc.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from auth import get_current_user
from models_orm import UserORM
from service_modules.client_import_service import get_client_import_service, ClientImportService
import logging

logger = logging.getLogger("gym_app")

router = APIRouter(tags=["Client Import"])

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
ALLOWED_EXTENSIONS = ('.csv', '.xlsx', '.xls')


@router.post("/api/owner/import-clients")
async def import_clients_csv(
    file: UploadFile = File(...),
    user: UserORM = Depends(get_current_user),
    service: ClientImportService = Depends(get_client_import_service)
):
    """Import clients from CSV or Excel file. Owner only.
    Auto-detects source platform (Golee, BookyWay, Gymdesk, etc.)."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can import clients")

    filename = (file.filename or '').lower()
    if not any(filename.endswith(ext) for ext in ALLOWED_EXTENSIONS):
        raise HTTPException(status_code=400, detail="Formati accettati: CSV, XLSX, XLS")

    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="File troppo grande. Massimo 10MB.")
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Il file è vuoto")

    # Convert Excel to CSV in memory if needed
    if filename.endswith('.xlsx') or filename.endswith('.xls'):
        try:
            import openpyxl
            import io
            wb = openpyxl.load_workbook(io.BytesIO(content), read_only=True)
            ws = wb.active
            output = io.StringIO()
            import csv
            writer = csv.writer(output)
            for row in ws.iter_rows(values_only=True):
                writer.writerow([str(cell) if cell is not None else '' for cell in row])
            content = output.getvalue().encode('utf-8')
            wb.close()
        except ImportError:
            raise HTTPException(status_code=400, detail="Formato Excel non supportato su questo server. Converti in CSV.")
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Errore lettura Excel: {str(e)}")

    result = service.process_csv(content, owner_id=user.id)

    logger.info(
        f"Client import by owner {user.id} (platform: {result.get('platform_detected', '?')}): "
        f"{result['created']} created, {result['skipped']} skipped, "
        f"{len(result['errors'])} errors"
    )

    return {
        "success": True,
        "platform_detected": result.get("platform_detected"),
        "fields_mapped": result.get("fields_mapped", []),
        "fields_unmapped": result.get("fields_unmapped", []),
        "created": result["created"],
        "skipped": result["skipped"],
        "errors": result["errors"],
        "created_clients": result["created_clients"]
    }
