"""
Migration script to add strength_goal columns to client_profile table
"""
import sqlite3
import os

def migrate():
    db_path = os.path.join(os.path.dirname(__file__), 'db', 'gym_app.db')
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Check existing columns
    cursor.execute("PRAGMA table_info(client_profile)")
    columns = [col[1] for col in cursor.fetchall()]

    # Add new columns if they don't exist
    new_columns = [
        ("strength_goal_upper", "INTEGER"),
        ("strength_goal_lower", "INTEGER"),
        ("strength_goal_cardio", "INTEGER"),
    ]

    for col_name, col_type in new_columns:
        if col_name not in columns:
            print(f"Adding column {col_name}...")
            cursor.execute(f"ALTER TABLE client_profile ADD COLUMN {col_name} {col_type}")
        else:
            print(f"Column {col_name} already exists")

    conn.commit()
    conn.close()
    print("Migration complete!")

if __name__ == "__main__":
    migrate()
