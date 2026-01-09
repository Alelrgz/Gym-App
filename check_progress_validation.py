import sys
import os
from pydantic import ValidationError

# Add project root to path
sys.path.append(os.getcwd())

from models import ClientData, CalendarData, Workout

def check_progress_validation():
    print("Checking ClientData validation with empty progress dict...")
    
    # Mock data
    valid_calendar = CalendarData(events=[])
    
    try:
        # Attempt to create ClientData with empty progress dict
        # This mimics what services.py does if diet_settings is missing
        client = ClientData(
            name="Test User",
            streak=0,
            gems=0,
            health_score=0,
            todays_workout=None,
            daily_quests=[],
            progress=None, # <--- This should now be valid
            calendar=valid_calendar
        )
        print("SUCCESS: ClientData created successfully (Unexpected)")
    except ValidationError as e:
        print("\n!!! CAUGHT EXPECTED VALIDATION ERROR !!!")
        print(e)
    except Exception as e:
        print(f"\n!!! CAUGHT UNEXPECTED ERROR: {type(e).__name__} !!!")
        print(e)

if __name__ == "__main__":
    check_progress_validation()
