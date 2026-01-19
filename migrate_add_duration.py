"""
Database migration script to add duration column to trainer_schedule table
"""
import sqlite3
import os

db_path = 'db/gym_app.db'

if not os.path.exists(db_path):
    print(f"[ERROR] Database not found at {db_path}")
    exit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    # Check if column exists
    cursor.execute("PRAGMA table_info(trainer_schedule)")
    columns = [row[1] for row in cursor.fetchall()]
    
    if 'duration' in columns:
        print("[INFO] Column 'duration' already exists in trainer_schedule table")
    else:
        print("[MIGRATE] Adding 'duration' column to trainer_schedule table...")
        cursor.execute("ALTER TABLE trainer_schedule ADD COLUMN duration INTEGER DEFAULT 60")
        conn.commit()
        print("[OK] Migration complete! Column added successfully.")
        
        # Verify
        cursor.execute("PRAGMA table_info(trainer_schedule)")
        columns = [row[1] for row in cursor.fetchall()]
        if 'duration' in columns:
            print("[VERIFY] Column verified in schema")
        else:
            print("[ERROR] Column not found after migration!")
            
except Exception as e:
    print(f"[ERROR] Migration failed: {e}")
    conn.rollback()
finally:
    conn.close()
