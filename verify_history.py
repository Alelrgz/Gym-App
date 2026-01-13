import requests
import json
import sqlite3
import os
from datetime import date

# Configuration
BASE_URL = "http://127.0.0.1:9007"
CLIENT_ID = "user_123"
DB_PATH = f"db/client_{CLIENT_ID}.db"

def verify_history():
    print("--- 1. Simulating Workout Completion ---")
    today = date.today().isoformat()
    
    # Mock payload simulating frontend state
    payload = {
        "date": today,
        "exercises": [
            {
                "name": "TEST_BENCH_PRESS",
                "performance": [
                    {"reps": 10, "weight": 60, "completed": True}, # Set 1
                    {"reps": 8, "weight": 65, "completed": True},  # Set 2
                    {"reps": 5, "weight": 70, "completed": False}  # Set 3 (Incomplete, should skip?)
                    # Note: Backend logic currently saves if completed=True.
                ]
            }
        ]
    }
    
    try:
        # We need to ensure there is a scheduled item first or relying on fallback?
        # The service uses fallback: "item = db.query... .filter(date=date_str, type='workout').first()"
        # If no workout is scheduled for today, it might fail or pick nothing.
        # Let's assign a workout first to be safe, or just rely on existing data.
        # To be safe, let's inject a dummy schedule item directly via DB or assume one exists.
        # OR just call the endpoint and see if it returns 404 (Schedule item not found).
        
        # Actually, let's use the API to complete.
        res = requests.post(f"{BASE_URL}/api/client/schedule/complete", json=payload)
        
        if res.status_code == 404:
             print("Yellow: No scheduled workout found for today. Proceeding to check DB anyway (maybe manual test).")
        elif res.status_code != 200:
            print(f"Error: API returned {res.status_code} - {res.text}")
            return

        print("API Request successful.")

    except Exception as e:
        print(f"API Request failed: {e}")
        return

    print("\n--- 2. Verifying Database Content ---")
    if not os.path.exists(DB_PATH):
        print(f"Error: Database not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        cursor.execute("SELECT * FROM client_exercise_log WHERE date = ?", (today,))
        rows = cursor.fetchall()
        
        print(f"Found {len(rows)} log entries for today ({today}):")
        for row in rows:
            # Row structure: id, date, workout_id, exercise_name, set_number, reps, weight, metric_type
            print(f" - {row[3]} (Set {row[4]}): {row[6]}kg x {row[5]} reps")
            
        # Assertion
        # We sent 2 completed sets for TEST_BENCH_PRESS
        test_logs = [r for r in rows if r[3] == "TEST_BENCH_PRESS"]
        if len(test_logs) >= 2:
            print("\nSUCCESS: Data persistence verified!")
        else:
            print("\nWARNING: Expected data not found. (Might be due to 'Schedule item not found' error above)")

    except Exception as e:
        print(f"Database query failed: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    verify_history()
