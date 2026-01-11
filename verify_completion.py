import sys
import os
from datetime import date

# Add project root to path
sys.path.append(os.getcwd())

from services import UserService
from models import ClientData

def verify_completion():
    service = UserService()
    client_id = "user_123_v2"
    today_str = date.today().isoformat()
    
    print(f"--- Verifying Workout Completion for {today_str} ---")

    # 1. Check Initial State
    print("\n1. Fetching Client Data (Initial)...")
    client_data = service.get_client(client_id)
    
    if not client_data.todays_workout:
        print("X No workout scheduled for today. Cannot verify completion.")
        return

    print(f"   Today's Workout: {client_data.todays_workout.title}")
    print(f"   Completed Status: {client_data.todays_workout.completed}")
    
    if client_data.todays_workout.completed:
        print("⚠️ Workout already completed. Resetting for test...")
        # Reset logic (hacky direct DB access or just assume we can toggle)
        # For this test, we'll just proceed to complete it again (idempotent) or fail if we wanted to test transition.
    
    # 2. Complete Workout
    print("\n2. Completing Workout...")
    payload = {"date": today_str}
    try:
        res = service.complete_schedule_item(payload)
        print(f"   Result: {res}")
    except Exception as e:
        print(f"❌ Failed to complete workout: {e}")
        return

    # 3. Verify Final State
    print("\n3. Fetching Client Data (Final)...")
    client_data_final = service.get_client(client_id)
    
    # DEBUG: Check calendar events
    today_events = [e for e in client_data_final.calendar.events if e.date == today_str]
    print(f"   DEBUG: Calendar Events for today: {today_events}")

    if client_data_final.todays_workout and client_data_final.todays_workout.completed:
        print("SUCCESS: Workout is marked as completed!")
    else:
        print("FAILURE: Workout is NOT marked as completed.")
        print(f"   Status: {client_data_final.todays_workout.completed if client_data_final.todays_workout else 'No Workout'}")

if __name__ == "__main__":
    verify_completion()
