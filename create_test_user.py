"""Create test user using existing auth_service"""
from database import global_engine, Base, GlobalSessionLocal
from models_client_orm import User
from auth_service import AuthService
import uuid

# Ensure tables exist
Base.metadata.create_all(bind=global_engine)

# Create session
db = GlobalSessionLocal()
auth = AuthService()

# Check if test user exists
existing = db.query(User).filter(User.username == "test").first()

if existing:
    print("✓ Test user already exists")
    print("  Username: test")
    print("  Password: test")
else:
    # Create test user
    test_user = User(
        id=str(uuid.uuid4()),
        username="test",
        hashed_password=auth.get_password_hash("test"),
        role="client"
    )
    db.add(test_user)
    db.commit()
    print("✓ Created test user:")
    print("  Username: test")
    print("  Password: test")

db.close()
