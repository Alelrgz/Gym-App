"""
Gym Assignment Service - handles client gym joining and trainer selection.
"""
from .base import (
    HTTPException, uuid, json, logging,
    get_db_session, UserORM, ClientProfileORM
)
from models import JoinGymRequest, SelectTrainerRequest, TrainerInfo
from typing import List

logger = logging.getLogger("gym_app")


class GymAssignmentService:
    """Service for managing client gym and trainer assignments."""

    def join_gym(self, client_id: str, gym_code: str) -> dict:
        """Join a gym using a gym code."""
        db = get_db_session()
        try:
            # Try to find owner by gym_code first (new system)
            owner = db.query(UserORM).filter(
                UserORM.gym_code == gym_code.strip().upper(),
                UserORM.role == "owner"
            ).first()

            # Fallback: try old system (owner ID directly)
            if not owner:
                owner_id = gym_code.replace("GYM_", "") if gym_code.startswith("GYM_") else gym_code
                owner = db.query(UserORM).filter(
                    UserORM.id == owner_id,
                    UserORM.role == "owner"
                ).first()

            if not owner:
                raise HTTPException(status_code=404, detail="Invalid gym code")

            # Get or create client profile
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()

            if not profile:
                # Create new profile
                user = db.query(UserORM).filter(UserORM.id == client_id).first()
                if not user:
                    raise HTTPException(status_code=404, detail="User not found")

                profile = ClientProfileORM(
                    id=client_id,
                    name=user.username,
                    streak=0,
                    gems=0,
                    health_score=0,
                    plan="Standard",
                    status="Active",
                    last_seen="Today",
                    gym_id=owner.id,
                    is_premium=False
                )
                db.add(profile)
            elif profile.gym_id == owner.id:
                # Already a member of this gym
                raise HTTPException(status_code=400, detail="You are already a member of this gym")
            else:
                # Update existing profile (switching gyms)
                profile.gym_id = owner.id

            db.commit()
            db.refresh(profile)

            logger.info(f"Client {client_id} joined gym {owner.id}")

            return {
                "status": "success",
                "message": f"Successfully joined {owner.username}'s gym",
                "gym_id": owner.id,
                "gym_name": owner.username
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error joining gym: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to join gym: {str(e)}")
        finally:
            db.close()

    def get_gym_trainers(self, gym_id: str) -> List[dict]:
        """Get all approved trainers in a gym."""
        db = get_db_session()
        try:
            # Get only approved trainers for this specific gym
            trainers = db.query(UserORM).filter(
                UserORM.role == "trainer",
                UserORM.gym_owner_id == gym_id,
                UserORM.is_approved == True
            ).all()

            # Count clients for each trainer
            result = []
            for trainer in trainers:
                client_count = db.query(ClientProfileORM).filter(
                    ClientProfileORM.trainer_id == trainer.id
                ).count()

                result.append({
                    "id": trainer.id,
                    "username": trainer.username,
                    "email": trainer.email,
                    "client_count": client_count
                })

            return result

        finally:
            db.close()

    def select_trainer(self, client_id: str, trainer_id: str) -> dict:
        """Select a trainer for the client."""
        db = get_db_session()
        try:
            # Verify trainer exists
            trainer = db.query(UserORM).filter(
                UserORM.id == trainer_id,
                UserORM.role == "trainer"
            ).first()

            if not trainer:
                raise HTTPException(status_code=404, detail="Trainer not found")

            # Get client profile
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()

            if not profile:
                raise HTTPException(status_code=404, detail="Client profile not found. Please join a gym first.")

            # Update trainer assignment
            profile.trainer_id = trainer_id
            db.commit()
            db.refresh(profile)

            logger.info(f"Client {client_id} selected trainer {trainer_id}")

            return {
                "status": "success",
                "message": f"Successfully assigned to trainer {trainer.username}",
                "trainer_id": trainer_id,
                "trainer_name": trainer.username
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error selecting trainer: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to select trainer: {str(e)}")
        finally:
            db.close()

    def get_client_gym_info(self, client_id: str) -> dict:
        """Get client's current gym and trainer info."""
        db = get_db_session()
        try:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()

            if not profile:
                return {
                    "has_gym": False,
                    "has_trainer": False,
                    "has_nutritionist": False,
                    "gym_id": None,
                    "gym_name": None,
                    "trainer_id": None,
                    "trainer_name": None,
                    "nutritionist_id": None,
                    "nutritionist_name": None
                }

            gym_name = None
            if profile.gym_id:
                gym_owner = db.query(UserORM).filter(UserORM.id == profile.gym_id).first()
                gym_name = gym_owner.username if gym_owner else None

            trainer_name = None
            trainer_profile_picture = None
            trainer_bio = None
            trainer_specialties = []
            if profile.trainer_id:
                trainer = db.query(UserORM).filter(UserORM.id == profile.trainer_id).first()
                if trainer:
                    trainer_name = trainer.username
                    trainer_profile_picture = trainer.profile_picture
                    trainer_bio = trainer.bio
                    if trainer.specialties:
                        trainer_specialties = [s.strip() for s in trainer.specialties.split(",") if s.strip()]

            nutritionist_name = None
            nutritionist_profile_picture = None
            nutritionist_bio = None
            nutritionist_specialties = []
            if profile.nutritionist_id:
                nutri = db.query(UserORM).filter(UserORM.id == profile.nutritionist_id).first()
                if nutri:
                    nutritionist_name = nutri.username
                    nutritionist_profile_picture = nutri.profile_picture
                    nutritionist_bio = nutri.bio
                    if nutri.specialties:
                        nutritionist_specialties = [s.strip() for s in nutri.specialties.split(",") if s.strip()]

            return {
                "has_gym": profile.gym_id is not None,
                "has_trainer": profile.trainer_id is not None,
                "has_nutritionist": profile.nutritionist_id is not None,
                "gym_id": profile.gym_id,
                "gym_name": gym_name,
                "trainer_id": profile.trainer_id,
                "trainer_name": trainer_name,
                "trainer_profile_picture": trainer_profile_picture,
                "trainer_bio": trainer_bio,
                "trainer_specialties": trainer_specialties,
                "nutritionist_id": profile.nutritionist_id,
                "nutritionist_name": nutritionist_name,
                "nutritionist_profile_picture": nutritionist_profile_picture,
                "nutritionist_bio": nutritionist_bio,
                "nutritionist_specialties": nutritionist_specialties
            }

        finally:
            db.close()

    def leave_gym(self, client_id: str) -> dict:
        """Leave current gym and unassign trainer."""
        db = get_db_session()
        try:
            profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()

            if not profile:
                raise HTTPException(status_code=404, detail="Client profile not found")

            if not profile.gym_id:
                raise HTTPException(status_code=400, detail="You are not currently in a gym")

            # Clear gym and trainer assignments
            profile.gym_id = None
            profile.trainer_id = None
            db.commit()

            logger.info(f"Client {client_id} left their gym")

            return {
                "status": "success",
                "message": "Successfully left gym"
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error leaving gym: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to leave gym: {str(e)}")
        finally:
            db.close()

    def generate_gym_code_for_owner(self, owner_id: str) -> str:
        """Generate a gym code for an owner who doesn't have one yet."""
        import random
        import string

        db = get_db_session()
        try:
            owner = db.query(UserORM).filter(UserORM.id == owner_id).first()
            if not owner:
                raise HTTPException(status_code=404, detail="Owner not found")

            if owner.gym_code:
                return owner.gym_code

            # Generate unique 6-char code
            while True:
                code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
                existing = db.query(UserORM).filter(UserORM.gym_code == code).first()
                if not existing:
                    break

            owner.gym_code = code
            db.commit()

            logger.info(f"Generated gym code {code} for owner {owner_id}")
            return code

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error generating gym code: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to generate gym code: {str(e)}")
        finally:
            db.close()

    def get_pending_trainers(self, owner_id: str) -> list:
        """Get all trainers and staff pending approval for this gym owner."""
        db = get_db_session()
        try:
            # Get pending trainers AND staff
            pending = db.query(UserORM).filter(
                UserORM.role.in_(["trainer", "staff", "nutritionist"]),
                UserORM.gym_owner_id == owner_id,
                UserORM.is_approved == False
            ).all()

            return [
                {
                    "id": t.id,
                    "username": t.username,
                    "email": t.email,
                    "role": t.role,
                    "sub_role": t.sub_role,
                    "created_at": t.created_at
                }
                for t in pending
            ]
        finally:
            db.close()

    def approve_trainer(self, owner_id: str, trainer_id: str) -> dict:
        """Approve a trainer's or staff member's registration."""
        db = get_db_session()
        try:
            # Find trainer OR staff member
            user = db.query(UserORM).filter(
                UserORM.id == trainer_id,
                UserORM.role.in_(["trainer", "staff", "nutritionist"]),
                UserORM.gym_owner_id == owner_id
            ).first()

            if not user:
                raise HTTPException(status_code=404, detail="User not found or not part of your gym")

            user.is_approved = True
            db.commit()

            role_label = {"staff": "Staff member", "trainer": "Trainer", "nutritionist": "Nutritionist"}.get(user.role, "User")
            logger.info(f"Owner {owner_id} approved {user.role} {trainer_id}")

            return {
                "status": "success",
                "message": f"{role_label} {user.username} has been approved"
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error approving trainer: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to approve trainer: {str(e)}")
        finally:
            db.close()

    def reject_trainer(self, owner_id: str, trainer_id: str) -> dict:
        """Reject a trainer's or staff member's registration (deletes their account)."""
        db = get_db_session()
        try:
            # Find trainer OR staff member
            user = db.query(UserORM).filter(
                UserORM.id == trainer_id,
                UserORM.role.in_(["trainer", "staff", "nutritionist"]),
                UserORM.gym_owner_id == owner_id
            ).first()

            if not user:
                raise HTTPException(status_code=404, detail="User not found or not part of your gym")

            username = user.username
            role = user.role
            db.delete(user)
            db.commit()

            logger.info(f"Owner {owner_id} rejected {role} {trainer_id}")

            return {
                "status": "success",
                "message": f"Trainer {username} has been rejected"
            }

        except HTTPException:
            db.rollback()
            raise
        except Exception as e:
            db.rollback()
            logger.error(f"Error rejecting trainer: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to reject trainer: {str(e)}")
        finally:
            db.close()

    def get_approved_trainers(self, owner_id: str) -> list:
        """Get all approved trainers and staff for this gym owner."""
        db = get_db_session()
        try:
            trainers = db.query(UserORM).filter(
                UserORM.role.in_(["trainer", "staff", "nutritionist"]),
                UserORM.gym_owner_id == owner_id,
                UserORM.is_approved == True
            ).all()

            # Count clients for each trainer
            result = []
            for trainer in trainers:
                if trainer.role == "trainer":
                    client_count = db.query(ClientProfileORM).filter(
                        ClientProfileORM.trainer_id == trainer.id
                    ).count()
                elif trainer.role == "nutritionist":
                    client_count = db.query(ClientProfileORM).filter(
                        ClientProfileORM.nutritionist_id == trainer.id
                    ).count()
                else:
                    client_count = 0

                result.append({
                    "id": trainer.id,
                    "username": trainer.username,
                    "email": trainer.email,
                    "role": trainer.role,
                    "sub_role": trainer.sub_role,
                    "client_count": client_count,
                    "created_at": trainer.created_at
                })

            return result
        finally:
            db.close()


# Singleton instance
gym_assignment_service = GymAssignmentService()


def get_gym_assignment_service() -> GymAssignmentService:
    """Dependency injection helper."""
    return gym_assignment_service
