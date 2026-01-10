import urllib.request
import urllib.parse
import json
from datetime import datetime, timedelta

BASE_URL = "http://127.0.0.1:9008"
TRAINER_ID = "trainer_default"

def make_request(url, method="GET", data=None, headers=None):
    if headers is None:
        headers = {}
    
    req = urllib.request.Request(url, method=method)
    for k, v in headers.items():
        req.add_header(k, v)
        
    if data:
        json_data = json.dumps(data).encode('utf-8')
        req.add_header('Content-Type', 'application/json')
        req.data = json_data
        
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} - {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"Error: {e}")
        return None

def test_weekly_splits():
    print("--- Testing Weekly Splits ---")
    
    # 1. Create a Split
    print("\n1. Creating a Split...")
    # First, get some workouts to use
    workouts = make_request(f"{BASE_URL}/api/trainer/workouts", headers={"x-trainer-id": TRAINER_ID})
    if not workouts:
        print("Failed to fetch workouts or no workouts found.")
        return
    
    workout_id = workouts[0]['id']
    print(f"Using workout ID: {workout_id}")
    
    split_payload = {
        "name": "Test Split PPL",
        "description": "A test PPL split",
        "days_per_week": 7,
        "schedule": {
            "Monday": workout_id,
            "Wednesday": workout_id,
            "Friday": workout_id
        }
    }
    
    split_data = make_request(
        f"{BASE_URL}/api/trainer/splits", 
        method="POST",
        data=split_payload, 
        headers={"x-trainer-id": TRAINER_ID}
    )
    
    if not split_data:
        print("Failed to create split")
        return
    
    split_id = split_data['id']
    print(f"Split created with ID: {split_id}")
    
    # 2. Verify Split Exists
    print("\n2. Verifying Split Exists...")
    splits = make_request(f"{BASE_URL}/api/trainer/splits", headers={"x-trainer-id": TRAINER_ID})
    found = False
    if splits:
        for s in splits:
            if s['id'] == split_id:
                found = True
                print("Split found in list!")
                break
    
    if not found:
        print("Split NOT found in list!")
        return

    # 3. Assign Split
    print("\n3. Assigning Split...")
    # Get a client
    trainer_data = make_request(f"{BASE_URL}/api/trainer/data", headers={"x-trainer-id": TRAINER_ID})
    clients = trainer_data['clients']
    if not clients:
        print("No clients found.")
        return
    
    client_id = clients[0]['id']
    print(f"Assigning to client: {client_id}")
    
    # Start next Monday
    today = datetime.now()
    days_ahead = 0 - today.weekday() if today.weekday() == 0 else 7 - today.weekday()
    next_monday = today + timedelta(days=days_ahead)
    start_date = next_monday.strftime("%Y-%m-%d")
    print(f"Start Date: {start_date} (Monday)")
    
    assign_payload = {
        "client_id": client_id,
        "split_id": split_id,
        "start_date": start_date
    }
    
    assign_res = make_request(f"{BASE_URL}/api/trainer/assign_split", method="POST", data=assign_payload)
    
    if not assign_res:
        print("Failed to assign split")
        return
    
    print("Split assigned successfully!")
    if 'logs' in assign_res:
        print("\n--- Server Logs ---")
        for log in assign_res['logs']:
            print(log)
        print("-------------------\n")
    
    # 4. Verify Client Schedule
    print("\n4. Verifying Client Schedule...")
    # Fetch client data
    client_data = make_request(f"{BASE_URL}/api/trainer/client/{client_id}")
    if not client_data:
        print("Failed to fetch client data")
        return

    calendar = client_data.get('calendar', {})
    
    # Check if workouts are assigned on Mondays, Wednesdays, Fridays
    # Check first week
    check_dates = [
        next_monday, # Mon
        next_monday + timedelta(days=2), # Wed
        next_monday + timedelta(days=4)  # Fri
    ]
    
    success = True
    for d in check_dates:
        d_str = d.strftime("%Y-%m-%d")
        if d_str in calendar:
            print(f"SUCCESS: Workout found on {d_str}")
        else:
            print(f"FAILURE: No workout on {d_str}")
            success = False
            
    if success:
        print("\nVerification PASSED! [OK]")
    else:
        print("\nVerification FAILED! [FAIL]")

if __name__ == "__main__":
    test_weekly_splits()
