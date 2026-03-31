"""
Staff/Reception API routes for gym management
"""

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from database import get_db_session
from models_orm import UserORM, AppointmentORM, CheckInORM, ClientProfileORM, SubscriptionPlanORM, ClientSubscriptionORM, ClientDocumentORM, MedicalCertificateORM, PaymentORM, TrainerAvailabilityORM, NotificationORM
from auth import get_current_user, get_password_hash
from datetime import datetime, date, timedelta
from service_modules.subscription_service import subscription_service
import json
import logging
import os

logger = logging.getLogger("gym_app")

router = APIRouter(prefix="/api/staff", tags=["staff"])


def _effective_gym_id(user: UserORM) -> str:
    """Get the gym owner ID for access checks. Owners use their own ID, staff use gym_owner_id."""
    return str(user.id) if user.role == "owner" else (user.gym_owner_id or "")


def get_db():
    db = get_db_session()
    try:
        yield db
    finally:
        db.close()


@router.get("/gym-info")
async def get_staff_gym_info(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get gym info for staff member"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    # Get the gym owner
    gym_owner = None
    if user.gym_owner_id:
        gym_owner = db.query(UserORM).filter(UserORM.id == user.gym_owner_id).first()

    return {
        "staff_name": user.username,
        "gym_name": f"{gym_owner.username}'s Gym" if gym_owner else "Your Gym",
        "gym_code": gym_owner.gym_code if gym_owner else None
    }


@router.get("/members")
async def get_gym_members(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all members (clients) of the gym"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    if not user.gym_owner_id:
        return []

    # Get all clients belonging to this gym (capped at 500)
    members = db.query(UserORM).filter(
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "client"
    ).limit(500).all()

    return [
        {
            "id": m.id,
            "username": m.username,
            "name": m.username,  # Could add a name field later
            "email": m.email,
            "profile_picture": m.registration_photo or m.profile_picture
        }
        for m in members
    ]


@router.post("/checkin")
async def check_in_member(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Check in a member"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    member_id = data.get("member_id")
    if not member_id:
        raise HTTPException(status_code=400, detail="Member ID required")

    # Verify member exists and belongs to same gym
    member = db.query(UserORM).filter(
        UserORM.id == member_id,
        UserORM.gym_owner_id == user.gym_owner_id
    ).first()

    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    # Check if member already checked in today
    today = date.today().isoformat()
    try:
        existing_checkin = db.query(CheckInORM).filter(
            CheckInORM.member_id == member_id,
            CheckInORM.gym_owner_id == user.gym_owner_id,
            CheckInORM.checked_in_at.like(f"{today}%")
        ).first()

        if existing_checkin:
            raise HTTPException(status_code=400, detail=f"{member.username} already checked in today")

        # Create check-in record
        checkin = CheckInORM(
            member_id=member_id,
            staff_id=user.id,
            gym_owner_id=user.gym_owner_id,
            checked_in_at=datetime.now().isoformat()
        )
        db.add(checkin)
        db.commit()
    except HTTPException:
        raise
    except Exception as e:
        # If CheckInORM doesn't exist, just log success
        logger.info(f"Check-in recorded for member {member_id} by staff {user.id}")

    return {"status": "success", "message": f"{member.username} checked in"}


@router.get("/checkins/today")
async def get_todays_checkins(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get today's check-in stats"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    today = date.today().isoformat()

    try:
        # Try to get check-ins if table exists
        total = db.query(CheckInORM).filter(
            CheckInORM.gym_owner_id == user.gym_owner_id,
            CheckInORM.checked_in_at.like(f"{today}%")
        ).count()

        checkins = db.query(CheckInORM).filter(
            CheckInORM.gym_owner_id == user.gym_owner_id,
            CheckInORM.checked_in_at.like(f"{today}%")
        ).order_by(CheckInORM.checked_in_at.desc()).limit(20).all()

        recent = []
        for c in checkins:
            member = db.query(UserORM).filter(UserORM.id == c.member_id).first()
            if member:
                time_str = c.checked_in_at.split("T")[1][:5] if "T" in c.checked_in_at else c.checked_in_at[-8:-3]
                recent.append({
                    "member_name": member.username,
                    "time": time_str
                })

        return {
            "count": total,
            "recent": recent
        }
    except Exception as e:
        # Table might not exist yet
        logger.warning("Failed to fetch checkin history: %s", e)
        return {
            "count": 0,
            "recent": []
        }


@router.get("/appointments/today")
async def get_todays_appointments(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get today's appointments for the gym"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    today = date.today().isoformat()

    # Get all trainers in this gym
    trainers = db.query(UserORM).filter(
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "trainer"
    ).all()

    trainer_ids = [t.id for t in trainers]

    if not trainer_ids:
        return []

    # Get today's appointments
    appointments = db.query(AppointmentORM).filter(
        AppointmentORM.trainer_id.in_(trainer_ids),
        AppointmentORM.date == today,
        AppointmentORM.status.in_(["scheduled", "confirmed", "pending_trainer"])
    ).order_by(AppointmentORM.start_time).all()

    result = []
    for appt in appointments:
        client = db.query(UserORM).filter(UserORM.id == appt.client_id).first()
        trainer = db.query(UserORM).filter(UserORM.id == appt.trainer_id).first()

        result.append({
            "id": appt.id,
            "client_name": client.username if client else "Unknown",
            "trainer_name": trainer.username if trainer else "Unknown",
            "time": appt.start_time,
            "duration": appt.duration,
            "status": appt.status
        })

    return result


@router.get("/trainers")
async def get_gym_trainers(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all trainers/nutritionists of the gym"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    if not user.gym_owner_id:
        return []

    # Get all trainers belonging to this gym
    trainers = db.query(UserORM).filter(
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "trainer",
        UserORM.is_approved == True
    ).all()

    return [
        {
            "id": t.id,
            "username": t.username,
            "name": t.username,
            "email": t.email,
            "profile_picture": t.profile_picture,
            "sub_role": t.sub_role or "trainer"
        }
        for t in trainers
    ]


@router.get("/trainer/{trainer_id}/schedule")
async def get_trainer_schedule(
    trainer_id: str,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get trainer's availability and today's appointments"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    # Verify trainer belongs to same gym
    trainer = db.query(UserORM).filter(
        UserORM.id == trainer_id,
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "trainer"
    ).first()

    if not trainer:
        raise HTTPException(status_code=404, detail="Trainer not found")

    today = date.today()
    today_str = today.isoformat()

    # Get today's appointments for this trainer
    appointments = db.query(AppointmentORM).filter(
        AppointmentORM.trainer_id == trainer_id,
        AppointmentORM.date == today_str,
        AppointmentORM.status.in_(["scheduled", "confirmed"])
    ).order_by(AppointmentORM.start_time).all()

    appt_list = []
    for appt in appointments:
        client = db.query(UserORM).filter(UserORM.id == appt.client_id).first()
        appt_list.append({
            "id": appt.id,
            "client_name": client.username if client else "Unknown",
            "time": appt.start_time,
            "duration": appt.duration,
            "status": appt.status,
            "session_type": appt.session_type or "General"
        })

    # Get this week's appointments (Mon-Sun)
    from datetime import timedelta
    weekday = today.weekday()  # 0=Mon
    week_start = today - timedelta(days=weekday)
    week_end = week_start + timedelta(days=6)

    week_appointments = db.query(AppointmentORM).filter(
        AppointmentORM.trainer_id == trainer_id,
        AppointmentORM.date >= week_start.isoformat(),
        AppointmentORM.date <= week_end.isoformat(),
        AppointmentORM.status.in_(["scheduled", "confirmed", "completed"])
    ).order_by(AppointmentORM.date, AppointmentORM.start_time).all()

    week_appt_list = []
    for appt in week_appointments:
        client = db.query(UserORM).filter(UserORM.id == appt.client_id).first()
        week_appt_list.append({
            "id": appt.id,
            "client_name": client.username if client else "Unknown",
            "date": appt.date,
            "time": appt.start_time,
            "end_time": appt.end_time,
            "duration": appt.duration,
            "status": appt.status,
            "session_type": appt.session_type or "General"
        })

    # Get trainer's availability from TrainerAvailabilityORM
    availability = []
    avail_slots = db.query(TrainerAvailabilityORM).filter(
        TrainerAvailabilityORM.trainer_id == trainer_id,
        TrainerAvailabilityORM.is_available == True
    ).all()
    for slot in avail_slots:
        availability.append({
            "day_of_week": slot.day_of_week,
            "start_time": slot.start_time,
            "end_time": slot.end_time
        })

    return {
        "trainer_name": trainer.username,
        "sub_role": trainer.sub_role or "trainer",
        "availability": availability,
        "today_appointments": appt_list,
        "week_appointments": week_appt_list,
        "week_start": week_start.isoformat(),
        "week_end": week_end.isoformat(),
    }


@router.get("/member/{member_id}")
async def get_member_details(
    member_id: str,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get detailed member profile for staff view"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    # Verify member belongs to same gym
    member = db.query(UserORM).filter(
        UserORM.id == member_id,
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "client"
    ).first()

    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    # Get assigned trainer if any
    trainer_name = None
    client_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == member_id).first()
    if client_profile and client_profile.trainer_id:
        trainer = db.query(UserORM).filter(UserORM.id == client_profile.trainer_id).first()
        if trainer:
            trainer_name = trainer.username

    # Get check-in stats
    today = date.today().isoformat()
    total_checkins = 0
    last_checkin = None
    checked_in_today = False

    try:
        checkins = db.query(CheckInORM).filter(
            CheckInORM.member_id == member_id
        ).order_by(CheckInORM.checked_in_at.desc()).all()

        total_checkins = len(checkins)
        if checkins:
            last_checkin = checkins[0].checked_in_at
            # Check if checked in today
            if last_checkin and last_checkin.startswith(today):
                checked_in_today = True
    except Exception as e:
        logger.warning("Failed to fetch checkin data for member: %s", e)

    # Get subscription info
    subscription_info = {
        "plan": "No active plan",
        "status": "inactive",
        "expires": None
    }

    try:
        from models_orm import ClientSubscriptionORM, SubscriptionPlanORM
        sub = db.query(ClientSubscriptionORM).filter(
            ClientSubscriptionORM.client_id == member_id,
            ClientSubscriptionORM.status.in_(["active", "trialing"])
        ).first()

        if sub:
            plan = db.query(SubscriptionPlanORM).filter(SubscriptionPlanORM.id == sub.plan_id).first()
            # Format expiry date
            expires = sub.current_period_end
            if expires and "T" in expires:
                expires = expires.split("T")[0]
            subscription_info = {
                "plan": plan.name if plan else "Unknown Plan",
                "status": sub.status,
                "expires": expires
            }
    except Exception as e:
        logger.warning("Failed to fetch subscription info: %s", e)

    # Format member since date
    member_since = member.created_at
    if member_since:
        try:
            if "T" in member_since:
                member_since = member_since.split("T")[0]
        except Exception as e:
            logger.warning("Failed to parse member_since date: %s", e)

    # Get medical certificate
    cert_info = None
    try:
        cert = db.query(MedicalCertificateORM).filter(
            MedicalCertificateORM.client_id == member_id
        ).order_by(MedicalCertificateORM.id.desc()).first()

        if cert:
            cert_status = "valid"
            if cert.expiration_date:
                try:
                    exp = datetime.strptime(cert.expiration_date, "%Y-%m-%d")
                    days_left = (exp - datetime.now()).days
                    if days_left < 0:
                        cert_status = "expired"
                    elif days_left <= 30:
                        cert_status = "expiring"
                except ValueError:
                    pass

            cert_info = {
                "id": cert.id,
                "filename": cert.filename,
                "file_url": cert.file_path,
                "expiration_date": cert.expiration_date,
                "status": cert_status,
                "approval_status": cert.approval_status or "approved",
                "rejection_reason": cert.rejection_reason,
            }
    except Exception as e:
        logger.warning("Failed to fetch medical certificate: %s", e)

    return {
        "id": member.id,
        "username": member.username,
        "name": getattr(member, 'name', None) or member.username,
        "email": member.email,
        "profile_picture": member.profile_picture,
        "registration_photo": member.registration_photo,
        "member_since": member_since,
        "trainer_name": trainer_name,
        "status": "active" if member.is_active else "inactive",
        "total_checkins": total_checkins,
        "last_checkin": last_checkin,
        "checked_in_today": checked_in_today,
        "subscription": subscription_info,
        "medical_certificate": cert_info
    }


# ============ MEDICAL CERTIFICATE MANAGEMENT FOR STAFF ============

@router.post("/upload-certificate/{member_id}")
async def staff_upload_certificate(
    member_id: str,
    request: Request,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Staff uploads a medical certificate on behalf of a client."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff/Owner access only")

    member = db.query(UserORM).filter(UserORM.id == member_id, UserORM.role == "client").first()
    if not member or member.gym_owner_id != user.gym_owner_id:
        raise HTTPException(status_code=404, detail="Member not found")

    data = await request.json()
    file_data = data.get("file_data")  # base64 data URL
    expiration_date = data.get("expiration_date")  # YYYY-MM-DD
    filename = data.get("filename", "certificato_medico.pdf")

    if not file_data:
        raise HTTPException(status_code=400, detail="file_data is required")

    import base64
    from service_modules.upload_helper import save_file

    # Parse data URL
    file_ext = "pdf"
    raw_data = file_data
    if file_data.startswith("data:"):
        mime_part = file_data.split(";")[0]
        if "image/" in mime_part:
            file_ext = mime_part.split("/")[1].split("+")[0]
        raw_data = file_data.split(",")[1]

    file_bytes = base64.b64decode(raw_data)
    save_filename = f"certificato_medico.{file_ext}"
    url = await save_file(file_bytes, f"certificates/{member_id}", save_filename, upload_type="document")

    # Delete old certificates
    old_certs = db.query(MedicalCertificateORM).filter(
        MedicalCertificateORM.client_id == member_id
    ).all()
    for old in old_certs:
        db.delete(old)

    # Create new certificate record (staff uploads are auto-approved)
    cert = MedicalCertificateORM(
        client_id=member_id,
        filename=filename,
        file_path=url,
        expiration_date=expiration_date,
        approval_status="approved",
        reviewed_by=str(user.id),
        reviewed_at=datetime.utcnow().isoformat(),
    )
    db.add(cert)
    db.commit()
    db.refresh(cert)

    # Calculate status
    cert_status = "valid"
    if expiration_date:
        try:
            exp = datetime.strptime(expiration_date, "%Y-%m-%d")
            days_left = (exp - datetime.now()).days
            if days_left < 0:
                cert_status = "expired"
            elif days_left <= 30:
                cert_status = "expiring"
        except ValueError:
            pass

    return {
        "status": "success",
        "certificate": {
            "id": cert.id,
            "filename": cert.filename,
            "file_url": url,
            "expiration_date": expiration_date,
            "cert_status": cert_status
        }
    }


@router.put("/update-certificate/{member_id}")
async def staff_update_certificate_expiry(
    member_id: str,
    request: Request,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Staff updates the expiration date of a member's certificate."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff/Owner access only")

    member = db.query(UserORM).filter(UserORM.id == member_id, UserORM.role == "client").first()
    if not member or member.gym_owner_id != user.gym_owner_id:
        raise HTTPException(status_code=404, detail="Member not found")

    data = await request.json()
    new_expiration = data.get("expiration_date")
    if not new_expiration:
        raise HTTPException(status_code=400, detail="expiration_date is required")

    cert = db.query(MedicalCertificateORM).filter(
        MedicalCertificateORM.client_id == member_id
    ).order_by(MedicalCertificateORM.id.desc()).first()

    if not cert:
        raise HTTPException(status_code=404, detail="No certificate found for this member")

    cert.expiration_date = new_expiration
    db.commit()

    return {"status": "success", "message": "Expiration date updated"}


@router.delete("/delete-certificate/{member_id}")
async def staff_delete_certificate(
    member_id: str,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Staff deletes a member's certificate."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff/Owner access only")

    member = db.query(UserORM).filter(UserORM.id == member_id, UserORM.role == "client").first()
    if not member or member.gym_owner_id != user.gym_owner_id:
        raise HTTPException(status_code=404, detail="Member not found")

    certs = db.query(MedicalCertificateORM).filter(
        MedicalCertificateORM.client_id == member_id
    ).all()

    if not certs:
        raise HTTPException(status_code=404, detail="No certificate found")

    from service_modules.upload_helper import delete_file
    for cert in certs:
        await delete_file(cert.file_path)
        db.delete(cert)
    db.commit()

    return {"status": "success", "message": "Certificate deleted"}


@router.post("/approve-certificate/{cert_id}")
async def staff_approve_certificate(
    cert_id: int,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Staff approves a client-uploaded medical certificate."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff/Owner access only")

    cert = db.query(MedicalCertificateORM).filter(MedicalCertificateORM.id == cert_id).first()
    if not cert:
        raise HTTPException(status_code=404, detail="Certificate not found")

    # Verify same gym
    client_user = db.query(UserORM).filter(UserORM.id == cert.client_id).first()
    if not client_user or client_user.gym_owner_id != _effective_gym_id(user):
        raise HTTPException(status_code=404, detail="Certificate not found")

    cert.approval_status = "approved"
    cert.reviewed_by = str(user.id)
    cert.reviewed_at = datetime.utcnow().isoformat()
    cert.rejection_reason = None

    # Notify client
    db.add(NotificationORM(
        user_id=cert.client_id,
        type="certificate_approved",
        title="Certificato approvato",
        message="Il tuo certificato medico è stato approvato dallo staff.",
    ))

    db.commit()
    return {"status": "success", "message": "Certificato approvato"}


@router.post("/reject-certificate/{cert_id}")
async def staff_reject_certificate(
    cert_id: int,
    request: Request,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Staff rejects a client-uploaded medical certificate."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff/Owner access only")

    cert = db.query(MedicalCertificateORM).filter(MedicalCertificateORM.id == cert_id).first()
    if not cert:
        raise HTTPException(status_code=404, detail="Certificate not found")

    # Verify same gym
    client_user = db.query(UserORM).filter(UserORM.id == cert.client_id).first()
    if not client_user or client_user.gym_owner_id != _effective_gym_id(user):
        raise HTTPException(status_code=404, detail="Certificate not found")

    data = await request.json()
    reason = data.get("reason", "")

    cert.approval_status = "rejected"
    cert.reviewed_by = str(user.id)
    cert.reviewed_at = datetime.utcnow().isoformat()
    cert.rejection_reason = reason

    # Notify client
    reason_text = f" Motivo: {reason}" if reason else ""
    db.add(NotificationORM(
        user_id=cert.client_id,
        type="certificate_rejected",
        title="Certificato rifiutato",
        message=f"Il tuo certificato medico è stato rifiutato dallo staff.{reason_text} Carica un nuovo certificato.",
    ))

    db.commit()
    return {"status": "success", "message": "Certificato rifiutato"}


@router.get("/pending-certificates")
async def get_pending_certificates(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all pending certificates for staff review."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff/Owner access only")

    pending = db.query(MedicalCertificateORM).filter(
        MedicalCertificateORM.approval_status == "pending"
    ).order_by(MedicalCertificateORM.id.desc()).all()

    gym_id = _effective_gym_id(user)
    results = []
    for cert in pending:
        client_user = db.query(UserORM).filter(UserORM.id == cert.client_id).first()
        if not client_user or client_user.gym_owner_id != gym_id:
            continue
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == cert.client_id).first()
        name = (profile.name if profile and profile.name else client_user.username) if client_user else "Unknown"

        results.append({
            "id": cert.id,
            "client_id": cert.client_id,
            "client_name": name,
            "filename": cert.filename,
            "file_url": cert.file_path,
            "expiration_date": cert.expiration_date,
            "uploaded_at": cert.uploaded_at,
        })

    return {"pending": results, "count": len(results)}


# ============ SUBSCRIPTION MANAGEMENT FOR STAFF ============

@router.get("/subscription-plans")
async def get_gym_subscription_plans(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all subscription plans for the gym (for staff to assign to clients)"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    if not user.gym_owner_id:
        return []

    plans = db.query(SubscriptionPlanORM).filter(
        SubscriptionPlanORM.gym_id == user.gym_owner_id,
        SubscriptionPlanORM.is_active == True
    ).all()

    return [
        {
            "id": p.id,
            "name": p.name,
            "description": p.description,
            "price": p.price,
            "currency": p.currency,
            "billing_interval": p.billing_interval,
            "trial_period_days": p.trial_period_days,
            "features": eval(p.features_json) if p.features_json else []
        }
        for p in plans
    ]


@router.post("/subscribe-client")
async def subscribe_client_to_plan(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Subscribe a client to a plan (staff-initiated, no payment required)"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    client_id = data.get("client_id")
    plan_id = data.get("plan_id")

    if not client_id or not plan_id:
        raise HTTPException(status_code=400, detail="client_id and plan_id required")

    # Verify client belongs to same gym
    client = db.query(UserORM).filter(
        UserORM.id == client_id,
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "client"
    ).first()

    if not client:
        raise HTTPException(status_code=404, detail="Client not found")

    # Verify plan exists and belongs to same gym
    plan = db.query(SubscriptionPlanORM).filter(
        SubscriptionPlanORM.id == plan_id,
        SubscriptionPlanORM.gym_id == user.gym_owner_id,
        SubscriptionPlanORM.is_active == True
    ).first()

    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    # Check if client already has active subscription
    existing = db.query(ClientSubscriptionORM).filter(
        ClientSubscriptionORM.client_id == client_id,
        ClientSubscriptionORM.gym_id == user.gym_owner_id,
        ClientSubscriptionORM.status.in_(["active", "trialing"])
    ).first()

    if existing:
        raise HTTPException(status_code=400, detail="Client already has an active subscription")

    # Create subscription (staff-initiated = no Stripe, marked as active immediately)
    import uuid
    now = datetime.utcnow().isoformat()

    # Calculate period end based on billing interval
    period_end = datetime.utcnow()
    if plan.billing_interval == "year":
        period_end += timedelta(days=365)
    else:
        period_end += timedelta(days=30)

    subscription = ClientSubscriptionORM(
        id=str(uuid.uuid4()),
        client_id=client_id,
        plan_id=plan_id,
        gym_id=user.gym_owner_id,
        status="active",
        start_date=now,
        current_period_start=now,
        current_period_end=period_end.isoformat(),
        created_at=now,
        updated_at=now
    )
    db.add(subscription)
    db.commit()

    logger.info(f"Staff {user.id} subscribed client {client_id} to plan {plan.name}")

    return {
        "status": "success",
        "message": f"{client.username} subscribed to {plan.name}",
        "subscription_id": subscription.id
    }


@router.post("/cancel-subscription")
async def cancel_client_subscription(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a client's subscription (staff-initiated)"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    client_id = data.get("client_id")
    if not client_id:
        raise HTTPException(status_code=400, detail="client_id required")

    # Verify client belongs to same gym
    client = db.query(UserORM).filter(
        UserORM.id == client_id,
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "client"
    ).first()

    if not client:
        raise HTTPException(status_code=404, detail="Client not found")

    # Find active subscription
    subscription = db.query(ClientSubscriptionORM).filter(
        ClientSubscriptionORM.client_id == client_id,
        ClientSubscriptionORM.gym_id == user.gym_owner_id,
        ClientSubscriptionORM.status.in_(["active", "trialing"])
    ).first()

    if not subscription:
        raise HTTPException(status_code=404, detail="No active subscription found")

    # Cancel immediately
    subscription.status = "canceled"
    subscription.canceled_at = datetime.utcnow().isoformat()
    subscription.updated_at = datetime.utcnow().isoformat()
    db.commit()

    logger.info(f"Staff {user.id} canceled subscription for client {client_id}")

    return {
        "status": "success",
        "message": f"Subscription canceled for {client.username}"
    }


@router.post("/change-subscription/preview")
async def preview_subscription_change(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Preview proration for changing a client's subscription plan"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    client_id = data.get("client_id")
    new_plan_id = data.get("plan_id")

    if not client_id or not new_plan_id:
        raise HTTPException(status_code=400, detail="client_id and plan_id required")

    client = db.query(UserORM).filter(
        UserORM.id == client_id,
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "client"
    ).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")

    new_plan = db.query(SubscriptionPlanORM).filter(
        SubscriptionPlanORM.id == new_plan_id,
        SubscriptionPlanORM.gym_id == user.gym_owner_id,
        SubscriptionPlanORM.is_active == True
    ).first()
    if not new_plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    subscription = db.query(ClientSubscriptionORM).filter(
        ClientSubscriptionORM.client_id == client_id,
        ClientSubscriptionORM.gym_id == user.gym_owner_id,
        ClientSubscriptionORM.status.in_(["active", "trialing"])
    ).first()

    old_plan_name = None
    old_plan_price = 0.0
    credit = 0.0
    amount_due = new_plan.price

    if subscription:
        old_plan = db.query(SubscriptionPlanORM).filter(
            SubscriptionPlanORM.id == subscription.plan_id
        ).first()
        if old_plan:
            old_plan_name = old_plan.name
            old_plan_price = old_plan.price or 0.0

            # Calculate prorated credit for remaining days
            try:
                period_end = datetime.fromisoformat(subscription.current_period_end)
                now = datetime.utcnow()
                remaining_days = max(0, (period_end - now).days)
                total_days = 365 if old_plan.billing_interval == "year" else 30
                credit = round(old_plan_price * (remaining_days / total_days), 2)
            except Exception as e:
                logger.warning("Failed to calculate plan change credit: %s", e)
                credit = 0.0

        amount_due = round(max(0, new_plan.price - credit), 2)

    return {
        "old_plan_name": old_plan_name,
        "old_plan_price": old_plan_price,
        "new_plan_name": new_plan.name,
        "new_plan_price": new_plan.price,
        "credit": credit,
        "amount_due": amount_due,
        "currency": new_plan.currency or "eur",
    }


@router.post("/change-subscription")
async def change_client_subscription(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Change a client's subscription to a different plan with payment"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    client_id = data.get("client_id")
    new_plan_id = data.get("plan_id")
    payment_method = data.get("payment_method", "cash")  # "cash" or "pos"

    if not client_id or not new_plan_id:
        raise HTTPException(status_code=400, detail="client_id and plan_id required")

    # Verify client belongs to same gym
    client = db.query(UserORM).filter(
        UserORM.id == client_id,
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "client"
    ).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")

    # Verify new plan exists
    new_plan = db.query(SubscriptionPlanORM).filter(
        SubscriptionPlanORM.id == new_plan_id,
        SubscriptionPlanORM.gym_id == user.gym_owner_id,
        SubscriptionPlanORM.is_active == True
    ).first()
    if not new_plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    # Find existing subscription
    subscription = db.query(ClientSubscriptionORM).filter(
        ClientSubscriptionORM.client_id == client_id,
        ClientSubscriptionORM.gym_id == user.gym_owner_id,
        ClientSubscriptionORM.status.in_(["active", "trialing"])
    ).first()

    import uuid
    now = datetime.utcnow().isoformat()

    # Calculate proration
    old_plan_name = None
    credit = 0.0
    if subscription:
        old_plan = db.query(SubscriptionPlanORM).filter(
            SubscriptionPlanORM.id == subscription.plan_id
        ).first()
        if old_plan:
            old_plan_name = old_plan.name
            try:
                period_end = datetime.fromisoformat(subscription.current_period_end)
                remaining_days = max(0, (period_end - datetime.utcnow()).days)
                total_days = 365 if old_plan.billing_interval == "year" else 30
                credit = round((old_plan.price or 0) * (remaining_days / total_days), 2)
            except Exception as e:
                logger.warning("Failed to calculate subscription credit on plan change: %s", e)
                credit = 0.0

        # Update existing subscription
        subscription.plan_id = new_plan_id
        subscription.current_period_start = now
        period_end = datetime.utcnow()
        if new_plan.billing_interval == "year":
            period_end += timedelta(days=365)
        else:
            period_end += timedelta(days=30)
        subscription.current_period_end = period_end.isoformat()
        subscription.updated_at = now
    else:
        # Create new subscription
        period_end = datetime.utcnow()
        if new_plan.billing_interval == "year":
            period_end += timedelta(days=365)
        else:
            period_end += timedelta(days=30)

        subscription = ClientSubscriptionORM(
            id=str(uuid.uuid4()),
            client_id=client_id,
            plan_id=new_plan_id,
            gym_id=user.gym_owner_id,
            status="active",
            start_date=now,
            current_period_start=now,
            current_period_end=period_end.isoformat(),
            created_at=now,
            updated_at=now
        )
        db.add(subscription)

    amount_due = round(max(0, (new_plan.price or 0) - credit), 2)

    # Record payment if amount > 0
    if amount_due > 0:
        payment_record = PaymentORM(
            id=str(uuid.uuid4()),
            client_id=client_id,
            subscription_id=subscription.id,
            gym_id=user.gym_owner_id,
            amount=amount_due,
            currency=new_plan.currency or "eur",
            status="recorded",
            description=f"Cambio piano: {old_plan_name or 'Nessuno'} → {new_plan.name}",
            payment_method=payment_method,
            paid_at=now,
            created_at=now
        )
        db.add(payment_record)

    db.commit()
    logger.info(f"Staff {user.id} changed client {client_id} to plan {new_plan.name} (paid €{amount_due} via {payment_method})")

    # Send notification + email in background
    try:
        from service_modules.notification_service import NotificationService
        ns = NotificationService(db)
        payment_label = "POS" if payment_method == "pos" else "Contanti"
        ns.create_notification(
            user_id=client_id,
            notification_type="subscription_changed",
            title="Abbonamento Aggiornato",
            message=f"Il tuo piano è stato cambiato a {new_plan.name}. "
                    f"{'Importo pagato: €' + f'{amount_due:.2f} ({payment_label})' if amount_due > 0 else 'Nessun importo aggiuntivo.'}",
            data={"plan_name": new_plan.name, "amount": amount_due, "payment_method": payment_method}
        )
    except Exception as e:
        logger.warning(f"Failed to send notification for plan change: {e}")

    try:
        from service_modules.email_service import get_email_service_for_gym
        email_svc = get_email_service_for_gym(user.gym_owner_id, db)
        client_email = client.email if hasattr(client, 'email') else None
        if not client_email:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.user_id == client_id).first()
            client_email = profile.email if profile and hasattr(profile, 'email') else None

        if client_email and email_svc and email_svc.is_configured():
            gym_owner = db.query(UserORM).filter(UserORM.id == user.gym_owner_id).first()
            gym_name = gym_owner.gym_name if gym_owner and gym_owner.gym_name else "La tua palestra"
            payment_label = "POS" if payment_method == "pos" else "Contanti"

            html = f"""
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                <h2 style="color: #E8772E;">Abbonamento Aggiornato</h2>
                <p>Ciao <b>{client.username}</b>,</p>
                <p>Il tuo abbonamento presso <b>{gym_name}</b> è stato aggiornato.</p>
                <table style="width: 100%; border-collapse: collapse; margin: 16px 0;">
                    {'<tr><td style="padding: 8px; border-bottom: 1px solid #eee; color: #666;">Piano precedente</td><td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right;"><b>' + (old_plan_name or "-") + '</b></td></tr>' if old_plan_name else ''}
                    <tr><td style="padding: 8px; border-bottom: 1px solid #eee; color: #666;">Nuovo piano</td><td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right;"><b>{new_plan.name}</b></td></tr>
                    <tr><td style="padding: 8px; border-bottom: 1px solid #eee; color: #666;">Prezzo</td><td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right;">€{new_plan.price:.2f}</td></tr>
                    {f'<tr><td style="padding: 8px; border-bottom: 1px solid #eee; color: #666;">Credito residuo</td><td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right; color: #22c55e;">-€{credit:.2f}</td></tr>' if credit > 0 else ''}
                    {f'<tr><td style="padding: 8px; color: #666;"><b>Importo pagato</b></td><td style="padding: 8px; text-align: right;"><b>€{amount_due:.2f}</b> ({payment_label})</td></tr>' if amount_due > 0 else '<tr><td style="padding: 8px; color: #666;" colspan="2">Nessun importo aggiuntivo dovuto.</td></tr>'}
                </table>
                <p style="color: #888; font-size: 12px;">Questo è un messaggio automatico da {gym_name}.</p>
            </div>
            """
            email_svc.send_email(client_email, f"Abbonamento aggiornato - {gym_name}", html)
    except Exception as e:
        logger.warning(f"Failed to send email for plan change: {e}")

    return {
        "status": "success",
        "message": f"{client.username} now on {new_plan.name} plan",
        "amount_paid": amount_due,
        "payment_method": payment_method,
        "credit": credit
    }


# ============ CLIENT ONBOARDING ============

@router.get("/waiver-template")
async def get_waiver_template(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get the gym's waiver template text for signing"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    # Default waiver text - gyms can customize this later
    waiver_text = """
ASSUMPTION OF RISK AND WAIVER OF LIABILITY

I hereby acknowledge that I have voluntarily chosen to participate in fitness activities at this gym facility.

I understand that physical exercise can be strenuous and subject to risk of serious injury, illness, and death. I understand that these risks include but are not limited to:
- Injuries from exercise equipment
- Sprains, strains, and muscle injuries
- Cardiovascular events
- Falls and collisions

I hereby assume all risks associated with my participation in fitness activities and release this gym, its owners, employees, and staff from any liability for injuries or damages that may occur.

I confirm that:
- I am physically fit to participate in exercise programs
- I will consult a physician before beginning any exercise program if I have any health concerns
- I will follow all safety rules and instructions provided by staff
- I will report any injuries or health issues immediately

By signing below, I acknowledge that I have read and understood this waiver and agree to its terms.
""".strip()

    return {
        "waiver_text": waiver_text
    }


@router.post("/reset-member-password")
async def reset_member_password(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Staff resets a member's password, generating a temporary one."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff or owner access required")

    member_id = data.get("member_id")
    if not member_id:
        raise HTTPException(status_code=400, detail="member_id is required")

    from service_modules.password_reset_service import staff_reset_password
    result = staff_reset_password(user, member_id)

    if result["status"] == "error":
        raise HTTPException(status_code=400, detail=result["message"])

    return result


@router.post("/change-member-username")
async def change_member_username(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Staff changes a member's username."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff or owner access required")

    member_id = data.get("member_id")
    new_username = data.get("new_username", "").strip()
    if not member_id or not new_username:
        raise HTTPException(status_code=400, detail="member_id and new_username are required")

    from service_modules.password_reset_service import staff_change_username
    result = staff_change_username(user, member_id, new_username)

    if result["status"] == "error":
        raise HTTPException(status_code=400, detail=result["message"])

    return result


@router.post("/update-registration-photo")
async def update_registration_photo(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Staff updates a member's registration photo (for ID verification at check-in)."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff or owner access required")

    member_id = data.get("member_id", "")
    photo_data = data.get("photo_data", "")
    if not member_id or not photo_data:
        raise HTTPException(status_code=400, detail="member_id and photo_data required")

    member = db.query(UserORM).filter(UserORM.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    if photo_data.startswith("data:image/"):
        import base64 as b64
        from service_modules.upload_helper import save_file as _save_file, _optimize_image
        try:
            header, photo_b64 = photo_data.split(",", 1)
            ext = header.split("/")[1].split(";")[0]
            if ext not in ("png", "jpg", "jpeg", "webp"):
                ext = "jpg"
            photo_bytes = b64.b64decode(photo_b64)
            optimized, ext = _optimize_image(photo_bytes, max_size=(400, 400), crop_square=True)
            photo_filename = f"reg_{member_id}.{ext}"
            url = await _save_file(optimized, "registration_photos", photo_filename)
            member.registration_photo = url
            db.commit()
            return {"status": "ok", "registration_photo": url}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to save photo: {e}")
    else:
        raise HTTPException(status_code=400, detail="Invalid photo data format")


@router.post("/onboard-client")
async def onboard_new_client(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Complete client onboarding - creates user, profile, document, and subscription in one transaction.
    """
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    import uuid
    import secrets

    # Extract required fields
    name = (data.get("name") or "").strip()
    phone = (data.get("phone") or "").strip()
    username = (data.get("username") or "").strip()

    # Auto-generate a random temporary password
    password = secrets.token_urlsafe(16)

    # Optional fields
    email = (data.get("email") or "").strip() or None
    date_of_birth = data.get("date_of_birth") or None

    # Document info
    document_type = data.get("document_type")  # "waiver" or "medical_certificate"
    document_data = data.get("document_data")  # Base64 signature or file data
    waiver_text = data.get("waiver_text")  # Waiver text if signing

    # Profile photo (optional, base64 data URL)
    profile_photo = data.get("profile_photo")

    # Subscription info
    plan_id = data.get("plan_id")
    payment_method = data.get("payment_method", "cash")  # "cash", "card", or "terminal"
    stripe_payment_intent_id = data.get("stripe_payment_intent_id")  # From card payment

    # Validation
    logger.info(f"Onboard attempt: name={name!r} phone={phone!r} username={username!r} email={email!r} plan_id={plan_id} payment_method={payment_method}")
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    if not phone:
        raise HTTPException(status_code=400, detail="Phone is required")
    if not username:
        raise HTTPException(status_code=400, detail="Username is required")

    # Check username uniqueness
    existing_user = db.query(UserORM).filter(UserORM.username == username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already taken")

    # Check email uniqueness if provided
    if email:
        existing_email = db.query(UserORM).filter(UserORM.email == email).first()
        if existing_email:
            raise HTTPException(status_code=400, detail="Email already registered")

    try:
        now = datetime.utcnow().isoformat()
        client_id = str(uuid.uuid4())

        # 1. Create user account
        new_user = UserORM(
            id=client_id,
            username=username,
            email=email,
            hashed_password=get_password_hash(password),
            role="client",
            is_active=True,
            gym_owner_id=user.gym_owner_id,
            phone=phone,
            must_change_password=True,  # Force password change on first login
            created_at=now
        )
        db.add(new_user)

        # 2. Create client profile
        new_profile = ClientProfileORM(
            id=client_id,
            name=name,
            email=email,
            date_of_birth=date_of_birth,
            gym_id=user.gym_owner_id,
            streak=0,
            gems=0,
            health_score=50
        )
        db.add(new_profile)

        # 3. Store document (waiver or medical certificate)
        if document_type and document_data:
            doc_id = str(uuid.uuid4())

            if document_type == "waiver":
                # Store waiver signature
                new_doc = ClientDocumentORM(
                    id=doc_id,
                    client_id=client_id,
                    gym_id=user.gym_owner_id,
                    document_type="waiver",
                    signature_data=document_data,  # Base64 signature
                    waiver_text=waiver_text,
                    signed_at=now,
                    uploaded_by=user.id,
                    created_at=now
                )
            else:
                # Store medical certificate file
                import base64
                from service_modules.upload_helper import save_file as sync_save_file

                # Determine file extension from data URL or default to pdf
                file_ext = "pdf"
                if document_data.startswith("data:image/"):
                    file_ext = document_data.split(";")[0].split("/")[1]
                    document_data = document_data.split(",")[1]
                elif document_data.startswith("data:application/pdf"):
                    document_data = document_data.split(",")[1]

                file_bytes = base64.b64decode(document_data)
                filename = f"medical_certificate.{file_ext}"
                url = await sync_save_file(file_bytes, f"documents/{client_id}", filename, upload_type="document")

                new_doc = ClientDocumentORM(
                    id=doc_id,
                    client_id=client_id,
                    gym_id=user.gym_owner_id,
                    document_type="medical_certificate",
                    file_path=url,
                    uploaded_by=user.id,
                    created_at=now
                )

            db.add(new_doc)

        # 4. Create subscription if plan selected
        subscription_id = None
        plan_name = None
        if plan_id:
            plan = db.query(SubscriptionPlanORM).filter(
                SubscriptionPlanORM.id == plan_id,
                SubscriptionPlanORM.gym_id == user.gym_owner_id,
                SubscriptionPlanORM.is_active == True
            ).first()

            if plan:
                plan_name = plan.name
                subscription_id = str(uuid.uuid4())

                # Calculate period end
                period_end = datetime.utcnow()
                if plan.billing_interval == "year":
                    period_end += timedelta(days=365)
                else:
                    period_end += timedelta(days=30)

                new_subscription = ClientSubscriptionORM(
                    id=subscription_id,
                    client_id=client_id,
                    plan_id=plan_id,
                    gym_id=user.gym_owner_id,
                    status="active",
                    start_date=now,
                    current_period_start=now,
                    current_period_end=period_end.isoformat(),
                    stripe_payment_intent_id=stripe_payment_intent_id,
                    created_at=now,
                    updated_at=now
                )
                db.add(new_subscription)

                # Create payment record if payment was made
                if payment_method in ("card", "cash", "qr", "terminal") and plan.price > 0:
                    payment_id = str(uuid.uuid4())
                    payment_record = PaymentORM(
                        id=payment_id,
                        client_id=client_id,
                        subscription_id=subscription_id,
                        gym_id=user.gym_owner_id,
                        amount=plan.price,
                        currency=plan.currency or "usd",
                        status="succeeded" if payment_method in ("card", "qr", "terminal") else "recorded",
                        stripe_payment_intent_id=stripe_payment_intent_id,
                        description=f"Onboarding: {plan.name}",
                        payment_method=payment_method,
                        paid_at=now,
                        created_at=now
                    )
                    db.add(payment_record)

                # Update profile premium status
                new_profile.is_premium = True

        # 5. Save profile photo if provided
        if profile_photo and profile_photo.startswith("data:image/"):
            import base64 as b64
            from service_modules.upload_helper import save_file as _save_file, _optimize_image
            try:
                header, photo_b64 = profile_photo.split(",", 1)
                ext = header.split("/")[1].split(";")[0]
                if ext not in ("png", "jpg", "jpeg", "webp"):
                    ext = "jpg"

                photo_bytes = b64.b64decode(photo_b64)
                optimized, ext = _optimize_image(photo_bytes, max_size=(400, 400), crop_square=True)
                photo_filename = f"{client_id}.{ext}"
                url = await _save_file(optimized, "profiles", photo_filename)
                new_user.profile_picture = url
                new_user.registration_photo = url  # Staff-taken photo for ID verification
            except Exception as photo_err:
                logger.warning(f"Failed to save profile photo: {photo_err}")

        db.commit()

        logger.info(f"Staff {user.id} onboarded new client: {username} (ID: {client_id})")

        return {
            "status": "success",
            "client_id": client_id,
            "username": username,
            "temporary_password": password,
            "name": name,
            "subscription_id": subscription_id,
            "plan_name": plan_name,
            "payment_method": payment_method,
            "message": f"Client {name} registered successfully!"
        }

    except Exception as e:
        db.rollback()
        logger.error(f"Onboarding error: {e}")
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")


# ═══════════════════════════════════════════════════════════
#  REMOTE SIGNING SESSIONS (QR handoff for desktop → phone)
# ═══════════════════════════════════════════════════════════
import secrets as _secrets
@router.post("/signing-session")
async def create_signing_session(
    data: dict,
    request: Request,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a temporary signing session. Returns a token and URL for the phone."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Only staff/owner can create signing sessions")

    from models_orm import SigningSessionORM
    # Clean up expired sessions
    now = datetime.utcnow().isoformat()
    db.query(SigningSessionORM).filter(SigningSessionORM.expires_at < now).delete()
    db.commit()

    token = _secrets.token_urlsafe(24)
    expires = (datetime.utcnow() + timedelta(minutes=10)).isoformat()
    db.add(SigningSessionORM(
        token=token,
        client_name=data.get("client_name", ""),
        waiver_text=data.get("waiver_text", ""),
        status="pending",
        created_by=user.id,
        expires_at=expires,
    ))
    db.commit()

    base_url = str(request.base_url).rstrip("/")
    signing_url = f"{base_url}/sign/{token}"

    return {"token": token, "url": signing_url}


@router.get("/signing-session/{token}/status")
async def get_signing_session_status(token: str, db: Session = Depends(get_db)):
    """Poll for signing completion. No auth required (token is the secret)."""
    from models_orm import SigningSessionORM
    session = db.query(SigningSessionORM).filter(SigningSessionORM.token == token).first()
    if not session or session.expires_at < datetime.utcnow().isoformat():
        raise HTTPException(status_code=404, detail="Session not found or expired")

    if session.status == "signed":
        sig = session.signature_data
        db.delete(session)
        db.commit()
        return {"status": "signed", "signature_data": sig}

    return {"status": "pending"}


@router.post("/signing-session/{token}/submit")
async def submit_signing_session(token: str, data: dict, db: Session = Depends(get_db)):
    """Submit signature from the phone browser. No auth required (token is the secret)."""
    from models_orm import SigningSessionORM
    session = db.query(SigningSessionORM).filter(SigningSessionORM.token == token).first()
    if not session or session.expires_at < datetime.utcnow().isoformat():
        raise HTTPException(status_code=404, detail="Session not found or expired")
    if session.status == "signed":
        raise HTTPException(status_code=400, detail="Already signed")

    sig = data.get("signature_data")
    if not sig:
        raise HTTPException(status_code=400, detail="signature_data is required")

    session.signature_data = sig
    session.status = "signed"
    session.signed_at = datetime.utcnow().isoformat()
    db.commit()
    return {"status": "success", "message": "Firma registrata!"}


# ═══════════════════════════════════════════════════════════
#  REMOTE PHOTO SNAP (QR handoff for desktop → phone camera)
# ═══════════════════════════════════════════════════════════

@router.post("/photo-snap-session")
async def create_photo_snap_session(
    request: Request,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a temporary photo capture session. Returns a token and URL for the phone."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Only staff/owner can create photo sessions")

    from models_orm import PhotoSnapSessionORM
    now = datetime.utcnow().isoformat()
    db.query(PhotoSnapSessionORM).filter(PhotoSnapSessionORM.expires_at < now).delete()
    db.commit()

    token = _secrets.token_urlsafe(24)
    expires = (datetime.utcnow() + timedelta(minutes=10)).isoformat()
    db.add(PhotoSnapSessionORM(
        token=token,
        status="pending",
        created_by=user.id,
        expires_at=expires,
    ))
    db.commit()

    base_url = str(request.base_url).rstrip("/")
    # For QR codes scanned by phones, localhost won't work — use production URL
    if "localhost" in base_url or "127.0.0.1" in base_url:
        import os
        base_url = os.environ.get("PRODUCTION_URL", "https://fitos-eu.onrender.com")
    return {"token": token, "url": f"{base_url}/snap/{token}"}


@router.get("/photo-snap-session/{token}/status")
async def get_photo_snap_status(token: str, db: Session = Depends(get_db)):
    """Poll for photo upload. No auth required (token is the secret)."""
    from models_orm import PhotoSnapSessionORM
    session = db.query(PhotoSnapSessionORM).filter(PhotoSnapSessionORM.token == token).first()
    if not session or session.expires_at < datetime.utcnow().isoformat():
        raise HTTPException(status_code=404, detail="Session not found or expired")

    if session.status == "uploaded":
        photo = session.photo_data
        db.delete(session)
        db.commit()
        return {"status": "uploaded", "photo_data": photo}

    return {"status": "pending"}


@router.post("/photo-snap-session/{token}/upload")
async def upload_photo_snap(token: str, data: dict, db: Session = Depends(get_db)):
    """Receive photo from phone browser. No auth required (token is the secret)."""
    from models_orm import PhotoSnapSessionORM
    session = db.query(PhotoSnapSessionORM).filter(PhotoSnapSessionORM.token == token).first()
    if not session or session.expires_at < datetime.utcnow().isoformat():
        raise HTTPException(status_code=404, detail="Session not found or expired")
    if session.status == "uploaded":
        raise HTTPException(status_code=400, detail="Already uploaded")

    photo = data.get("photo_data")
    if not photo or not photo.startswith("data:image/"):
        raise HTTPException(status_code=400, detail="photo_data must be a data:image/ URL")

    session.photo_data = photo
    session.status = "uploaded"
    db.commit()
    return {"status": "success"}


@router.post("/send-credentials")
async def send_client_credentials(
    data: dict,
    user: UserORM = Depends(get_current_user)
):
    """Send welcome credentials to a newly registered client via email, WhatsApp link, or SMS link."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Only staff/owner can send credentials")

    client_id = data.get("client_id")
    method = data.get("method")  # "email", "whatsapp", "sms"
    username = data.get("username", "")
    temp_password = data.get("temporary_password", "")
    name = data.get("name", "")

    if not client_id or not method:
        raise HTTPException(status_code=400, detail="client_id and method are required")

    db = get_db_session()
    try:
        client = db.query(UserORM).filter(UserORM.id == client_id).first()
        if not client:
            raise HTTPException(status_code=404, detail="Client not found")

        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
        phone = client.phone or ""
        email = client.email or (profile.email if profile else None) or ""
        client_name = name or (profile.name if profile else None) or client.username

        # Get gym name and code
        gym_id = _effective_gym_id(user)
        gym_owner = db.query(UserORM).filter(UserORM.id == gym_id).first()
        gym_name = getattr(gym_owner, 'gym_name', None) or "FitOS"

        # Generate magic login link
        import hashlib, hmac, os, uuid
        from models_orm import MagicLoginTokenORM
        magic_secret = os.environ.get("SECRET_KEY", "gym-secret-key-change-me")
        raw_token = _secrets.token_urlsafe(32)
        token_hash = hmac.new(magic_secret.encode(), raw_token.encode(), hashlib.sha256).hexdigest()
        magic_expires = (datetime.utcnow() + timedelta(hours=24)).isoformat()
        db.add(MagicLoginTokenORM(
            id=str(uuid.uuid4()),
            user_id=client.id,
            token_hash=token_hash,
            expires_at=magic_expires,
        ))
        db.commit()
        magic_link = f"{data.get('base_url', '').rstrip('/') or ''}/magic/{raw_token}"

        # Get gym code and custom template
        from models_orm import GymORM
        gym = db.query(GymORM).filter(GymORM.owner_id == gym_id).first()
        gym_code = gym.gym_code if gym else (gym_owner.gym_code if gym_owner else "")
        base_url = data.get('base_url', '').rstrip('/') or ''
        join_link = f"{base_url}/join/{gym_code}" if gym_code else ""

        # Use custom template if available, with placeholder substitution
        template = gym.welcome_message_template if gym else None
        if template:
            message = template.replace("{nome}", client_name).replace("{username}", username)\
                .replace("{password}", temp_password).replace("{palestra}", gym_name)\
                .replace("{link}", magic_link).replace("{codice}", gym_code)\
                .replace("{download}", join_link)
        else:
            message = (
                f"Benvenuto in {gym_name}!\n\n"
                f"Le tue credenziali per accedere all'app:\n"
                f"Username: {username}\n"
                f"Password: {temp_password}\n\n"
                f"Oppure accedi direttamente:\n{magic_link}\n\n"
                f"Cambia la password al primo accesso.\n"
                f"Scarica l'app FitOS per iniziare!"
            )

        if method == "email":
            if not email:
                raise HTTPException(status_code=400, detail="Nessuna email disponibile per questo cliente")
            try:
                from service_modules.email_service import get_email_service_for_gym
                email_svc = get_email_service_for_gym(gym_id, db)
                if not email_svc or not email_svc.is_configured():
                    raise HTTPException(status_code=400, detail="Email non configurata. Configura SMTP nelle impostazioni.")

                html = f"""
                <div style="font-family:Arial,sans-serif;max-width:500px;margin:0 auto;background:#1a1a1a;color:#fff;padding:24px;border-radius:12px;">
                    <h2 style="color:#f97316;">Benvenuto in {gym_name}!</h2>
                    <p>Ciao <strong>{client_name}</strong>,</p>
                    <p>Il tuo account è stato creato. Ecco le tue credenziali:</p>
                    <div style="background:#252525;padding:16px;border-radius:8px;margin:16px 0;">
                        <p style="margin:4px 0;"><strong>Username:</strong> {username}</p>
                        <p style="margin:4px 0;"><strong>Password:</strong> <code style="color:#22c55e;font-size:18px;">{temp_password}</code></p>
                    </div>
                    <p style="color:#facc15;font-size:13px;">⚠️ Cambia la password al primo accesso.</p>
                    <p>Scarica l'app FitOS per iniziare il tuo percorso fitness!</p>
                </div>
                """
                sent = email_svc.send_email(email, f"Le tue credenziali - {gym_name}", html)
                if not sent:
                    raise HTTPException(status_code=500, detail="Invio email fallito")
                return {"status": "success", "method": "email", "message": f"Credenziali inviate a {email}"}
            except HTTPException:
                raise
            except Exception as e:
                logger.error(f"Failed to send credentials email: {e}")
                raise HTTPException(status_code=500, detail=f"Invio email fallito: {str(e)}")

        elif method == "whatsapp":
            if not phone:
                raise HTTPException(status_code=400, detail="Nessun numero di telefono disponibile")
            import re
            import urllib.parse
            phone_clean = re.sub(r'[\s\-\(\)]', '', phone)
            if not phone_clean.startswith('+'):
                if phone_clean.startswith('0'):
                    phone_clean = '+39' + phone_clean[1:]
                else:
                    phone_clean = '+39' + phone_clean
            wa_message = urllib.parse.quote(message)
            whatsapp_link = f"https://wa.me/{phone_clean.lstrip('+')}?text={wa_message}"

            # Push notification to staff's phone so they can tap to open
            notif_title = f"Invia credenziali a {client_name}"
            notif_body = "Tocca per aprire WhatsApp e inviare le credenziali"
            notif_data = {"link": whatsapp_link, "method": "whatsapp", "client_name": client_name}

            db.add(NotificationORM(
                user_id=user.id,
                type="send_credentials_link",
                title=notif_title,
                message=notif_body,
                data=json.dumps(notif_data),
                read=False,
                created_at=datetime.utcnow().isoformat()
            ))
            db.commit()

            try:
                from service_modules.notification_service import send_fcm_push
                send_fcm_push(db, user.id, notif_title, notif_body, notif_data)
            except Exception:
                pass  # FCM is best-effort

            return {"status": "success", "method": "whatsapp", "link": whatsapp_link, "message": "Notifica inviata al tuo telefono"}

        elif method == "sms":
            if not phone:
                raise HTTPException(status_code=400, detail="Nessun numero di telefono disponibile")
            import urllib.parse
            sms_body = urllib.parse.quote(message)
            sms_link = f"sms:{phone}?body={sms_body}"

            notif_title = f"Invia credenziali a {client_name}"
            notif_body = "Tocca per aprire SMS e inviare le credenziali"
            notif_data = {"link": sms_link, "method": "sms", "client_name": client_name}

            db.add(NotificationORM(
                user_id=user.id,
                type="send_credentials_link",
                title=notif_title,
                message=notif_body,
                data=json.dumps(notif_data),
                read=False,
                created_at=datetime.utcnow().isoformat()
            ))
            db.commit()

            try:
                from service_modules.notification_service import send_fcm_push
                send_fcm_push(db, user.id, notif_title, notif_body, notif_data)
            except Exception:
                pass  # FCM is best-effort

            return {"status": "success", "method": "sms", "link": sms_link, "message": "Notifica inviata al tuo telefono"}

        else:
            raise HTTPException(status_code=400, detail=f"Metodo non supportato: {method}")

    finally:
        db.close()


@router.post("/onboarding-checkout-session")
async def create_onboarding_checkout_session(
    data: dict,
    request: Request,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a Stripe Checkout Session for onboarding QR code payment."""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    import stripe

    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key or stripe.api_key.startswith("your_"):
        raise HTTPException(status_code=400, detail="Stripe is not configured")

    plan_id = data.get("plan_id")
    client_name = data.get("client_name", "New Client")

    if not plan_id:
        raise HTTPException(status_code=400, detail="plan_id is required")

    plan = db.query(SubscriptionPlanORM).filter(
        SubscriptionPlanORM.id == plan_id,
        SubscriptionPlanORM.gym_id == user.gym_owner_id,
        SubscriptionPlanORM.is_active == True
    ).first()

    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    try:
        amount_cents = int(plan.price * 100)
        if amount_cents < 50:
            amount_cents = 50

        base_url = str(request.base_url).rstrip("/")
        success_url = f"{base_url}/api/staff/onboarding-checkout-success?session_id={{CHECKOUT_SESSION_ID}}"
        cancel_url = f"{base_url}/api/staff/onboarding-checkout-canceled"

        checkout_session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            mode="payment",
            line_items=[{
                "price_data": {
                    "currency": (plan.currency or "eur").lower(),
                    "product_data": {
                        "name": f"Gym Membership: {plan.name}",
                        "description": f"Membership for {client_name}",
                    },
                    "unit_amount": amount_cents,
                },
                "quantity": 1,
            }],
            metadata={
                "type": "onboarding",
                "gym_id": user.gym_owner_id,
                "plan_id": plan_id,
                "plan_name": plan.name,
                "client_name": client_name,
                "staff_id": user.id,
            },
            success_url=success_url,
            cancel_url=cancel_url,
        )

        return {
            "checkout_url": checkout_session.url,
            "session_id": checkout_session.id,
            "amount": plan.price,
            "currency": plan.currency or "EUR"
        }

    except stripe.StripeError as e:
        logger.error(f"Stripe error creating checkout session: {e}")
        raise HTTPException(status_code=400, detail=f"Payment setup failed: {str(e)}")


@router.get("/checkout-session-status/{session_id}")
async def get_checkout_session_status(
    session_id: str,
    user: UserORM = Depends(get_current_user)
):
    """Poll a Stripe Checkout Session to check if payment is complete."""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    import stripe

    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key or stripe.api_key.startswith("your_"):
        raise HTTPException(status_code=400, detail="Stripe is not configured")

    try:
        session = stripe.checkout.Session.retrieve(session_id)
        return {
            "status": session.payment_status,
            "payment_intent_id": session.payment_intent if session.payment_status == "paid" else None
        }
    except stripe.StripeError as e:
        raise HTTPException(status_code=400, detail=f"Failed to check session: {str(e)}")


@router.get("/onboarding-checkout-success")
async def onboarding_checkout_success(session_id: str):
    """Simple success page shown on client's phone after QR code payment."""
    return HTMLResponse(content="""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Complete</title>
        <style>
            body { font-family: system-ui, -apple-system, sans-serif; background: #111827; color: white;
                   display: flex; align-items: center; justify-content: center; min-height: 100vh;
                   margin: 0; text-align: center; padding: 20px; }
            .container { max-width: 400px; }
            .checkmark { font-size: 64px; margin-bottom: 16px; color: #22c55e; }
            h1 { font-size: 24px; margin-bottom: 8px; }
            p { color: #9ca3af; font-size: 16px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="checkmark">&#10003;</div>
            <h1>Payment Complete!</h1>
            <p>Your payment was successful. You can close this page now.<br>
            The staff member will complete your registration.</p>
        </div>
    </body>
    </html>
    """, status_code=200)


@router.get("/onboarding-checkout-canceled")
async def onboarding_checkout_canceled():
    """Simple cancel page shown on client's phone if they cancel QR code payment."""
    return HTMLResponse(content="""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Payment Canceled</title>
        <style>
            body { font-family: system-ui, -apple-system, sans-serif; background: #111827; color: white;
                   display: flex; align-items: center; justify-content: center; min-height: 100vh;
                   margin: 0; text-align: center; padding: 20px; }
            .container { max-width: 400px; }
            .icon { font-size: 64px; margin-bottom: 16px; color: #ef4444; }
            h1 { font-size: 24px; margin-bottom: 8px; }
            p { color: #9ca3af; font-size: 16px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="icon">&#10007;</div>
            <h1>Payment Canceled</h1>
            <p>The payment was not completed. You can close this page.<br>
            Please ask the staff member if you'd like to try again.</p>
        </div>
    </body>
    </html>
    """, status_code=200)


@router.post("/create-payment-intent")
async def create_onboarding_payment_intent(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a Stripe PaymentIntent for onboarding card payment."""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    import stripe
    import os

    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key or stripe.api_key.startswith("your_"):
        raise HTTPException(status_code=400, detail="Stripe is not configured for this gym")

    plan_id = data.get("plan_id")
    client_name = data.get("client_name", "New Client")
    coupon_code = data.get("coupon_code")

    if not plan_id:
        raise HTTPException(status_code=400, detail="plan_id is required")

    # Get the plan
    plan = db.query(SubscriptionPlanORM).filter(
        SubscriptionPlanORM.id == plan_id,
        SubscriptionPlanORM.gym_id == user.gym_owner_id,
        SubscriptionPlanORM.is_active == True
    ).first()

    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    try:
        # Calculate amount with coupon discount if applicable
        amount = plan.price
        discount_applied = None

        if coupon_code:
            coupon_result = subscription_service.validate_coupon(user.gym_owner_id, coupon_code, plan_id)
            if coupon_result.get("valid"):
                if coupon_result["discount_type"] == "percent":
                    discount = amount * (coupon_result["discount_value"] / 100)
                    amount = max(0, amount - discount)
                    discount_applied = f"{coupon_result['discount_value']}% off"
                else:
                    amount = max(0, amount - coupon_result["discount_value"])
                    discount_applied = f"${coupon_result['discount_value']} off"

        # Convert price to cents (Stripe uses smallest currency unit)
        amount_cents = int(amount * 100)

        if amount_cents < 50:
            # Stripe minimum is 50 cents
            amount_cents = 50

        intent = stripe.PaymentIntent.create(
            amount=amount_cents,
            currency=plan.currency.lower() if plan.currency else "eur",
            metadata={
                "gym_id": user.gym_owner_id,
                "plan_id": plan_id,
                "plan_name": plan.name,
                "client_name": client_name,
                "onboarding": "true",
                "coupon_code": coupon_code or "",
                "discount_applied": discount_applied or ""
            },
            description=f"Gym membership: {plan.name} for {client_name}"
        )

        logger.info(f"Created PaymentIntent {intent.id} for onboarding, amount: {amount_cents}")

        return {
            "client_secret": intent.client_secret,
            "amount": amount,
            "original_amount": plan.price,
            "discount_applied": discount_applied,
            "currency": plan.currency or "EUR"
        }

    except stripe.StripeError as e:
        logger.error(f"Stripe error creating PaymentIntent: {e}")
        raise HTTPException(status_code=400, detail=f"Payment setup failed: {str(e)}")
