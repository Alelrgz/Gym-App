import sqlite3

def check_column():
    conn = sqlite3.connect('gym_app.db')
    cursor = conn.cursor()
    try:
        cursor.execute("PRAGMA table_info(trainer_schedule)")
        columns = [info[1] for info in cursor.fetchall()]
        if 'workout_id' in columns:
            print("Column 'workout_id' exists.")
        else:
            print("Column 'workout_id' DOES NOT exist.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    check_column()
