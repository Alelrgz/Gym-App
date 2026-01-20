import sqlite3

def check_schema():
    conn = sqlite3.connect('db/gym_app.db')
    cursor = conn.cursor()
    
    print("Checking trainer_schedule columns:")
    cursor.execute("PRAGMA table_info(trainer_schedule)")
    columns = cursor.fetchall()
    
    found = False
    for col in columns:
        print(col)
        if col[1] == 'workout_id':
            found = True
            
    if found:
        print("\nSUCCESS: workout_id column found.")
    else:
        print("\nFAILURE: workout_id column NOT found.")
        
    conn.close()

if __name__ == "__main__":
    check_schema()
