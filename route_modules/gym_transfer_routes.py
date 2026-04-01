"""
Gym Transfer Routes — handles client gym switching.

Two flows:
A) Client-initiated: Client flags themselves as wanting to transfer → walks into new gym → staff completes it
B) Staff-initiated: Client walks in → staff searches them system-wide → pulls them into their gym

Both flows: old subscription cancelled, client moved, old assignments cleared.
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from auth import get_current_user
from gym_context import get_gym_context
from models_orm import UserORM, GymORM, GymTransferRequestORM, ClientProfileORM, ClientSubscriptionORM
from database import get_db_session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import uuid
import logging

logger = logging.getLogger("gym_app")
router = APIRouter()


class ClientTransferRequest(BaseModel):
    note: Optional[str] = None


class StaffTransferRequest(BaseModel):
    client_id: str


class RejectTransferRequest(BaseModel):
    note: Optional[str] = None


# ─── SHARED: execute the actual transfer ─────────────────────────

def _execute_transfer(db, client_id: str, from_gym_id: str, to_gym_id: str, reviewed_by: str):
    """Cancel old sub, move client to new gym, clear assignments. Returns gym name."""
    # 1. Cancel active subscription at old gym
    if from_gym_id:
        active_sub = db.query(ClientSubscriptionORM).filter(
            ClientSubscriptionORM.client_id == client_id,
            ClientSubscriptionORM.gym_id == from_gym_id,
            ClientSubscriptionORM.status == "active"
        ).first()
        if active_sub:
            if active_sub.stripe_subscription_id:
                try:
                    import stripe
                    stripe.Subscription.delete(active_sub.stripe_subscription_id)
                except Exception as e:
                    logger.warning(f"Stripe cancel during transfer: {e}")
            active_sub.status = "canceled"
            active_sub.canceled_at = datetime.utcnow().isoformat()
            active_sub.ended_at = datetime.utcnow().isoformat()

    # 2. Move client to new gym
    profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
    new_gym = db.query(GymORM).filter(GymORM.id == to_gym_id).first()
    gym_name = new_gym.name if new_gym else "Palestra"

    if profile:
        profile.gym_id = new_gym.owner_id if new_gym else to_gym_id
        profile.trainer_id = None
        profile.nutritionist_id = None
        profile.current_split_id = None
        profile.split_expiry_date = None

    # 3. Send notification
    try:
        from models_orm import NotificationORM
        db.add(NotificationORM(
            id=str(uuid.uuid4()),
            user_id=client_id,
            type="gym_transfer",
            title="Trasferimento completato",
            message=f"Il tuo trasferimento a {gym_name} è stato completato. Benvenuto!",
        ))
    except Exception:
        pass

    return gym_name


# ─── CLIENT ENDPOINTS ────────────────────────────────────────────

@router.post("/api/client/request-gym-transfer")
async def request_gym_transfer(
    body: ClientTransferRequest,
    user: UserORM = Depends(get_current_user),
):
    """Client flags themselves as wanting to transfer. No gym code needed —
    they just walk into the new gym and staff completes it."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Solo i clienti possono richiedere un trasferimento")

    db = get_db_session()
    try:
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user.id).first()
        if not profile or not profile.gym_id:
            raise HTTPException(status_code=400, detail="Non sei iscritto a nessuna palestra")

        # Check for existing pending transfer
        existing = db.query(GymTransferRequestORM).filter(
            GymTransferRequestORM.client_id == user.id,
            GymTransferRequestORM.status == "pending"
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail="Hai già una richiesta di trasferimento in corso")

        transfer = GymTransferRequestORM(
            id=str(uuid.uuid4()),
            client_id=user.id,
            from_gym_id=profile.gym_id,
            to_gym_id=None,  # No target yet — staff will complete
            status="pending",
            client_note=body.note,
        )
        db.add(transfer)
        db.commit()

        logger.info(f"Client {user.id} requested gym transfer")
        return {"status": "success", "message": "Richiesta di trasferimento registrata. Recati nella nuova palestra per completare il trasferimento."}

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Error requesting gym transfer: {e}")
        raise HTTPException(status_code=500, detail="Errore nel richiedere il trasferimento")
    finally:
        db.close()


@router.get("/api/client/transfer-status")
async def get_transfer_status(user: UserORM = Depends(get_current_user)):
    """Get client's pending transfer request (if any)."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Solo i clienti")

    db = get_db_session()
    try:
        transfer = db.query(GymTransferRequestORM).filter(
            GymTransferRequestORM.client_id == user.id,
            GymTransferRequestORM.status == "pending"
        ).first()

        if not transfer:
            return {"has_pending": False}

        return {
            "has_pending": True,
            "transfer_id": transfer.id,
            "created_at": transfer.created_at,
        }
    finally:
        db.close()


@router.post("/api/client/cancel-transfer")
async def cancel_transfer(user: UserORM = Depends(get_current_user)):
    """Cancel a pending transfer request."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Solo i clienti")

    db = get_db_session()
    try:
        transfer = db.query(GymTransferRequestORM).filter(
            GymTransferRequestORM.client_id == user.id,
            GymTransferRequestORM.status == "pending"
        ).first()
        if not transfer:
            raise HTTPException(status_code=404, detail="Nessuna richiesta di trasferimento in corso")

        transfer.status = "cancelled"
        transfer.reviewed_at = datetime.utcnow().isoformat()
        db.commit()

        return {"status": "success", "message": "Richiesta di trasferimento annullata"}
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="Errore nell'annullamento")
    finally:
        db.close()


# ─── STAFF / OWNER ENDPOINTS ────────────────────────────────────

@router.get("/api/staff/search-clients")
async def search_clients_system_wide(
    q: str = Query(..., min_length=2),
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Search ALL clients in the FitOS system (not just this gym).
    Used by staff to find clients from other gyms for transfers."""
    if user.role not in ("owner",) and not (user.role == "owner" and user.sub_role == "staff"):
        raise HTTPException(status_code=403, detail="Solo staff e proprietari")

    db = get_db_session()
    try:
        search = f"%{q.strip().lower()}%"

        # Search by username or profile name
        clients = db.query(UserORM).filter(
            UserORM.role == "client",
            UserORM.is_active == True,
            UserORM.username.ilike(search)
        ).limit(20).all()

        # Also search by profile name
        profile_matches = db.query(ClientProfileORM).filter(
            ClientProfileORM.name.ilike(search)
        ).limit(20).all()
        profile_client_ids = {p.id for p in profile_matches}

        # Merge results
        if profile_client_ids:
            extra = db.query(UserORM).filter(
                UserORM.id.in_(profile_client_ids),
                UserORM.role == "client",
                UserORM.is_active == True,
            ).all()
            seen = {c.id for c in clients}
            clients.extend(c for c in extra if c.id not in seen)

        result = []
        for c in clients[:20]:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == c.id).first()
            current_gym_name = None
            is_own_member = False
            wants_transfer = False

            if profile and profile.gym_id:
                if profile.gym_id == gym_id:
                    is_own_member = True
                # Resolve gym name
                gym_orm = db.query(GymORM).filter(GymORM.owner_id == profile.gym_id).first()
                if gym_orm:
                    current_gym_name = gym_orm.name
                else:
                    owner = db.query(UserORM).filter(UserORM.id == profile.gym_id).first()
                    current_gym_name = owner.username if owner else None

            # Check if client has a pending transfer
            pending = db.query(GymTransferRequestORM).filter(
                GymTransferRequestORM.client_id == c.id,
                GymTransferRequestORM.status == "pending"
            ).first()
            if pending:
                wants_transfer = True

            result.append({
                "id": c.id,
                "username": c.username,
                "name": profile.name if profile else c.username,
                "profile_picture": c.profile_picture,
                "current_gym": current_gym_name,
                "is_own_member": is_own_member,
                "wants_transfer": wants_transfer,
                "has_gym": profile.gym_id is not None if profile else False,
            })

        return result
    finally:
        db.close()


@router.post("/api/staff/transfer-client")
async def staff_initiate_transfer(
    body: StaffTransferRequest,
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Staff-initiated: pull a client from another gym into this gym.
    Cancels old subscription, moves client, clears assignments."""
    if user.role not in ("owner",) and not (user.role == "owner" and user.sub_role == "staff"):
        raise HTTPException(status_code=403, detail="Solo staff e proprietari")

    db = get_db_session()
    try:
        client = db.query(UserORM).filter(
            UserORM.id == body.client_id,
            UserORM.role == "client"
        ).first()
        if not client:
            raise HTTPException(status_code=404, detail="Cliente non trovato")

        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == body.client_id).first()
        from_gym_id = profile.gym_id if profile else None

        # Can't transfer to same gym
        if from_gym_id == gym_id:
            raise HTTPException(status_code=400, detail="Il cliente è già iscritto a questa palestra")

        # Check owner_id match too
        new_gym = db.query(GymORM).filter(GymORM.id == gym_id).first()
        if new_gym and from_gym_id == new_gym.owner_id:
            raise HTTPException(status_code=400, detail="Il cliente è già iscritto a questa palestra")

        # Execute transfer
        gym_name = _execute_transfer(db, body.client_id, from_gym_id, gym_id, user.id)

        # Close any pending transfer request from this client
        pending = db.query(GymTransferRequestORM).filter(
            GymTransferRequestORM.client_id == body.client_id,
            GymTransferRequestORM.status == "pending"
        ).first()
        if pending:
            pending.status = "approved"
            pending.to_gym_id = gym_id
            pending.reviewed_by = user.id
            pending.reviewed_at = datetime.utcnow().isoformat()

        # Log the transfer
        transfer = GymTransferRequestORM(
            id=str(uuid.uuid4()),
            client_id=body.client_id,
            from_gym_id=from_gym_id,
            to_gym_id=gym_id,
            status="approved",
            reviewed_by=user.id,
            reviewed_at=datetime.utcnow().isoformat(),
        )
        db.add(transfer)
        db.commit()

        logger.info(f"Staff {user.id} transferred client {body.client_id} to gym {gym_id}")

        return {
            "status": "success",
            "message": f"Cliente trasferito a {gym_name}",
            "client_name": (profile.name if profile else None) or client.username,
        }

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Error in staff transfer: {e}")
        raise HTTPException(status_code=500, detail="Errore nel trasferimento")
    finally:
        db.close()


@router.get("/api/staff/pending-transfers")
async def get_pending_transfers(
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Get clients who flagged themselves as wanting to transfer (visible to all gyms)."""
    if user.role not in ("owner",) and not (user.role == "owner" and user.sub_role == "staff"):
        raise HTTPException(status_code=403, detail="Solo staff e proprietari")

    db = get_db_session()
    try:
        # Show transfers that target this gym OR have no target (client just flagged)
        transfers = db.query(GymTransferRequestORM).filter(
            GymTransferRequestORM.status == "pending"
        ).all()

        result = []
        for t in transfers:
            client = db.query(UserORM).filter(UserORM.id == t.client_id).first()
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == t.client_id).first()

            # Skip if already our member
            if profile and profile.gym_id and (profile.gym_id == gym_id):
                continue

            from_gym = None
            if t.from_gym_id:
                from_gym_orm = db.query(GymORM).filter(GymORM.owner_id == t.from_gym_id).first()
                if from_gym_orm:
                    from_gym = from_gym_orm.name
                else:
                    from_owner = db.query(UserORM).filter(UserORM.id == t.from_gym_id).first()
                    from_gym = from_owner.username if from_owner else None

            result.append({
                "id": t.id,
                "client_id": t.client_id,
                "client_name": (profile.name if profile else None) or (client.username if client else "Unknown"),
                "client_profile_picture": client.profile_picture if client else None,
                "from_gym": from_gym,
                "note": t.client_note,
                "created_at": t.created_at,
            })

        return result
    finally:
        db.close()


@router.post("/api/staff/approve-transfer/{transfer_id}")
async def approve_transfer(
    transfer_id: str,
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Accept a client's transfer request — pull them into this gym."""
    if user.role not in ("owner",) and not (user.role == "owner" and user.sub_role == "staff"):
        raise HTTPException(status_code=403, detail="Solo staff e proprietari")

    db = get_db_session()
    try:
        transfer = db.query(GymTransferRequestORM).filter(
            GymTransferRequestORM.id == transfer_id,
            GymTransferRequestORM.status == "pending"
        ).first()
        if not transfer:
            raise HTTPException(status_code=404, detail="Richiesta non trovata")

        _execute_transfer(db, transfer.client_id, transfer.from_gym_id, gym_id, user.id)

        transfer.status = "approved"
        transfer.to_gym_id = gym_id
        transfer.reviewed_by = user.id
        transfer.reviewed_at = datetime.utcnow().isoformat()
        db.commit()

        logger.info(f"Transfer {transfer_id} approved by {user.id}")
        return {"status": "success", "message": "Trasferimento completato"}

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Error approving transfer: {e}")
        raise HTTPException(status_code=500, detail="Errore nel trasferimento")
    finally:
        db.close()


@router.post("/api/staff/reject-transfer/{transfer_id}")
async def reject_transfer(
    transfer_id: str,
    body: RejectTransferRequest = None,
    user: UserORM = Depends(get_current_user),
    gym_id: str = Depends(get_gym_context),
):
    """Reject a transfer request."""
    if user.role not in ("owner",) and not (user.role == "owner" and user.sub_role == "staff"):
        raise HTTPException(status_code=403, detail="Solo staff e proprietari")

    db = get_db_session()
    try:
        transfer = db.query(GymTransferRequestORM).filter(
            GymTransferRequestORM.id == transfer_id,
            GymTransferRequestORM.status == "pending"
        ).first()
        if not transfer:
            raise HTTPException(status_code=404, detail="Richiesta non trovata")

        transfer.status = "rejected"
        transfer.staff_note = body.note if body else None
        transfer.reviewed_by = user.id
        transfer.reviewed_at = datetime.utcnow().isoformat()
        db.commit()

        # Notify client
        try:
            from models_orm import NotificationORM
            db.add(NotificationORM(
                id=str(uuid.uuid4()),
                user_id=transfer.client_id,
                type="gym_transfer",
                title="Trasferimento rifiutato",
                message="La tua richiesta di trasferimento è stata rifiutata.",
            ))
            db.commit()
        except Exception:
            pass

        return {"status": "success", "message": "Trasferimento rifiutato"}

    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Error rejecting transfer: {e}")
        raise HTTPException(status_code=500, detail="Errore nel rifiuto")
    finally:
        db.close()
