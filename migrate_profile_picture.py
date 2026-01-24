"""
Migration to add profile_picture column to users table.
"""
import sqlite3
import os

def migrate():
    db_path = os.path.join(os.path.dirname(__file__), 'db', 'gym_app.db')
    print(f"Using database: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Check existing columns
    cursor.execute("PRAGMA table_info(users)")
    columns = [col[1] for col in cursor.fetchall()]
    print(f"Existing columns: {columns}")

    # Add profile_picture if missing
    if 'profile_picture' not in columns:
        print("Adding profile_picture column...")
        cursor.execute("ALTER TABLE users ADD COLUMN profile_picture TEXT")
        print("Added profile_picture column")
    else:
        print("profile_picture column already exists")

    conn.commit()
    conn.close()
    print("Migration complete!")

    # Create uploads directory
    uploads_dir = os.path.join(os.path.dirname(__file__), 'static', 'uploads', 'profiles')
    os.makedirs(uploads_dir, exist_ok=True)
    print(f"Created uploads directory: {uploads_dir}")

if __name__ == "__main__":
    migrate()
