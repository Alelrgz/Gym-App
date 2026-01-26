"""
Migration: Add specialties column to users table.
"""
from sqlalchemy import text
from database import get_db_session

def migrate():
    db = get_db_session()
    try:
        # Add specialties column to users table
        print("Adding specialties column to users table...")
        try:
            db.execute(text("ALTER TABLE users ADD COLUMN specialties VARCHAR"))
            db.commit()
            print("[OK] specialties column added successfully!")
        except Exception as e:
            if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                print("[INFO] specialties column already exists, skipping...")
            else:
                raise e

        print("\nMigration completed successfully!")

    except Exception as e:
        print(f"[ERROR] Migration failed: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    migrate()
