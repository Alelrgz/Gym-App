from database import GlobalSessionLocal
from models_orm import UserORM
from auth import verify_password, get_password_hash

db = GlobalSessionLocal()
try:
    username = "test_trainer_ps2"
    user = db.query(UserORM).filter(UserORM.username == username).first()
    
    if user:
        print(f"User found: {user.username}")
        print(f"Stored Hash: {user.hashed_password}")
        
        # Test password "pass"
        is_valid = verify_password("pass", user.hashed_password)
        print(f"Password 'pass' valid? {is_valid}")
        
        if not is_valid:
            # Check if double hashing occurred or something
            print("Trying to re-hash 'pass' to compare...")
            new_hash = get_password_hash("pass")
            print(f"New Hash of 'pass': {new_hash}")
    else:
        print(f"User {username} not found")

finally:
    db.close()
