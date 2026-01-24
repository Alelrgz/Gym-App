"""
Migration to add client_id and appointment_id columns to trainer_schedule table.
"""
import sqlite3
import os

def migrate():
    db_path = os.path.join(os.path.dirname(__file__), 'db', 'gym_app.db')
    print(f"Using database: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Check existing columns
    cursor.execute("PRAGMA table_info(trainer_schedule)")
    columns = [col[1] for col in cursor.fetchall()]
    print(f"Existing columns: {columns}")

    # Add client_id if missing
    if 'client_id' not in columns:
        print("Adding client_id column...")
        cursor.execute("ALTER TABLE trainer_schedule ADD COLUMN client_id TEXT")
        print("Added client_id column")
    else:
        print("client_id column already exists")

    # Add appointment_id if missing
    if 'appointment_id' not in columns:
        print("Adding appointment_id column...")
        cursor.execute("ALTER TABLE trainer_schedule ADD COLUMN appointment_id TEXT")
        print("Added appointment_id column")
    else:
        print("appointment_id column already exists")

    conn.commit()
    conn.close()
    print("Migration complete!")

if __name__ == "__main__":
    migrate()
