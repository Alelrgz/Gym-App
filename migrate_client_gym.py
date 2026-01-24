"""
Database Migration - Add gym_id to client_profile
Run this script to add the gym_id column for gym assignment functionality.
"""
import os
import sys
from dotenv import load_dotenv

load_dotenv()

from database import engine, Base, get_db_session
from models_orm import ClientProfileORM
from sqlalchemy import text


def migrate():
    print("\n" + "=" * 60)
    print("CLIENT GYM ASSIGNMENT MIGRATION")
    print("=" * 60)

    print("\nDatabase URL:", os.getenv("DATABASE_URL", "sqlite:///db/gym_app.db"))

    # Use raw SQL to add column if it doesn't exist
    print("\nAdding gym_id column to client_profile...")
    db = get_db_session()
    try:
        # Try to add the column (will fail silently if it exists)
        try:
            db.execute(text("ALTER TABLE client_profile ADD COLUMN gym_id VARCHAR"))
            db.commit()
            print("[OK] gym_id column added successfully!")
        except Exception as e:
            if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                print("[INFO] gym_id column already exists, skipping...")
            else:
                raise
    finally:
        db.close()

    # Also ensure all tables are created
    Base.metadata.create_all(bind=engine)

    # List table schema
    print("\nClient Profile table now includes:")
    from sqlalchemy import inspect
    inspector = inspect(engine)
    columns = inspector.get_columns('client_profile')

    for col in columns:
        print(f"  - {col['name']}: {col['type']}")

    print("\n" + "=" * 60)
    print("MIGRATION COMPLETE")
    print("=" * 60)
    print("\nNew Features:")
    print("- Clients can join gyms using gym codes")
    print("- Clients can select their trainer from available trainers")
    print("- Trainers see only their assigned clients")
    print("\n")


if __name__ == "__main__":
    try:
        migrate()
    except Exception as e:
        print(f"\n[ERROR] Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
