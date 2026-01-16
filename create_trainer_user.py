"""Create test trainer user using existing auth_service"""
from database import engine, Base, SessionLocal
from models_orm import UserORM as User
# from auth_service import AuthService
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
import uuid

# Ensure tables exist
Base.metadata.create_all(bind=engine)

# Create session
db = SessionLocal()


# Check if test user exists
username = "trainer_test"
existing = db.query(User).filter(User.username == username).first()

if existing:
    print(f" User '{username}' already exists")
    # Update password and role
    existing.hashed_password = pwd_context.hash(username)
    if existing.role != "trainer":
        existing.role = "trainer"
    db.commit()
    print("  Updated password and ensured role is 'trainer'")
else:
    # Create test user
    test_user = User(
        id=str(uuid.uuid4()),
        username=username,
        hashed_password=pwd_context.hash(username), # Password same as username
        role="trainer"
    )
    db.add(test_user)
    db.commit()
    print(f" Created user '{username}':")
    print(f"  Password: {username}")

db.close()
