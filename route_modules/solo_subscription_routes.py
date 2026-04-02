"""
Solo Subscription Routes — handles the €4.99/month solo plan for gymless clients.
Uses Stripe Checkout Sessions (same pattern as appointment booking).
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from auth import get_current_user
from models_orm import UserORM, ClientProfileORM
from database import get_db_session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
import os
import secrets
import stripe
import logging

logger = logging.getLogger("gym_app")
router = APIRouter()

PLANS = {
    "solo": {"price": 499, "name": "FitOS Solo", "description": "Allenamenti personalizzati, diario alimentare, tracking"},
    "solo_pro": {"price": 999, "name": "FitOS Solo Pro", "description": "Workout AI, piano alimentare AI, analisi avanzata"},
}


class SoloCheckoutRequest(BaseModel):
    plan: Optional[str] = "solo"


class TrialEmailRequest(BaseModel):
    email: str


class TrialVerifyRequest(BaseModel):
    email: str
    code: str


# In-memory verification codes (short-lived, no need for DB)
_pending_verifications: dict[str, dict] = {}


@router.post("/api/client/solo-checkout")
async def create_solo_checkout(
    body: SoloCheckoutRequest,
    request: Request,
    user: UserORM = Depends(get_current_user),
):
    """Create a Stripe Checkout Session for a solo subscription plan."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Solo i clienti")

    plan_key = body.plan or "solo"
    plan = PLANS.get(plan_key)
    if not plan:
        raise HTTPException(status_code=400, detail="Piano non valido")

    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Pagamenti non configurati")

    db = get_db_session()
    try:
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user.id).first()
        if profile and profile.account_type in ("solo_premium", "solo_pro"):
            raise HTTPException(status_code=400, detail="Hai già un abbonamento Solo attivo")

        # Determine base URL for redirects
        origin = request.headers.get("origin") or request.headers.get("referer") or "https://fitos-eu.onrender.com"
        base_url = origin.rstrip("/")

        session = stripe.checkout.Session.create(
            mode="subscription",
            payment_method_types=["card"],
            line_items=[{
                "price_data": {
                    "currency": "eur",
                    "unit_amount": plan["price"],
                    "recurring": {"interval": "month"},
                    "product_data": {
                        "name": plan["name"],
                        "description": plan["description"],
                    },
                },
                "quantity": 1,
            }],
            success_url=f"{base_url}/api/client/solo-checkout-success?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=f"{base_url}/?solo_cancelled=true",
            client_reference_id=user.id,
            customer_email=user.email,
            metadata={
                "user_id": user.id,
                "type": "solo_subscription",
                "plan": plan_key,
            },
        )

        return {"checkout_url": session.url}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Solo checkout error: {e}")
        raise HTTPException(status_code=500, detail="Errore nella creazione del pagamento")
    finally:
        db.close()


@router.get("/api/client/solo-checkout-success")
async def solo_checkout_success(session_id: str):
    """Handle successful solo subscription payment — activate the account."""
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Stripe not configured")

    db = get_db_session()
    try:
        session = stripe.checkout.Session.retrieve(session_id)
        user_id = session.client_reference_id

        if not user_id:
            raise HTTPException(status_code=400, detail="Invalid session")

        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user_id).first()
        if profile:
            plan_key = session.metadata.get("plan", "solo") if session.metadata else "solo"
            profile.account_type = "solo_pro" if plan_key == "solo_pro" else "solo_premium"
            profile.is_premium = True
            db.commit()
            logger.info(f"Solo subscription activated for {user_id}")

        # Redirect back to app
        return RedirectResponse(url="/?role=client&solo_success=true")

    except Exception as e:
        logger.error(f"Solo checkout success error: {e}")
        return RedirectResponse(url="/?role=client&solo_error=true")
    finally:
        db.close()


# ─── FREE TRIAL WITH EMAIL VERIFICATION ─────────────────────────

TRIAL_DAYS = 15


@router.post("/api/client/trial-send-code")
async def trial_send_verification_code(
    body: TrialEmailRequest,
    user: UserORM = Depends(get_current_user),
):
    """Send a 6-digit verification code to the user's email. Blocks disposable emails."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Solo i clienti")

    email = body.email.strip().lower()

    # Check disposable email
    from service_modules.disposable_email_checker import validate_email_for_trial
    is_valid, error_msg = validate_email_for_trial(email)
    if not is_valid:
        raise HTTPException(status_code=400, detail=error_msg)

    db = get_db_session()
    try:
        # Check if user already had a trial
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user.id).first()
        if profile and profile.trial_started_at:
            raise HTTPException(status_code=400, detail="Hai già usufruito della prova gratuita")

        # Check if email is already used by another verified user
        other = db.query(UserORM).filter(
            UserORM.email == email,
            UserORM.id != user.id
        ).first()
        if other:
            other_profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == other.id).first()
            if other_profile and other_profile.email_verified:
                raise HTTPException(status_code=400, detail="Questa email è già associata a un altro account")

        # Generate 6-digit code
        code = f"{secrets.randbelow(900000) + 100000}"
        _pending_verifications[user.id] = {
            "code": code,
            "email": email,
            "expires": (datetime.utcnow() + timedelta(minutes=10)).isoformat(),
        }

        # Send email
        from service_modules.email_service import get_email_service
        email_service = get_email_service()
        if not email_service.is_configured():
            raise HTTPException(status_code=500, detail="Servizio email non configurato")

        html = f"""
        <div style="font-family: -apple-system, sans-serif; max-width: 400px; margin: 0 auto; padding: 32px;">
            <h2 style="color: #22c55e; margin-bottom: 8px;">FitOS</h2>
            <p>Il tuo codice di verifica:</p>
            <div style="font-size: 32px; font-weight: 800; letter-spacing: 4px; color: #22c55e;
                        background: #1a1a2e; padding: 16px 24px; border-radius: 12px; text-align: center; margin: 16px 0;">
                {code}
            </div>
            <p style="color: #888; font-size: 13px;">Il codice scade tra 10 minuti.</p>
        </div>
        """
        sent = email_service.send_email(email, "Il tuo codice FitOS", html)
        if not sent:
            raise HTTPException(status_code=500, detail="Errore nell'invio dell'email")

        logger.info(f"Verification code sent to {email} for user {user.id}")
        return {"status": "success", "message": "Codice inviato"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Trial send code error: {e}")
        raise HTTPException(status_code=500, detail="Errore nell'invio del codice")
    finally:
        db.close()


@router.post("/api/client/trial-verify")
async def trial_verify_and_activate(
    body: TrialVerifyRequest,
    user: UserORM = Depends(get_current_user),
):
    """Verify the email code and activate the 15-day free trial."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Solo i clienti")

    pending = _pending_verifications.get(user.id)
    if not pending:
        raise HTTPException(status_code=400, detail="Nessun codice in attesa. Richiedi un nuovo codice.")

    # Check expiry
    if datetime.utcnow() > datetime.fromisoformat(pending["expires"]):
        del _pending_verifications[user.id]
        raise HTTPException(status_code=400, detail="Codice scaduto. Richiedi un nuovo codice.")

    # Check code
    if body.code.strip() != pending["code"]:
        raise HTTPException(status_code=400, detail="Codice non valido")

    # Check email matches
    if body.email.strip().lower() != pending["email"]:
        raise HTTPException(status_code=400, detail="Email non corrispondente")

    # Clean up
    del _pending_verifications[user.id]

    db = get_db_session()
    try:
        # Update user email
        db_user = db.query(UserORM).filter(UserORM.id == user.id).first()
        if db_user:
            db_user.email = pending["email"]

        # Activate trial
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user.id).first()
        if not profile:
            profile = ClientProfileORM(id=user.id, name=db_user.username if db_user else "User")
            db.add(profile)

        now = datetime.utcnow()
        profile.email_verified = True
        profile.account_type = "solo_trial"
        profile.trial_started_at = now.isoformat()
        profile.trial_ends_at = (now + timedelta(days=TRIAL_DAYS)).isoformat()
        profile.is_premium = True
        db.commit()

        logger.info(f"Trial activated for user {user.id}, expires {profile.trial_ends_at}")

        return {
            "status": "success",
            "message": f"Prova gratuita di {TRIAL_DAYS} giorni attivata!",
            "trial_ends_at": profile.trial_ends_at,
        }

    except Exception as e:
        db.rollback()
        logger.error(f"Trial activation error: {e}")
        raise HTTPException(status_code=500, detail="Errore nell'attivazione della prova")
    finally:
        db.close()
