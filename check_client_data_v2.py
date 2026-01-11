import asyncio
import os
import sys

# Ensure we can import from the current directory
sys.path.append(os.getcwd())

from services import UserService

async def main():
    service = UserService()
    try:
        data = service.get_client("user_123")
        print("--- CLIENT DATA ---")
        # Print keys to keep it brief but informative
        print(f"Name: {data.name}")
        print(f"Progress exists: {data.progress is not None}")
        if data.progress:
            print(f"Progress Photos: {len(data.progress.photos)}")
            print(f"Progress Macros: {data.progress.macros}")
        else:
            print("PROGRESS IS NONE!")
            
        print(f"Todays Workout exists: {data.todays_workout is not None}")
        print(f"Calendar events: {len(data.calendar.events)}")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
