"""
Subscription Service - handles subscription plans, payments, and Stripe integration.
"""
from .base import (
    HTTPException, json, logging, date, datetime,
    get_db_session
)
from models_orm import SubscriptionPlanORM, ClientSubscriptionORM, PaymentORM
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

            # Create Stripe subscription
            stripe_sub = stripe.Subscription.create(
                customer=stripe_customer.id,
                items=[{"price": plan.stripe_price_id}],
                trial_period_days=plan.trial_period_days if plan.trial_period_days > 0 else None,
                metadata={
                    "client_id": client_id,
                    "gym_id": gym_id,
                    "plan_id": plan.id
                }
            )

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
