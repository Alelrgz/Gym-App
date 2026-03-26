"""
Client Import Routes - CSV/Excel upload endpoint for bulk client creation.
Supports automatic platform detection from Golee, BookyWay, Gymdesk, etc.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from auth import get_current_user
from models_orm import UserORM
from service_modules.client_import_service import get_client_import_service, ClientImportService
from database import get_db as _get_db_dep
from sqlalchemy.orm import Session
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
        "can_bulk_send": True,
    }


@router.post("/api/owner/send-credentials-bulk")
async def send_credentials_bulk(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(_get_db_dep)
):
    """Send credentials to multiple clients at once via WhatsApp/email/SMS."""
    if user.role not in ("owner", "staff"):
        raise HTTPException(status_code=403, detail="Only owner/staff can send credentials")

    client_ids = data.get("client_ids", [])
    method = data.get("method", "whatsapp")
    base_url = data.get("base_url", "")

    if not client_ids:
        raise HTTPException(status_code=400, detail="No client IDs provided")

    from models_orm import ClientProfileORM, GymORM, MagicLoginTokenORM
    from datetime import datetime, timedelta
    import secrets as _sec, hashlib, hmac, os, uuid, urllib.parse, re

    gym = db.query(GymORM).filter(GymORM.owner_id == user.id).first()
    gym_code = gym.gym_code if gym else ""
    gym_name = gym.name if gym else user.username
    secret = os.environ.get("SECRET_KEY", "gym-secret-key-change-me")

    sent = 0
    failed = 0
    results = []

    for cid in client_ids:
        try:
            client = db.query(UserORM).filter(UserORM.id == cid).first()
            if not client:
                failed += 1
                continue

            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == cid).first()
            phone = getattr(client, 'phone', '') or ''
            client_name = (profile.name if profile else None) or client.username

            # Generate magic link
            raw_token = _sec.token_urlsafe(32)
            token_hash = hmac.new(secret.encode(), raw_token.encode(), hashlib.sha256).hexdigest()
            db.add(MagicLoginTokenORM(
                id=str(uuid.uuid4()),
                user_id=client.id,
                token_hash=token_hash,
                expires_at=(datetime.utcnow() + timedelta(hours=24)).isoformat(),
            ))

            magic_link = f"{base_url.rstrip('/')}/magic/{raw_token}" if base_url else ""

            msg = (
                f"Ciao {client_name}! Benvenuto/a in {gym_name}.\n"
                f"Le tue credenziali FitOS:\n"
                f"Username: {client.username}\n"
                f"Password: {client.username}\n"  # Default temp password = username
            )
            if magic_link:
                msg += f"\nAccedi direttamente:\n{magic_link}\n"
            if gym_code:
                msg += f"\nScarica l'app: {base_url.rstrip('/')}/join/{gym_code}"

            email = client.email or (profile.email if profile else None) or ""

            # Auto mode: prefer WhatsApp (phone) > email > skip
            effective_method = method
            if method == "auto":
                effective_method = "whatsapp" if phone else ("email" if email else "none")

            if effective_method == "whatsapp" and phone:
                clean_phone = re.sub(r'[\s\-\(\).]', '', phone)
                if clean_phone.startswith("3") and len(clean_phone) == 10:
                    clean_phone = "39" + clean_phone
                elif clean_phone.startswith("+"):
                    clean_phone = clean_phone[1:]
                elif clean_phone.startswith("0"):
                    clean_phone = "39" + clean_phone[1:]
                wa_url = f"https://wa.me/{clean_phone}?text={urllib.parse.quote(msg)}"
                results.append({"client_id": cid, "name": client_name, "method": "whatsapp", "whatsapp_url": wa_url})
                sent += 1
            elif effective_method == "email" and email:
                results.append({"client_id": cid, "name": client_name, "method": "email", "email": email})
                sent += 1
            else:
                results.append({"client_id": cid, "name": client_name, "method": "none", "reason": "no_contact_info"})
                failed += 1
        except Exception:
            failed += 1

    db.commit()
    return {"sent": sent, "failed": failed, "results": results}
