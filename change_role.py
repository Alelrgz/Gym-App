from database import GlobalSessionLocal
from models_orm import UserORM
import sys

def change_role(username, new_role):
    db = GlobalSessionLocal()
    try:
        user = db.query(UserORM).filter(UserORM.username == username).first()
        if not user:
            print(f"User '{username}' not found.")
            return

        print(f"Found user: {user.username}, Current Role: {user.role}")
        user.role = new_role
        db.commit()
        print(f"Successfully changed role to '{new_role}'.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python change_role.py <username> <new_role>")
    else:
        change_role(sys.argv[1], sys.argv[2])
