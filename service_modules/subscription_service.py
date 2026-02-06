"""
Subscription Service - handles subscription plans, payments, and Stripe integration.
"""
from .base import (
    HTTPException, json, logging, date, datetime,
    get_db_session
)
from models_orm import SubscriptionPlanORM, ClientSubscriptionORM, PaymentORM, UserORM, PlanOfferORM, ClientProfileORM, NotificationORM
from models import (
    CreateSubscriptionPlanRequest, UpdateSubscriptionPlanRequest,
    CreateSubscriptionRequest, CancelSubscriptionRequest,
    SubscriptionPlan, ClientSubscription, Payment
)
import stripe
import os
import uuid

# Configure Stripe
stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")

logger = logging.getLogger("gym_app")

# Check if Stripe is configured
def is_stripe_configured():
    """Check if Stripe API key is configured (not a placeholder)."""
    api_key = os.environ.get("STRIPE_SECRET_KEY")
    return api_key and not api_key.startswith("your_") and len(api_key) > 20


class SubscriptionService:
    """Service for managing subscriptions, plans, and payments."""

    # --- SUBSCRIPTION PLANS (Trainer/Owner Management) ---

    def create_plan(self, gym_id: str, plan_data: CreateSubscriptionPlanRequest) -> dict:
        """Create a new subscription plan for a gym."""
        db = get_db_session()
        try:
            stripe_product_id = None
            stripe_price_id = None

            # Only create Stripe objects if Stripe is configured
            if is_stripe_configured():
                try:
                    # Create Stripe Product
                    stripe_product = stripe.Product.create(
                        name=f"{plan_data.name}",
                        description=plan_data.description or "",
                        metadata={"gym_id": gym_id}
                    )

                    # Create Stripe Price
                    stripe_price = stripe.Price.create(
                        product=stripe_product.id,
                        unit_amount=int(plan_data.price * 100),  # Convert dollars to cents
                        currency="usd",
                        recurring={
                            "interval": plan_data.billing_interval,  # month or year
                            "trial_period_days": plan_data.trial_period_days if plan_data.trial_period_days > 0 else None
                        }
                    )

                    stripe_product_id = stripe_product.id
                    stripe_price_id = stripe_price.id
                    logger.info(f"Created Stripe product and price for plan")
                except stripe.StripeError as e:
                    logger.warning(f"Stripe error (using test mode): {e}")
                    # Continue without Stripe - use test mode
                    stripe_product_id = f"test_prod_{uuid.uuid4().hex[:8]}"
                    stripe_price_id = f"test_price_{uuid.uuid4().hex[:8]}"
            else:
                logger.info("Stripe not configured - creating plan in test mode")
                # Use test IDs
                stripe_product_id = f"test_prod_{uuid.uuid4().hex[:8]}"
                stripe_price_id = f"test_price_{uuid.uuid4().hex[:8]}"

            # Create plan in database
            plan_id = str(uuid.uuid4())
            plan = SubscriptionPlanORM(
                id=plan_id,
                gym_id=gym_id,
                name=plan_data.name,
                description=plan_data.description,
                price=plan_data.price,
                currency="usd",
                stripe_price_id=stripe_price_id,
                stripe_product_id=stripe_product_id,
                features_json=json.dumps(plan_data.features) if plan_data.features else "[]",
                trial_period_days=plan_data.trial_period_days,
                billing_interval=plan_data.billing_interval,
                is_active=True
            )

            db.add(plan)
            db.commit()
            db.refresh(plan)

            logger.info(f"Created subscription plan: {plan_id} for gym: {gym_id}")

            return {
                "status": "success",
                "plan_id": plan_id,
                "stripe_product_id": stripe_product_id,
                "stripe_price_id": stripe_price_id,
                "test_mode": not is_stripe_configured()
            }

        except Exception as e:
            db.rollback()
            logger.error(f"Error creating plan: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create plan: {str(e)}")
        finally:
            db.close()

    def get_gym_plans(self, gym_id: str, include_inactive: bool = False) -> list:
        """Get all subscription plans for a gym."""
        db = get_db_session()
        try:
            query = db.query(SubscriptionPlanORM).filter(
                SubscriptionPlanORM.gym_id == gym_id
            )

            if not include_inactive:
                query = query.filter(SubscriptionPlanORM.is_active == True)

            plans = query.all()

            result = []
            for plan in plans:
                # Count active subscriptions
                active_subs = db.query(ClientSubscriptionORM).filter(
                    ClientSubscriptionORM.plan_id == plan.id,
                    ClientSubscriptionORM.status.in_(["active", "trialing"])
                ).count()

                result.append({
                    "id": plan.id,
                    "name": plan.name,
                    "description": plan.description,
                    "price": plan.price,
                    "currency": plan.currency,
                    "features": json.loads(plan.features_json) if plan.features_json else [],
                    "is_active": plan.is_active,
                    "trial_period_days": plan.trial_period_days,
                    "billing_interval": plan.billing_interval,
                    "active_subscriptions": active_subs,
                    "monthly_revenue": active_subs * plan.price if plan.billing_interval == "month" else (active_subs * plan.price / 12),
                    "created_at": plan.created_at
                })

            return result

        finally:
            db.close()

    def update_plan(self, plan_id: str, gym_id: str, plan_data: UpdateSubscriptionPlanRequest) -> dict:
        """Update a subscription plan."""
        db = get_db_session()
        try:
            plan = db.query(SubscriptionPlanORM).filter(
                SubscriptionPlanORM.id == plan_id,
                SubscriptionPlanORM.gym_id == gym_id
            ).first()

            if not plan:
                raise HTTPException(status_code=404, detail="Plan not found")

            # Update Stripe product if needed (only if Stripe is configured and not test mode)
            if is_stripe_configured() and not plan.stripe_product_id.startswith("test_"):
                if plan_data.name or plan_data.description:
                    try:
                        stripe.Product.modify(
                            plan.stripe_product_id,
                            name=plan_data.name or plan.name,
                            description=plan_data.description or plan.description
                        )
                    except stripe.StripeError as e:
                        logger.warning(f"Stripe error updating product (continuing): {e}")

            # Update database
            if plan_data.name:
                plan.name = plan_data.name
            if plan_data.description:
                plan.description = plan_data.description
            if plan_data.features:
                plan.features_json = json.dumps(plan_data.features)
            if plan_data.is_active is not None:
                plan.is_active = plan_data.is_active
            if plan_data.trial_period_days is not None:
                plan.trial_period_days = plan_data.trial_period_days

            plan.updated_at = datetime.utcnow().isoformat()

            db.commit()

            logger.info(f"Updated subscription plan: {plan_id}")

            return {"status": "success"}

        except Exception as e:
            db.rollback()
            logger.error(f"Error updating plan: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to update plan: {str(e)}")
        finally:
            db.close()

    def delete_plan(self, plan_id: str, gym_id: str) -> dict:
        """Soft delete a subscription plan (mark as inactive)."""
        db = get_db_session()
        try:
            plan = db.query(SubscriptionPlanORM).filter(
                SubscriptionPlanORM.id == plan_id,
                SubscriptionPlanORM.gym_id == gym_id
            ).first()

            if not plan:
                raise HTTPException(status_code=404, detail="Plan not found")

            # Check if there are active subscriptions
            active_subs = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.plan_id == plan_id,
                ClientSubscriptionORM.status.in_(["active", "trialing"])
            ).count()

            if active_subs > 0:
                raise HTTPException(
                    status_code=400,
                    detail=f"Cannot delete plan with {active_subs} active subscriptions"
                )

            # Soft delete by marking inactive
            plan.is_active = False
            plan.updated_at = datetime.utcnow().isoformat()

            db.commit()

            logger.info(f"Deleted subscription plan: {plan_id}")

            return {"status": "success"}

        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to delete plan: {str(e)}")
        finally:
            db.close()

    # --- CLIENT SUBSCRIPTIONS ---

    def create_subscription(self, client_id: str, gym_id: str, request: CreateSubscriptionRequest) -> dict:
        """Create a new subscription for a client."""
        db = get_db_session()
        try:
            # Get plan
            plan = db.query(SubscriptionPlanORM).filter(
                SubscriptionPlanORM.id == request.plan_id,
                SubscriptionPlanORM.is_active == True
            ).first()

            if not plan:
                raise HTTPException(status_code=404, detail="Plan not found or inactive")

            # Check if client already has an active subscription to this gym
            existing = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.client_id == client_id,
                ClientSubscriptionORM.gym_id == gym_id,
                ClientSubscriptionORM.status.in_(["active", "trialing"])
            ).first()

            if existing:
                raise HTTPException(
                    status_code=400,
                    detail="Client already has an active subscription to this gym"
                )

            # Get or create Stripe customer
            # In a real implementation, you'd store stripe_customer_id on the User model
            # For now, we'll create a new customer
            stripe_customer = stripe.Customer.create(
                metadata={"client_id": client_id, "gym_id": gym_id}
            )

            # Attach payment method if provided
            if request.payment_method_id:
                stripe.PaymentMethod.attach(
                    request.payment_method_id,
                    customer=stripe_customer.id
                )
                stripe.Customer.modify(
                    stripe_customer.id,
                    invoice_settings={"default_payment_method": request.payment_method_id}
                )

            # Get gym's connected Stripe account for payment routing
            gym_stripe_account = self.get_gym_stripe_account(gym_id)

            # Resolve coupon if provided
            stripe_coupon_id = None
            if request.coupon_code:
                coupon_result = self.validate_coupon(gym_id, request.coupon_code, request.plan_id)
                if coupon_result.get("valid"):
                    # Find the offer to get Stripe coupon ID
                    offer = db.query(PlanOfferORM).filter(
                        PlanOfferORM.id == coupon_result["offer_id"]
                    ).first()
                    if offer and offer.stripe_coupon_id:
                        stripe_coupon_id = offer.stripe_coupon_id
                    # Increment redemption count
                    if offer:
                        offer.current_redemptions = (offer.current_redemptions or 0) + 1
                        db.commit()

            # Build subscription parameters
            sub_params = {
                "customer": stripe_customer.id,
                "items": [{"price": plan.stripe_price_id}],
                "trial_period_days": plan.trial_period_days if plan.trial_period_days > 0 else None,
                "metadata": {
                    "client_id": client_id,
                    "gym_id": gym_id,
                    "plan_id": plan.id
                }
            }

            # Apply Stripe coupon if available
            if stripe_coupon_id:
                sub_params["coupon"] = stripe_coupon_id
                logger.info(f"Applying Stripe coupon {stripe_coupon_id} to subscription")

            # If gym has a connected account, route payments to them
            if gym_stripe_account:
                # Use application_fee_percent to take a platform fee (optional)
                # Set to 0 for no fee, or e.g. 5 for 5% platform fee
                platform_fee_percent = float(os.environ.get("STRIPE_PLATFORM_FEE_PERCENT", "0"))
                sub_params["transfer_data"] = {
                    "destination": gym_stripe_account
                }
                if platform_fee_percent > 0:
                    sub_params["application_fee_percent"] = platform_fee_percent
                logger.info(f"Routing payments to connected account: {gym_stripe_account}")
            else:
                logger.info(f"No connected account for gym {gym_id}, payments go to platform")

            # Create Stripe subscription
            stripe_sub = stripe.Subscription.create(**sub_params)

            # Create subscription in database
            subscription_id = str(uuid.uuid4())
            subscription = ClientSubscriptionORM(
                id=subscription_id,
                client_id=client_id,
                plan_id=plan.id,
                gym_id=gym_id,
                stripe_subscription_id=stripe_sub.id,
                stripe_customer_id=stripe_customer.id,
                status=stripe_sub.status,
                start_date=datetime.utcnow().isoformat(),
                current_period_start=datetime.fromtimestamp(stripe_sub.current_period_start).isoformat(),
                current_period_end=datetime.fromtimestamp(stripe_sub.current_period_end).isoformat(),
                trial_end=datetime.fromtimestamp(stripe_sub.trial_end).isoformat() if stripe_sub.trial_end else None
            )

            db.add(subscription)
            db.commit()
            db.refresh(subscription)

            logger.info(f"Created subscription: {subscription_id} for client: {client_id}")

            return {
                "status": "success",
                "subscription_id": subscription_id,
                "stripe_subscription_id": stripe_sub.id,
                "client_secret": stripe_sub.latest_invoice.payment_intent.client_secret if stripe_sub.latest_invoice else None
            }

        except stripe.StripeError as e:
            db.rollback()
            logger.error(f"Stripe error creating subscription: {e}")
            raise HTTPException(status_code=400, detail=f"Stripe error: {str(e)}")
        except Exception as e:
            db.rollback()
            logger.error(f"Error creating subscription: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create subscription: {str(e)}")
        finally:
            db.close()

    def get_client_subscription(self, client_id: str, gym_id: str) -> dict:
        """Get client's active subscription for a gym."""
        db = get_db_session()
        try:
            subscription = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.client_id == client_id,
                ClientSubscriptionORM.gym_id == gym_id,
                ClientSubscriptionORM.status.in_(["active", "trialing", "past_due"])
            ).first()

            if not subscription:
                return None

            # Get plan details
            plan = db.query(SubscriptionPlanORM).filter(
                SubscriptionPlanORM.id == subscription.plan_id
            ).first()

            return {
                "id": subscription.id,
                "status": subscription.status,
                "plan": {
                    "id": plan.id,
                    "name": plan.name,
                    "price": plan.price,
                    "billing_interval": plan.billing_interval
                },
                "current_period_start": subscription.current_period_start,
                "current_period_end": subscription.current_period_end,
                "cancel_at_period_end": subscription.cancel_at_period_end,
                "trial_end": subscription.trial_end
            }

        finally:
            db.close()

    def cancel_subscription(self, subscription_id: str, client_id: str, request: CancelSubscriptionRequest) -> dict:
        """Cancel a subscription."""
        db = get_db_session()
        try:
            subscription = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.id == subscription_id,
                ClientSubscriptionORM.client_id == client_id
            ).first()

            if not subscription:
                raise HTTPException(status_code=404, detail="Subscription not found")

            # Cancel in Stripe
            if request.cancel_immediately:
                stripe.Subscription.delete(subscription.stripe_subscription_id)
                subscription.status = "canceled"
                subscription.ended_at = datetime.utcnow().isoformat()
            else:
                stripe.Subscription.modify(
                    subscription.stripe_subscription_id,
                    cancel_at_period_end=True
                )
                subscription.cancel_at_period_end = True

            subscription.canceled_at = datetime.utcnow().isoformat()
            subscription.updated_at = datetime.utcnow().isoformat()

            db.commit()

            logger.info(f"Canceled subscription: {subscription_id}")

            return {"status": "success"}

        except stripe.StripeError as e:
            db.rollback()
            raise HTTPException(status_code=400, detail=f"Stripe error: {str(e)}")
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Failed to cancel subscription: {str(e)}")
        finally:
            db.close()

    # --- PAYMENT HISTORY ---

    def get_payment_history(self, client_id: str, gym_id: str) -> list:
        """Get payment history for a client."""
        db = get_db_session()
        try:
            payments = db.query(PaymentORM).filter(
                PaymentORM.client_id == client_id,
                PaymentORM.gym_id == gym_id
            ).order_by(PaymentORM.created_at.desc()).all()

            return [
                {
                    "id": p.id,
                    "amount": p.amount,
                    "currency": p.currency,
                    "status": p.status,
                    "description": p.description,
                    "paid_at": p.paid_at,
                    "created_at": p.created_at
                }
                for p in payments
            ]

        finally:
            db.close()

    # --- PLAN OFFERS (Promotional discounts) ---

    def create_offer(self, gym_id: str, offer_data: dict) -> dict:
        """Create a promotional offer for subscription plans."""
        db = get_db_session()
        try:
            offer_id = str(uuid.uuid4())

            # Validate plan_id if provided
            if offer_data.get("plan_id"):
                plan = db.query(SubscriptionPlanORM).filter(
                    SubscriptionPlanORM.id == offer_data["plan_id"],
                    SubscriptionPlanORM.gym_id == gym_id
                ).first()
                if not plan:
                    raise HTTPException(status_code=404, detail="Plan not found")

            # Create Stripe Coupon if Stripe is configured
            stripe_coupon_id = None
            if is_stripe_configured():
                try:
                    coupon_params = {
                        "name": offer_data["title"],
                        "duration": "repeating" if offer_data.get("discount_duration_months", 1) > 1 else "once",
                        "metadata": {"gym_id": gym_id, "offer_id": offer_id}
                    }

                    if offer_data.get("discount_duration_months", 1) > 1:
                        coupon_params["duration_in_months"] = offer_data["discount_duration_months"]

                    if offer_data["discount_type"] == "percent":
                        coupon_params["percent_off"] = float(offer_data["discount_value"])
                    else:
                        # Fixed amount off - need currency
                        coupon_params["amount_off"] = int(float(offer_data["discount_value"]) * 100)
                        coupon_params["currency"] = "usd"

                    if offer_data.get("max_redemptions"):
                        coupon_params["max_redemptions"] = offer_data["max_redemptions"]

                    stripe_coupon = stripe.Coupon.create(**coupon_params)
                    stripe_coupon_id = stripe_coupon.id
                    logger.info(f"Created Stripe coupon: {stripe_coupon_id}")
                except stripe.StripeError as e:
                    logger.warning(f"Failed to create Stripe coupon: {e}")

            # Create offer (inactive by default - owner must activate to notify clients)
            offer = PlanOfferORM(
                id=offer_id,
                gym_id=gym_id,
                plan_id=offer_data.get("plan_id"),
                title=offer_data["title"],
                description=offer_data.get("description"),
                discount_type=offer_data["discount_type"],  # "percent" or "fixed"
                discount_value=offer_data["discount_value"],
                discount_duration_months=offer_data.get("discount_duration_months", 1),
                coupon_code=offer_data.get("coupon_code"),
                stripe_coupon_id=stripe_coupon_id,
                is_active=False,  # Created as draft - must be activated to notify clients
                starts_at=offer_data.get("starts_at", datetime.utcnow().isoformat()),
                expires_at=offer_data.get("expires_at"),
                max_redemptions=offer_data.get("max_redemptions"),
                current_redemptions=0,
                created_at=datetime.utcnow().isoformat(),
                updated_at=datetime.utcnow().isoformat()
            )

            db.add(offer)
            db.commit()

            logger.info(f"Created offer {offer_id} for gym {gym_id} (inactive - pending activation)")

            return {
                "offer_id": offer_id,
                "title": offer.title,
                "discount_type": offer.discount_type,
                "discount_value": offer.discount_value,
                "stripe_coupon_id": stripe_coupon_id
            }

        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error creating offer: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create offer: {str(e)}")
        finally:
            db.close()

    def _notify_clients_of_offer(self, db, gym_id: str, offer: PlanOfferORM):
        """Send notifications to all clients of the gym about a new offer."""
        try:
            # Get all clients associated with this gym
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()

            # Get gym owner name for notification
            owner = db.query(UserORM).filter(UserORM.id == gym_id).first()
            gym_name = owner.username if owner else "Your gym"

            # Create notification for each client
            for client in clients:
                discount_symbol = '%' if offer.discount_type == 'percent' else '€'
                default_msg = f"Get {offer.discount_value}{discount_symbol} off!"
                notification = NotificationORM(
                    user_id=client.id,
                    type="offer",
                    title="🎉 New Offer Available!",
                    message=f"{offer.title}: {offer.description or default_msg}",
                    data=json.dumps({
                        "offer_id": offer.id,
                        "gym_id": gym_id,
                        "discount_type": offer.discount_type,
                        "discount_value": offer.discount_value,
                        "coupon_code": offer.coupon_code
                    }),
                    read=False,
                    created_at=datetime.utcnow().isoformat()
                )
                db.add(notification)

            db.commit()
            logger.info(f"Sent offer notifications to {len(clients)} clients")

        except Exception as e:
            logger.error(f"Error sending offer notifications: {e}")
            # Don't fail the offer creation if notifications fail

    def get_gym_offers(self, gym_id: str, include_inactive: bool = False) -> list:
        """Get all offers for a gym."""
        db = get_db_session()
        try:
            query = db.query(PlanOfferORM).filter(PlanOfferORM.gym_id == gym_id)

            if not include_inactive:
                query = query.filter(PlanOfferORM.is_active == True)

            offers = query.order_by(PlanOfferORM.created_at.desc()).all()

            return [
                {
                    "id": o.id,
                    "plan_id": o.plan_id,
                    "title": o.title,
                    "description": o.description,
                    "discount_type": o.discount_type,
                    "discount_value": o.discount_value,
                    "discount_duration_months": o.discount_duration_months,
                    "coupon_code": o.coupon_code,
                    "is_active": o.is_active,
                    "starts_at": o.starts_at,
                    "expires_at": o.expires_at,
                    "max_redemptions": o.max_redemptions,
                    "current_redemptions": o.current_redemptions,
                    "created_at": o.created_at
                }
                for o in offers
            ]

        finally:
            db.close()

    def get_active_offers_for_client(self, gym_id: str) -> list:
        """Get active offers available for a client to use."""
        db = get_db_session()
        try:
            now = datetime.utcnow().isoformat()

            offers = db.query(PlanOfferORM).filter(
                PlanOfferORM.gym_id == gym_id,
                PlanOfferORM.is_active == True,
                PlanOfferORM.starts_at <= now
            ).all()

            # Filter out expired and maxed out offers
            active_offers = []
            for o in offers:
                # Check expiry
                if o.expires_at and o.expires_at < now:
                    continue
                # Check max redemptions
                if o.max_redemptions and o.current_redemptions >= o.max_redemptions:
                    continue

                # Get plan name if specific plan
                plan_name = None
                if o.plan_id:
                    plan = db.query(SubscriptionPlanORM).filter(
                        SubscriptionPlanORM.id == o.plan_id
                    ).first()
                    plan_name = plan.name if plan else None

                active_offers.append({
                    "id": o.id,
                    "plan_id": o.plan_id,
                    "plan_name": plan_name,
                    "title": o.title,
                    "description": o.description,
                    "discount_type": o.discount_type,
                    "discount_value": o.discount_value,
                    "discount_duration_months": o.discount_duration_months,
                    "coupon_code": o.coupon_code,
                    "expires_at": o.expires_at
                })

            return active_offers

        finally:
            db.close()

    def update_offer(self, gym_id: str, offer_id: str, offer_data: dict) -> dict:
        """Update an existing offer."""
        db = get_db_session()
        try:
            offer = db.query(PlanOfferORM).filter(
                PlanOfferORM.id == offer_id,
                PlanOfferORM.gym_id == gym_id
            ).first()

            if not offer:
                raise HTTPException(status_code=404, detail="Offer not found")

            # Track if offer is being activated (for notifications)
            was_inactive = not offer.is_active
            is_being_activated = False

            # Update fields
            if "title" in offer_data:
                offer.title = offer_data["title"]
            if "description" in offer_data:
                offer.description = offer_data["description"]
            if "is_active" in offer_data:
                is_being_activated = was_inactive and offer_data["is_active"]
                offer.is_active = offer_data["is_active"]
            if "expires_at" in offer_data:
                offer.expires_at = offer_data["expires_at"]

            offer.updated_at = datetime.utcnow().isoformat()

            db.commit()

            # Send notifications to clients when offer is activated
            if is_being_activated:
                self._notify_clients_of_offer(db, gym_id, offer)
                logger.info(f"Activated offer {offer_id} - notifications sent to gym clients")

            return {"status": "updated", "offer_id": offer_id, "notifications_sent": is_being_activated}

        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error updating offer: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to update offer: {str(e)}")
        finally:
            db.close()

    def delete_offer(self, gym_id: str, offer_id: str) -> dict:
        """Delete (deactivate) an offer."""
        db = get_db_session()
        try:
            offer = db.query(PlanOfferORM).filter(
                PlanOfferORM.id == offer_id,
                PlanOfferORM.gym_id == gym_id
            ).first()

            if not offer:
                raise HTTPException(status_code=404, detail="Offer not found")

            # Soft delete - just deactivate
            offer.is_active = False
            offer.updated_at = datetime.utcnow().isoformat()

            db.commit()

            return {"status": "deleted", "offer_id": offer_id}

        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error deleting offer: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to delete offer: {str(e)}")
        finally:
            db.close()

    def validate_coupon(self, gym_id: str, coupon_code: str, plan_id: str = None) -> dict:
        """Validate a coupon code and return discount info."""
        db = get_db_session()
        try:
            now = datetime.utcnow().isoformat()

            offer = db.query(PlanOfferORM).filter(
                PlanOfferORM.gym_id == gym_id,
                PlanOfferORM.coupon_code == coupon_code,
                PlanOfferORM.is_active == True,
                PlanOfferORM.starts_at <= now
            ).first()

            if not offer:
                return {"valid": False, "error": "Invalid coupon code"}

            # Check expiry
            if offer.expires_at and offer.expires_at < now:
                return {"valid": False, "error": "Coupon has expired"}

            # Check max redemptions
            if offer.max_redemptions and offer.current_redemptions >= offer.max_redemptions:
                return {"valid": False, "error": "Coupon limit reached"}

            # Check if coupon is for specific plan
            if offer.plan_id and plan_id and offer.plan_id != plan_id:
                return {"valid": False, "error": "Coupon not valid for this plan"}

            return {
                "valid": True,
                "offer_id": offer.id,
                "discount_type": offer.discount_type,
                "discount_value": offer.discount_value,
                "discount_duration_months": offer.discount_duration_months,
                "title": offer.title
            }

        finally:
            db.close()

    # --- STRIPE CONNECT (for gym owners to receive payments) ---

    def create_connect_account(self, owner_id: str, return_url: str, refresh_url: str) -> dict:
        """Create a Stripe Connect account for a gym owner and return onboarding link."""
        if not is_stripe_configured():
            raise HTTPException(status_code=400, detail="Stripe is not configured")

        db = get_db_session()
        try:
            # Get owner
            owner = db.query(UserORM).filter(
                UserORM.id == owner_id,
                UserORM.role == "owner"
            ).first()

            if not owner:
                raise HTTPException(status_code=404, detail="Owner not found")

            # Check if already has a connected account
            if owner.stripe_account_id:
                # Account exists, create new onboarding link to complete setup if needed
                account_link = stripe.AccountLink.create(
                    account=owner.stripe_account_id,
                    refresh_url=refresh_url,
                    return_url=return_url,
                    type="account_onboarding"
                )
                return {
                    "account_id": owner.stripe_account_id,
                    "onboarding_url": account_link.url,
                    "status": owner.stripe_account_status or "pending"
                }

            # Create new Connect account (Express type for easy onboarding)
            account = stripe.Account.create(
                type="express",
                country="IT",  # Default to Italy, can be made dynamic
                email=owner.email,
                capabilities={
                    "card_payments": {"requested": True},
                    "transfers": {"requested": True},
                },
                business_type="company",
                metadata={
                    "owner_id": owner_id,
                    "gym_code": owner.gym_code
                }
            )

            # Save account ID to database
            owner.stripe_account_id = account.id
            owner.stripe_account_status = "pending"
            db.commit()

            # Create onboarding link
            account_link = stripe.AccountLink.create(
                account=account.id,
                refresh_url=refresh_url,
                return_url=return_url,
                type="account_onboarding"
            )

            logger.info(f"Created Stripe Connect account for owner {owner_id}: {account.id}")

            return {
                "account_id": account.id,
                "onboarding_url": account_link.url,
                "status": "pending"
            }

        except stripe.StripeError as e:
            logger.error(f"Stripe error creating Connect account: {e}")
            raise HTTPException(status_code=400, detail=f"Stripe error: {str(e)}")
        finally:
            db.close()

    def get_connect_account_status(self, owner_id: str) -> dict:
        """Get the status of a gym owner's Stripe Connect account."""
        db = get_db_session()
        try:
            owner = db.query(UserORM).filter(
                UserORM.id == owner_id,
                UserORM.role == "owner"
            ).first()

            if not owner:
                raise HTTPException(status_code=404, detail="Owner not found")

            if not owner.stripe_account_id:
                return {
                    "connected": False,
                    "status": None,
                    "can_receive_payments": False
                }

            # Get account status from Stripe
            if is_stripe_configured():
                try:
                    account = stripe.Account.retrieve(owner.stripe_account_id)

                    # Check if account can receive payments
                    can_receive = (
                        account.charges_enabled and
                        account.payouts_enabled
                    )

                    # Update status in database
                    if can_receive:
                        owner.stripe_account_status = "active"
                    elif account.details_submitted:
                        owner.stripe_account_status = "pending_verification"
                    else:
                        owner.stripe_account_status = "pending"

                    db.commit()

                    return {
                        "connected": True,
                        "account_id": owner.stripe_account_id,
                        "status": owner.stripe_account_status,
                        "can_receive_payments": can_receive,
                        "charges_enabled": account.charges_enabled,
                        "payouts_enabled": account.payouts_enabled,
                        "details_submitted": account.details_submitted
                    }

                except stripe.StripeError as e:
                    logger.error(f"Error checking Stripe account: {e}")
                    return {
                        "connected": True,
                        "account_id": owner.stripe_account_id,
                        "status": owner.stripe_account_status or "unknown",
                        "can_receive_payments": False,
                        "error": str(e)
                    }
            else:
                # Test mode
                return {
                    "connected": True,
                    "account_id": owner.stripe_account_id,
                    "status": "test_mode",
                    "can_receive_payments": True
                }

        finally:
            db.close()

    def get_gym_stripe_account(self, gym_id: str) -> str:
        """Get the Stripe Connect account ID for a gym (by owner)."""
        db = get_db_session()
        try:
            # Find the owner of this gym
            owner = db.query(UserORM).filter(
                UserORM.id == gym_id,  # gym_id is typically the owner's user id
                UserORM.role == "owner"
            ).first()

            if not owner:
                # Try finding by gym_code if gym_id is actually a gym code
                owner = db.query(UserORM).filter(
                    UserORM.gym_code == gym_id,
                    UserORM.role == "owner"
                ).first()

            if owner and owner.stripe_account_id and owner.stripe_account_status == "active":
                return owner.stripe_account_id

            return None

        finally:
            db.close()

    def create_connect_login_link(self, owner_id: str) -> dict:
        """Create a login link for the owner to access their Stripe dashboard."""
        if not is_stripe_configured():
            raise HTTPException(status_code=400, detail="Stripe is not configured")

        db = get_db_session()
        try:
            owner = db.query(UserORM).filter(
                UserORM.id == owner_id,
                UserORM.role == "owner"
            ).first()

            if not owner or not owner.stripe_account_id:
                raise HTTPException(status_code=404, detail="No connected Stripe account found")

            login_link = stripe.Account.create_login_link(owner.stripe_account_id)

            return {"url": login_link.url}

        except stripe.StripeError as e:
            logger.error(f"Error creating login link: {e}")
            raise HTTPException(status_code=400, detail=f"Stripe error: {str(e)}")
        finally:
            db.close()

    # --- STRIPE WEBHOOKS ---

    def handle_webhook(self, payload: dict, signature: str) -> dict:
        """Handle Stripe webhook events."""
        webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET")

        try:
            event = stripe.Webhook.construct_event(
                payload, signature, webhook_secret
            )
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid payload")
        except stripe.SignatureVerificationError:
            raise HTTPException(status_code=400, detail="Invalid signature")

        # Handle the event
        if event.type == "customer.subscription.updated":
            self._handle_subscription_updated(event.data.object)
        elif event.type == "customer.subscription.deleted":
            self._handle_subscription_deleted(event.data.object)
        elif event.type == "invoice.payment_succeeded":
            self._handle_payment_succeeded(event.data.object)
        elif event.type == "invoice.payment_failed":
            self._handle_payment_failed(event.data.object)

        return {"status": "success"}

    def _handle_subscription_updated(self, stripe_sub):
        """Handle subscription.updated webhook."""
        db = get_db_session()
        try:
            subscription = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.stripe_subscription_id == stripe_sub.id
            ).first()

            if subscription:
                subscription.status = stripe_sub.status
                subscription.current_period_start = datetime.fromtimestamp(stripe_sub.current_period_start).isoformat()
                subscription.current_period_end = datetime.fromtimestamp(stripe_sub.current_period_end).isoformat()
                subscription.cancel_at_period_end = stripe_sub.cancel_at_period_end
                subscription.updated_at = datetime.utcnow().isoformat()

                db.commit()
                logger.info(f"Updated subscription from webhook: {subscription.id}")

        finally:
            db.close()

    def _handle_subscription_deleted(self, stripe_sub):
        """Handle subscription.deleted webhook."""
        db = get_db_session()
        try:
            subscription = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.stripe_subscription_id == stripe_sub.id
            ).first()

            if subscription:
                subscription.status = "canceled"
                subscription.ended_at = datetime.utcnow().isoformat()
                subscription.updated_at = datetime.utcnow().isoformat()

                db.commit()
                logger.info(f"Canceled subscription from webhook: {subscription.id}")

        finally:
            db.close()

    def _handle_payment_succeeded(self, invoice):
        """Handle invoice.payment_succeeded webhook."""
        db = get_db_session()
        try:
            subscription = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.stripe_subscription_id == invoice.subscription
            ).first()

            if subscription:
                # Create payment record
                payment = PaymentORM(
                    id=str(uuid.uuid4()),
                    client_id=subscription.client_id,
                    subscription_id=subscription.id,
                    gym_id=subscription.gym_id,
                    amount=invoice.amount_paid / 100,  # Convert cents to dollars
                    currency=invoice.currency,
                    status="succeeded",
                    stripe_payment_intent_id=invoice.payment_intent,
                    stripe_invoice_id=invoice.id,
                    description=f"Payment for subscription",
                    paid_at=datetime.fromtimestamp(invoice.status_transitions.paid_at).isoformat() if invoice.status_transitions.paid_at else None
                )

                db.add(payment)
                db.commit()
                logger.info(f"Recorded payment from webhook: {payment.id}")

        finally:
            db.close()

    def _handle_payment_failed(self, invoice):
        """Handle invoice.payment_failed webhook."""
        db = get_db_session()
        try:
            subscription = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.stripe_subscription_id == invoice.subscription
            ).first()

            if subscription:
                subscription.status = "past_due"
                subscription.updated_at = datetime.utcnow().isoformat()

                # Create failed payment record
                payment = PaymentORM(
                    id=str(uuid.uuid4()),
                    client_id=subscription.client_id,
                    subscription_id=subscription.id,
                    gym_id=subscription.gym_id,
                    amount=invoice.amount_due / 100,
                    currency=invoice.currency,
                    status="failed",
                    stripe_payment_intent_id=invoice.payment_intent,
                    stripe_invoice_id=invoice.id,
                    description=f"Failed payment for subscription"
                )

                db.add(payment)
                db.commit()
                logger.info(f"Recorded failed payment from webhook: {payment.id}")

        finally:
            db.close()


# Singleton instance
subscription_service = SubscriptionService()


def get_subscription_service() -> SubscriptionService:
    """Dependency injection helper."""
    return subscription_service
