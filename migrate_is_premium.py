"""
Database migration script to add is_premium column to client_profile table
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
    cursor.execute("PRAGMA table_info(client_profile)")
    columns = [row[1] for row in cursor.fetchall()]
    
    if 'is_premium' in columns:
        print("[INFO] Column 'is_premium' already exists in client_profile table")
    else:
        print("[MIGRATE] Adding 'is_premium' column to client_profile table...")
        cursor.execute("ALTER TABLE client_profile ADD COLUMN is_premium BOOLEAN DEFAULT 0")
        conn.commit()
        print("[OK] Migration complete! Column added successfully.")
        
        # Verify
        cursor.execute("PRAGMA table_info(client_profile)")
        columns = [row[1] for row in cursor.fetchall()]
        if 'is_premium' in columns:
            print("[VERIFY] Column verified in schema")
        else:
            print("[ERROR] Column not found after migration!")
            
except Exception as e:
    print(f"[ERROR] Migration failed: {e}")
    conn.rollback()
finally:
    conn.close()
