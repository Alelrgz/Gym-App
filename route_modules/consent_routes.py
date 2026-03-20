"""
Consent Management Routes

Endpoints for clients to grant/revoke data consent,
and for professionals to check consent status.
Also includes owner audit log access.
"""

import json
import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from database import get_db
from auth import get_current_user
from models_orm import (
    UserORM, ClientProfileORM, DataConsentORM, SensitiveDataAccessLogORM
)
from authorization import (
    ALL_SCOPES, TRAINER_SCOPES, NUTRITIONIST_SCOPES,
    get_user_gym_id, enforce_gym_isolation
)

logger = logging.getLogger("gym_app")
consent_router = APIRouter()


# --- CLIENT: Grant Consent ---

@consent_router.post("/api/client/consent")
async def grant_consent(
    request: Request,
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """
    Client grants data access consent to a professional.
    Body: {
        "professional_id": "uuid",
        "scopes": ["weight", "diet", "training_data", ...],
        "subscription_id": "optional",
        "appointment_id": "optional"
    }
    """
    if current_user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can grant consent")

    body = await request.json()
    professional_id = body.get("professional_id")
    scopes = body.get("scopes", [])
    subscription_id = body.get("subscription_id")
    appointment_id = body.get("appointment_id")

    if not professional_id:
        raise HTTPException(status_code=400, detail="professional_id is required")
    if not scopes:
        raise HTTPException(status_code=400, detail="At least one scope is required")

    # Validate scopes
    invalid = [s for s in scopes if s not in ALL_SCOPES]
    if invalid:
        raise HTTPException(status_code=400, detail=f"Invalid scopes: {invalid}")

    # Verify professional exists and is a trainer/nutritionist
    professional = db.query(UserORM).filter(UserORM.id == professional_id).first()
    if not professional:
        raise HTTPException(status_code=404, detail="Professional not found")

    effective_role = professional.sub_role or professional.role
    if effective_role not in ("trainer", "nutritionist", "both"):
        raise HTTPException(status_code=400, detail="User is not a trainer or nutritionist")

    # Check if active consent already exists — update it
    existing = db.query(DataConsentORM).filter(
        DataConsentORM.client_id == current_user.id,
        DataConsentORM.professional_id == professional_id,
        DataConsentORM.status == "active"
    ).first()

    if existing:
        # Merge scopes
        try:
            current_scopes = json.loads(existing.consent_scope) if existing.consent_scope else []
        except json.JSONDecodeError:
            current_scopes = []
        merged = list(set(current_scopes + scopes))
        existing.consent_scope = json.dumps(merged)
        db.commit()
        return {
            "status": "updated",
            "consent_id": existing.id,
            "scopes": merged,
            "message": "Consent updated with additional scopes"
        }

    # Create new consent
    consent = DataConsentORM(
        client_id=current_user.id,
        professional_id=professional_id,
        professional_role=effective_role,
        consent_scope=json.dumps(scopes),
        subscription_id=subscription_id,
        appointment_id=appointment_id,
        status="active"
    )
    db.add(consent)
    db.commit()
    db.refresh(consent)

    logger.info(f"Consent granted: client={current_user.id} -> professional={professional_id}, scopes={scopes}")

    return {
        "status": "granted",
        "consent_id": consent.id,
        "scopes": scopes,
        "message": "Data access consent granted"
    }


# --- CLIENT: List My Consents ---

@consent_router.get("/api/client/consents")
async def list_my_consents(
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """List all active and revoked consents for the current client."""
    if current_user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view their consents")

    consents = db.query(DataConsentORM).filter(
        DataConsentORM.client_id == current_user.id
    ).order_by(DataConsentORM.granted_at.desc()).limit(200).all()

    # Batch fetch all professional names (avoid N+1)
    prof_ids = list({c.professional_id for c in consents if c.professional_id})
    profs = db.query(UserORM).filter(UserORM.id.in_(prof_ids)).all() if prof_ids else []
    prof_lookup = {p.id: p.username for p in profs}

    result = []
    for c in consents:
        try:
            scopes = json.loads(c.consent_scope) if c.consent_scope else []
        except json.JSONDecodeError:
            scopes = []

        result.append({
            "id": c.id,
            "professional_id": c.professional_id,
            "professional_name": prof_lookup.get(c.professional_id, "Unknown"),
            "professional_role": c.professional_role,
            "scopes": scopes,
            "status": c.status,
            "granted_at": c.granted_at,
            "revoked_at": c.revoked_at,
            "revoked_reason": c.revoked_reason,
        })

    return {"consents": result}


# --- CLIENT: Revoke Consent ---

@consent_router.post("/api/client/consent/revoke")
async def revoke_consent(
    request: Request,
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """
    Client revokes data access consent.
    Body: { "consent_id": 1, "reason": "optional reason" }
    OR: { "professional_id": "uuid", "reason": "optional" }
    """
    if current_user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can revoke consent")

    body = await request.json()
    consent_id = body.get("consent_id")
    professional_id = body.get("professional_id")
    reason = body.get("reason", "")

    if consent_id:
        consent = db.query(DataConsentORM).filter(
            DataConsentORM.id == consent_id,
            DataConsentORM.client_id == current_user.id,
            DataConsentORM.status == "active"
        ).first()
    elif professional_id:
        consent = db.query(DataConsentORM).filter(
            DataConsentORM.professional_id == professional_id,
            DataConsentORM.client_id == current_user.id,
            DataConsentORM.status == "active"
        ).first()
    else:
        raise HTTPException(status_code=400, detail="consent_id or professional_id required")

    if not consent:
        raise HTTPException(status_code=404, detail="No active consent found")

    consent.status = "revoked"
    consent.revoked_at = datetime.utcnow().isoformat()
    consent.revoked_reason = reason or None
    db.commit()

    logger.info(f"Consent revoked: client={current_user.id}, consent_id={consent.id}")

    return {"status": "revoked", "message": "Data access consent has been revoked"}


# --- CLIENT: Check Consent for a Professional ---

@consent_router.get("/api/client/consent/check/{professional_id}")
async def check_consent_for_professional(
    professional_id: str,
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """Check if the client has active consent for a specific professional."""
    if current_user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can check their consents")

    consent = db.query(DataConsentORM).filter(
        DataConsentORM.client_id == current_user.id,
        DataConsentORM.professional_id == professional_id,
        DataConsentORM.status == "active"
    ).first()

    if consent:
        try:
            scopes = json.loads(consent.consent_scope) if consent.consent_scope else []
        except json.JSONDecodeError:
            scopes = []
        return {"has_consent": True, "scopes": scopes, "consent_id": consent.id}

    return {"has_consent": False, "scopes": [], "consent_id": None}


# --- PROFESSIONAL: Check Consent Status for a Client ---

@consent_router.get("/api/professional/client/{client_id}/consent-status")
async def get_consent_status_for_client(
    client_id: str,
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """
    Trainer/nutritionist checks what data scopes they have consent for
    with a specific client.
    """
    effective_role = current_user.sub_role or current_user.role
    if effective_role not in ("trainer", "nutritionist", "both"):
        raise HTTPException(status_code=403, detail="Only professionals can check consent status")

    consent = db.query(DataConsentORM).filter(
        DataConsentORM.professional_id == current_user.id,
        DataConsentORM.client_id == client_id,
        DataConsentORM.status == "active"
    ).first()

    if consent:
        try:
            scopes = json.loads(consent.consent_scope) if consent.consent_scope else []
        except json.JSONDecodeError:
            scopes = []
        return {
            "has_consent": True,
            "scopes": scopes,
            "consent_id": consent.id,
            "granted_at": consent.granted_at
        }

    return {"has_consent": False, "scopes": [], "consent_id": None, "granted_at": None}


# --- OWNER: Audit Log ---

@consent_router.get("/api/owner/audit-log")
async def get_audit_log(
    request: Request,
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """
    Owner views the audit log of sensitive data access in their gym.
    Query params: ?limit=50&offset=0&client_id=&accessor_id=&resource_type=
    """
    if current_user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view audit logs")

    limit = int(request.query_params.get("limit", "50"))
    offset = int(request.query_params.get("offset", "0"))
    filter_client = request.query_params.get("client_id")
    filter_accessor = request.query_params.get("accessor_id")
    filter_type = request.query_params.get("resource_type")

    limit = min(limit, 200)  # Cap at 200

    query = db.query(SensitiveDataAccessLogORM)

    # Filter to only this gym's data
    # Get all client IDs in this gym
    gym_clients = db.query(ClientProfileORM.id).filter(
        ClientProfileORM.gym_id == current_user.id
    ).all()
    gym_client_ids = [c[0] for c in gym_clients]

    if not gym_client_ids:
        return {"logs": [], "total": 0}

    query = query.filter(SensitiveDataAccessLogORM.client_id.in_(gym_client_ids))

    if filter_client:
        query = query.filter(SensitiveDataAccessLogORM.client_id == filter_client)
    if filter_accessor:
        query = query.filter(SensitiveDataAccessLogORM.accessor_id == filter_accessor)
    if filter_type:
        query = query.filter(SensitiveDataAccessLogORM.resource_type == filter_type)

    total = query.count()
    logs = query.order_by(SensitiveDataAccessLogORM.accessed_at.desc()).offset(offset).limit(limit).all()

    # Batch fetch all user names (avoid N+1)
    all_user_ids = list({log.accessor_id for log in logs} | {log.client_id for log in logs})
    users = db.query(UserORM.id, UserORM.username).filter(UserORM.id.in_(all_user_ids)).all() if all_user_ids else []
    user_cache = {u.id: u.username for u in users}

    result = []
    for log in logs:
        result.append({
            "id": log.id,
            "accessor_name": user_cache.get(log.accessor_id, "Unknown"),
            "accessor_role": log.accessor_role,
            "client_name": user_cache.get(log.client_id, "Unknown"),
            "resource_type": log.resource_type,
            "action": log.action,
            "endpoint": log.endpoint,
            "accessed_at": log.accessed_at,
        })

    return {"logs": result, "total": total}


# --- OWNER: Consent Overview ---

@consent_router.get("/api/owner/consent-overview")
async def get_consent_overview(
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """Owner views all active consents in their gym."""
    if current_user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view consent overview")

    # Get all clients in this gym
    gym_clients = db.query(ClientProfileORM.id).filter(
        ClientProfileORM.gym_id == current_user.id
    ).all()
    gym_client_ids = [c[0] for c in gym_clients]

    if not gym_client_ids:
        return {"consents": [], "summary": {"total_active": 0, "total_revoked": 0}}

    consents = db.query(DataConsentORM).filter(
        DataConsentORM.client_id.in_(gym_client_ids)
    ).order_by(DataConsentORM.granted_at.desc()).all()

    # Batch fetch all user names (avoid N+1)
    all_user_ids = list({c.client_id for c in consents} | {c.professional_id for c in consents})
    users = db.query(UserORM.id, UserORM.username).filter(UserORM.id.in_(all_user_ids)).all() if all_user_ids else []
    user_cache = {u.id: u.username for u in users}

    active = 0
    revoked = 0
    result = []

    for c in consents:
        try:
            scopes = json.loads(c.consent_scope) if c.consent_scope else []
        except json.JSONDecodeError:
            scopes = []

        if c.status == "active":
            active += 1
        else:
            revoked += 1

        result.append({
            "id": c.id,
            "client_name": user_cache.get(c.client_id, "Unknown"),
            "professional_name": user_cache.get(c.professional_id, "Unknown"),
            "professional_role": c.professional_role,
            "scopes": scopes,
            "status": c.status,
            "granted_at": c.granted_at,
            "revoked_at": c.revoked_at,
        })

    return {
        "consents": result,
        "summary": {"total_active": active, "total_revoked": revoked}
    }
