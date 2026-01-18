import sqlite3
import os

def check():
    db_path = "db/gym_app.db"
    print(f"Checking DB at: {db_path}")
    
    if not os.path.exists(db_path):
        print("ERROR: DB file not found at expected path!")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Get schema of client_profile
        print("\nStructure of client_profile:")
        for col in cursor.execute("PRAGMA table_info(client_profile)"):
            print(col)
            
        # Check xax
        print("\nChecking user 'xax':")
        row = cursor.execute("SELECT name, is_premium FROM client_profile WHERE name='xax'").fetchone()
        if row:
            print(f"Found: Name={row[0]}, is_premium={row[1]}")
        else:
            print("User 'xax' not found in client_profile.")
            
    except Exception as e:
        print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    check()
