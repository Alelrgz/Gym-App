"""
Nutritionist Service - handles nutritionist data, client body composition, and diet management.
"""
from .base import (
    HTTPException, json, logging, date, datetime, timedelta,
    get_db_session, uuid,
    UserORM, ClientProfileORM, ClientDietSettingsORM,
    ClientDailyDietSummaryORM, WeightHistoryORM
)

logger = logging.getLogger("gym_app")


class NutritionistService:
    """Service for managing nutritionist data and operations."""

    def get_nutritionist(self, nutritionist_id: str) -> dict:
        """Get complete nutritionist data including clients from their gym."""
        db = get_db_session()
        try:
            nutritionist = db.query(UserORM).filter(UserORM.id == nutritionist_id).first()
            gym_id = nutritionist.gym_owner_id if nutritionist else None

            # Get all clients from the same gym
            if gym_id:
                client_profiles = db.query(ClientProfileORM).filter(
                    ClientProfileORM.gym_id == gym_id
                ).all()
            else:
                client_profiles = db.query(ClientProfileORM).filter(
                    ClientProfileORM.nutritionist_id == nutritionist_id
                ).all()

            client_ids = [p.id for p in client_profiles]
            clients_orm = db.query(UserORM).filter(
                UserORM.id.in_(client_ids)
            ).all() if client_ids else []

            clients = []
            active_count = 0
            at_risk_count = 0
            today = date.today()
            profile_lookup = {p.id: p for p in client_profiles}

            for c in clients_orm:
                profile = profile_lookup.get(c.id)

                # Check last diet log for activity status
                last_log = db.query(ClientDailyDietSummaryORM).filter(
                    ClientDailyDietSummaryORM.client_id == c.id
                ).order_by(ClientDailyDietSummaryORM.date.desc()).first()

                days_inactive = 99
                if last_log and last_log.date:
                    try:
                        last_date = datetime.strptime(last_log.date, "%Y-%m-%d").date()
                        days_inactive = (today - last_date).days
                    except Exception:
                        days_inactive = 99

                status = "Active" if days_inactive <= 5 else "At Risk"
                if status == "At Risk":
                    at_risk_count += 1
                else:
                    active_count += 1

                # Get current diet settings
                diet = db.query(ClientDietSettingsORM).filter(
                    ClientDietSettingsORM.id == c.id
                ).first()

                clients.append({
                    "id": c.id,
                    "name": profile.name if profile and profile.name else c.username,
                    "status": status,
                    "last_seen": f"{days_inactive} days ago" if days_inactive < 99 else "Never",
                    "plan": profile.plan if profile and profile.plan else "Standard",
                    "is_premium": profile.is_premium if profile else False,
                    "profile_picture": c.profile_picture,
                    "weight": profile.weight if profile else None,
                    "body_fat_pct": profile.body_fat_pct if profile else None,
                    "weight_goal": profile.weight_goal if profile else None,
                    "calories_target": diet.calories_target if diet else None,
                })

            return {
                "id": nutritionist_id,
                "name": nutritionist.username if nutritionist else None,
                "profile_picture": nutritionist.profile_picture if nutritionist else None,
                "specialties": nutritionist.specialties if nutritionist else None,
                "clients": clients,
                "active_clients": active_count,
                "at_risk_clients": at_risk_count
            }
        finally:
            db.close()

    def get_client_detail(self, client_id: str) -> dict:
        """Get detailed client data for the nutritionist panel."""
        db = get_db_session()
        try:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            user = db.query(UserORM).filter(UserORM.id == client_id).first()
            diet = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()

            if not profile:
                raise HTTPException(status_code=404, detail="Client not found")

            return {
                "id": client_id,
                "name": profile.name or (user.username if user else ""),
                "profile_picture": user.profile_picture if user else None,
                "weight": profile.weight,
                "body_fat_pct": profile.body_fat_pct,
                "fat_mass": profile.fat_mass,
                "lean_mass": profile.lean_mass,
                "weight_goal": profile.weight_goal,
                "diet": {
                    "fitness_goal": diet.fitness_goal if diet else "maintain",
                    "calories_target": diet.calories_target if diet else 2000,
                    "protein_target": diet.protein_target if diet else 150,
                    "carbs_target": diet.carbs_target if diet else 200,
                    "fat_target": diet.fat_target if diet else 70,
                    "hydration_target": diet.hydration_target if diet else 2500,
                    "calories_current": diet.calories_current if diet else 0,
                    "protein_current": diet.protein_current if diet else 0,
                    "carbs_current": diet.carbs_current if diet else 0,
                    "fat_current": diet.fat_current if diet else 0,
                } if diet else None
            }
        finally:
            db.close()

    def add_body_composition(self, nutritionist_id: str, client_id: str,
                              weight: float, body_fat_pct: float = None,
                              fat_mass: float = None, lean_mass: float = None) -> dict:
        """Add a body composition entry for a client."""
        db = get_db_session()
        try:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if not profile:
                raise HTTPException(status_code=404, detail="Client not found")

            # Calculate derived values
            if body_fat_pct is not None and fat_mass is None:
                fat_mass = round(weight * body_fat_pct / 100, 1)
            if fat_mass is not None and lean_mass is None:
                lean_mass = round(weight - fat_mass, 1)

            # Insert into weight history
            entry = WeightHistoryORM(
                client_id=client_id,
                weight=weight,
                body_fat_pct=body_fat_pct,
                fat_mass=fat_mass,
                lean_mass=lean_mass,
                recorded_at=datetime.now().isoformat()
            )
            db.add(entry)

            # Update current values on profile
            profile.weight = weight
            if body_fat_pct is not None:
                profile.body_fat_pct = body_fat_pct
            if fat_mass is not None:
                profile.fat_mass = fat_mass
            if lean_mass is not None:
                profile.lean_mass = lean_mass

            db.commit()
            return {"status": "success", "message": "Body composition recorded"}
        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()

    def set_weight_goal(self, nutritionist_id: str, client_id: str, weight_goal: float) -> dict:
        """Set a weight goal for a client."""
        db = get_db_session()
        try:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
            if not profile:
                raise HTTPException(status_code=404, detail="Client not found")

            profile.weight_goal = weight_goal
            db.commit()
            return {"status": "success", "message": f"Weight goal set to {weight_goal}kg"}
        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            db.close()


nutritionist_service = NutritionistService()

def get_nutritionist_service() -> NutritionistService:
    return nutritionist_service
