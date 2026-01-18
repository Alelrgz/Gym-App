import sqlite3

def migrate():
    print("Migrating database...")
    # Correct path relative to root
    db_path = "db/gym_app.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        cursor.execute("ALTER TABLE client_profile ADD COLUMN is_premium BOOLEAN DEFAULT 0")
        conn.commit()
        print("Successfully added is_premium column.")
    except sqlite3.OperationalError as e:
        if "duplicate column" in str(e):
            print("Column is_premium already exists.")
        else:
            print(f"Error: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()
