import sys
import os

# Add current directory to path
sys.path.append(os.getcwd())

from services import UserService

def check_workout_details():
    print("Checking Workout Details...")
    service = UserService()
    workout_id = "949d3d09-83f0-4e9e-9899-ecf25063a1aa"
    
    try:
        details = service.get_workout_details(workout_id)
        print(f"Details for {workout_id}:")
        print(f"Title: {details.get('title')}")
        print(f"ID: {details.get('id')}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_workout_details()
