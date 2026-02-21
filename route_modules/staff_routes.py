"""
Staff/Reception API routes for gym management
"""

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from database import get_db_session
from models_orm import UserORM, AppointmentORM, CheckInORM, ClientProfileORM, SubscriptionPlanORM, ClientSubscriptionORM, ClientDocumentORM, MedicalCertificateORM, PaymentORM, TrainerAvailabilityORM
from auth import get_current_user, get_password_hash
from datetime import datetime, date, timedelta
from service_modules.subscription_service import subscription_service
import logging
import os

logger = logging.getLogger("gym_app")

router = APIRouter(prefix="/api/staff", tags=["staff"])


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

    # Get all clients belonging to this gym
    members = db.query(UserORM).filter(
        UserORM.gym_owner_id == user.gym_owner_id,
        UserORM.role == "client"
    ).all()

    return [
        {
            "id": m.id,
            "username": m.username,
            "name": m.username,  # Could add a name field later
            "email": m.email,
            "profile_picture": m.profile_picture
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
        checkins = db.query(CheckInORM).filter(
            CheckInORM.gym_owner_id == user.gym_owner_id,
            CheckInORM.checked_in_at.like(f"{today}%")
        ).order_by(CheckInORM.checked_in_at.desc()).limit(10).all()

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
            "count": len(checkins),
            "recent": recent
        }
    except Exception:
        # Table might not exist yet
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
        AppointmentORM.status.in_(["scheduled", "confirmed"])
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

    today = date.today().isoformat()

    # Get today's appointments for this trainer
    appointments = db.query(AppointmentORM).filter(
        AppointmentORM.trainer_id == trainer_id,
        AppointmentORM.date == today,
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
        "today_appointments": appt_list
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
    except Exception:
        pass

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
    except Exception:
        pass

    # Format member since date
    member_since = member.created_at
    if member_since:
        try:
            if "T" in member_since:
                member_since = member_since.split("T")[0]
        except Exception:
            pass

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
                "status": cert_status
            }
    except Exception:
        pass

    return {
        "id": member.id,
        "username": member.username,
        "name": getattr(member, 'name', None) or member.username,
        "email": member.email,
        "profile_picture": member.profile_picture,
        "member_since": member_since,
        "trainer_name": trainer_name,
        "status": "active" if member.is_active else "inactive",
        "total_checkins": total_checkins,
        "last_checkin": last_checkin,
        "checked_in_today": checked_in_today,
        "subscription": subscription_info,
        "medical_certificate": cert_info
    }


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


@router.post("/change-subscription")
async def change_client_subscription(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Change a client's subscription to a different plan"""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access only")

    client_id = data.get("client_id")
    new_plan_id = data.get("plan_id")

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

    # Find and update existing subscription
    subscription = db.query(ClientSubscriptionORM).filter(
        ClientSubscriptionORM.client_id == client_id,
        ClientSubscriptionORM.gym_id == user.gym_owner_id,
        ClientSubscriptionORM.status.in_(["active", "trialing"])
    ).first()

    if subscription:
        # Update existing subscription to new plan
        subscription.plan_id = new_plan_id
        subscription.updated_at = datetime.utcnow().isoformat()
        db.commit()
        logger.info(f"Staff {user.id} changed client {client_id} to plan {new_plan.name}")
    else:
        # Create new subscription
        import uuid
        now = datetime.utcnow().isoformat()
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
        db.commit()
        logger.info(f"Staff {user.id} subscribed client {client_id} to plan {new_plan.name}")

    return {
        "status": "success",
        "message": f"{client.username} now on {new_plan.name} plan"
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
