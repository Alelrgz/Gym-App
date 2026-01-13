import sys
import os

# Add current directory to path
sys.path.append(os.getcwd())

from services import UserService

def debug_get_client():
    print("Debugging get_client()...")
    service = UserService()
    
    try:
        client_data = service.get_client("user_123")
        print(f"Resulting todays_workout: {client_data.todays_workout}")
        if client_data.todays_workout:
            print(f"Title: {client_data.todays_workout.title}")
        else:
            print("Title: None")
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    debug_get_client()
