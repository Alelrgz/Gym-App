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

    # Get gym code for WhatsApp invite links
    from models_orm import GymORM
    from database import get_db_session as _get_db
    _db = _get_db()
    try:
        gym = _db.query(GymORM).filter(GymORM.owner_id == user.id).first()
        gym_code = gym.gym_code if gym else ""
        gym_name = gym.name if gym and gym.name else user.username
    finally:
        _db.close()

    # Build WhatsApp links for each created client with a phone number
    import urllib.parse
    for client in result["created_clients"]:
        phone = client.get("phone", "")
        if phone:
            msg = (
                f"Ciao {client['name']}! Benvenuto/a in {gym_name}.\n"
                f"Le tue credenziali FitOS:\n"
                f"Username: {client['username']}\n"
                f"Password: {client['temp_password']}\n"
                f"Scarica l'app: https://fitos-eu.onrender.com/join/{gym_code}"
            )
            # Clean phone: remove spaces, dashes, ensure +39 prefix for Italian numbers
            clean_phone = phone.replace(" ", "").replace("-", "").replace(".", "")
            if clean_phone.startswith("3") and len(clean_phone) == 10:
                clean_phone = "39" + clean_phone  # Italian mobile
            elif clean_phone.startswith("+"):
                clean_phone = clean_phone[1:]
            client["whatsapp_url"] = f"https://wa.me/{clean_phone}?text={urllib.parse.quote(msg)}"

    return {
        "success": True,
        "platform_detected": result.get("platform_detected"),
        "fields_mapped": result.get("fields_mapped", []),
        "fields_unmapped": result.get("fields_unmapped", []),
        "created": result["created"],
        "skipped": result["skipped"],
        "errors": result["errors"],
        "created_clients": result["created_clients"],
        "gym_code": gym_code,
    }
