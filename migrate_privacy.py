"""
Migration: Add privacy system for client-to-client chat.
- Adds privacy_mode column to client_profile table
- Creates chat_requests table for managing chat requests
"""
from sqlalchemy import text
from database import get_db_session

def migrate():
    db = get_db_session()
    try:
        # Add privacy_mode column to client_profile table
        print("Adding privacy_mode column to client_profile table...")
        try:
            db.execute(text("ALTER TABLE client_profile ADD COLUMN privacy_mode VARCHAR DEFAULT 'public'"))
            db.commit()
            print("[OK] privacy_mode column added successfully!")
        except Exception as e:
            if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                print("[INFO] privacy_mode column already exists, skipping...")
            else:
                raise e

        # Create chat_requests table
        print("Creating chat_requests table...")
        try:
            db.execute(text("""
                CREATE TABLE IF NOT EXISTS chat_requests (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    from_user_id VARCHAR NOT NULL,
                    to_user_id VARCHAR NOT NULL,
                    status VARCHAR DEFAULT 'pending',
                    message VARCHAR,
                    created_at VARCHAR,
                    responded_at VARCHAR,
                    FOREIGN KEY (from_user_id) REFERENCES users(id),
                    FOREIGN KEY (to_user_id) REFERENCES users(id)
                )
            """))
            db.commit()
            print("[OK] chat_requests table created successfully!")
        except Exception as e:
            if "already exists" in str(e).lower():
                print("[INFO] chat_requests table already exists, skipping...")
            else:
                raise e

        # Create indexes for performance
        print("Creating indexes...")
        try:
            db.execute(text("CREATE INDEX IF NOT EXISTS idx_chat_requests_from_user ON chat_requests(from_user_id)"))
            db.execute(text("CREATE INDEX IF NOT EXISTS idx_chat_requests_to_user ON chat_requests(to_user_id)"))
            db.execute(text("CREATE INDEX IF NOT EXISTS idx_chat_requests_status ON chat_requests(status)"))
            db.commit()
            print("[OK] Indexes created successfully!")
        except Exception as e:
            print(f"[WARN] Index creation: {e}")

        print("\nMigration completed successfully!")

    except Exception as e:
        print(f"[ERROR] Migration failed: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    migrate()
