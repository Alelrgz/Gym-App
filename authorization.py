"""
Authorization Module — Consent-Based Access Control

Provides FastAPI dependencies for:
1. Role checking
2. Gym isolation (users can only access data within their gym)
3. Consent verification (professionals need client consent for sensitive data)
4. Audit logging (all sensitive data access is recorded)
"""

import json
import logging
from typing import Optional, List
from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session
from database import get_db
from auth import get_current_user
from models_orm import (
    UserORM, ClientProfileORM, DataConsentORM, SensitiveDataAccessLogORM
)

logger = logging.getLogger("gym_app")

# --- SENSITIVE DATA SCOPES ---
# These define what types of data require consent

TRAINER_SCOPES = ["weight", "training_data", "physique_photos", "medical_cert"]
NUTRITIONIST_SCOPES = ["weight", "body_composition", "diet", "health_data"]
ALL_SCOPES = ["weight", "body_composition", "diet", "health_data", "medical_cert", "physique_photos", "training_data"]

# Scopes that staff/owners can NEVER access (sensitive health data)
STAFF_BLOCKED_SCOPES = ALL_SCOPES
OWNER_BLOCKED_SCOPES = ["diet", "health_data", "physique_photos", "body_composition", "weight"]


# --- GYM ISOLATION ---

def get_user_gym_id(user: UserORM, db: Session) -> Optional[str]:
    """Extract the gym ID for any user based on their role."""
    if user.role == "owner":
        return user.id  # Owner IS the gym
    elif user.role in ("trainer", "nutritionist", "staff") or (
        user.role == "trainer" and user.sub_role in ("trainer", "nutritionist", "both")
    ):
        return user.gym_owner_id
    elif user.role == "client":
        profile = db.query(ClientProfileORM).filter(
            ClientProfileORM.id == user.id
        ).first()
        return profile.gym_id if profile else None
    return None


def enforce_gym_isolation(current_user: UserORM, client_id: str, db: Session):
    """
    Verify the current user and target client belong to the same gym.
    Raises 403 if they don't.
    """
    # Self-access is always allowed
    if current_user.id == client_id:
        return

    user_gym_id = get_user_gym_id(current_user, db)
    if not user_gym_id:
        raise HTTPException(status_code=403, detail="You are not associated with any gym")

    client_profile = db.query(ClientProfileORM).filter(
        ClientProfileORM.id == client_id
    ).first()
    if not client_profile:
        raise HTTPException(status_code=404, detail="Client not found")

    client_gym_id = client_profile.gym_id
    if not client_gym_id or user_gym_id != client_gym_id:
        raise HTTPException(status_code=403, detail="Client is not in your gym")


# --- CONSENT CHECKS ---

def get_active_consent(
    professional_id: str, client_id: str, db: Session
) -> Optional[DataConsentORM]:
    """Get the active consent record between a professional and client."""
    return db.query(DataConsentORM).filter(
        DataConsentORM.professional_id == professional_id,
        DataConsentORM.client_id == client_id,
        DataConsentORM.status == "active"
    ).first()


def check_consent_scope(consent: DataConsentORM, scope: str) -> bool:
    """Check if a consent record includes a specific scope."""
    if not consent or not consent.consent_scope:
        return False
    try:
        scopes = json.loads(consent.consent_scope)
        return scope in scopes
    except (json.JSONDecodeError, TypeError):
        return False


def enforce_consent(
    current_user: UserORM, client_id: str, scope: str, db: Session
) -> Optional[int]:
    """
    Verify the professional has active consent from the client for the given scope.
    Returns the consent_id if authorized.
    Raises 403 if not.
    """
    consent = get_active_consent(current_user.id, client_id, db)

    if not consent:
        raise HTTPException(
            status_code=403,
            detail=f"No active data consent from this client. "
                   f"The client must grant you access to their data."
        )

    if not check_consent_scope(consent, scope):
        raise HTTPException(
            status_code=403,
            detail=f"Client has not consented to share '{scope}' data with you."
        )

    return consent.id


# --- AUDIT LOGGING ---

def log_sensitive_access(
    accessor: UserORM,
    client_id: str,
    resource_type: str,
    action: str,
    endpoint: str,
    db: Session,
    request: Optional[Request] = None,
    consent_id: Optional[int] = None
):
    """Record an access to sensitive data in the audit log."""
    try:
        log_entry = SensitiveDataAccessLogORM(
            accessor_id=accessor.id,
            accessor_role=accessor.role if accessor.sub_role is None else accessor.sub_role,
            client_id=client_id,
            resource_type=resource_type,
            action=action,
            endpoint=endpoint,
            consent_id=consent_id,
            ip_address=request.client.host if request and request.client else None,
            user_agent=(request.headers.get("user-agent", "")[:200]
                        if request else None),
        )
        db.add(log_entry)
        db.commit()
    except Exception as e:
        logger.warning(f"Failed to write audit log: {e}")
        try:
            db.rollback()
        except Exception:
            pass


# --- COMBINED AUTHORIZATION ---

def authorize_client_access(
    current_user: UserORM,
    client_id: str,
    scope: Optional[str],
    action: str,
    endpoint: str,
    db: Session,
    request: Optional[Request] = None
):
    """
    Full authorization check for accessing a client's data.

    Steps:
    1. Self-access → always allowed (no audit)
    2. Role check → must be trainer/nutritionist/owner/staff
    3. Gym isolation → must be in the same gym
    4. Staff → blocked from all sensitive data
    5. Owner → blocked from health-related sensitive data
    6. Trainer/Nutritionist → requires active consent for the scope
    7. Audit log → record the access

    Returns consent_id if consent was used, None otherwise.
    """
    # 1. Self-access
    if current_user.id == client_id:
        return None

    # 2. Role check
    effective_role = current_user.sub_role or current_user.role
    if effective_role not in ("trainer", "nutritionist", "both", "owner", "staff"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    # 3. Gym isolation
    enforce_gym_isolation(current_user, client_id, db)

    consent_id = None

    if scope:
        # 4. Staff — no sensitive data access
        if effective_role == "staff":
            raise HTTPException(
                status_code=403,
                detail="Staff members cannot access sensitive client data"
            )

        # 5. Owner — limited sensitive data access
        if effective_role == "owner" and scope in OWNER_BLOCKED_SCOPES:
            raise HTTPException(
                status_code=403,
                detail="Owners cannot access this type of sensitive data"
            )

        # 6. Trainer/Nutritionist — require consent
        if effective_role in ("trainer", "nutritionist", "both"):
            consent_id = enforce_consent(current_user, client_id, scope, db)

        # 7. Audit log
        log_sensitive_access(
            accessor=current_user,
            client_id=client_id,
            resource_type=scope,
            action=action,
            endpoint=endpoint,
            db=db,
            request=request,
            consent_id=consent_id
        )

    return consent_id


def get_consented_client_ids(
    professional_id: str, scope: str, db: Session
) -> List[str]:
    """
    Get list of client IDs that have given active consent
    to a professional for a specific scope.
    """
    consents = db.query(DataConsentORM).filter(
        DataConsentORM.professional_id == professional_id,
        DataConsentORM.status == "active"
    ).all()

    client_ids = []
    for consent in consents:
        if check_consent_scope(consent, scope):
            client_ids.append(consent.client_id)

    return client_ids
