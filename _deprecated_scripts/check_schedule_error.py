import sys
import os

# Add project root to path
sys.path.append(os.getcwd())

from services import UserService
from models import ClientData
from pydantic import ValidationError

def reproduce():
    print("Attempting to fetch client data for 'user_456' (Sarah)...")
    service = UserService()
    
    try:
        # user_456 in data.py has "todays_workout": None
        client_data = service.get_client("user_456")
        print("Successfully fetched client data!")
        print(f"Name: {client_data.name}")
        print(f"Workout: {client_data.todays_workout}")
    except ValidationError as e:
        print("\n!!! CAUGHT EXPECTED VALIDATION ERROR !!!")
        print(e)
    except Exception as e:
        print(f"\n!!! CAUGHT UNEXPECTED ERROR: {type(e).__name__} !!!")
        print(e)

if __name__ == "__main__":
    reproduce()
