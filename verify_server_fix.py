import requests
import datetime

def verify_fix():
    base_url = "http://localhost:9007"
    username = "trainer_test"
    password = "trainer_test"
    
    # 1. Login
    print(f"Logging in as {username}...")
    try:
        resp = requests.post(f"{base_url}/api/auth/login", data={"username": username, "password": password})
        if resp.status_code != 200:
            print("Login failed, trying to register...")
            resp = requests.post(f"{base_url}/api/auth/register", json={"username": username, "password": password, "role": "trainer"})
            if resp.status_code == 200:
                print("Registered. Logging in again...")
                resp = requests.post(f"{base_url}/api/auth/login", data={"username": username, "password": password})
            else:
                print(f"Registration failed: {resp.status_code} {resp.text}")
                return

        token = resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        print("Login successful.")

        # 2. Add Event
        print("Adding event with 150 min duration...")
        today = datetime.date.today().isoformat()
        event_data = {
            "title": "Test Duration",
            "date": today,
            "time": "10:00",
            "type": "personal",
            "duration": 150
        }
        resp = requests.post(f"{base_url}/api/trainer/events", json=event_data, headers=headers)
        if resp.status_code != 200:
            print(f"Failed to add event: {resp.status_code} {resp.text}")
            return
        print("Event added.")

        # 3. Get Trainer Data
        print("Fetching trainer data...")
        resp = requests.get(f"{base_url}/api/trainer/data", headers=headers)
        if resp.status_code != 200:
            print(f"Failed to get data: {resp.status_code} {resp.text}")
            return
            
        data = resp.json()
        schedule = data.get("schedule", [])
        
        found = False
        for event in schedule:
            if event['title'] == "Test Duration":
                found = True
                print(f"Event: {event['title']}, Duration: {event.get('duration')}")
                if event.get('duration') == 150:
                    print("SUCCESS: Event has correct duration 150.")
                else:
                    print(f"FAILURE: Event has incorrect duration {event.get('duration')}.")
        
        if not found:
            print("WARNING: Event not found in schedule.")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    verify_fix()
