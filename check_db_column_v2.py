import sqlite3
import os

def check_column():
    db_path = os.path.join(os.path.dirname(__file__), 'db', 'gym_app.db')
    print(f"Checking DB at: {db_path}")
    if not os.path.exists(db_path):
        print("DB file does not exist.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    try:
        cursor.execute("PRAGMA table_info(trainer_schedule)")
        columns = [info[1] for info in cursor.fetchall()]
        if 'workout_id' in columns:
            print("Column 'workout_id' exists.")
        else:
            print("Column 'workout_id' DOES NOT exist.")
            print(f"Columns found: {columns}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    check_column()
