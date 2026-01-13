from services import UserService
from datetime import date

service = UserService()
today_str = date.today().isoformat()

print(f"--- Checking Schedule for {today_str} ---")
schedule = service.get_client_schedule(today_str)
print(f"Full Schedule Response: {schedule}")

workout_event = next((e for e in schedule["events"] if e["type"] == "workout"), None)
if workout_event:
    print(f"Workout Title: '{workout_event['title']}'")
    print(f"Workout Details: '{workout_event['details']}'")
else:
    print("No workout event found for today.")
