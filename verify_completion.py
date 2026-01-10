from services import UserService
from datetime import date
import uuid

service = UserService()
client_id = "user_123"
today_str = date.today().isoformat()

print(f"--- Verifying Schedule & Completion for {today_str} ---")

# 1. Assign a workout (if none exists)
# We'll use a dummy workout ID or one we know exists.
# Let's try to assign 'workout_1' (Full Body A)
assignment = {
    "client_id": client_id,
    "workout_id": "workout_1",
    "date": today_str
}
print(f"Assigning workout: {assignment}")
try:
    res = service.assign_workout(assignment)
    print(f"Assignment result: {res}")
except Exception as e:
    print(f"Assignment failed: {e}")

# 2. Fetch Schedule
print("\nFetching schedule...")
schedule = service.get_client_schedule(today_str)
print(f"Schedule: {schedule}")

workout_event = next((e for e in schedule["events"] if e["type"] == "workout"), None)
if not workout_event:
    print("Error: No workout event found!")
    exit(1)

print(f"Found workout event: {workout_event['title']} (ID: {workout_event['id']}, Completed: {workout_event['completed']})")

# 3. Mark as Complete
print("\nMarking as complete...")
try:
    comp_res = service.complete_schedule_item({"date": today_str, "item_id": workout_event["id"]})
    print(f"Completion result: {comp_res}")
except Exception as e:
    print(f"Completion failed: {e}")

# 4. Verify Completion
print("\nVerifying completion status...")
schedule_after = service.get_client_schedule(today_str)
workout_event_after = next((e for e in schedule_after["events"] if e["id"] == workout_event["id"]), None)

if workout_event_after and workout_event_after["completed"]:
    print("SUCCESS: Workout is marked as completed!")
else:
    print(f"FAILURE: Workout status is {workout_event_after['completed'] if workout_event_after else 'Not Found'}")
