"""
Gym Assignment Routes - API endpoints for clients to join gyms and select trainers
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from auth import get_current_user
from gym_context import get_gym_context
from service_modules.gym_assignment_service import get_gym_assignment_service, GymAssignmentService
from models import JoinGymRequest, SelectTrainerRequest
from models_orm import UserORM
from database import get_db_session
from pydantic import BaseModel
from typing import Optional
import os
from datetime import datetime

router = APIRouter()


# --- PUBLIC ENDPOINTS (no auth required) ---

@router.get("/api/public/gym/{gym_code}")
async def get_public_gym_info(gym_code: str):
    """Public endpoint to resolve a gym code to gym info. Used by magic join links."""
    from models_orm import GymORM
    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(GymORM.gym_code == gym_code.strip().upper()).first()
        if not gym:
            raise HTTPException(status_code=404, detail="Palestra non trovata")
        owner = db.query(UserORM).filter(UserORM.id == gym.owner_id).first()
        return {
            "gym_code": gym.gym_code,
            "gym_name": gym.name or (owner.username if owner else "Palestra"),
            "gym_logo": gym.logo,
            "owner_name": owner.username if owner else None,
        }
    finally:
        db.close()


@router.get("/api/public/gyms")
async def discover_gyms(
    lat: float = None,
    lng: float = None,
    q: str = None,
):
    """Public endpoint for gym discovery. Returns active gyms sorted by distance if location provided."""
    from models_orm import GymORM
    import math
    db = get_db_session()
    try:
        query = db.query(GymORM).filter(GymORM.is_active == True)

        if q:
            search = f"%{q.strip().lower()}%"
            query = query.filter(
                (GymORM.name.ilike(search)) | (GymORM.city.ilike(search))
            )

        gyms = query.limit(50).all()

        def _distance(gym):
            """Haversine distance in km."""
            if not lat or not lng or not gym.latitude or not gym.longitude:
                return None
            R = 6371
            dlat = math.radians(gym.latitude - lat)
            dlng = math.radians(gym.longitude - lng)
            a = math.sin(dlat/2)**2 + math.cos(math.radians(lat)) * math.cos(math.radians(gym.latitude)) * math.sin(dlng/2)**2
            return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

        result = []
        for gym in gyms:
            dist = _distance(gym)
            owner = db.query(UserORM).filter(UserORM.id == gym.owner_id).first()
            # Count members
            member_count = db.query(ClientProfileORM).filter(ClientProfileORM.gym_id == gym.owner_id).count()
            result.append({
                "id": gym.id,
                "name": gym.name or (owner.username if owner else "Palestra"),
                "logo": gym.logo,
                "gym_code": gym.gym_code,
                "address": gym.address,
                "city": gym.city,
                "latitude": gym.latitude,
                "longitude": gym.longitude,
                "distance_km": round(dist, 1) if dist is not None else None,
                "member_count": member_count,
            })

        # Sort by distance if location provided, otherwise by name
        if lat and lng:
            result.sort(key=lambda g: g['distance_km'] if g['distance_km'] is not None else 999999)
        else:
            result.sort(key=lambda g: (g['name'] or '').lower())

        return result
    finally:
        db.close()


# --- CLIENT ENDPOINTS ---

@router.post("/api/client/join-gym")
async def join_gym(
    request: JoinGymRequest,
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Join a gym using a gym code."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can join gyms")

    return service.join_gym(user.id, request.gym_code)


@router.get("/api/client/gym-info")
async def get_gym_info(
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get client's current gym and trainer information."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view gym info")

    return service.get_client_gym_info(user.id)


@router.get("/api/gym/{gym_id}/trainers")
async def get_gym_trainers(
    gym_id: str,
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get all trainers in a gym."""
    # Any authenticated user can view trainers
    return service.get_gym_trainers(gym_id)


@router.post("/api/client/select-trainer")
async def select_trainer(
    request: SelectTrainerRequest,
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Select a trainer for the client."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can select trainers")

    return service.select_trainer(user.id, request.trainer_id)


@router.post("/api/client/leave-gym")
async def leave_gym(
    user: UserORM = Depends(get_current_user),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Leave current gym and unassign trainer."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can leave gyms")

    return service.leave_gym(user.id)


# --- OWNER ENDPOINTS ---

@router.get("/api/owner/gym-code")
async def get_gym_code(
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get the gym code that trainers/clients can use to join."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view gym codes")

    from models_orm import GymORM
    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(GymORM.id == gym_id).first()
        gym_code = gym.gym_code if gym else (user.gym_code or service.generate_gym_code_for_owner(user.id))
        gym_name = gym.name if gym else (user.gym_name or "")
        gym_logo = gym.logo if gym else (user.gym_logo or "")
    finally:
        db.close()

    return {
        "gym_code": gym_code,
        "owner_name": user.username,
        "gym_name": gym_name,
        "gym_logo": gym_logo,
        "message": "Share this code with trainers and clients to let them join your gym"
    }


@router.get("/api/owner/pending-trainers")
async def get_pending_trainers(
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get list of trainers pending approval."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view pending trainers")

    return service.get_pending_trainers(gym_id)


@router.post("/api/owner/approve-trainer/{trainer_id}")
async def approve_trainer(
    trainer_id: str,
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Approve a trainer's registration."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can approve trainers")

    return service.approve_trainer(gym_id, trainer_id)


@router.post("/api/owner/reject-trainer/{trainer_id}")
async def reject_trainer(
    trainer_id: str,
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Reject a trainer's registration."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can reject trainers")

    return service.reject_trainer(gym_id, trainer_id)


@router.get("/api/owner/approved-trainers")
async def get_approved_trainers(
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get list of approved trainers for this gym."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view trainers")

    return service.get_approved_trainers(gym_id)


# --- GYM SETTINGS ENDPOINTS ---

class GymSettingsUpdate(BaseModel):
    gym_name: Optional[str] = None
    password: Optional[str] = None
    auto_approve_trainers: Optional[bool] = None
    auto_approve_staff: Optional[bool] = None
    welcome_message_template: Optional[str] = None


@router.get("/api/owner/gym-settings")
async def get_gym_settings(
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Get gym branding settings (name, logo)."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view gym settings")

    from models_orm import GymORM
    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(GymORM.id == gym_id).first()
        return {
            "gym_name": gym.name if gym else (user.gym_name or ""),
            "gym_logo": gym.logo if gym else (user.gym_logo or ""),
            "gym_code": gym.gym_code if gym else "",
            "device_api_key": user.device_api_key or "",
            "gate_duration": getattr(user, 'gate_duration', 5) or 5,
            "default_commission_rate": getattr(user, 'default_commission_rate', 0) or 0,
            "auto_approve_trainers": bool(gym.auto_approve_trainers) if gym else False,
            "auto_approve_staff": bool(gym.auto_approve_staff) if gym else False,
            "welcome_message_template": gym.welcome_message_template if gym else None,
            "join_link": f"https://fitos-eu.onrender.com/join/{gym.gym_code}" if gym and gym.gym_code else None,
        }
    finally:
        db.close()


@router.post("/api/owner/gym-settings")
async def update_gym_settings(
    request: GymSettingsUpdate,
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Update gym name (requires password confirmation)."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can update gym settings")

    # Require password for gym name changes
    if request.gym_name is not None:
        if not request.password:
            raise HTTPException(status_code=400, detail="Password required to change gym name")
        from simple_auth import verify_password
        if not verify_password(request.password, user.hashed_password):
            raise HTTPException(status_code=403, detail="Incorrect password")

    from models_orm import GymORM
    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(GymORM.id == gym_id, GymORM.owner_id == user.id).first()
        if gym and request.gym_name is not None:
            gym.name = request.gym_name.strip()
        if gym and request.auto_approve_trainers is not None:
            gym.auto_approve_trainers = request.auto_approve_trainers
        if gym and request.auto_approve_staff is not None:
            gym.auto_approve_staff = request.auto_approve_staff
        if gym and request.welcome_message_template is not None:
            gym.welcome_message_template = request.welcome_message_template.strip() or None
        # Also update legacy UserORM field if this is the primary gym
        if gym_id == user.id:
            db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
            if db_user and request.gym_name is not None:
                db_user.gym_name = request.gym_name.strip()
        db.commit()
        return {"success": True, "message": "Gym settings updated"}
    finally:
        db.close()


@router.post("/api/owner/gym-logo")
async def upload_gym_logo(
    file: UploadFile = File(...),
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Upload or update gym logo."""
    from service_modules.upload_helper import save_file, delete_file, _optimize_image, ALLOWED_IMAGE_EXTENSIONS, MAX_IMAGE_SIZE
    from models_orm import GymORM

    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can update gym logo")

    if not file.filename or '.' not in file.filename:
        raise HTTPException(status_code=400, detail="Invalid file")

    ext = file.filename.rsplit('.', 1)[1].lower()
    if ext not in ALLOWED_IMAGE_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Invalid file type. Allowed: {', '.join(ALLOWED_IMAGE_EXTENSIONS)}")

    content = await file.read()
    if len(content) > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=400, detail="File too large. Maximum 5MB")

    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(GymORM.id == gym_id, GymORM.owner_id == user.id).first()
        old_logo = gym.logo if gym else user.gym_logo
        if old_logo:
            await delete_file(old_logo)

        optimized, ext = _optimize_image(content, max_size=(400, 400), crop_square=False)
        filename = f"gym_logo_{gym_id}.{ext}"
        url = await save_file(optimized, "profiles", filename)

        if gym:
            gym.logo = url
        # Also update legacy UserORM field for primary gym
        if gym_id == user.id:
            db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
            if db_user:
                db_user.gym_logo = url
        db.commit()
    finally:
        db.close()

    cache_bust = f"?t={int(datetime.now().timestamp())}"
    return {
        "success": True,
        "gym_logo": url + cache_bust,
        "message": "Gym logo updated"
    }


@router.delete("/api/owner/gym-logo")
async def delete_gym_logo(
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Delete gym logo."""
    from service_modules.upload_helper import delete_file
    from models_orm import GymORM

    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can delete gym logo")

    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(GymORM.id == gym_id, GymORM.owner_id == user.id).first()
        old_logo = gym.logo if gym else user.gym_logo
        if old_logo:
            await delete_file(old_logo)
        if gym:
            gym.logo = None
        if gym_id == user.id:
            db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
            if db_user:
                db_user.gym_logo = None
        db.commit()
    finally:
        db.close()

    return {"success": True, "message": "Gym logo deleted"}


# --- COMMISSION ENDPOINTS ---

class CommissionRateRequest(BaseModel):
    commission_rate: float  # 0-100 percentage


@router.put("/api/owner/trainers/{trainer_id}/commission")
async def set_trainer_commission(
    trainer_id: str,
    body: CommissionRateRequest,
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Set the commission rate for a trainer."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can set commission rates")
    if not (0 <= body.commission_rate <= 100):
        raise HTTPException(status_code=400, detail="Commission rate must be between 0 and 100")

    db = get_db_session()
    try:
        trainer = db.query(UserORM).filter(
            UserORM.id == trainer_id,
            UserORM.gym_owner_id == gym_id,
            UserORM.role.in_(["trainer", "staff", "nutritionist"])
        ).first()
        if not trainer:
            raise HTTPException(status_code=404, detail="Trainer not found in your gym")
        trainer.commission_rate = body.commission_rate
        db.commit()
        return {"success": True, "commission_rate": body.commission_rate}
    finally:
        db.close()


@router.get("/api/owner/commissions")
async def get_trainer_commissions(
    period: str = "month",  # "month", "last_month", "year", "all"
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Get all trainers with their commission calculations."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view commissions")

    from models_orm import AppointmentORM, PaymentORM, ClientProfileORM
    from datetime import datetime, date
    db = get_db_session()
    try:
        # Date filter
        now = datetime.utcnow()
        if period == "month":
            start = now.replace(day=1, hour=0, minute=0, second=0).isoformat()
        elif period == "last_month":
            if now.month == 1:
                start = now.replace(year=now.year - 1, month=12, day=1, hour=0, minute=0, second=0).isoformat()
            else:
                start = now.replace(month=now.month - 1, day=1, hour=0, minute=0, second=0).isoformat()
            # end = first day of current month
            end_dt = now.replace(day=1, hour=0, minute=0, second=0)
        elif period == "year":
            start = now.replace(month=1, day=1, hour=0, minute=0, second=0).isoformat()
        else:
            start = None

        trainers = db.query(UserORM).filter(
            UserORM.gym_owner_id == gym_id,
            UserORM.role.in_(["trainer", "staff", "nutritionist"]),
            UserORM.is_approved == True
        ).all()

        result = []
        for trainer in trainers:
            # --- Appointment revenue (direct trainer link) ---
            # Filter by appointment date (when service was delivered), not created_at (when booked)
            appt_query = db.query(AppointmentORM).filter(
                AppointmentORM.trainer_id == trainer.id,
                AppointmentORM.payment_status == "paid"
            )
            if start:
                appt_query = appt_query.filter(AppointmentORM.date >= start[:10])
            if period == "last_month":
                appt_query = appt_query.filter(AppointmentORM.date < end_dt.strftime("%Y-%m-%d"))
            appts = appt_query.all()
            appt_revenue = sum((a.price or 0) for a in appts)
            appt_count = len(appts)

            # --- Subscription revenue (via clients assigned to this trainer) ---
            client_ids = [r[0] for r in db.query(ClientProfileORM.id).filter(
                ClientProfileORM.trainer_id == trainer.id
            ).all()]
            sub_revenue = 0.0
            sub_count = 0
            if client_ids:
                pay_query = db.query(PaymentORM).filter(
                    PaymentORM.client_id.in_(client_ids),
                    PaymentORM.gym_id == gym_id,
                    PaymentORM.status == "succeeded"
                )
                if start:
                    pay_query = pay_query.filter(PaymentORM.paid_at >= start)
                if period == "last_month":
                    pay_query = pay_query.filter(PaymentORM.paid_at < end_dt.isoformat())
                payments = pay_query.all()
                sub_revenue = sum((p.amount or 0) for p in payments)
                sub_count = len(payments)

            rate = trainer.commission_rate or 0.0
            total_revenue = appt_revenue + sub_revenue
            commission_due = round(total_revenue * rate / 100, 2)

            result.append({
                "id": trainer.id,
                "username": trainer.username,
                "role": trainer.role,
                "commission_rate": rate,
                "appt_revenue": round(appt_revenue, 2),
                "appt_count": appt_count,
                "sub_revenue": round(sub_revenue, 2),
                "sub_count": sub_count,
                "client_count": len(client_ids),
                "total_revenue": round(total_revenue, 2),
                "commission_due": commission_due,
            })

        return result
    finally:
        db.close()


@router.get("/api/trainer/my-commissions")
async def get_my_commissions(
    period: str = "month",  # "month", "last_month", "year", "all"
    user: UserORM = Depends(get_current_user)
):
    """Get a trainer's own commission/earnings data."""
    if user.role not in ("trainer", "staff", "nutritionist"):
        raise HTTPException(status_code=403, detail="Only trainers/staff can view their commissions")

    from models_orm import AppointmentORM, PaymentORM, ClientProfileORM
    from datetime import datetime
    db = get_db_session()
    try:
        now = datetime.utcnow()
        end_dt = None
        if period == "month":
            start = now.replace(day=1, hour=0, minute=0, second=0).isoformat()
        elif period == "last_month":
            if now.month == 1:
                start = now.replace(year=now.year - 1, month=12, day=1, hour=0, minute=0, second=0).isoformat()
            else:
                start = now.replace(month=now.month - 1, day=1, hour=0, minute=0, second=0).isoformat()
            end_dt = now.replace(day=1, hour=0, minute=0, second=0)
        elif period == "year":
            start = now.replace(month=1, day=1, hour=0, minute=0, second=0).isoformat()
        else:
            start = None

        # Appointment revenue (filter by appointment date, not created_at)
        appt_query = db.query(AppointmentORM).filter(
            AppointmentORM.trainer_id == user.id,
            AppointmentORM.payment_status == "paid"
        )
        if start:
            start_date = start[:10]  # YYYY-MM-DD
            appt_query = appt_query.filter(AppointmentORM.date >= start_date)
        if end_dt:
            appt_query = appt_query.filter(AppointmentORM.date < end_dt.strftime("%Y-%m-%d"))
        appts = appt_query.all()
        appt_revenue = sum((a.price or 0) for a in appts)
        appt_count = len(appts)

        # Subscription revenue via assigned clients
        client_ids = [r[0] for r in db.query(ClientProfileORM.id).filter(
            ClientProfileORM.trainer_id == user.id
        ).all()]
        sub_revenue = 0.0
        sub_count = 0
        if client_ids and user.gym_owner_id:
            pay_query = db.query(PaymentORM).filter(
                PaymentORM.client_id.in_(client_ids),
                PaymentORM.gym_id == user.gym_owner_id,
                PaymentORM.status == "succeeded"
            )
            if start:
                pay_query = pay_query.filter(PaymentORM.paid_at >= start)
            if end_dt:
                pay_query = pay_query.filter(PaymentORM.paid_at < end_dt.isoformat())
            payments = pay_query.all()
            sub_revenue = sum((p.amount or 0) for p in payments)
            sub_count = len(payments)

        rate = user.commission_rate or 0.0
        total_revenue = appt_revenue + sub_revenue
        commission_due = round(total_revenue * rate / 100, 2)

        return {
            "commission_rate": rate,
            "appt_revenue": round(appt_revenue, 2),
            "appt_count": appt_count,
            "sub_revenue": round(sub_revenue, 2),
            "sub_count": sub_count,
            "total_revenue": round(total_revenue, 2),
            "commission_due": commission_due,
            "period": period,
        }
    finally:
        db.close()


# ═══════════════════════════════════════════════════════════
#  OWNER ONBOARDING — SETUP WIZARD & CHECKLIST
# ═══════════════════════════════════════════════════════════

@router.get("/api/owner/onboarding-status")
async def get_onboarding_status(
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Get owner's setup completion checklist."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner only")

    from models_orm import GymORM, SubscriptionPlanORM
    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(GymORM.id == gym_id).first()
        plans = db.query(SubscriptionPlanORM).filter(
            SubscriptionPlanORM.gym_id == gym_id,
            SubscriptionPlanORM.is_active == True
        ).count()
        members = db.query(UserORM).filter(
            UserORM.gym_owner_id == gym_id,
            UserORM.role == "client",
            UserORM.is_active == True
        ).count()
        staff = db.query(UserORM).filter(
            UserORM.gym_owner_id == gym_id,
            UserORM.role == "owner",
            UserORM.sub_role == "staff",
            UserORM.is_active == True
        ).count()
        trainers = db.query(UserORM).filter(
            UserORM.gym_owner_id == gym_id,
            UserORM.role == "trainer",
            UserORM.is_approved == True,
            UserORM.is_active == True
        ).count()

        has_logo = bool(gym and gym.logo)
        has_name = bool(gym and gym.name and gym.name != f"{user.username}'s Gym")
        has_plans = plans > 0
        has_stripe = bool(gym and gym.stripe_account_id and gym.stripe_account_status == "active")
        has_members = members > 0
        has_staff = staff > 0 or trainers > 0
        has_waiver = bool(gym and gym.welcome_message_template)

        steps = [
            {"key": "gym_name", "label": "Nome palestra", "done": has_name, "icon": "edit"},
            {"key": "gym_logo", "label": "Logo palestra", "done": has_logo, "icon": "image"},
            {"key": "plans", "label": "Abbonamento", "done": has_plans, "icon": "card_membership"},
            {"key": "stripe", "label": "Pagamenti (Stripe)", "done": has_stripe, "icon": "payment"},
            {"key": "staff", "label": "Staff o trainer", "done": has_staff, "icon": "group"},
            {"key": "members", "label": "Primo cliente", "done": has_members, "icon": "person_add"},
            {"key": "welcome_msg", "label": "Messaggio benvenuto", "done": has_waiver, "icon": "message"},
        ]
        completed = sum(1 for s in steps if s["done"])

        return {
            "steps": steps,
            "completed": completed,
            "total": len(steps),
            "is_complete": completed == len(steps),
            "gym_code": gym.gym_code if gym else "",
        }
    finally:
        db.close()


@router.post("/api/owner/setup-plan-templates")
async def create_plan_templates(
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Create pre-built subscription plan templates (Monthly, Quarterly, Annual)."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner only")

    from models_orm import SubscriptionPlanORM
    import uuid as _uuid
    db = get_db_session()
    try:
        # Check if plans already exist
        existing = db.query(SubscriptionPlanORM).filter(
            SubscriptionPlanORM.gym_id == gym_id,
            SubscriptionPlanORM.is_active == True
        ).count()
        if existing > 0:
            return {"status": "skipped", "message": "Piani già esistenti", "created": 0}

        import json
        templates = [
            {"name": "Mensile", "billing_type": "monthly", "price": 39.90,
             "description": "Accesso completo alla palestra", "features": ["Accesso illimitato", "Scheda personalizzata"]},
            {"name": "Trimestrale", "billing_type": "annual", "price": 33.30, "annual_price": 99.90, "installment_count": 4,
             "description": "Risparmia con il piano trimestrale", "features": ["Accesso illimitato", "Scheda personalizzata", "Sconto 15%"]},
            {"name": "Annuale", "billing_type": "annual", "price": 29.16, "annual_price": 349.90, "installment_count": 1,
             "description": "Il miglior rapporto qualità-prezzo", "features": ["Accesso illimitato", "Scheda personalizzata", "Sconto 25%", "Priorità prenotazioni"]},
        ]

        created = 0
        for t in templates:
            db.add(SubscriptionPlanORM(
                id=str(_uuid.uuid4()),
                gym_id=gym_id,
                name=t["name"],
                description=t.get("description", ""),
                price=t.get("price", 0),
                billing_type=t["billing_type"],
                annual_price=t.get("annual_price"),
                installment_count=t.get("installment_count", 1),
                features_json=json.dumps(t.get("features", [])),
                is_active=True,
                created_at=datetime.utcnow().isoformat(),
            ))
            created += 1
        db.commit()
        return {"status": "success", "message": f"{created} piani creati", "created": created}
    finally:
        db.close()


@router.get("/api/owner/default-waiver")
async def get_default_waiver(user: UserORM = Depends(get_current_user)):
    """Get default Italian waiver text for gyms."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner only")

    return {"waiver_text": """ASSUNZIONE DI RISCHIO E LIBERATORIA

Il sottoscritto dichiara di aver scelto volontariamente di partecipare alle attività di fitness presso questa struttura.

Dichiaro di essere consapevole che l'esercizio fisico può essere impegnativo e comportare rischi di infortuni. Comprendo che tali rischi includono, ma non si limitano a:
- Lesioni derivanti dall'uso di attrezzature
- Distorsioni, stiramenti e infortuni muscolari
- Eventi cardiovascolari
- Cadute e collisioni

Con la presente assumo tutti i rischi connessi alla mia partecipazione alle attività di fitness e sollevo questa palestra, i suoi proprietari, dipendenti e collaboratori da qualsiasi responsabilità per infortuni o danni che possano verificarsi.

Confermo che:
- Sono fisicamente idoneo a partecipare a programmi di esercizio fisico
- Consulterò un medico prima di iniziare qualsiasi programma di esercizio in caso di problemi di salute
- Seguirò tutte le regole di sicurezza e le istruzioni fornite dallo staff
- Segnalerò immediatamente eventuali infortuni o problemi di salute

Con la firma sottostante, dichiaro di aver letto e compreso la presente liberatoria e di accettarne i termini."""}


@router.post("/api/owner/invite-staff")
async def invite_staff(
    data: dict,
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Quick invite: create staff account and return WhatsApp link with credentials."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner only")

    name = (data.get("name") or "").strip()
    phone = (data.get("phone") or "").strip()
    role = data.get("role", "staff")  # "staff" or "trainer"

    if not name or not phone:
        raise HTTPException(status_code=400, detail="Nome e telefono sono obbligatori")

    import uuid as _uuid, secrets as _sec, re, urllib.parse
    from auth import get_password_hash
    from models_orm import GymORM

    db = get_db_session()
    try:
        # Auto-generate username from name
        username = name.lower().replace(" ", ".").replace("'", "")
        # Ensure unique
        existing = db.query(UserORM).filter(UserORM.username == username).first()
        if existing:
            username = f"{username}{_sec.randbelow(999):03d}"

        password = _sec.token_urlsafe(12)
        staff_id = str(_uuid.uuid4())
        now = datetime.utcnow().isoformat()

        new_user = UserORM(
            id=staff_id,
            username=username,
            hashed_password=get_password_hash(password),
            role="owner" if role == "staff" else "trainer",
            sub_role="staff" if role == "staff" else None,
            is_active=True,
            is_approved=True,
            gym_owner_id=gym_id if role != "staff" else None,
            phone=phone,
            must_change_password=True,
            created_at=now,
        )
        # Staff are sub-owners; trainers link via gym_owner_id
        if role == "staff":
            new_user.gym_owner_id = gym_id
        db.add(new_user)
        db.commit()

        # Build WhatsApp link
        gym = db.query(GymORM).filter(GymORM.id == gym_id).first()
        gym_name = gym.name if gym else "FitOS"
        msg = (
            f"Ciao {name}! Sei stato aggiunto come {'staff' if role == 'staff' else 'trainer'} "
            f"in {gym_name} su FitOS.\n\n"
            f"Le tue credenziali:\n"
            f"Username: {username}\n"
            f"Password: {password}\n\n"
            f"Cambia la password al primo accesso."
        )
        clean_phone = re.sub(r'[\s\-\(\).]', '', phone)
        if clean_phone.startswith("3") and len(clean_phone) == 10:
            clean_phone = "39" + clean_phone
        elif clean_phone.startswith("+"):
            clean_phone = clean_phone[1:]
        elif clean_phone.startswith("0"):
            clean_phone = "39" + clean_phone[1:]

        wa_url = f"https://wa.me/{clean_phone}?text={urllib.parse.quote(msg)}"

        return {
            "status": "success",
            "staff_id": staff_id,
            "username": username,
            "temporary_password": password,
            "whatsapp_url": wa_url,
        }
    finally:
        db.close()
