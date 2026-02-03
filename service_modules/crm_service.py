"""
CRM Service - handles client relationship management analytics and tracking.
"""
from .base import (
    HTTPException, json, logging, date, datetime, timedelta,
    get_db_session, UserORM, ClientProfileORM, ClientScheduleORM,
    ClientSubscriptionORM, AppointmentORM, AutomatedMessageLogORM
)
from typing import List, Optional

logger = logging.getLogger("gym_app")


class CRMService:
    """Service for CRM analytics and client management."""

    def get_client_pipeline(self, gym_id: str) -> dict:
        """
        Get client funnel/pipeline data.
        Categories:
        - New: joined < 14 days
        - Active: last activity <= 5 days
        - At-Risk: 5 < days_inactive <= 14
        - Churning: days_inactive > 14 OR subscription canceled/past_due
        """
        db = get_db_session()
        try:
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()

            today = date.today()
            pipeline = {"new": 0, "active": 0, "at_risk": 0, "churning": 0, "total": 0}

            for client in clients:
                pipeline["total"] += 1
                status = self._calculate_client_status(client, db, today)
                if status in pipeline:
                    pipeline[status] += 1

            return pipeline

        except Exception as e:
            logger.error(f"Error getting client pipeline: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to get pipeline: {str(e)}")
        finally:
            db.close()

    def get_at_risk_clients(self, gym_id: str, limit: int = 20) -> List[dict]:
        """Get detailed list of at-risk clients needing attention."""
        db = get_db_session()
        try:
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()

            today = date.today()
            at_risk_clients = []

            for client in clients:
                days_inactive = self._get_days_inactive(client, db, today)

                # Include if 5-30 days inactive (at-risk or early churning)
                if 5 < days_inactive <= 30:
                    # Get trainer name
                    trainer_name = None
                    if client.trainer_id:
                        trainer = db.query(UserORM).filter(UserORM.id == client.trainer_id).first()
                        trainer_name = trainer.username if trainer else None

                    # Get user info for name/email
                    user = db.query(UserORM).filter(UserORM.id == client.id).first()

                    # Get last workout date
                    last_workout = db.query(ClientScheduleORM).filter(
                        ClientScheduleORM.client_id == client.id,
                        ClientScheduleORM.type == "workout",
                        ClientScheduleORM.completed == True
                    ).order_by(ClientScheduleORM.date.desc()).first()

                    at_risk_clients.append({
                        "id": client.id,
                        "name": user.username if user else "Unknown",
                        "email": user.email if user else None,
                        "days_inactive": days_inactive,
                        "last_workout_date": last_workout.date if last_workout else None,
                        "health_score": client.health_score or 0,
                        "streak": client.streak or 0,
                        "trainer_id": client.trainer_id,
                        "trainer_name": trainer_name,
                        "status": client.status
                    })

            # Sort by days inactive (most inactive first)
            at_risk_clients.sort(key=lambda x: x["days_inactive"], reverse=True)

            return at_risk_clients[:limit]

        except Exception as e:
            logger.error(f"Error getting at-risk clients: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to get at-risk clients: {str(e)}")
        finally:
            db.close()

    def get_retention_analytics(self, gym_id: str, period: str = "month") -> dict:
        """
        Calculate retention metrics.
        - engagement_rate: % of clients with activity in last 7 days
        - churn_rate: % of clients in churning status
        - at_risk_count: current at-risk clients
        - avg_health_score: average health score across all clients
        """
        db = get_db_session()
        try:
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()

            if not clients:
                return {
                    "engagement_rate": 0,
                    "churn_rate": 0,
                    "at_risk_count": 0,
                    "avg_health_score": 0,
                    "total_clients": 0,
                    "period": period
                }

            today = date.today()
            total = len(clients)
            engaged = 0
            churning = 0
            at_risk = 0
            total_health = 0
            health_count = 0

            for client in clients:
                days_inactive = self._get_days_inactive(client, db, today)

                if days_inactive <= 7:
                    engaged += 1

                status = self._calculate_client_status(client, db, today)
                if status == "churning":
                    churning += 1
                elif status == "at_risk":
                    at_risk += 1

                if client.health_score:
                    total_health += client.health_score
                    health_count += 1

            engagement_rate = round((engaged / total) * 100) if total > 0 else 0
            churn_rate = round((churning / total) * 100) if total > 0 else 0
            avg_health = round(total_health / health_count) if health_count > 0 else 0

            return {
                "engagement_rate": engagement_rate,
                "churn_rate": churn_rate,
                "at_risk_count": at_risk,
                "avg_health_score": avg_health,
                "total_clients": total,
                "active_count": engaged,
                "churning_count": churning,
                "period": period
            }

        except Exception as e:
            logger.error(f"Error getting retention analytics: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to get analytics: {str(e)}")
        finally:
            db.close()

    def get_client_interactions(self, gym_id: str, client_id: str = None, limit: int = 50) -> List[dict]:
        """
        Get recent client activities/interactions.
        Sources: workouts completed, appointments, automated messages sent
        """
        db = get_db_session()
        try:
            interactions = []

            # Get client IDs for this gym
            if client_id:
                client_ids = [client_id]
            else:
                clients = db.query(ClientProfileORM.id).filter(
                    ClientProfileORM.gym_id == gym_id
                ).all()
                client_ids = [c.id for c in clients]

            if not client_ids:
                return []

            # Get completed workouts (last 30 days)
            thirty_days_ago = (date.today() - timedelta(days=30)).isoformat()

            workouts = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id.in_(client_ids),
                ClientScheduleORM.type == "workout",
                ClientScheduleORM.completed == True,
                ClientScheduleORM.date >= thirty_days_ago
            ).order_by(ClientScheduleORM.date.desc()).limit(limit).all()

            for w in workouts:
                user = db.query(UserORM).filter(UserORM.id == w.client_id).first()
                interactions.append({
                    "id": f"workout-{w.id}",
                    "client_id": w.client_id,
                    "client_name": user.username if user else "Unknown",
                    "type": "workout",
                    "description": f"Completed {w.title or 'workout'}",
                    "timestamp": w.date
                })

            # Get appointments (completed)
            appointments = db.query(AppointmentORM).filter(
                AppointmentORM.client_id.in_(client_ids),
                AppointmentORM.status == "completed",
                AppointmentORM.date >= thirty_days_ago
            ).order_by(AppointmentORM.date.desc()).limit(limit).all()

            for a in appointments:
                user = db.query(UserORM).filter(UserORM.id == a.client_id).first()
                trainer = db.query(UserORM).filter(UserORM.id == a.trainer_id).first()
                interactions.append({
                    "id": f"appointment-{a.id}",
                    "client_id": a.client_id,
                    "client_name": user.username if user else "Unknown",
                    "type": "appointment",
                    "description": f"Session with {trainer.username if trainer else 'trainer'}",
                    "timestamp": a.date
                })

            # Get automated messages sent
            messages = db.query(AutomatedMessageLogORM).filter(
                AutomatedMessageLogORM.client_id.in_(client_ids),
                AutomatedMessageLogORM.status == "sent"
            ).order_by(AutomatedMessageLogORM.sent_at.desc()).limit(limit).all()

            for m in messages:
                user = db.query(UserORM).filter(UserORM.id == m.client_id).first()
                interactions.append({
                    "id": f"message-{m.id}",
                    "client_id": m.client_id,
                    "client_name": user.username if user else "Unknown",
                    "type": "automated_message",
                    "description": f"Auto-message: {m.trigger_type}",
                    "timestamp": m.sent_at
                })

            # Sort by timestamp (most recent first)
            interactions.sort(key=lambda x: x["timestamp"] or "", reverse=True)

            return interactions[:limit]

        except Exception as e:
            logger.error(f"Error getting client interactions: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to get interactions: {str(e)}")
        finally:
            db.close()

    def _calculate_client_status(self, client: ClientProfileORM, db, today: date) -> str:
        """Determine client's pipeline status."""
        # Check subscription status first
        subscription = db.query(ClientSubscriptionORM).filter(
            ClientSubscriptionORM.client_id == client.id,
            ClientSubscriptionORM.gym_id == client.gym_id
        ).first()

        if subscription and subscription.status in ['canceled', 'past_due']:
            return 'churning'

        # Calculate days inactive
        days_inactive = self._get_days_inactive(client, db, today)

        # Check if new user (account created < 14 days)
        user = db.query(UserORM).filter(UserORM.id == client.id).first()
        if user and user.created_at:
            try:
                created = datetime.fromisoformat(user.created_at.replace('Z', '+00:00')).date()
                account_age = (today - created).days
                if account_age <= 14 and days_inactive <= 7:
                    return 'new'
            except:
                pass

        # Classify by inactivity
        if days_inactive <= 5:
            return 'active'
        elif days_inactive <= 14:
            return 'at_risk'
        else:
            return 'churning'

    def _get_days_inactive(self, client: ClientProfileORM, db, today: date) -> int:
        """Calculate days since last activity."""
        # Try to get last workout date
        last_workout = db.query(ClientScheduleORM).filter(
            ClientScheduleORM.client_id == client.id,
            ClientScheduleORM.type == "workout",
            ClientScheduleORM.completed == True
        ).order_by(ClientScheduleORM.date.desc()).first()

        if last_workout and last_workout.date:
            try:
                last_date = datetime.fromisoformat(last_workout.date).date()
                return (today - last_date).days
            except:
                pass

        # Fallback to last_seen field
        if client.last_seen:
            # Parse various formats like "Today", "5 days ago", or ISO date
            if client.last_seen.lower() == "today":
                return 0
            elif "days ago" in client.last_seen.lower():
                try:
                    days = int(client.last_seen.split()[0])
                    return days
                except:
                    pass
            else:
                try:
                    last_date = datetime.fromisoformat(client.last_seen.replace('Z', '+00:00')).date()
                    return (today - last_date).days
                except:
                    pass

        # If no activity data, consider very inactive
        return 999

    def get_activity_feed(self, gym_id: str, limit: int = 20) -> List[dict]:
        """
        Get recent activity feed for the gym dashboard.
        Includes: workouts, appointments, new signups, subscriptions.
        """
        db = get_db_session()
        try:
            activities = []
            today = date.today()
            seven_days_ago = (today - timedelta(days=7)).isoformat()

            # Get client IDs for this gym
            clients = db.query(ClientProfileORM).filter(
                ClientProfileORM.gym_id == gym_id
            ).all()
            client_ids = [c.id for c in clients]
            client_map = {c.id: c for c in clients}

            if not client_ids:
                return []

            # 1. Recent completed workouts
            workouts = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id.in_(client_ids),
                ClientScheduleORM.type == "workout",
                ClientScheduleORM.completed == True,
                ClientScheduleORM.date >= seven_days_ago
            ).order_by(ClientScheduleORM.date.desc()).limit(limit).all()

            for w in workouts:
                user = db.query(UserORM).filter(UserORM.id == w.client_id).first()
                activities.append({
                    "type": "workout",
                    "icon": "💪",
                    "title": f"{user.username if user else 'Client'} completed a workout",
                    "description": w.title or "Training session",
                    "timestamp": w.date,
                    "client_id": w.client_id
                })

            # 2. Completed appointments
            appointments = db.query(AppointmentORM).filter(
                AppointmentORM.client_id.in_(client_ids),
                AppointmentORM.status == "completed",
                AppointmentORM.date >= seven_days_ago
            ).order_by(AppointmentORM.date.desc()).limit(limit).all()

            for a in appointments:
                user = db.query(UserORM).filter(UserORM.id == a.client_id).first()
                trainer = db.query(UserORM).filter(UserORM.id == a.trainer_id).first()
                activities.append({
                    "type": "appointment",
                    "icon": "📅",
                    "title": f"{user.username if user else 'Client'} had a session",
                    "description": f"With {trainer.username if trainer else 'trainer'}",
                    "timestamp": a.date,
                    "client_id": a.client_id
                })

            # 3. New client signups (users who joined this gym recently)
            for client in clients:
                user = db.query(UserORM).filter(UserORM.id == client.id).first()
                if user and user.created_at:
                    try:
                        created = user.created_at
                        if isinstance(created, str):
                            created_date = datetime.fromisoformat(created.replace('Z', '+00:00')).date()
                        else:
                            created_date = created.date() if hasattr(created, 'date') else created

                        if created_date >= today - timedelta(days=7):
                            activities.append({
                                "type": "signup",
                                "icon": "🎉",
                                "title": f"{user.username} joined the gym",
                                "description": "New member",
                                "timestamp": user.created_at if isinstance(user.created_at, str) else user.created_at.isoformat(),
                                "client_id": client.id
                            })
                    except:
                        pass

            # 4. Recent subscriptions
            subscriptions = db.query(ClientSubscriptionORM).filter(
                ClientSubscriptionORM.gym_id == gym_id,
                ClientSubscriptionORM.status == "active"
            ).order_by(ClientSubscriptionORM.created_at.desc()).limit(limit).all()

            for sub in subscriptions:
                if sub.created_at:
                    try:
                        created = sub.created_at
                        if isinstance(created, str):
                            created_date = datetime.fromisoformat(created.replace('Z', '+00:00')).date()
                        else:
                            created_date = created.date() if hasattr(created, 'date') else created

                        if created_date >= today - timedelta(days=7):
                            user = db.query(UserORM).filter(UserORM.id == sub.client_id).first()
                            activities.append({
                                "type": "subscription",
                                "icon": "💳",
                                "title": f"{user.username if user else 'Client'} subscribed",
                                "description": sub.plan_name or "New subscription",
                                "timestamp": sub.created_at if isinstance(sub.created_at, str) else sub.created_at.isoformat(),
                                "client_id": sub.client_id
                            })
                    except:
                        pass

            # Sort by timestamp (most recent first)
            def get_sort_key(item):
                ts = item.get("timestamp", "")
                if not ts:
                    return ""
                return ts

            activities.sort(key=get_sort_key, reverse=True)

            return activities[:limit]

        except Exception as e:
            logger.error(f"Error getting activity feed: {e}")
            return []
        finally:
            db.close()


# Singleton instance
crm_service = CRMService()


def get_crm_service() -> CRMService:
    """Dependency injection helper."""
    return crm_service
