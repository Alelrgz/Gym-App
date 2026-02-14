"""Add Spotify OAuth token columns to users table"""
import sqlite3
import os

DB_PATH = "db/gym_app.db"

def migrate():
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    try:
        # Check if columns already exist
        cursor.execute("PRAGMA table_info(users)")
        columns = [row[1] for row in cursor.fetchall()]

        columns_to_add = []
        if 'spotify_access_token' not in columns:
            columns_to_add.append("ADD COLUMN spotify_access_token TEXT")
        if 'spotify_refresh_token' not in columns:
            columns_to_add.append("ADD COLUMN spotify_refresh_token TEXT")
        if 'spotify_token_expires_at' not in columns:
            columns_to_add.append("ADD COLUMN spotify_token_expires_at TEXT")

        if not columns_to_add:
            print("[OK] Spotify token columns already exist")
            return

        # Add columns
        for alter_stmt in columns_to_add:
            sql = f"ALTER TABLE users {alter_stmt}"
            print(f"Executing: {sql}")
            cursor.execute(sql)

        conn.commit()
        print("[SUCCESS] Added Spotify token columns to users table")

    except Exception as e:
        print(f"[ERROR] Migration failed: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()
