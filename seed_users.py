from database import global_engine, GlobalSessionLocal, Base
from models_orm import UserORM
from auth import get_password_hash
import uuid

def seed_users():
    Base.metadata.create_all(bind=global_engine)
    db = GlobalSessionLocal()
    
    users = [
        {"username": "client", "password": "password", "role": "client", "email": "client@example.com"},
        {"username": "trainer", "password": "password", "role": "trainer", "email": "trainer@example.com"},
        {"username": "owner", "password": "password", "role": "owner", "email": "owner@example.com"},
        {"username": "user_123", "password": "password", "role": "client", "email": "user_123@example.com"} # For backward compatibility testing
    ]
    
    print("Seeding users...")
    for u in users:
        existing = db.query(UserORM).filter(UserORM.username == u["username"]).first()
        if not existing:
            user = UserORM(
                id=str(uuid.uuid4()) if u["username"] != "user_123" else "user_123",
                username=u["username"],
                email=u["email"],
                hashed_password=get_password_hash(u["password"]),
                role=u["role"],
                is_active=True
            )
            db.add(user)
            print(f"Created user: {u['username']} / {u['password']}")
        else:
            print(f"User {u['username']} already exists.")
            
    db.commit()
    db.close()
    print("Done.")

if __name__ == "__main__":
    seed_users()
