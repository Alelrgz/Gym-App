import sqlite3
import os

DB_PATH = "db/gym_app.db"

def migrate():
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}. Skipping migration.")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    try:
        print("Checking if 'completed' column exists in 'trainer_schedule'...")
        cursor.execute("PRAGMA table_info(trainer_schedule)")
        columns = [info[1] for info in cursor.fetchall()]
        
        if "completed" in columns:
            print("'completed' column already exists. No action needed.")
        else:
            print("Adding 'completed' column...")
            cursor.execute("ALTER TABLE trainer_schedule ADD COLUMN completed BOOLEAN DEFAULT 0")
            conn.commit()
            print("Migration successful: Added 'completed' column.")
            
    except Exception as e:
        print(f"Migration failed: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()
