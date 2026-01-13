import urllib.request
import urllib.error
import json
from datetime import date

BASE_URL = "http://localhost:5000"

def reproduce_500():
    print("Attempting to reproduce 500 error on /api/trainer/assign_split...")
    
    # 1. Fetch existing splits to get a valid ID
    trainer_id = "trainer_default"
    headers = {
        "x-trainer-id": trainer_id,
        "Content-Type": "application/json"
    }
    
    try:
        req = urllib.request.Request(f"{BASE_URL}/api/trainer/splits", headers=headers)
        with urllib.request.urlopen(req) as response:
            splits = json.loads(response.read().decode())
    except Exception as e:
        print(f"Failed to fetch splits: {e}")
        return

    if not splits:
        print("No splits found. Creating one...")
        split_payload = {
            "name": "Test Split",
            "description": "For reproduction",
            "days_per_week": 7,
            "schedule": {
                "Monday": "workout_1", 
                "Wednesday": "rest"
            }
        }
        try:
            req = urllib.request.Request(
                f"{BASE_URL}/api/trainer/splits", 
                data=json.dumps(split_payload).encode(),
                headers=headers,
                method="POST"
            )
            with urllib.request.urlopen(req) as response:
                split_data = json.loads(response.read().decode())
                split_id = split_data["id"]
        except Exception as e:
            print(f"Failed to create split: {e}")
            return
    else:
        split_id = splits[0]["id"]
        
    print(f"Using split_id: {split_id}")
    
    # 2. Assign Split
    payload = {
        "client_id": "user_123", # Default client
        "split_id": split_id,
        "start_date": date.today().isoformat()
    }
    
    print(f"Sending payload: {json.dumps(payload, indent=2)}")
    
    try:
        req = urllib.request.Request(
            f"{BASE_URL}/api/trainer/assign_split",
            data=json.dumps(payload).encode(),
            headers=headers,
            method="POST"
        )
        with urllib.request.urlopen(req) as response:
            print(f"Status Code: {response.status}")
            print(f"Response: {response.read().decode()}")
            print("❌ Success (200 OK) - Did not reproduce 500 error")
            
    except urllib.error.HTTPError as e:
        print(f"Status Code: {e.code}")
        print(f"Response: {e.read().decode()}")
        if e.code == 500:
            print("✅ Reproduced 500 Internal Server Error")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    reproduce_500()
