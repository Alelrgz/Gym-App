"""
Automated Message Service - handles creating and managing automated message templates.
"""
from .base import (
    HTTPException, json, logging, datetime, timedelta, uuid,
    get_db_session, AutomatedMessageTemplateORM, AutomatedMessageLogORM,
    UserORM, ClientProfileORM
)
from typing import List, Optional

logger = logging.getLogger("gym_app")


class AutomatedMessageService:
    """Service for managing automated message templates and tracking sent messages."""

    def create_template(self, gym_id: str, data: dict) -> dict:
        """Create a new automated message template."""
        db = get_db_session()
        try:
            template_id = str(uuid.uuid4())

            template = AutomatedMessageTemplateORM(
                id=template_id,
                gym_id=gym_id,
                name=data.get("name"),
                trigger_type=data.get("trigger_type"),
                trigger_config=json.dumps(data.get("trigger_config")) if data.get("trigger_config") else None,
                subject=data.get("subject"),
                message_template=data.get("message_template"),
                delivery_methods=json.dumps(data.get("delivery_methods", ["in_app"])),
                is_enabled=data.get("is_enabled", True),
                send_delay_hours=data.get("send_delay_hours", 0),
                created_at=datetime.utcnow().isoformat()
            )

            db.add(template)
            db.commit()
            db.refresh(template)

            logger.info(f"Created automated message template: {template.name} for gym {gym_id}")

            return self._template_to_dict(template)

        except Exception as e:
            db.rollback()
            logger.error(f"Error creating automated message template: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to create template: {str(e)}")
        finally:
            db.close()

    def get_templates(self, gym_id: str, include_disabled: bool = True) -> List[dict]:
        """Get all templates for a gym."""
        db = get_db_session()
        try:
            query = db.query(AutomatedMessageTemplateORM).filter(
                AutomatedMessageTemplateORM.gym_id == gym_id
            )

            if not include_disabled:
                query = query.filter(AutomatedMessageTemplateORM.is_enabled == True)

            templates = query.order_by(
                AutomatedMessageTemplateORM.created_at.desc()
            ).all()

            return [self._template_to_dict(t) for t in templates]

        finally:
            db.close()

    def get_template(self, template_id: str, gym_id: str) -> dict:
        """Get a specific template."""
        db = get_db_session()
        try:
            template = db.query(AutomatedMessageTemplateORM).filter(
                AutomatedMessageTemplateORM.id == template_id,
                AutomatedMessageTemplateORM.gym_id == gym_id
            ).first()

            if not template:
                raise HTTPException(status_code=404, detail="Template not found")

            return self._template_to_dict(template)

        finally:
            db.close()

    def update_template(self, template_id: str, gym_id: str, updates: dict) -> dict:
        """Update an existing template."""
        db = get_db_session()
        try:
            template = db.query(AutomatedMessageTemplateORM).filter(
                AutomatedMessageTemplateORM.id == template_id,
                AutomatedMessageTemplateORM.gym_id == gym_id
            ).first()

            if not template:
                raise HTTPException(status_code=404, detail="Template not found")

            # Update allowed fields
            if "name" in updates:
                template.name = updates["name"]
            if "trigger_type" in updates:
                template.trigger_type = updates["trigger_type"]
            if "trigger_config" in updates:
                template.trigger_config = json.dumps(updates["trigger_config"]) if updates["trigger_config"] else None
            if "subject" in updates:
                template.subject = updates["subject"]
            if "message_template" in updates:
                template.message_template = updates["message_template"]
            if "delivery_methods" in updates:
                template.delivery_methods = json.dumps(updates["delivery_methods"])
            if "is_enabled" in updates:
                template.is_enabled = updates["is_enabled"]
            if "send_delay_hours" in updates:
                template.send_delay_hours = updates["send_delay_hours"]

            template.updated_at = datetime.utcnow().isoformat()

            db.commit()
            db.refresh(template)

            logger.info(f"Updated automated message template: {template_id}")

            return self._template_to_dict(template)

        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error updating automated message template: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to update template: {str(e)}")
        finally:
            db.close()

    def delete_template(self, template_id: str, gym_id: str) -> dict:
        """Delete a template."""
        db = get_db_session()
        try:
            template = db.query(AutomatedMessageTemplateORM).filter(
                AutomatedMessageTemplateORM.id == template_id,
                AutomatedMessageTemplateORM.gym_id == gym_id
            ).first()

            if not template:
                raise HTTPException(status_code=404, detail="Template not found")

            db.delete(template)
            db.commit()

            logger.info(f"Deleted automated message template: {template_id}")

            return {"status": "success", "message": "Template deleted"}

        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error deleting automated message template: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to delete template: {str(e)}")
        finally:
            db.close()

    def toggle_template(self, template_id: str, gym_id: str) -> dict:
        """Toggle a template's enabled status."""
        db = get_db_session()
        try:
            template = db.query(AutomatedMessageTemplateORM).filter(
                AutomatedMessageTemplateORM.id == template_id,
                AutomatedMessageTemplateORM.gym_id == gym_id
            ).first()

            if not template:
                raise HTTPException(status_code=404, detail="Template not found")

            template.is_enabled = not template.is_enabled
            template.updated_at = datetime.utcnow().isoformat()

            db.commit()
            db.refresh(template)

            status = "enabled" if template.is_enabled else "disabled"
            logger.info(f"Template {template_id} {status}")

            return self._template_to_dict(template)

        except HTTPException:
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error toggling automated message template: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to toggle template: {str(e)}")
        finally:
            db.close()

    def preview_message(self, template_id: str, gym_id: str, sample_client_id: str = None) -> dict:
        """Preview a message with variable substitution using sample data."""
        db = get_db_session()
        try:
            template = db.query(AutomatedMessageTemplateORM).filter(
                AutomatedMessageTemplateORM.id == template_id,
                AutomatedMessageTemplateORM.gym_id == gym_id
            ).first()

            if not template:
                raise HTTPException(status_code=404, detail="Template not found")

            # Get sample client data if provided
            sample_client = None
            if sample_client_id:
                user = db.query(UserORM).filter(UserORM.id == sample_client_id).first()
                profile = db.query(ClientProfileORM).filter(ClientProfileORM.user_id == sample_client_id).first()
                if user:
                    sample_client = {
                        "id": user.id,
                        "name": user.username,
                        "email": user.email
                    }

            # Build context with sample or placeholder data
            context = {
                "client_name": sample_client["name"] if sample_client else "John Doe",
                "days_inactive": "7",
                "workout_title": "Push Day",
                "trainer_name": "Your Trainer",
                "gym_name": "Your Gym"
            }

            # Substitute variables
            preview_message = self.substitute_variables(template.message_template, context)
            preview_subject = self.substitute_variables(template.subject, context) if template.subject else None

            return {
                "subject": preview_subject,
                "message": preview_message,
                "variables_used": self._extract_variables(template.message_template),
                "sample_client": sample_client
            }

        finally:
            db.close()

    def substitute_variables(self, template: str, context: dict) -> str:
        """Replace {variables} in template with context values."""
        if not template:
            return template

        result = template
        for key, value in context.items():
            result = result.replace(f"{{{key}}}", str(value))

        return result

    def _extract_variables(self, template: str) -> List[str]:
        """Extract variable names from a template string."""
        import re
        if not template:
            return []
        return re.findall(r'\{(\w+)\}', template)

    def was_message_sent(
        self,
        template_id: str,
        client_id: str,
        trigger_ref: str = None,
        within_hours: int = 24
    ) -> bool:
        """Check if a message was already sent (for deduplication)."""
        db = get_db_session()
        try:
            cutoff = (datetime.utcnow() - timedelta(hours=within_hours)).isoformat()

            query = db.query(AutomatedMessageLogORM).filter(
                AutomatedMessageLogORM.template_id == template_id,
                AutomatedMessageLogORM.client_id == client_id,
                AutomatedMessageLogORM.triggered_at >= cutoff
            )

            if trigger_ref:
                query = query.filter(AutomatedMessageLogORM.trigger_reference == trigger_ref)

            return query.first() is not None

        finally:
            db.close()

    def log_message(
        self,
        template_id: str,
        client_id: str,
        gym_id: str,
        trigger_type: str,
        trigger_ref: str,
        delivery_method: str,
        status: str = "sent",
        error_message: str = None
    ) -> None:
        """Log a sent automated message."""
        db = get_db_session()
        try:
            log_entry = AutomatedMessageLogORM(
                template_id=template_id,
                client_id=client_id,
                gym_id=gym_id,
                trigger_type=trigger_type,
                trigger_reference=trigger_ref,
                delivery_method=delivery_method,
                status=status,
                error_message=error_message,
                triggered_at=datetime.utcnow().isoformat(),
                sent_at=datetime.utcnow().isoformat() if status == "sent" else None
            )

            db.add(log_entry)
            db.commit()

            logger.info(f"Logged automated message: template={template_id}, client={client_id}, status={status}")

        except Exception as e:
            db.rollback()
            logger.error(f"Error logging automated message: {e}")
        finally:
            db.close()

    def get_message_log(self, gym_id: str, limit: int = 50) -> List[dict]:
        """Get recent message log for a gym."""
        db = get_db_session()
        try:
            logs = db.query(AutomatedMessageLogORM).filter(
                AutomatedMessageLogORM.gym_id == gym_id
            ).order_by(
                AutomatedMessageLogORM.triggered_at.desc()
            ).limit(limit).all()

            # Get client names for the logs
            client_ids = list(set(log.client_id for log in logs))
            clients = {}
            if client_ids:
                users = db.query(UserORM).filter(UserORM.id.in_(client_ids)).all()
                clients = {u.id: u.username for u in users}

            # Get template names
            template_ids = list(set(log.template_id for log in logs if log.template_id))
            templates = {}
            if template_ids:
                tmps = db.query(AutomatedMessageTemplateORM).filter(
                    AutomatedMessageTemplateORM.id.in_(template_ids)
                ).all()
                templates = {t.id: t.name for t in tmps}

            return [
                {
                    "id": log.id,
                    "template_id": log.template_id,
                    "template_name": templates.get(log.template_id, "Unknown"),
                    "client_id": log.client_id,
                    "client_name": clients.get(log.client_id, "Unknown"),
                    "trigger_type": log.trigger_type,
                    "trigger_reference": log.trigger_reference,
                    "delivery_method": log.delivery_method,
                    "status": log.status,
                    "error_message": log.error_message,
                    "triggered_at": log.triggered_at,
                    "sent_at": log.sent_at
                }
                for log in logs
            ]

        finally:
            db.close()

    def _template_to_dict(self, template: AutomatedMessageTemplateORM) -> dict:
        """Convert a template ORM to dictionary."""
        return {
            "id": template.id,
            "gym_id": template.gym_id,
            "name": template.name,
            "trigger_type": template.trigger_type,
            "trigger_config": json.loads(template.trigger_config) if template.trigger_config else None,
            "subject": template.subject,
            "message_template": template.message_template,
            "delivery_methods": json.loads(template.delivery_methods) if template.delivery_methods else ["in_app"],
            "is_enabled": template.is_enabled,
            "send_delay_hours": template.send_delay_hours,
            "created_at": template.created_at,
            "updated_at": template.updated_at
        }


# Singleton instance
automated_message_service = AutomatedMessageService()


def get_automated_message_service() -> AutomatedMessageService:
    """Dependency injection helper."""
    return automated_message_service
