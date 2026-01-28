"""
Migration: Update conversations table for client-to-client messaging.
Adds user1_id, user2_id, conversation_type, user1_unread_count, user2_unread_count columns.
"""
from sqlalchemy import text
from database import get_db_session

def migrate():
    db = get_db_session()
    try:
        columns_to_add = [
            ("user1_id", "VARCHAR"),
            ("user2_id", "VARCHAR"),
            ("conversation_type", "VARCHAR DEFAULT 'trainer_client'"),
            ("user1_unread_count", "INTEGER DEFAULT 0"),
            ("user2_unread_count", "INTEGER DEFAULT 0"),
        ]

        for col_name, col_type in columns_to_add:
            print(f"Adding {col_name} column to conversations table...")
            try:
                db.execute(text(f"ALTER TABLE conversations ADD COLUMN {col_name} {col_type}"))
                db.commit()
                print(f"[OK] {col_name} column added successfully!")
            except Exception as e:
                if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                    print(f"[INFO] {col_name} column already exists, skipping...")
                else:
                    raise e

        # Create indexes
        print("Creating indexes...")
        try:
            db.execute(text("CREATE INDEX IF NOT EXISTS idx_conversations_user1 ON conversations(user1_id)"))
            db.execute(text("CREATE INDEX IF NOT EXISTS idx_conversations_user2 ON conversations(user2_id)"))
            db.execute(text("CREATE INDEX IF NOT EXISTS idx_conversations_type ON conversations(conversation_type)"))
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
