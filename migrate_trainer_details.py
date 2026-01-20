"""
Migration to add 'details' column to trainer_schedule table.
This enables saving workout exercise performance data when a trainer completes their personal workout.
"""
import sqlite3
import os

# Change to the script directory to find the database
script_dir = os.path.dirname(os.path.abspath(__file__))
db_path = os.path.join(script_dir, "db", "gym_app.db")

print(f"Database path: {db_path}")

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Check if column already exists
cursor.execute("PRAGMA table_info(trainer_schedule)")
columns = [col[1] for col in cursor.fetchall()]
print(f"Current columns in trainer_schedule: {columns}")

if 'details' not in columns:
    print("Adding 'details' column to trainer_schedule table...")
    cursor.execute("ALTER TABLE trainer_schedule ADD COLUMN details TEXT")
    conn.commit()
    print("✅ Column 'details' added successfully!")
else:
    print("⚠️ Column 'details' already exists, skipping.")

conn.close()
print("Migration complete!")
