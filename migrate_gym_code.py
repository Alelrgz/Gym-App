"""
Gym Code Migration
Adds gym_code, gym_owner_id, and is_approved columns to users table.
"""
import os
import string
import random
from dotenv import load_dotenv

load_dotenv()

from database import engine, Base, get_db_session
from models_orm import UserORM
from sqlalchemy import text


def generate_gym_code(length=6):
    """Generate a random 6-character alphanumeric code."""
    chars = string.ascii_uppercase + string.digits
    return ''.join(random.choice(chars) for _ in range(length))


def migrate():
    print("\n" + "=" * 60)
    print("GYM CODE MIGRATION")
    print("=" * 60)

    db = get_db_session()

    # Add gym_code column
    print("\nAdding gym_code column...")
    try:
        db.execute(text("ALTER TABLE users ADD COLUMN gym_code VARCHAR(6)"))
        db.commit()
        print("[OK] gym_code column added!")
    except Exception as e:
        if "duplicate" in str(e).lower() or "already exists" in str(e).lower():
            print("[INFO] gym_code column already exists")
        else:
            print(f"[ERROR] {e}")

    # Add gym_owner_id column
    print("\nAdding gym_owner_id column...")
    try:
        db.execute(text("ALTER TABLE users ADD COLUMN gym_owner_id VARCHAR"))
        db.commit()
        print("[OK] gym_owner_id column added!")
    except Exception as e:
        if "duplicate" in str(e).lower() or "already exists" in str(e).lower():
            print("[INFO] gym_owner_id column already exists")
        else:
            print(f"[ERROR] {e}")

    # Add is_approved column
    print("\nAdding is_approved column...")
    try:
        db.execute(text("ALTER TABLE users ADD COLUMN is_approved BOOLEAN DEFAULT 1"))
        db.commit()
        print("[OK] is_approved column added!")
    except Exception as e:
        if "duplicate" in str(e).lower() or "already exists" in str(e).lower():
            print("[INFO] is_approved column already exists")
        else:
            print(f"[ERROR] {e}")

    # Generate gym codes for existing owners who don't have one
    print("\nGenerating gym codes for existing owners...")
    owners = db.query(UserORM).filter(UserORM.role == "owner", UserORM.gym_code == None).all()

    for owner in owners:
        # Generate unique code
        while True:
            code = generate_gym_code()
            existing = db.query(UserORM).filter(UserORM.gym_code == code).first()
            if not existing:
                break

        owner.gym_code = code
        print(f"  - {owner.username}: {code}")

    db.commit()
    print(f"[OK] Generated codes for {len(owners)} owners")

    db.close()

    print("\n" + "=" * 60)
    print("MIGRATION COMPLETE!")
    print("=" * 60)
    print("\nNew fields added to users table:")
    print("  - gym_code: 6-char alphanumeric code for owners")
    print("  - gym_owner_id: Links trainers to their gym owner")
    print("  - is_approved: Whether trainer is approved by owner")
    print("\n")


if __name__ == "__main__":
    migrate()
