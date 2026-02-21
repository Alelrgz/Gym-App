"""
Subscription Routes - API endpoints for subscription management
"""
from fastapi import APIRouter, Depends, Header, Request, HTTPException
from typing import Optional
from auth import get_current_user
from service_modules.subscription_service import get_subscription_service, SubscriptionService
from models import (
    CreateSubscriptionPlanRequest, UpdateSubscriptionPlanRequest,
    CreateSubscriptionRequest, CancelSubscriptionRequest
)
import logging
import traceback

logger = logging.getLogger("gym_app")
router = APIRouter()


# --- OWNER ENDPOINTS (Plan Management) ---
# Only gym OWNERS can manage subscription plans and pricing

@router.post("/api/owner/subscription-plans")
async def create_subscription_plan(
    plan_data: CreateSubscriptionPlanRequest,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Create a new subscription plan (owner only)."""
    try:
        logger.info(f"CREATE PLAN: Request received from user {user.username} (role: {user.role})")
        logger.info(f"CREATE PLAN: Plan data - name: {plan_data.name}, billing_type: {plan_data.billing_type}, annual_price: {plan_data.annual_price}, monthly_price: {plan_data.monthly_price}, installments: {plan_data.installment_count}")

        if user.role != "owner":
            logger.warning(f"CREATE PLAN: Access denied - user {user.username} is not an owner")
            raise HTTPException(status_code=403, detail="Only gym owners can create subscription plans")

        logger.info(f"CREATE PLAN: Calling service.create_plan with gym_id={user.id}")
        result = service.create_plan(user.id, plan_data)
        logger.info(f"CREATE PLAN: Success - plan created with id={result.get('plan_id')}")

        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"CREATE PLAN ERROR: {type(e).__name__}: {str(e)}")
        logger.error(f"CREATE PLAN TRACEBACK:\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Failed to create plan: {str(e)}")


@router.get("/api/owner/subscription-plans")
async def get_owner_plans(
    include_inactive: bool = False,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Get all subscription plans for the owner's gym."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view subscription plans")

    return service.get_gym_plans(user.id, include_inactive)


@router.put("/api/owner/subscription-plans/{plan_id}")
async def update_subscription_plan(
    plan_id: str,
    plan_data: UpdateSubscriptionPlanRequest,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Update a subscription plan."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can update subscription plans")

    return service.update_plan(plan_id, user.id, plan_data)


@router.delete("/api/owner/subscription-plans/{plan_id}")
async def delete_subscription_plan(
    plan_id: str,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Delete (deactivate) a subscription plan."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can delete subscription plans")

    return service.delete_plan(plan_id, user.id)


# --- PLAN OFFERS (Promotional Discounts) ---

@router.post("/api/owner/offers")
async def create_offer(
    offer_data: dict,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Create a promotional offer (owner only)."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can create offers")

    return service.create_offer(user.id, offer_data)


@router.get("/api/owner/offers")
async def get_gym_offers(
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Get all offers for the gym."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can view all offers")

    return service.get_gym_offers(user.id, include_inactive=True)


@router.put("/api/owner/offers/{offer_id}")
async def update_offer(
    offer_id: str,
    offer_data: dict,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Update an offer."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can update offers")

    return service.update_offer(user.id, offer_id, offer_data)


@router.delete("/api/owner/offers/{offer_id}")
async def delete_offer(
    offer_id: str,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Delete (deactivate) an offer."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can delete offers")

    return service.delete_offer(user.id, offer_id)


@router.get("/api/client/offers/{gym_id}")
async def get_available_offers(
    gym_id: str,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Get active offers available for a client."""
    return service.get_active_offers_for_client(gym_id)


@router.post("/api/client/validate-coupon")
async def validate_coupon(
    data: dict,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Validate a coupon code."""
    return service.validate_coupon(
        data.get("gym_id"),
        data.get("coupon_code"),
        data.get("plan_id")
    )


# --- CLIENT ENDPOINTS (Subscription Management) ---

@router.get("/api/client/subscription-plans/{gym_id}")
async def get_available_plans(
    gym_id: str,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Get available subscription plans for a gym (client view)."""
    return service.get_gym_plans(gym_id, include_inactive=False)


@router.post("/api/client/subscribe")
async def subscribe_to_plan(
    request_data: CreateSubscriptionRequest,
    gym_id: str,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Subscribe to a plan."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can subscribe")

    return service.create_subscription(user.id, gym_id, request_data)


@router.get("/api/client/subscription/{gym_id}")
async def get_my_subscription(
    gym_id: str,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Get client's active subscription for a gym."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view their subscription")

    return service.get_client_subscription(user.id, gym_id)


@router.post("/api/client/cancel-subscription")
async def cancel_my_subscription(
    request_data: CancelSubscriptionRequest,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Cancel a subscription."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can cancel subscriptions")

    return service.cancel_subscription(request_data.subscription_id, user.id, request_data)


@router.get("/api/client/payment-history/{gym_id}")
async def get_my_payment_history(
    gym_id: str,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Get payment history for a gym."""
    if user.role != "client":
        raise HTTPException(status_code=403, detail="Only clients can view payment history")

    return service.get_payment_history(user.id, gym_id)


# --- STRIPE CONNECT (Owner Payment Setup) ---

@router.post("/api/owner/stripe-connect/onboard")
async def start_stripe_connect_onboarding(
    request: Request,
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Start Stripe Connect onboarding for a gym owner."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can set up payment accounts")

    # Get base URL from request
    base_url = str(request.base_url).rstrip("/")

    # Return and refresh URLs
    return_url = f"{base_url}/?role=owner&mode=stripe_success"
    refresh_url = f"{base_url}/?role=owner&mode=stripe_refresh"

    return service.create_connect_account(user.id, return_url, refresh_url)


@router.get("/api/owner/stripe-connect/status")
async def get_stripe_connect_status(
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Get the status of a gym owner's Stripe Connect account."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can check payment account status")

    return service.get_connect_account_status(user.id)


@router.get("/api/owner/stripe-connect/dashboard")
async def get_stripe_dashboard_link(
    user = Depends(get_current_user),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Get a login link to the Stripe Express dashboard."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Only gym owners can access the payment dashboard")

    return service.create_connect_login_link(user.id)


# --- STRIPE WEBHOOK ---

@router.post("/webhook/stripe")
async def stripe_webhook(
    request: Request,
    stripe_signature: Optional[str] = Header(None, alias="Stripe-Signature"),
    service: SubscriptionService = Depends(get_subscription_service)
):
    """Handle Stripe webhook events."""
    payload = await request.body()

    return service.handle_webhook(payload, stripe_signature)
