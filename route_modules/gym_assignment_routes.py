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
    service: GymAssignmentService = Depends(get_gym_assignment_service)
):
    """Get the gym code that trainers/clients can use to join."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view gym codes")

    # Use the new gym_code field
    gym_code = user.gym_code or service.generate_gym_code_for_owner(user.id)

    return {
        "gym_code": gym_code,
        "owner_name": user.username,
        "gym_name": user.gym_name or "",
        "gym_logo": user.gym_logo or "",
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


@router.get("/api/owner/gym-settings")
async def get_gym_settings(user: UserORM = Depends(get_current_user)):
    """Get gym branding settings (name, logo)."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view gym settings")

    return {
        "gym_name": user.gym_name or "",
        "gym_logo": user.gym_logo or "",
    }


@router.post("/api/owner/gym-settings")
async def update_gym_settings(
    request: GymSettingsUpdate,
    user: UserORM = Depends(get_current_user)
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

    db = get_db_session()
    try:
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            if request.gym_name is not None:
                db_user.gym_name = request.gym_name.strip()
            db.commit()
        return {"success": True, "message": "Gym settings updated"}
    finally:
        db.close()


@router.post("/api/owner/gym-logo")
async def upload_gym_logo(
    file: UploadFile = File(...),
    user: UserORM = Depends(get_current_user)
):
    """Upload or update gym logo."""
    from service_modules.upload_helper import save_file, delete_file, _optimize_image, ALLOWED_IMAGE_EXTENSIONS, MAX_IMAGE_SIZE

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

    # Delete old logo
    if user.gym_logo:
        await delete_file(user.gym_logo)

    optimized, ext = _optimize_image(content, max_size=(400, 400), crop_square=False)
    filename = f"gym_logo_{user.id}.{ext}"

    url = await save_file(optimized, "profiles", filename)

    db = get_db_session()
    try:
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
async def delete_gym_logo(user: UserORM = Depends(get_current_user)):
    """Delete gym logo."""
    from service_modules.upload_helper import delete_file

    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can delete gym logo")

    if user.gym_logo:
        await delete_file(user.gym_logo)

    db = get_db_session()
    try:
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
    user: UserORM = Depends(get_current_user)
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
            UserORM.gym_owner_id == user.id,
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
    user: UserORM = Depends(get_current_user)
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
            UserORM.gym_owner_id == user.id,
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
                    PaymentORM.gym_id == user.id,
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
