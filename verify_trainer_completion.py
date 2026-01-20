import requests
import uuid
from datetime import date

BASE_URL = "http://localhost:9007"

def verify():
    # 1. Register a test trainer
    username = f"verify_trainer_{uuid.uuid4().hex[:8]}"
    password = "password123"
    
    print(f"Registering trainer {username}...")
    res = requests.post(f"{BASE_URL}/api/auth/register", json={
        "username": username,
        "password": password,
        "role": "trainer",
        "email": f"{username}@test.com"
    })
    if res.status_code != 200:
        print(f"Registration failed: {res.text}")
        return

    # 2. Login
    print("Logging in...")
    res = requests.post(f"{BASE_URL}/api/auth/login", data={
        "username": username,
        "password": password
    })
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 3. Add Event
    print("Adding event...")
    event_data = {
        "title": "Test Event",
        "date": date.today().isoformat(),
        "time": "10:00",
        "type": "personal",
        "duration": 60
    }
    res = requests.post(f"{BASE_URL}/api/trainer/events", json=event_data, headers=headers)
    if res.status_code != 200:
        print(f"Add event failed: {res.text}")
        return
    
    event_id = res.json()["event_id"]
    print(f"Event added with ID: {event_id}")

    # 4. Toggle Complete (True)
    print("Toggling complete (expect True)...")
    res = requests.post(f"{BASE_URL}/api/trainer/events/{event_id}/toggle_complete", headers=headers)
    data = res.json()
    print(f"Response: {data}")
    if not data.get("completed"):
        print("FAILED: Expected completed=True")
        return

    # 5. Verify via Get Data
    print("Verifying via /api/trainer/data...")
    res = requests.get(f"{BASE_URL}/api/trainer/data", headers=headers)
    schedule = res.json()["schedule"]
    event = next((e for e in schedule if e["id"] == str(event_id)), None)
    if not event or not event["completed"]:
        print(f"FAILED: Event not found or not completed in schedule list. Event: {event}")
        return
    print("Verified: Event is completed in schedule.")

    # 6. Toggle Complete (False)
    print("Toggling complete (expect False)...")
    res = requests.post(f"{BASE_URL}/api/trainer/events/{event_id}/toggle_complete", headers=headers)
    data = res.json()
    print(f"Response: {data}")
    if data.get("completed"):
        print("FAILED: Expected completed=False")
        return

    print("SUCCESS: Verification passed!")

if __name__ == "__main__":
    verify()
