import requests
import uuid
import datetime

BASE_URL = "http://localhost:9007"

def verify_trainer_workout():
    # 1. Register Trainer
    trainer_username = f"trainer_test_{uuid.uuid4().hex[:6]}"
    trainer_password = "password123"
    print(f"Registering trainer: {trainer_username}")
    
    res = requests.post(f"{BASE_URL}/api/auth/register", json={
        "username": trainer_username,
        "password": trainer_password,
        "role": "trainer"
    })
    if res.status_code != 200:
        print(f"Registration failed: {res.text}")
        return
    
    # Login
    res = requests.post(f"{BASE_URL}/api/auth/login", data={
        "username": trainer_username,
        "password": trainer_password
    })
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("Logged in.")

    # 2. Create Workout
    print("Creating workout...")
    workout_payload = {
        "title": "Test Trainer Workout",
        "duration": "45 min",
        "difficulty": "Hard",
        "exercises": [
            {
                "name": "Pushups", 
                "sets": 3, 
                "reps": 10,
                "rest": 60,
                "video_id": "pushups"
            }
        ]
    }
    res = requests.post(f"{BASE_URL}/api/trainer/workouts", json=workout_payload, headers=headers)
    if res.status_code != 200:
        print(f"Create workout failed: {res.text}")
        return
    workout_id = res.json()["id"]
    print(f"Workout created: {workout_id}")

    # 3. Schedule for Today
    today = datetime.date.today().isoformat()
    print(f"Scheduling workout for today ({today})...")
    event_payload = {
        "date": today,
        "time": "09:00",
        "title": "My Daily Grind",
        "type": "personal",
        "duration": 60,
        "workout_id": workout_id
    }
    res = requests.post(f"{BASE_URL}/api/trainer/events", json=event_payload, headers=headers)
    if res.status_code != 200:
        print(f"Schedule event failed: {res.text}")
        return
    print("Event scheduled.")

    # 4. Verify Data
    print("Fetching trainer data...")
    res = requests.get(f"{BASE_URL}/api/trainer/data", headers=headers)
    
    if res.status_code != 200:
        print(f"Fetch failed with status {res.status_code}")
        print("Response Text:", res.text)
        return

    try:
        data = res.json()
    except Exception as e:
        print(f"JSON Decode Error: {e}")
        print("Response Text:", res.text)
        return
    
    # Check Schedule
    schedule = data.get("schedule", [])
    print(f"Schedule has {len(schedule)} items.")
    found_event = False
    for event in schedule:
        print(f"Event: {event}")
        if event.get("date") == today and event.get("title") == "My Daily Grind":
            found_event = True
            # Note: The schedule item in TrainerData might NOT have workout_id if the model doesn't expose it?
            # Let's check TrainerEvent model in models.py
            pass

    todays_workout = data.get("todays_workout")
    if todays_workout:
        print("SUCCESS: Found todays_workout!")
        print(f"Title: {todays_workout['title']}")
        print(f"ID: {todays_workout['id']}")
        
        if todays_workout['id'] == workout_id:
            print("Verified: Workout ID matches.")
        else:
            print(f"ERROR: Workout ID mismatch. Expected {workout_id}, got {todays_workout['id']}")
    else:
        print("FAILURE: todays_workout is Missing or Null.")
        
        if found_event:
            print("Event WAS found in schedule, but todays_workout is null.")
        else:
            print("Event was NOT found in schedule.")

if __name__ == "__main__":
    verify_trainer_workout()
