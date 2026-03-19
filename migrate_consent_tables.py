"""
Migration: Create consent tables and backfill existing relationships.

For existing trainer-client and nutritionist-client relationships,
creates default consent records so existing functionality is preserved.
"""

import json
import logging
from sqlalchemy import text
from database import engine, IS_POSTGRES, SessionLocal
from models_orm import (
    DataConsentORM, SensitiveDataAccessLogORM,
    ClientProfileORM, UserORM
)
from authorization import TRAINER_SCOPES, NUTRITIONIST_SCOPES

logger = logging.getLogger("gym_app")


def run_consent_migration():
    """Create consent tables and backfill existing relationships."""

    # 1. Create tables (if they don't exist)
    from database import Base
    try:
        DataConsentORM.__table__.create(engine, checkfirst=True)
        SensitiveDataAccessLogORM.__table__.create(engine, checkfirst=True)
        logger.info("Consent tables created/verified.")
    except Exception as e:
        logger.warning(f"Table creation note: {e}")

    # 2. Backfill existing trainer-client relationships
    db = SessionLocal()
    try:
        # Check if we already backfilled (avoid duplicate runs)
        existing_consents = db.query(DataConsentORM).count()
        if existing_consents > 0:
            logger.info(f"Consent backfill already done ({existing_consents} records exist). Skipping.")
            return

        # Get all client profiles with assigned trainers
        profiles_with_trainer = db.query(ClientProfileORM).filter(
            ClientProfileORM.trainer_id.isnot(None)
        ).all()

        trainer_count = 0
        for profile in profiles_with_trainer:
            # Verify the trainer exists
            trainer = db.query(UserORM).filter(UserORM.id == profile.trainer_id).first()
            if not trainer:
                continue

            consent = DataConsentORM(
                client_id=profile.id,
                professional_id=profile.trainer_id,
                professional_role="trainer",
                consent_scope=json.dumps(TRAINER_SCOPES),
                status="active",
            )
            db.add(consent)
            trainer_count += 1

        # Get all client profiles with assigned nutritionists
        profiles_with_nutritionist = db.query(ClientProfileORM).filter(
            ClientProfileORM.nutritionist_id.isnot(None)
        ).all()

        nutri_count = 0
        for profile in profiles_with_nutritionist:
            # Verify the nutritionist exists
            nutri = db.query(UserORM).filter(UserORM.id == profile.nutritionist_id).first()
            if not nutri:
                continue

            consent = DataConsentORM(
                client_id=profile.id,
                professional_id=profile.nutritionist_id,
                professional_role="nutritionist",
                consent_scope=json.dumps(NUTRITIONIST_SCOPES),
                status="active",
            )
            db.add(consent)
            nutri_count += 1

        db.commit()
        logger.info(
            f"Consent backfill complete: "
            f"{trainer_count} trainer consents, "
            f"{nutri_count} nutritionist consents created."
        )

    except Exception as e:
        logger.error(f"Consent backfill failed: {e}")
        try:
            db.rollback()
        except Exception:
            pass
    finally:
        db.close()
