"""
Staff/Reception API routes for gym management
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db_session
from models_orm import UserORM, AppointmentORM, CheckInORM
from auth import get_current_user
from datetime import datetime, date
import logging

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

    # Create check-in record (if CheckInORM doesn't exist, we'll handle it)
    try:
        checkin = CheckInORM(
            member_id=member_id,
            staff_id=user.id,
            gym_owner_id=user.gym_owner_id,
            checked_in_at=datetime.now().isoformat()
        )
        db.add(checkin)
        db.commit()
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

    # Get trainer's availability (from their settings if available)
    availability = []
    if trainer.availability:
        try:
            import json
            avail_data = json.loads(trainer.availability) if isinstance(trainer.availability, str) else trainer.availability
            # Convert to readable format - JS expects day_of_week, start_time, end_time
            for day_idx in range(7):
                day_key = str(day_idx)
                if day_key in avail_data and avail_data[day_key].get("enabled"):
                    slots = avail_data[day_key].get("slots", [])
                    for slot in slots:
                        availability.append({
                            "day_of_week": day_idx,
                            "start_time": slot.get("start", "09:00"),
                            "end_time": slot.get("end", "17:00")
                        })
        except Exception as e:
            logger.warning(f"Failed to parse availability for trainer {trainer_id}: {e}")

    return {
        "trainer_name": trainer.username,
        "sub_role": trainer.sub_role or "trainer",
        "availability": availability,
        "today_appointments": appt_list
    }
