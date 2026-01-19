import requests
import json
import sys

BASE_URL = "http://localhost:8000"

def register_trainer():
    username = "test_trainer_verify"
    email = "verify@test.com"
    password = "password"
    
    # Try login first
    print(f"Logging in as {username}...")
    res = requests.post(f"{BASE_URL}/api/auth/login", data={"username": username, "password": password})
    
    if res.status_code == 200:
        return res.json()["access_token"]
        
    # Register if not exists
    print(f"Registering {username}...")
    res = requests.post(f"{BASE_URL}/api/auth/register", json={
        "username": username,
        "email": email,
        "password": password,
        "role": "trainer"
    })
    
    if res.status_code == 200:
        # Login to get token
        res = requests.post(f"{BASE_URL}/api/auth/login", data={"username": username, "password": password})
        return res.json()["access_token"]
    else:
        print(f"Failed to register/login: {res.text}")
        sys.exit(1)

def clear_events(token):
    headers = {"Authorization": f"Bearer {token}"}
    res = requests.get(f"{BASE_URL}/api/trainer/data", headers=headers)
    if res.status_code == 200:
        events = res.json().get("schedule", [])
        print(f"Clearing {len(events)} existing events...")
        for e in events:
            requests.delete(f"{BASE_URL}/api/trainer/events/{e['id']}", headers=headers)

def test_schedule(token):
    headers = {"Authorization": f"Bearer {token}"}
    date = "2025-01-01" # Future date
    
    print("\n--- TEST 1: Create Event (9:00 AM, 60 min) ---")
    res = requests.post(f"{BASE_URL}/api/trainer/events", headers=headers, json={
        "date": date,
        "time": "09:00 AM",
        "title": "Event 1",
        "type": "personal",
        "duration": 60
    })
    if res.status_code == 200:
        print("SUCCESS")
    else:
        print(f"FAILED: {res.text}")
        return

    print("\n--- TEST 2: Create Sequential Event (10:00 AM, 60 min) ---")
    res = requests.post(f"{BASE_URL}/api/trainer/events", headers=headers, json={
        "date": date,
        "time": "10:00 AM",
        "title": "Event 2",
        "type": "personal",
        "duration": 60
    })
    if res.status_code == 200:
        print("SUCCESS")
    else:
        print(f"FAILED: {res.text}")

    print("\n--- TEST 3: Create Overlapping Event (9:30 AM, 60 min) ---")
    res = requests.post(f"{BASE_URL}/api/trainer/events", headers=headers, json={
        "date": date,
        "time": "09:30 AM",
        "title": "Conflict Event",
        "type": "personal",
        "duration": 60
    })
    if res.status_code == 409:
        print(f"CORRECTLY REJECTED: {res.json()['detail']}")
    else:
        print(f"FAILED TO REJECT (Status {res.status_code}): {res.text}")

    print("\n--- TEST 4: Create Enveloping Event (8:30 AM, 120 min) ---")
    res = requests.post(f"{BASE_URL}/api/trainer/events", headers=headers, json={
        "date": date,
        "time": "08:30 AM",
        "title": "Big Conflict",
        "type": "personal",
        "duration": 120
    })
    if res.status_code == 409:
        print(f"CORRECTLY REJECTED: {res.json()['detail']}")
    else:
        print(f"FAILED TO REJECT (Status {res.status_code}): {res.text}")

    print("\n--- TEST 5: Verify Persistence ---")
    res = requests.get(f"{BASE_URL}/api/trainer/data", headers=headers)
    data = res.json()
    events = [e for e in data.get("schedule", []) if e["date"] == date]
    
    print(f"Found {len(events)} events for {date}:")
    for e in events:
        print(f"- {e['time']} ({e['duration']} min): {e['title']}")
        if "duration" not in e:
             print("MISSING DURATION FIELD IN RESPONSE")
        elif e["duration"] != 60:
             print(f"WRONG DURATION: {e['duration']}")
        else:
             print("DURATION CORRECT")

if __name__ == "__main__":
    try:
        token = register_trainer()
        clear_events(token)
        test_schedule(token)
    except Exception as e:
        print(f"Error: {e}")
