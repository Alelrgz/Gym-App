"""
Trigger Check Service - detects trigger conditions and queues automated messages.
"""
from .base import (
    HTTPException, json, logging, datetime, timedelta, date,
    get_db_session, ClientScheduleORM, ClientProfileORM, UserORM,
    AutomatedMessageTemplateORM
)
from models_orm import AppointmentORM
from typing import List, Dict, Optional
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
            context = self._build_context(match)

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
                            "trigger_reference": trigger_ref
                        }
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

    def _build_context(self, match: dict) -> dict:
        """Build context dictionary for variable substitution."""
        return {
            "client_name": match.get("client_name", ""),
            "days_inactive": str(match.get("days_inactive", "")),
            "workout_title": match.get("workout_title", ""),
            "trainer_name": match.get("trainer_name", ""),
            "appointment_date": match.get("appointment_date", ""),
            "appointment_time": match.get("appointment_time", "")
        }

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


# Singleton instance
trigger_check_service = TriggerCheckService()


def get_trigger_check_service() -> TriggerCheckService:
    """Dependency injection helper."""
    return trigger_check_service
