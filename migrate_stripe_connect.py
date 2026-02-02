"""
Migration script to add Stripe Connect columns to users table
"""
import sqlite3
import os

def migrate():
    db_path = os.path.join(os.path.dirname(__file__), 'db', 'gym_app.db')
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Check existing columns
    cursor.execute("PRAGMA table_info(users)")
    columns = [col[1] for col in cursor.fetchall()]

    # Add new columns if they don't exist
    new_columns = [
        ("stripe_account_id", "TEXT"),
        ("stripe_account_status", "TEXT"),
    ]

    for col_name, col_type in new_columns:
        if col_name not in columns:
            print(f"Adding column {col_name}...")
            cursor.execute(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}")
        else:
            print(f"Column {col_name} already exists")

    conn.commit()
    conn.close()
    print("Migration complete!")

if __name__ == "__main__":
    migrate()
