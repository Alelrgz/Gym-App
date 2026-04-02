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
import os
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
