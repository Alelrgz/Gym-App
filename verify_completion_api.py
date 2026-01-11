import sys
import os

from datetime import date

# Add project root to path
sys.path.append(os.getcwd())

def verify_completion_api():
    print("Verifying Workout Completion API...")
    
    # Assuming app is running on localhost:8000 (standard for this project)
    # If not, we might need to start it or use the service layer directly.
    # Using service layer directly is safer for a script.
    
    from services import UserService
    from database import get_client_session
    from models_client_orm import ClientScheduleORM
    
    service = UserService()
    client_id = "user_123" # Default used in service
    today_str = date.today().isoformat()
    
    # 1. Ensure there is a workout scheduled for today
    db = get_client_session(client_id)
    try:
        # Clear existing for today
        db.query(ClientScheduleORM).filter(
            ClientScheduleORM.date == today_str,
            ClientScheduleORM.type == "workout"
        ).delete()
        
        # Add a test workout
        test_workout = ClientScheduleORM(
            date=today_str,
            title="Test Workout",
            type="workout",
            completed=False,
            workout_id="test_w_1"
        )
        db.add(test_workout)
        db.commit()
        
        print(f"Created test workout for {today_str}")
        
        # 2. Call Service Method (simulating API call)
        payload = {"date": today_str}
        result = service.complete_schedule_item(payload)
        print(f"Service Result: {result}")
        
        # 3. Verify in DB
        updated_item = db.query(ClientScheduleORM).filter(
            ClientScheduleORM.date == today_str,
            ClientScheduleORM.type == "workout"
        ).first()
        
        if updated_item and updated_item.completed:
            print("Verification PASSED: Workout marked as completed.")
        else:
            print("Verification FAILED: Workout not marked as completed.")
            
    except Exception as e:
        print(f"Verification FAILED: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    verify_completion_api()
