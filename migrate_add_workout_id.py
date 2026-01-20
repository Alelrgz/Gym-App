import sqlite3

def migrate():
    conn = sqlite3.connect('gym_app.db')
    cursor = conn.cursor()
    try:
        cursor.execute("ALTER TABLE trainer_schedule ADD COLUMN workout_id TEXT")
        print("Successfully added 'workout_id' column to 'trainer_schedule'.")
        conn.commit()
    except Exception as e:
        print(f"Error during migration: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()
