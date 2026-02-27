"""
NFC Shower Timer System — Device API, Staff Management, and Owner Settings
"""

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from database import get_db_session
from models_orm import UserORM, NfcTagORM, ShowerUsageORM, ClientProfileORM, CheckInORM
from auth import get_current_user
from fastapi.responses import PlainTextResponse
from datetime import datetime, date
import uuid as uuid_mod
import hashlib
import time
import logging

logger = logging.getLogger("gym_app")

router = APIRouter(tags=["shower"])


def get_db():
    db = get_db_session()
    try:
        yield db
    finally:
        db.close()


def _get_device_owner(request: Request, db: Session):
    """Authenticate ESP32 device via X-Device-Key header. Returns the gym owner."""
    api_key = request.headers.get("X-Device-Key")
    if not api_key:
        raise HTTPException(status_code=401, detail="Missing X-Device-Key header")

    owner = db.query(UserORM).filter(
        UserORM.device_api_key == api_key,
        UserORM.role == "owner"
    ).first()

    if not owner:
        raise HTTPException(status_code=401, detail="Invalid device API key")

    return owner


# ==================== DEVICE API (ESP32-facing) ====================

@router.post("/api/device/nfc-validate")
async def validate_nfc_tag(request: Request, data: dict, db: Session = Depends(get_db)):
    """ESP32 sends NFC UID to validate member and get shower timer."""
    owner = _get_device_owner(request, db)

    nfc_uid = (data.get("nfc_uid") or "").strip().upper()
    shower_id = data.get("shower_id", "default")

    if not nfc_uid:
        raise HTTPException(status_code=400, detail="nfc_uid required")

    # Look up tag
    tag = db.query(NfcTagORM).filter(
        NfcTagORM.nfc_uid == nfc_uid,
        NfcTagORM.gym_owner_id == owner.id,
        NfcTagORM.is_active == True
    ).first()

    if not tag:
        return {"access": False, "reason": "unregistered", "message": "Tag not registered"}

    # Look up member
    member = db.query(UserORM).filter(UserORM.id == tag.member_id).first()
    if not member or not member.is_active:
        return {"access": False, "reason": "inactive", "message": "Member inactive"}

    # Get display name
    member_name = member.username
    profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == tag.member_id).first()
    if profile and profile.name:
        member_name = profile.name

    # Check daily limit
    daily_limit = owner.shower_daily_limit or 3
    today_str = date.today().isoformat()

    today_count = db.query(ShowerUsageORM).filter(
        ShowerUsageORM.member_id == tag.member_id,
        ShowerUsageORM.gym_owner_id == owner.id,
        ShowerUsageORM.started_at.like(f"{today_str}%")
    ).count()

    if today_count >= daily_limit:
        return {
            "access": False,
            "reason": "daily_limit",
            "message": f"Daily limit reached ({daily_limit})",
            "member_name": member_name
        }

    # Grant access
    timer_minutes = owner.shower_timer_minutes or 8
    timer_seconds = timer_minutes * 60

    # Create usage record (started, not yet completed)
    usage = ShowerUsageORM(
        nfc_tag_id=tag.id,
        member_id=tag.member_id,
        gym_owner_id=owner.id,
        shower_id=shower_id,
        started_at=datetime.utcnow().isoformat(),
        timer_seconds=timer_seconds,
        completed=False
    )
    db.add(usage)
    db.commit()

    remaining = daily_limit - today_count - 1

    logger.info(f"Shower access granted: {member_name} (tag {nfc_uid}, {timer_seconds}s, {remaining} remaining)")

    return {
        "access": True,
        "timer_seconds": timer_seconds,
        "member_name": member_name,
        "remaining_sessions": remaining,
        "session_id": usage.id
    }


@router.post("/api/device/shower-complete")
async def shower_session_complete(request: Request, data: dict, db: Session = Depends(get_db)):
    """ESP32 reports shower session completion."""
    owner = _get_device_owner(request, db)

    session_id = data.get("session_id")
    duration_seconds = data.get("duration_seconds", 0)

    if not session_id:
        raise HTTPException(status_code=400, detail="session_id required")

    usage = db.query(ShowerUsageORM).filter(
        ShowerUsageORM.id == session_id,
        ShowerUsageORM.gym_owner_id == owner.id
    ).first()

    if not usage:
        raise HTTPException(status_code=404, detail="Session not found")

    usage.completed = True
    usage.duration_seconds = int(duration_seconds)
    usage.ended_at = datetime.utcnow().isoformat()
    db.commit()

    logger.info(f"Shower session {session_id} completed: {duration_seconds}s")

    return {"status": "logged", "session_id": session_id}


@router.get("/api/device/ping")
async def device_ping(request: Request):
    """Device health check for ESP32 boot sequence."""
    return {"status": "ok", "server_time": datetime.utcnow().isoformat()}


# ==================== TURNSTILE/QR DEVICE API ====================

_ACCESS_SECRET = "gym-turnstile-access-2024"


@router.post("/api/device/turnstile-verify")
async def turnstile_verify(request: Request, data: dict, db: Session = Depends(get_db)):
    """Pi sends raw QR data; server verifies HMAC, checks membership, logs check-in."""
    owner = _get_device_owner(request, db)

    qr_data = (data.get("qr_data") or "").strip()
    if not qr_data:
        return {"access": False, "reason": "empty_qr", "member_name": None, "gate_seconds": 0}

    # Parse QR format: GYMACCESS + 32-char user_id (UUID without dashes) + 12-char token
    if not qr_data.startswith("GYMACCESS") or len(qr_data) != 9 + 32 + 12:
        return {"access": False, "reason": "invalid_format", "member_name": None, "gate_seconds": 0}

    hex_user_id = qr_data[9:41]
    token = qr_data[41:53]

    # Reconstruct UUID with dashes
    try:
        user_id = f"{hex_user_id[:8]}-{hex_user_id[8:12]}-{hex_user_id[12:16]}-{hex_user_id[16:20]}-{hex_user_id[20:]}"
    except Exception:
        return {"access": False, "reason": "invalid_user_id", "member_name": None, "gate_seconds": 0}

    # Verify HMAC: check current and previous 30-second window
    current_window = int(time.time() // 30)
    token_valid = False
    for window in [current_window, current_window - 1]:
        raw = f"{user_id}:{window}:{_ACCESS_SECRET}"
        expected = hashlib.sha256(raw.encode()).hexdigest()[:12]
        if token == expected:
            token_valid = True
            break

    if not token_valid:
        return {"access": False, "reason": "token_expired", "member_name": None, "gate_seconds": 0}

    # Look up member — must belong to this gym
    member = db.query(UserORM).filter(
        UserORM.id == user_id,
        UserORM.gym_owner_id == owner.id,
        UserORM.role == "client",
        UserORM.is_active == True
    ).first()

    if not member:
        return {"access": False, "reason": "not_member", "member_name": None, "gate_seconds": 0}

    # Get display name
    member_name = member.username
    profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user_id).first()
    if profile and profile.name:
        member_name = profile.name

    gate_seconds = owner.turnstile_gate_seconds or 5

    # Create check-in if not already checked in today
    today_str = date.today().isoformat()
    already_today = db.query(CheckInORM).filter(
        CheckInORM.member_id == user_id,
        CheckInORM.gym_owner_id == owner.id,
        CheckInORM.checked_in_at.like(f"{today_str}%")
    ).first()

    if not already_today:
        checkin = CheckInORM(
            member_id=user_id,
            staff_id=None,
            gym_owner_id=owner.id,
            checked_in_at=datetime.utcnow().isoformat(),
            notes="Turnstile QR scan"
        )
        db.add(checkin)
        db.commit()

    logger.info(f"Turnstile access granted: {member_name} (user {user_id}, gate {gate_seconds}s)")

    return {
        "access": True,
        "member_name": member_name,
        "gate_seconds": gate_seconds,
        "reason": "ok"
    }


@router.get("/api/device/pi-setup")
async def pi_setup_script(request: Request):
    """Returns the bash install script for Raspberry Pi turnstile setup."""
    scheme = request.headers.get("x-forwarded-proto", "http")
    host = request.headers.get("host", "localhost:9008")
    server_url = f"{scheme}://{host}"

    script = f"""#!/bin/bash
# ===================================================
# Raspberry Pi Turnstile Scanner — Auto-Install Script
# Generated by Gym App Server
# ===================================================
set -e

SERVER_URL=""
DEVICE_KEY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --server) SERVER_URL="$2"; shift 2;;
        --key) DEVICE_KEY="$2"; shift 2;;
        *) echo "Unknown option: $1"; exit 1;;
    esac
done

if [ -z "$SERVER_URL" ] || [ -z "$DEVICE_KEY" ]; then
    echo "Usage: curl -sSL {server_url}/api/device/pi-setup | bash -s -- --server URL --key KEY"
    exit 1
fi

echo "=== Gym Turnstile Scanner Setup ==="
echo "Server: $SERVER_URL"
echo ""

# 1. System dependencies
echo "[1/5] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq python3-pip python3-venv libzbar0 libopencv-dev v4l-utils

# 2. Create app directory
APP_DIR="/opt/gym-turnstile"
echo "[2/5] Setting up $APP_DIR ..."
sudo mkdir -p "$APP_DIR"
sudo chown $USER:$USER "$APP_DIR"

# 3. Python virtual environment + dependencies
echo "[3/5] Creating Python environment..."
python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install --quiet opencv-python-headless pyzbar requests RPi.GPIO 2>/dev/null || \\
"$APP_DIR/venv/bin/pip" install --quiet opencv-python-headless pyzbar requests

# 4. Download scanner script & write config
echo "[4/5] Downloading scanner script..."
curl -sSL "$SERVER_URL/static/pi/turnstile_scanner.py" -o "$APP_DIR/turnstile_scanner.py"

cat > "$APP_DIR/config.json" <<CONF
{{{{
    "server_url": "$SERVER_URL",
    "device_api_key": "$DEVICE_KEY",
    "relay_pin": 17,
    "green_led_pin": 27,
    "red_led_pin": 22,
    "buzzer_pin": 23,
    "camera_index": 0
}}}}
CONF

# 5. Systemd service
echo "[5/5] Installing systemd service..."
sudo tee /etc/systemd/system/gym-turnstile.service > /dev/null <<SVC
[Unit]
Description=Gym Turnstile QR Scanner
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python $APP_DIR/turnstile_scanner.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
SVC

sudo systemctl daemon-reload
sudo systemctl enable gym-turnstile.service
sudo systemctl start gym-turnstile.service

echo ""
echo "=== Setup Complete ==="
echo "Scanner is now running as a system service."
echo "  Status:  sudo systemctl status gym-turnstile"
echo "  Logs:    sudo journalctl -u gym-turnstile -f"
echo "  Restart: sudo systemctl restart gym-turnstile"
"""

    return PlainTextResponse(content=script, media_type="text/plain")


# ==================== STAFF API ====================

@router.post("/api/staff/register-nfc")
async def register_nfc_tag(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Register an NFC tag to a member."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff access only")

    gym_owner_id = user.gym_owner_id if user.role == "staff" else user.id

    nfc_uid = (data.get("nfc_uid") or "").strip().upper()
    member_id = data.get("member_id")
    label = (data.get("label") or "").strip()

    if not nfc_uid or not member_id:
        raise HTTPException(status_code=400, detail="nfc_uid and member_id required")

    # Verify member belongs to same gym
    member = db.query(UserORM).filter(
        UserORM.id == member_id,
        UserORM.gym_owner_id == gym_owner_id,
        UserORM.role == "client"
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    # Check if UID already registered
    existing = db.query(NfcTagORM).filter(NfcTagORM.nfc_uid == nfc_uid).first()
    if existing:
        if existing.is_active:
            raise HTTPException(status_code=400, detail="This NFC tag is already registered")
        # Reactivate if previously deactivated
        existing.member_id = member_id
        existing.gym_owner_id = gym_owner_id
        existing.registered_by = user.id
        existing.label = label or None
        existing.is_active = True
        existing.registered_at = datetime.utcnow().isoformat()
        db.commit()
        logger.info(f"NFC tag {nfc_uid} reactivated for member {member_id} by {user.id}")
        return {"status": "success", "tag_id": existing.id, "message": f"NFC tag registered to {member.username}"}

    tag = NfcTagORM(
        nfc_uid=nfc_uid,
        member_id=member_id,
        gym_owner_id=gym_owner_id,
        registered_by=user.id,
        label=label or None,
        registered_at=datetime.utcnow().isoformat()
    )
    db.add(tag)
    db.commit()

    logger.info(f"NFC tag {nfc_uid} registered to member {member_id} by {user.id}")

    return {"status": "success", "tag_id": tag.id, "message": f"NFC tag registered to {member.username}"}


@router.delete("/api/staff/unregister-nfc/{tag_id}")
async def unregister_nfc_tag(
    tag_id: int,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Unregister (deactivate) an NFC tag."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff access only")

    gym_owner_id = user.gym_owner_id if user.role == "staff" else user.id

    tag = db.query(NfcTagORM).filter(
        NfcTagORM.id == tag_id,
        NfcTagORM.gym_owner_id == gym_owner_id
    ).first()
    if not tag:
        raise HTTPException(status_code=404, detail="Tag not found")

    tag.is_active = False
    db.commit()

    logger.info(f"NFC tag {tag.nfc_uid} unregistered by {user.id}")

    return {"status": "success", "message": "NFC tag unregistered"}


@router.get("/api/staff/nfc-tags")
async def list_nfc_tags(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List all registered NFC tags for the gym."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff access only")

    gym_owner_id = user.gym_owner_id if user.role == "staff" else user.id

    tags = db.query(NfcTagORM).filter(
        NfcTagORM.gym_owner_id == gym_owner_id,
        NfcTagORM.is_active == True
    ).order_by(NfcTagORM.registered_at.desc()).all()

    result = []
    for tag in tags:
        member = db.query(UserORM).filter(UserORM.id == tag.member_id).first()
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == tag.member_id).first()
        member_name = (profile.name if profile and profile.name else member.username) if member else "Unknown"

        result.append({
            "id": tag.id,
            "nfc_uid": tag.nfc_uid,
            "member_id": tag.member_id,
            "member_name": member_name,
            "label": tag.label,
            "registered_at": tag.registered_at
        })

    return result


@router.get("/api/staff/shower-usage")
async def get_shower_usage(
    day: str = None,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get shower usage logs for a day (defaults to today)."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff access only")

    gym_owner_id = user.gym_owner_id if user.role == "staff" else user.id
    target_day = day or date.today().isoformat()

    usages = db.query(ShowerUsageORM).filter(
        ShowerUsageORM.gym_owner_id == gym_owner_id,
        ShowerUsageORM.started_at.like(f"{target_day}%")
    ).order_by(ShowerUsageORM.started_at.desc()).all()

    result = []
    for u in usages:
        member = db.query(UserORM).filter(UserORM.id == u.member_id).first()
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == u.member_id).first()
        member_name = (profile.name if profile and profile.name else member.username) if member else "Unknown"

        time_str = ""
        if u.started_at and "T" in u.started_at:
            time_str = u.started_at.split("T")[1][:5]

        result.append({
            "id": u.id,
            "member_name": member_name,
            "started_at": u.started_at,
            "time": time_str,
            "duration_seconds": u.duration_seconds,
            "timer_seconds": u.timer_seconds,
            "completed": u.completed,
            "shower_id": u.shower_id
        })

    return {"date": target_day, "count": len(result), "usages": result}


# ==================== OWNER API ====================

@router.get("/api/owner/shower-settings")
async def get_shower_settings(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get shower timer settings."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    return {
        "shower_timer_minutes": user.shower_timer_minutes or 8,
        "shower_daily_limit": user.shower_daily_limit or 3,
        "device_api_key": user.device_api_key,
        "turnstile_gate_seconds": user.turnstile_gate_seconds or 5
    }


@router.put("/api/owner/shower-settings")
async def update_shower_settings(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update shower timer settings."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    timer_minutes = data.get("shower_timer_minutes")
    daily_limit = data.get("shower_daily_limit")
    gate_seconds = data.get("turnstile_gate_seconds")

    if timer_minutes is not None:
        user.shower_timer_minutes = max(1, min(30, int(timer_minutes)))

    if daily_limit is not None:
        user.shower_daily_limit = max(1, min(20, int(daily_limit)))

    if gate_seconds is not None:
        user.turnstile_gate_seconds = max(2, min(15, int(gate_seconds)))

    db.commit()

    return {
        "status": "success",
        "shower_timer_minutes": user.shower_timer_minutes or 8,
        "shower_daily_limit": user.shower_daily_limit or 3,
        "turnstile_gate_seconds": user.turnstile_gate_seconds or 5
    }


@router.post("/api/owner/generate-device-key")
async def generate_device_key(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Generate or regenerate device API key for ESP32 devices."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    new_key = str(uuid_mod.uuid4())
    user.device_api_key = new_key
    db.commit()

    logger.info(f"Owner {user.id} generated new device API key")

    return {"status": "success", "device_api_key": new_key}
