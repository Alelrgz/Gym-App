"""
Stripe Connect Routes for Professionals (Trainers/Nutritionists)
Handles onboarding, status checks, and payout dashboard access.
"""
import os
import uuid
import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from database import get_db
from auth import get_current_user
from models_orm import UserORM, StripeTransferORM

logger = logging.getLogger("gym_app")

stripe_connect_router = APIRouter(tags=["Stripe Connect"])


def _get_stripe():
    """Lazy import stripe to avoid import-time env var issues."""
    import stripe
    stripe.api_key = os.environ.get("STRIPE_SECRET_KEY", "")
    return stripe


# --- Professional Onboarding ---

@stripe_connect_router.post("/api/professional/stripe-connect/onboard")
async def professional_stripe_onboard(
    request: Request,
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """Create or resume Stripe Connect Express onboarding for a trainer/nutritionist."""
    if current_user.role not in ("trainer", "nutritionist"):
        raise HTTPException(status_code=403, detail="Only trainers and nutritionists can onboard")

    stripe = _get_stripe()
    if not stripe.api_key:
        raise HTTPException(status_code=400, detail="Stripe is not configured")

    body = await request.json()
    return_url = body.get("return_url", "")
    refresh_url = body.get("refresh_url", "")

    if not return_url or not refresh_url:
        raise HTTPException(status_code=400, detail="return_url and refresh_url are required")

    try:
        # Already has an account — create new onboarding link
        if current_user.stripe_account_id:
            account_link = stripe.AccountLink.create(
                account=current_user.stripe_account_id,
                refresh_url=refresh_url,
                return_url=return_url,
                type="account_onboarding"
            )
            return {
                "account_id": current_user.stripe_account_id,
                "onboarding_url": account_link.url,
                "status": current_user.stripe_account_status or "pending"
            }

        # Create new Connect Express account
        account = stripe.Account.create(
            type="express",
            country="IT",
            email=current_user.email,
            capabilities={
                "card_payments": {"requested": True},
                "transfers": {"requested": True},
            },
            business_type="individual",
            metadata={
                "user_id": current_user.id,
                "role": current_user.role,
                "gym_owner_id": current_user.gym_owner_id or "",
            }
        )

        current_user.stripe_account_id = account.id
        current_user.stripe_account_status = "pending"
        db.commit()

        account_link = stripe.AccountLink.create(
            account=account.id,
            refresh_url=refresh_url,
            return_url=return_url,
            type="account_onboarding"
        )

        logger.info(f"Created Stripe Connect account for {current_user.role} {current_user.id}: {account.id}")

        return {
            "account_id": account.id,
            "onboarding_url": account_link.url,
            "status": "pending"
        }

    except Exception as e:
        logger.error(f"Stripe Connect onboarding error: {e}")
        raise HTTPException(status_code=400, detail=f"Stripe error: {str(e)}")


@stripe_connect_router.get("/api/professional/stripe-connect/status")
async def professional_stripe_status(
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """Get Stripe Connect status for the current professional."""
    if current_user.role not in ("trainer", "nutritionist"):
        raise HTTPException(status_code=403, detail="Only trainers and nutritionists")

    if not current_user.stripe_account_id:
        return {
            "connected": False,
            "status": None,
            "can_receive_payments": False
        }

    stripe = _get_stripe()
    try:
        account = stripe.Account.retrieve(current_user.stripe_account_id)
        can_receive = (
            account.charges_enabled and
            account.payouts_enabled and
            not account.requirements.get("currently_due", [])
        )

        new_status = "active" if can_receive else "pending"
        if current_user.stripe_account_status != new_status:
            current_user.stripe_account_status = new_status
            db.commit()

        return {
            "connected": True,
            "account_id": current_user.stripe_account_id,
            "status": new_status,
            "can_receive_payments": can_receive,
            "charges_enabled": account.charges_enabled,
            "payouts_enabled": account.payouts_enabled,
        }
    except Exception as e:
        logger.error(f"Stripe Connect status error: {e}")
        return {
            "connected": True,
            "account_id": current_user.stripe_account_id,
            "status": current_user.stripe_account_status or "unknown",
            "can_receive_payments": False,
            "error": str(e)
        }


@stripe_connect_router.get("/api/professional/stripe-connect/dashboard")
async def professional_stripe_dashboard(
    current_user: UserORM = Depends(get_current_user)
):
    """Get a Stripe Express dashboard login link for the professional."""
    if current_user.role not in ("trainer", "nutritionist"):
        raise HTTPException(status_code=403, detail="Only trainers and nutritionists")

    if not current_user.stripe_account_id:
        raise HTTPException(status_code=400, detail="No Stripe account connected")

    stripe = _get_stripe()
    try:
        login_link = stripe.Account.create_login_link(current_user.stripe_account_id)
        return {"dashboard_url": login_link.url}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Stripe error: {str(e)}")


# --- Payout History ---

@stripe_connect_router.get("/api/professional/payouts")
async def get_my_payouts(
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """Get payout/transfer history for the current professional."""
    if current_user.role not in ("trainer", "nutritionist"):
        raise HTTPException(status_code=403, detail="Only trainers and nutritionists")

    transfers = db.query(StripeTransferORM).filter(
        StripeTransferORM.destination_user_id == current_user.id
    ).order_by(StripeTransferORM.created_at.desc()).limit(100).all()

    total_earned = sum(t.amount for t in transfers if t.status == "completed")

    return {
        "total_earned": total_earned / 100,  # Convert cents to EUR
        "transfers": [{
            "id": t.id,
            "amount": t.amount / 100,
            "currency": t.currency,
            "status": t.status,
            "appointment_id": t.appointment_id,
            "created_at": t.created_at,
        } for t in transfers]
    }


@stripe_connect_router.get("/api/owner/payouts")
async def get_gym_payouts(
    db: Session = Depends(get_db),
    current_user: UserORM = Depends(get_current_user)
):
    """Get all payout history for a gym owner's professionals."""
    if current_user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners")

    # Get all professionals in this gym
    professionals = db.query(UserORM).filter(
        UserORM.gym_owner_id == current_user.id,
        UserORM.role.in_(["trainer", "nutritionist"])
    ).all()

    pro_ids = [p.id for p in professionals]

    transfers = db.query(StripeTransferORM).filter(
        StripeTransferORM.destination_user_id.in_(pro_ids + [current_user.id])
    ).order_by(StripeTransferORM.created_at.desc()).limit(200).all()

    gym_total = sum(t.amount for t in transfers
                    if t.destination_user_id == current_user.id and t.status == "completed")
    pro_total = sum(t.amount for t in transfers
                    if t.destination_user_id != current_user.id and t.status == "completed")

    return {
        "gym_revenue": gym_total / 100,
        "professional_payouts": pro_total / 100,
        "professionals": [{
            "id": p.id,
            "name": p.username,
            "role": p.role,
            "stripe_connected": p.stripe_account_status == "active",
            "commission_rate": p.commission_rate or 0,
        } for p in professionals],
        "transfers": [{
            "id": t.id,
            "amount": t.amount / 100,
            "currency": t.currency,
            "status": t.status,
            "destination_role": t.destination_role,
            "destination_user_id": t.destination_user_id,
            "appointment_id": t.appointment_id,
            "created_at": t.created_at,
        } for t in transfers]
    }
