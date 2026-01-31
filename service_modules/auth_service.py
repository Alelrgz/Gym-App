"""
Auth Service - handles user authentication and registration.
"""
from .base import (
    HTTPException, uuid, logging,
    get_db_session, UserORM
)
from auth import verify_password, get_password_hash

logger = logging.getLogger("gym_app")


class AuthService:
    """Service for managing authentication and user registration."""

    def authenticate_user(self, username: str, password: str):
        """Authenticate a user by username and password."""
        db = get_db_session()
        try:
            user = db.query(UserORM).filter(UserORM.username == username).first()
            if not user:
                return False
            if not verify_password(password, user.hashed_password):
                return False
            return user
        finally:
            db.close()

    def register_user(self, user_data: dict):
        """Register a new user."""
        logger.debug(f"register_user called for {user_data.get('username')}")
        db = get_db_session()
        try:
            # Handle empty email as None
            email = user_data.get("email")
            if email == "":
                email = None

            # Check if user exists
            query = db.query(UserORM).filter(UserORM.username == user_data["username"])
            if email:
                query = db.query(UserORM).filter(
                    (UserORM.username == user_data["username"]) |
                    (UserORM.email == email)
                )

            existing_user = query.first()

            if existing_user:
                raise HTTPException(status_code=400, detail="Username or email already registered")

            hashed_pw = get_password_hash(user_data["password"])

            new_user = UserORM(
                id=str(uuid.uuid4()),
                username=user_data["username"],
                email=email,
                hashed_password=hashed_pw,
                role=user_data.get("role", "client"),
                is_active=True
            )

            db.add(new_user)
            db.commit()
            db.refresh(new_user)

            return {"status": "success", "message": "User registered successfully", "user_id": new_user.id}
        except HTTPException as he:
            raise he
        except Exception as e:
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")
        finally:
            db.close()


# Singleton instance
auth_service = AuthService()

def get_auth_service() -> AuthService:
    """Dependency injection helper."""
    return auth_service
