import sqlite3

DB_PATH = "db/gym_app.db"

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        print("Attempting to add 'workout_id' column to 'trainer_schedule' table...")
        cursor.execute("ALTER TABLE trainer_schedule ADD COLUMN workout_id TEXT")
        conn.commit()
        print("Successfully added 'workout_id' column.")
    except sqlite3.OperationalError as e:
        if "duplicate column" in str(e):
            print("Column 'workout_id' already exists.")
        else:
            print(f"Error adding column: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()
