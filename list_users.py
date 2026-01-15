from database import GlobalSessionLocal
from models_orm import UserORM

db = GlobalSessionLocal()
try:
    users = db.query(UserORM).all()
    print(f"Found {len(users)} users:")
    for user in users:
        print(f"Username: {user.username}, Role: {user.role}, ID: {user.id}")
finally:
    db.close()
