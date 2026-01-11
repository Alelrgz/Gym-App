import sys
import os
from datetime import date

# Add current directory to path
sys.path.append(os.getcwd())

from services import UserService
from database import get_client_session
from models_client_orm import ClientScheduleORM

def verify_today_workout():
    print("Verifying Today's Workout Logic...")
    service = UserService()
    client_id = "user_123"
    today_str = date.today().isoformat()
    
    # 1. Ensure there is a workout scheduled for today
    db = get_client_session(client_id)
    try:
        # Clear existing workouts for today to start fresh
        db.query(ClientScheduleORM).filter(
            ClientScheduleORM.date == today_str,
            ClientScheduleORM.type == "workout"
        ).delete()
        
        # Create a test workout event
        test_workout_id = "w1" # Valid workout from data.py
        new_event = ClientScheduleORM(
            date=today_str,
            title="TEST WORKOUT",
            type="workout",
            completed=False,
            workout_id=test_workout_id,
            details="Testing sync"
        )
        db.add(new_event)
        db.commit()
        print(f"Created test workout event for {today_str}")
    finally:
        db.close()
        
    # 2. Fetch client data and check todays_workout
    try:
        client_data = service.get_client(client_id)
        
        if client_data.todays_workout:
            print("Found today's workout!")
            print(f"Title: {client_data.todays_workout.title}")
            
            if client_data.todays_workout.title == "Full Body Blast": # Title of w1
                print("SUCCESS: Retrieved correct workout details.")
            else:
                print(f"WARNING: Expected 'Full Body Blast', got '{client_data.todays_workout.title}'")
        else:
            print("FAILED: todays_workout is None (Unexpected for Test 1)")
            
        # 3. Test "Rest Day" (No workout scheduled)
        print("\nTest 2: Verifying Rest Day (No workout)...")
        db = get_client_session(client_id)
        try:
             db.query(ClientScheduleORM).filter(
                ClientScheduleORM.date == today_str,
                ClientScheduleORM.type == "workout"
            ).delete()
             db.commit()
        finally:
            db.close()
            
        client_data_rest = service.get_client(client_id)
        if client_data_rest.todays_workout is None:
            print("SUCCESS: todays_workout is None as expected for Rest Day.")
        else:
            print(f"FAILED: Expected None, got {client_data_rest.todays_workout}")

    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    verify_today_workout()
