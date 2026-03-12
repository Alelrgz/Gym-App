"""
Trigger Check Service - detects trigger conditions and queues automated messages.
"""
from .base import (
    HTTPException, json, logging, datetime, timedelta, date,
    get_db_session, ClientScheduleORM, ClientProfileORM, UserORM,
    AutomatedMessageTemplateORM
)
from models_orm import AppointmentORM, ClientSubscriptionORM, SubscriptionPlanORM, PlanOfferORM, PaymentORM
from typing import List, Dict, Optional
import os
from .automated_message_service import get_automated_message_service
from .message_dispatch_service import get_message_dispatch_service

logger = logging.getLogger("gym_app")


class TriggerCheckService:
    """Service for checking trigger conditions and sending automated messages."""

    def check_all_triggers(self, gym_id: str = None) -> dict:
        """
        Main entry point - check all triggers for a gym (or all gyms).
        Returns summary of processed triggers.
        """
        db = get_db_session()
        try:
            results = {
                "gyms_processed": 0,
                "templates_checked": 0,
                "messages_sent": 0,
                "messages_skipped": 0,
                "errors": []
            }

            # Get all gyms with enabled templates, or specific gym
            query = db.query(AutomatedMessageTemplateORM).filter(
                AutomatedMessageTemplateORM.is_enabled == True
            )
            if gym_id:
                query = query.filter(AutomatedMessageTemplateORM.gym_id == gym_id)

            templates = query.all()

            # Group templates by gym
            gyms_templates = {}
            for template in templates:
                if template.gym_id not in gyms_templates:
                    gyms_templates[template.gym_id] = []
                gyms_templates[template.gym_id].append(template)

            # Process each gym
            for gid, gym_templates in gyms_templates.items():
                results["gyms_processed"] += 1

                for template in gym_templates:
                    results["templates_checked"] += 1

                    try:
                        sent, skipped = self._process_template(gid, template)
                        results["messages_sent"] += sent
                        results["messages_skipped"] += skipped
                    except Exception as e:
                        error_msg = f"Error processing template {template.id}: {str(e)}"
                        logger.error(error_msg)
                        results["errors"].append(error_msg)

            logger.info(f"Trigger check complete: {results}")
            return results

        finally:
            db.close()

    def _process_template(self, gym_id: str, template: AutomatedMessageTemplateORM) -> tuple:
        """Process a single template and return (sent_count, skipped_count)."""
        sent = 0
        skipped = 0

        trigger_config = json.loads(template.trigger_config) if template.trigger_config else {}

        # Get matches based on trigger type
        if template.trigger_type == "missed_workout":
            matches = self.check_missed_workouts(gym_id)
        elif template.trigger_type == "days_inactive":
            threshold = trigger_config.get("days_threshold", 5)
            matches = self.check_days_inactive(gym_id, threshold)
        elif template.trigger_type == "no_show_appointment":
            matches = self.check_no_show_appointments(gym_id)
        elif template.trigger_type == "subscription_canceled":
            days_since = trigger_config.get("days_since_cancellation", 7)
            matches = self.check_subscription_canceled(gym_id, days_since)
        elif template.trigger_type == "payment_failed":
            days_window = trigger_config.get("days_threshold", 3)
            matches = self.check_payment_failed(gym_id, days_window)
        elif template.trigger_type == "upcoming_appointment":
            hours_before = trigger_config.get("hours_before", 24)
            matches = self.check_upcoming_appointments(gym_id, hours_before)
        else:
            logger.warning(f"Unknown trigger type: {template.trigger_type}")
            return 0, 0

        # Process each match
        auto_msg_service = get_automated_message_service()
        dispatch_service = get_message_dispatch_service()

        for match in matches:
            client_id = match["client_id"]
            trigger_ref = match.get("trigger_reference")

            # Check deduplication
            if auto_msg_service.was_message_sent(template.id, client_id, trigger_ref, within_hours=24):
                skipped += 1
                continue

            # Build context for variable substitution
            context = self._build_context(match, gym_id=gym_id, linked_offer_id=template.linked_offer_id)

            # Substitute variables in message
            message = auto_msg_service.substitute_variables(template.message_template, context)
            subject = auto_msg_service.substitute_variables(template.subject, context) if template.subject else None

            # Get delivery methods
            delivery_methods = json.loads(template.delivery_methods) if template.delivery_methods else ["in_app"]

            # Send via each delivery method
            for method in delivery_methods:
                try:
                    success = dispatch_service.send_message(
                        client_id=client_id,
                        delivery_method=method,
                        title=template.name,
                        message=message,
                        subject=subject,
                        data={
                            "template_id": template.id,
                            "trigger_type": template.trigger_type,
                            "trigger_reference": trigger_ref,
                            **({"coupon_code": context["coupon_code"], "offer_title": context["offer_title"]} if context.get("coupon_code") else {}),
                        },
                        gym_id=gym_id
                    )

                    # Log the message
                    auto_msg_service.log_message(
                        template_id=template.id,
                        client_id=client_id,
                        gym_id=gym_id,
                        trigger_type=template.trigger_type,
                        trigger_ref=trigger_ref,
                        delivery_method=method,
                        status="sent" if success else "failed"
                    )

                    if success:
                        sent += 1
                    else:
                        skipped += 1

                except Exception as e:
                    logger.error(f"Error sending message: {e}")
                    auto_msg_service.log_message(
                        template_id=template.id,
                        client_id=client_id,
                        gym_id=gym_id,
                        trigger_type=template.trigger_type,
                        trigger_ref=trigger_ref,
                        delivery_method=method,
                        status="failed",
                        error_message=str(e)
                    )
                    skipped += 1

        return sent, skipped

    def _build_context(self, match: dict, gym_id: str = None, linked_offer_id: str = None) -> dict:
        """Build context dictionary for variable substitution."""
        ctx = {
            "client_name": match.get("client_name", ""),
            "days_inactive": str(match.get("days_inactive", "")),
            "workout_title": match.get("workout_title", ""),
            "trainer_name": match.get("trainer_name", ""),
            "appointment_date": match.get("appointment_date", ""),
            "appointment_time": match.get("appointment_time", ""),
            "plan_name": match.get("plan_name", ""),
            "canceled_at": match.get("canceled_at", ""),
            "days_since_cancellation": str(match.get("days_since_cancellation", "")),
            "amount": match.get("amount", ""),
            "currency": match.get("currency", ""),
            "gym_name": "",
            # Offer variables (populated when linked_offer_id is set)
            "offer_title": "",
            "discount_value": "",
            "discount_symbol": "",
            "coupon_code": "",
            "offer_expires": "",
            "checkout_link": "",
        }

        # Enrich with gym name, trainer name, and linked offer
        if gym_id or match.get("client_id") or linked_offer_id:
            db = get_db_session()
            try:
                if gym_id and not ctx["gym_name"]:
                    gym_user = db.query(UserORM).filter(UserORM.id == gym_id).first()
                    if gym_user:
                        ctx["gym_name"] = gym_user.username or ""

                if match.get("client_id") and not ctx["trainer_name"]:
                    profile = db.query(ClientProfileORM).filter(
                        ClientProfileORM.id == match["client_id"]
                    ).first()
                    if profile and profile.trainer_id:
                        trainer = db.query(UserORM).filter(UserORM.id == str(profile.trainer_id)).first()
                        if trainer:
                            ctx["trainer_name"] = trainer.username or ""

                # Load linked offer details
                if linked_offer_id:
                    offer = db.query(PlanOfferORM).filter(
                        PlanOfferORM.id == linked_offer_id,
                        PlanOfferORM.is_active == True
                    ).first()
                    if offer:
                        ctx["offer_title"] = offer.title or ""
                        ctx["discount_value"] = str(int(offer.discount_value) if offer.discount_value == int(offer.discount_value) else offer.discount_value)
                        ctx["discount_symbol"] = "%" if offer.discount_type == "percent" else "€"
                        ctx["coupon_code"] = offer.coupon_code or ""
                        ctx["offer_expires"] = offer.expires_at or "nessuna scadenza"
                        # Build checkout link
                        base = os.environ.get("SERVER_BASE_URL", "http://localhost:9008")
                        client_id = match.get("client_id", "")
                        ctx["checkout_link"] = f"{base}/api/redeem/{linked_offer_id}?client_id={client_id}"
            except Exception:
                pass
            finally:
                db.close()

        return ctx

    def check_missed_workouts(self, gym_id: str) -> List[dict]:
        """
        Find clients with scheduled workouts that were not completed.
        Returns list of {client_id, client_name, workout_title, date, trigger_reference}
        """
        db = get_db_session()
        try:
            today = date.today().isoformat()

            # Get all clients in this gym
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()
            client_ids = [c.user_id for c in clients]

            if not client_ids:
                return []

            # Find missed workouts (past date, not completed)
            missed = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id.in_(client_ids),
                ClientScheduleORM.date < today,
                ClientScheduleORM.completed == False,
                ClientScheduleORM.type == "workout"
            ).all()

            # Get client names
            client_names = {}
            if missed:
                users = db.query(UserORM).filter(
                    UserORM.id.in_([m.client_id for m in missed])
                ).all()
                client_names = {u.id: u.username for u in users}

            return [
                {
                    "client_id": m.client_id,
                    "client_name": client_names.get(m.client_id, ""),
                    "workout_title": m.title or "Workout",
                    "date": m.date,
                    "trigger_reference": f"schedule_{m.id}"
                }
                for m in missed
            ]

        finally:
            db.close()

    def check_days_inactive(self, gym_id: str, threshold_days: int) -> List[dict]:
        """
        Find clients who haven't completed a workout in X days.
        Returns list of {client_id, client_name, days_inactive, last_workout_date}
        """
        db = get_db_session()
        try:
            today = date.today()
            cutoff_date = (today - timedelta(days=threshold_days)).isoformat()

            # Get all clients in this gym
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()

            if not clients:
                return []

            # Get client names
            user_ids = [c.user_id for c in clients]
            users = db.query(UserORM).filter(UserORM.id.in_(user_ids)).all()
            client_names = {u.id: u.username for u in users}

            results = []
            for client in clients:
                # Find last completed workout
                last_workout = db.query(ClientScheduleORM).filter(
                    ClientScheduleORM.client_id == client.user_id,
                    ClientScheduleORM.type == "workout",
                    ClientScheduleORM.completed == True
                ).order_by(ClientScheduleORM.date.desc()).first()

                if last_workout:
                    last_date = datetime.strptime(last_workout.date, "%Y-%m-%d").date()
                    days_inactive = (today - last_date).days

                    if days_inactive >= threshold_days:
                        results.append({
                            "client_id": client.user_id,
                            "client_name": client_names.get(client.user_id, ""),
                            "days_inactive": days_inactive,
                            "last_workout_date": last_workout.date,
                            "trigger_reference": f"inactive_{client.user_id}_{today.isoformat()}"
                        })
                else:
                    # No workouts ever - check account age
                    # For simplicity, treat as inactive if no workouts at all
                    results.append({
                        "client_id": client.user_id,
                        "client_name": client_names.get(client.user_id, ""),
                        "days_inactive": threshold_days,
                        "last_workout_date": None,
                        "trigger_reference": f"inactive_{client.user_id}_{today.isoformat()}"
                    })

            return results

        finally:
            db.close()

    def check_no_show_appointments(self, gym_id: str) -> List[dict]:
        """
        Find appointments where client didn't show up.
        Returns list of {client_id, client_name, trainer_name, appointment_date, appointment_time, trigger_reference}
        """
        db = get_db_session()
        try:
            today = date.today().isoformat()

            # Get all clients in this gym
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()
            client_ids = [c.user_id for c in clients]

            if not client_ids:
                return []

            # Find past appointments that are still "scheduled" (not completed, not canceled)
            no_shows = db.query(AppointmentORM).filter(
                AppointmentORM.client_id.in_(client_ids),
                AppointmentORM.date < today,
                AppointmentORM.status == "scheduled"
            ).all()

            if not no_shows:
                return []

            # Get client and trainer names
            all_user_ids = list(set(
                [a.client_id for a in no_shows] +
                [a.trainer_id for a in no_shows if a.trainer_id]
            ))
            users = db.query(UserORM).filter(UserORM.id.in_(all_user_ids)).all()
            user_names = {u.id: u.username for u in users}

            return [
                {
                    "client_id": a.client_id,
                    "client_name": user_names.get(a.client_id, ""),
                    "trainer_name": user_names.get(a.trainer_id, "") if a.trainer_id else "",
                    "appointment_date": a.date,
                    "appointment_time": a.start_time,
                    "trigger_reference": f"appointment_{a.id}"
                }
                for a in no_shows
            ]

        finally:
            db.close()


    def check_subscription_canceled(self, gym_id: str, days_since_threshold: int = 7) -> List[dict]:
        """
        Find clients whose subscription was recently canceled.
        Returns list of {client_id, client_name, plan_name, canceled_at, days_since_cancellation, trigger_reference}
        """
        db = get_db_session()
        try:
            today = date.today()

            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()

            if not clients:
                return []

            client_ids = [c.id for c in clients]

            # Find canceled/past_due subscriptions
            canceled_subs = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.client_id.in_(client_ids),
                ClientSubscriptionORM.gym_id == gym_id,
                ClientSubscriptionORM.status.in_(['canceled', 'past_due']),
            ).all()

            if not canceled_subs:
                return []

            # Get user names
            users = db.query(UserORM).filter(UserORM.id.in_(client_ids)).all()
            user_names = {u.id: u.username for u in users}

            results = []
            for sub in canceled_subs:
                cancel_date_str = sub.canceled_at or sub.current_period_end or sub.created_at
                if not cancel_date_str:
                    continue

                try:
                    cancel_date = datetime.fromisoformat(
                        cancel_date_str.replace('Z', '+00:00')
                    ).date()
                    days_since = (today - cancel_date).days
                except:
                    continue

                if days_since > days_since_threshold:
                    continue

                # Verify no active subscription exists
                active = db.query(ClientSubscriptionORM).filter(
                    ClientSubscriptionORM.client_id == sub.client_id,
                    ClientSubscriptionORM.gym_id == gym_id,
                    ClientSubscriptionORM.status == "active"
                ).first()
                if active:
                    continue

                # Get plan name
                plan_name = ""
                if sub.plan_id:
                    plan = db.query(SubscriptionPlanORM).filter(
                        SubscriptionPlanORM.id == sub.plan_id
                    ).first()
                    plan_name = plan.name if plan else ""

                results.append({
                    "client_id": sub.client_id,
                    "client_name": user_names.get(sub.client_id, ""),
                    "plan_name": plan_name,
                    "canceled_at": cancel_date_str,
                    "days_since_cancellation": days_since,
                    "trigger_reference": f"sub_canceled_{sub.id}"
                })

            return results
        finally:
            db.close()


    def check_upcoming_appointments(self, gym_id: str, hours_before: int = 24) -> List[dict]:
        """
        Find appointments happening within the next X hours.
        Returns list of {client_id, client_name, trainer_name, appointment_date, appointment_time, trigger_reference}
        """
        db = get_db_session()
        try:
            now = datetime.utcnow()
            today = date.today()
            tomorrow = today + timedelta(days=1)

            # Get all clients in this gym
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()
            client_ids = [c.user_id for c in clients]

            if not client_ids:
                return []

            # Find upcoming appointments within the window (today and tomorrow)
            upcoming = db.query(AppointmentORM).filter(
                AppointmentORM.client_id.in_(client_ids),
                AppointmentORM.status == "scheduled",
                AppointmentORM.date.in_([today.isoformat(), tomorrow.isoformat()])
            ).all()

            if not upcoming:
                return []

            # Get user names
            all_user_ids = list(set(
                [a.client_id for a in upcoming] +
                [a.trainer_id for a in upcoming if a.trainer_id]
            ))
            users = db.query(UserORM).filter(UserORM.id.in_(all_user_ids)).all()
            user_names = {u.id: u.username for u in users}

            results = []
            for a in upcoming:
                # Calculate hours until appointment
                try:
                    appt_dt = datetime.strptime(f"{a.date} {a.start_time}", "%Y-%m-%d %H:%M")
                    hours_until = (appt_dt - now).total_seconds() / 3600
                except (ValueError, TypeError):
                    continue

                # Only include if within the window and in the future
                if 0 < hours_until <= hours_before:
                    results.append({
                        "client_id": a.client_id,
                        "client_name": user_names.get(a.client_id, ""),
                        "trainer_name": user_names.get(a.trainer_id, "") if a.trainer_id else "",
                        "appointment_date": a.date,
                        "appointment_time": a.start_time,
                        "trigger_reference": f"upcoming_appt_{a.id}_{a.date}"
                    })

            return results

        finally:
            db.close()

    def check_payment_failed(self, gym_id: str, days_window: int = 3) -> List[dict]:
        """
        Find clients with recently failed payments.
        Returns list of {client_id, client_name, amount, plan_name, trigger_reference}
        """
        db = get_db_session()
        try:
            cutoff = (date.today() - timedelta(days=days_window)).isoformat()

            # Get all clients in this gym
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()
            client_ids = [c.user_id for c in clients]

            if not client_ids:
                return []

            # Find recent failed payments
            failed = db.query(PaymentORM).filter(
                PaymentORM.client_id.in_(client_ids),
                PaymentORM.gym_id == gym_id,
                PaymentORM.status == "failed",
                PaymentORM.created_at >= cutoff
            ).all()

            if not failed:
                return []

            # Get client names
            users = db.query(UserORM).filter(
                UserORM.id.in_([p.client_id for p in failed])
            ).all()
            user_names = {u.id: u.username for u in users}

            # Get plan names via subscription
            sub_ids = [p.subscription_id for p in failed if p.subscription_id]
            plan_names = {}
            if sub_ids:
                subs = db.query(ClientSubscriptionORM).filter(
                    ClientSubscriptionORM.id.in_(sub_ids)
                ).all()
                plan_ids = [s.plan_id for s in subs if s.plan_id]
                if plan_ids:
                    plans = db.query(SubscriptionPlanORM).filter(
                        SubscriptionPlanORM.id.in_(plan_ids)
                    ).all()
                    plan_map = {p.id: p.name for p in plans}
                    for s in subs:
                        plan_names[s.id] = plan_map.get(s.plan_id, "")

            return [
                {
                    "client_id": p.client_id,
                    "client_name": user_names.get(p.client_id, ""),
                    "amount": str(p.amount or 0),
                    "currency": p.currency or "eur",
                    "plan_name": plan_names.get(p.subscription_id, ""),
                    "trigger_reference": f"payment_failed_{p.id}"
                }
                for p in failed
            ]

        finally:
            db.close()

    def fire_for_client(self, gym_id: str, client_id: str, trigger_type: str, match_data: dict):
        """
        Fire automations for a specific client immediately (called from webhooks).
        Unlike check_all_triggers which scans all clients, this targets one client.
        """
        db = get_db_session()
        try:
            templates = db.query(AutomatedMessageTemplateORM).filter(
                AutomatedMessageTemplateORM.gym_id == gym_id,
                AutomatedMessageTemplateORM.trigger_type == trigger_type,
                AutomatedMessageTemplateORM.is_enabled == True
            ).all()

            if not templates:
                return

            auto_msg_service = get_automated_message_service()
            dispatch_service = get_message_dispatch_service()

            for template in templates:
                trigger_ref = match_data.get("trigger_reference")

                if auto_msg_service.was_message_sent(template.id, client_id, trigger_ref, within_hours=24):
                    continue

                context = self._build_context(match_data, gym_id=gym_id, linked_offer_id=template.linked_offer_id)
                message = auto_msg_service.substitute_variables(template.message_template, context)
                subject = auto_msg_service.substitute_variables(template.subject, context) if template.subject else None

                delivery_methods = json.loads(template.delivery_methods) if template.delivery_methods else ["in_app"]

                for method in delivery_methods:
                    try:
                        success = dispatch_service.send_message(
                            client_id=client_id,
                            delivery_method=method,
                            title=template.name,
                            message=message,
                            subject=subject,
                            data={
                                "template_id": template.id,
                                "trigger_type": trigger_type,
                                "trigger_reference": trigger_ref,
                                **({"coupon_code": context["coupon_code"], "offer_title": context["offer_title"]} if context.get("coupon_code") else {}),
                            },
                            gym_id=gym_id
                        )
                        auto_msg_service.log_message(
                            template_id=template.id,
                            client_id=client_id,
                            gym_id=gym_id,
                            trigger_type=trigger_type,
                            trigger_ref=trigger_ref,
                            delivery_method=method,
                            status="sent" if success else "failed"
                        )
                    except Exception as e:
                        logger.error(f"Error in fire_for_client: {e}")

        except Exception as e:
            logger.error(f"Error in fire_for_client: {e}")
        finally:
            db.close()


# Singleton instance
trigger_check_service = TriggerCheckService()


def get_trigger_check_service() -> TriggerCheckService:
    """Dependency injection helper."""
    return trigger_check_service
