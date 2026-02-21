"""
Stripe Terminal (POS reader) API routes for in-person payments.
Server-driven integration for smart readers (WisePOS E).

Test mode: when using sk_test_ keys, Connect is not required.
The platform account is used directly and simulated readers are supported.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db_session
from models_orm import UserORM, SubscriptionPlanORM
from auth import get_current_user
import stripe
import logging
import os

logger = logging.getLogger("gym_app")

router = APIRouter(prefix="/api/terminal", tags=["terminal"])

# Simulated reader registration code (Stripe test mode only)
_SIMULATED_REG_CODE = "simulated-wpe"


def get_db():
    db = get_db_session()
    try:
        yield db
    finally:
        db.close()


def _is_test_mode() -> bool:
    """True when using Stripe test-mode keys (sandbox)."""
    key = stripe.api_key or ""
    return key.startswith("sk_test_")


def _stripe_kwargs(owner: UserORM) -> dict:
    """
    Returns extra kwargs for Stripe API calls.
    In live mode: routes to the connected account.
    In test mode: no stripe_account (platform account used directly).
    """
    if _is_test_mode():
        return {}
    return {"stripe_account": owner.stripe_account_id}


def _get_owner(user: UserORM, db: Session) -> UserORM:
    """Get the gym owner record for a staff or owner user."""
    if user.role == "owner":
        return user
    if user.role == "staff" and user.gym_owner_id:
        owner = db.query(UserORM).filter(UserORM.id == user.gym_owner_id, UserORM.role == "owner").first()
        if owner:
            return owner
    raise HTTPException(status_code=400, detail="Could not find gym owner")


def _require_connect(owner: UserORM):
    """Ensure the owner has an active Stripe Connect account (skipped in test mode)."""
    if _is_test_mode():
        return  # platform account used directly in sandbox
    if not owner.stripe_account_id or owner.stripe_account_status != "active":
        raise HTTPException(status_code=400, detail="Stripe Connect account not active. Set up payments first.")


# ─── Status ────────────────────────────────────────────────────────────────


@router.get("/test-mode")
async def get_test_mode_status(user: UserORM = Depends(get_current_user)):
    """Returns whether the backend is in Stripe test mode (sandbox)."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff or owner access required")
    return {"is_test_mode": _is_test_mode()}


# ─── Owner Endpoints ───────────────────────────────────────────────────────


@router.post("/create-location")
async def create_terminal_location(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a Stripe Terminal Location for the gym."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can set up terminal locations")

    _require_connect(user)

    sk = _stripe_kwargs(user)

    # Return existing location if already set up
    if user.stripe_terminal_location_id:
        try:
            loc = stripe.terminal.Location.retrieve(user.stripe_terminal_location_id, **sk)
            return {"location_id": loc.id, "display_name": loc.display_name, "already_exists": True}
        except stripe.error.InvalidRequestError:
            pass  # Location was deleted, create a new one

    address = data.get("address", {})
    if not address.get("line1") or not address.get("city") or not address.get("country") or not address.get("postal_code"):
        raise HTTPException(status_code=400, detail="Address requires: line1, city, country, postal_code")

    try:
        addr_payload = {
            "line1": address["line1"],
            "city": address["city"],
            "country": address["country"],
            "postal_code": address["postal_code"],
        }
        if address.get("line2"):
            addr_payload["line2"] = address["line2"]
        if address.get("state"):
            addr_payload["state"] = address["state"]

        location = stripe.terminal.Location.create(
            display_name=user.gym_name or "Gym",
            address=addr_payload,
            **sk
        )

        db_owner = db.query(UserORM).filter(UserORM.id == user.id).first()
        db_owner.stripe_terminal_location_id = location.id
        db.commit()

        logger.info(f"Terminal location created: {location.id} for owner {user.id}")
        return {"location_id": location.id, "display_name": location.display_name}

    except stripe.error.StripeError as e:
        logger.error(f"Failed to create terminal location: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/register-reader")
async def register_terminal_reader(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Register a reader using its registration code.
    In test mode: pass registration_code="simulated" (or leave empty)
    to create a Stripe-simulated WisePOS E reader.
    """
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can register readers")

    _require_connect(user)

    if not user.stripe_terminal_location_id:
        raise HTTPException(status_code=400, detail="Set up a terminal location first")

    registration_code = data.get("registration_code", "").strip()
    label = data.get("label", "Reception").strip()

    # In test mode, accept "simulated" or empty → use the magic simulated code
    if _is_test_mode() and registration_code in ("", "simulated"):
        registration_code = _SIMULATED_REG_CODE
    elif not registration_code:
        raise HTTPException(status_code=400, detail="Registration code is required (shown on the reader screen)")

    sk = _stripe_kwargs(user)

    try:
        reader = stripe.terminal.Reader.create(
            registration_code=registration_code,
            label=label,
            location=user.stripe_terminal_location_id,
            **sk
        )

        db_owner = db.query(UserORM).filter(UserORM.id == user.id).first()
        db_owner.stripe_terminal_reader_id = reader.id
        db.commit()

        logger.info(f"Terminal reader registered: {reader.id} for owner {user.id}")
        return {
            "reader_id": reader.id,
            "label": reader.label,
            "status": reader.status,
            "simulated": _is_test_mode(),
        }

    except stripe.error.StripeError as e:
        logger.error(f"Failed to register terminal reader: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/import-reader")
async def import_existing_reader(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Link an already-registered Stripe Terminal reader by its ID (tmr_xxx).
    For owners who set up the reader directly in the Stripe Dashboard.
    """
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can link readers")

    reader_id = data.get("reader_id", "").strip()
    if not reader_id or not reader_id.startswith("tmr_"):
        raise HTTPException(status_code=400, detail="Invalid reader ID — must start with tmr_")

    sk = _stripe_kwargs(user)

    try:
        # Validate the reader exists on Stripe
        reader = stripe.terminal.Reader.retrieve(reader_id, **sk)

        db_owner = db.query(UserORM).filter(UserORM.id == user.id).first()
        db_owner.stripe_terminal_reader_id = reader.id
        db.commit()

        logger.info(f"Imported existing reader: {reader.id} for owner {user.id}")
        return {
            "reader_id": reader.id,
            "label": reader.label,
            "status": reader.status,
            "device_type": reader.device_type,
        }

    except stripe.error.InvalidRequestError as e:
        raise HTTPException(status_code=404, detail=f"Reader not found on Stripe: {e.user_message or str(e)}")
    except stripe.error.StripeError as e:
        logger.error(f"Failed to import reader: {e}")
        raise HTTPException(status_code=400, detail=str(e))


# ─── Staff / Owner Endpoints ──────────────────────────────────────────────


@router.get("/readers")
async def list_terminal_readers(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List registered readers for the gym."""
    if user.role not in ("staff", "owner"):
        raise HTTPException(status_code=403, detail="Staff or owner access required")

    owner = _get_owner(user, db)
    _require_connect(owner)

    if not owner.stripe_terminal_location_id:
        return {"readers": [], "is_test_mode": _is_test_mode()}

    sk = _stripe_kwargs(owner)

    try:
        readers = stripe.terminal.Reader.list(location=owner.stripe_terminal_location_id, **sk)

        reader_data = [
            {
                "id": r.id,
                "label": r.label,
                "status": r.status,
                "device_type": r.device_type,
            }
            for r in readers.data
        ]

        # If location list is empty but we have a stored reader ID, fetch it directly.
        # This happens when the reader is at a different location (e.g. imported from dashboard).
        if not reader_data and owner.stripe_terminal_reader_id:
            try:
                r = stripe.terminal.Reader.retrieve(owner.stripe_terminal_reader_id, **sk)
                reader_data = [{"id": r.id, "label": r.label, "status": r.status, "device_type": r.device_type}]
            except stripe.error.StripeError:
                pass

        return {"readers": reader_data, "is_test_mode": _is_test_mode()}

    except stripe.error.StripeError as e:
        logger.error(f"Failed to list readers: {e}")
        return {"readers": [], "is_test_mode": _is_test_mode()}


@router.post("/process-payment")
async def process_terminal_payment(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a PaymentIntent and hand it off to the reader."""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access required")

    owner = _get_owner(user, db)
    _require_connect(owner)

    if not owner.stripe_terminal_reader_id:
        raise HTTPException(status_code=400, detail="No POS terminal registered. Ask the gym owner to set one up.")

    plan_id = data.get("plan_id")
    client_name = data.get("client_name", "Customer")
    coupon_code = data.get("coupon_code")

    if not plan_id:
        raise HTTPException(status_code=400, detail="Plan ID is required")

    plan = db.query(SubscriptionPlanORM).filter(SubscriptionPlanORM.id == plan_id).first()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    amount = plan.price
    currency = plan.currency or "eur"

    if coupon_code:
        from service_modules.subscription_service import subscription_service
        coupon_result = subscription_service.validate_coupon(coupon_code, owner.id)
        if coupon_result.get("valid"):
            if coupon_result.get("discount_type") == "percent":
                amount = amount * (1 - coupon_result["discount_value"] / 100)
            elif coupon_result.get("discount_type") == "fixed":
                amount = max(0, amount - coupon_result["discount_value"])

    amount_cents = int(round(amount * 100))
    if amount_cents < 50:
        raise HTTPException(status_code=400, detail="Amount too small for card payment")

    sk = _stripe_kwargs(owner)

    try:
        intent = stripe.PaymentIntent.create(
            amount=amount_cents,
            currency=currency,
            payment_method_types=["card_present"],
            capture_method="automatic",
            description=f"Abbonamento palestra: {plan.name} per {client_name}",
            metadata={
                "gym_id": owner.id,
                "plan_id": plan_id,
                "plan_name": plan.name,
                "client_name": client_name,
                "payment_source": "terminal_onboarding",
            },
            **sk
        )

        stripe.terminal.Reader.process_payment_intent(
            owner.stripe_terminal_reader_id,
            payment_intent=intent.id,
            **sk
        )

        logger.info(f"Terminal payment started: {intent.id} on reader {owner.stripe_terminal_reader_id}")
        return {
            "payment_intent_id": intent.id,
            "amount": amount,
            "amount_cents": amount_cents,
            "currency": currency,
            "status": "processing",
            "is_test_mode": _is_test_mode(),
        }

    except stripe.error.StripeError as e:
        logger.error(f"Terminal payment error: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/payment-status/{payment_intent_id}")
async def get_terminal_payment_status(
    payment_intent_id: str,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Poll for terminal payment status."""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access required")

    owner = _get_owner(user, db)
    _require_connect(owner)

    sk = _stripe_kwargs(owner)

    try:
        intent = stripe.PaymentIntent.retrieve(payment_intent_id, **sk)
        return {"status": intent.status, "payment_intent_id": intent.id}

    except stripe.error.StripeError as e:
        logger.error(f"Failed to check payment status: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/simulate-payment")
async def simulate_terminal_payment(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Test mode only: simulates a card tap on the registered reader.
    Calls Stripe TestHelpers to present a payment method on the simulated reader.
    """
    if not _is_test_mode():
        raise HTTPException(status_code=400, detail="simulate-payment is only available in test mode")

    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access required")

    owner = _get_owner(user, db)

    if not owner.stripe_terminal_reader_id:
        raise HTTPException(status_code=400, detail="No reader registered")

    try:
        stripe.terminal.Reader.TestHelpers.present_payment_method(
            owner.stripe_terminal_reader_id
        )
        logger.info(f"Simulated card tap on reader {owner.stripe_terminal_reader_id}")
        return {"status": "simulated_tap_sent"}

    except stripe.error.StripeError as e:
        logger.error(f"Failed to simulate payment: {e}")
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/cancel-payment")
async def cancel_terminal_payment(
    data: dict,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel an in-progress terminal payment."""
    if user.role != "staff":
        raise HTTPException(status_code=403, detail="Staff access required")

    owner = _get_owner(user, db)
    _require_connect(owner)

    payment_intent_id = data.get("payment_intent_id")
    if not payment_intent_id:
        raise HTTPException(status_code=400, detail="payment_intent_id is required")

    sk = _stripe_kwargs(owner)

    try:
        if owner.stripe_terminal_reader_id:
            try:
                stripe.terminal.Reader.cancel_action(owner.stripe_terminal_reader_id, **sk)
            except stripe.error.StripeError:
                pass  # Reader may not have an active action

        stripe.PaymentIntent.cancel(payment_intent_id, **sk)

        logger.info(f"Terminal payment canceled: {payment_intent_id}")
        return {"status": "canceled"}

    except stripe.error.StripeError as e:
        logger.error(f"Failed to cancel terminal payment: {e}")
        raise HTTPException(status_code=400, detail=str(e))
