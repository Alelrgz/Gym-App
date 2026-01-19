import urllib.request
import urllib.error
import json
import uuid
import urllib.parse
from datetime import datetime, timedelta

BASE_URL = "http://localhost:9007"

def test_split_assignment():
    username = f"trainer_{uuid.uuid4().hex[:8]}"
    password = "password123"
    email = f"{username}@example.com"
    
    # 1. Register Trainer
    print(f"Registering {username}...")
    reg_data = {
        "username": username,
        "password": password,
        "email": email,
        "role": "trainer"
    }
    
    trainer_id = None
    token = None
    
    try:
        req = urllib.request.Request(
            f"{BASE_URL}/api/auth/register",
            data=json.dumps(reg_data).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req) as response:
            print("Registration successful")
            
        # Login to get ID and Token
        login_data = urllib.parse.urlencode({
            "username": username,
            "password": password
        }).encode('utf-8')
        
        req = urllib.request.Request(
            f"{BASE_URL}/api/auth/login",
            data=login_data,
            headers={'Content-Type': 'application/x-www-form-urlencoded'}
        )
        with urllib.request.urlopen(req) as response:
            resp_json = json.loads(response.read().decode('utf-8'))
            token = resp_json.get("access_token")
            trainer_id = resp_json.get("user_id") # Assuming login returns user_id, if not we fetch profile
            print(f"Login successful. Token: {token[:10]}...")

    except Exception as e:
        print(f"Auth failed: {e}")
        return

    # 2. Create a Client (Need a client to assign to)
    client_username = f"client_{uuid.uuid4().hex[:8]}"
    print(f"Registering client {client_username}...")
    try:
        req = urllib.request.Request(
            f"{BASE_URL}/api/auth/register",
            data=json.dumps({
                "username": client_username,
                "password": "password123",
                "email": f"{client_username}@example.com",
                "role": "client"
            }).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req) as response:
            pass
            
        # We need client ID. Login as client? Or just fetch trainer clients?
        # Trainer needs to "own" the client? Currently clients are global or claimed?
        # Let's just login as client to get ID.
        login_data = urllib.parse.urlencode({
            "username": client_username,
            "password": "password123"
        }).encode('utf-8')
        
        req = urllib.request.Request(
            f"{BASE_URL}/api/auth/login",
            data=login_data,
            headers={'Content-Type': 'application/x-www-form-urlencoded'}
        )
        with urllib.request.urlopen(req) as response:
            resp_json = json.loads(response.read().decode('utf-8'))
            client_token = resp_json.get("access_token")
            # client_id = resp_json.get("user_id") # Might be missing
            
            # Fetch profile to get ID
            req_profile = urllib.request.Request(
                f"{BASE_URL}/api/client/data",
                headers={'Authorization': f"Bearer {client_token}"}
            )
            with urllib.request.urlopen(req_profile) as res_prof:
                prof_json = json.loads(res_prof.read().decode('utf-8'))
                print(f"DEBUG: Client Profile: {prof_json}")
                client_id = prof_json.get("id")
                
            print(f"Client created with ID: {client_id}")
            
    except Exception as e:
        print(f"Client setup failed: {e}")
        return

    # 3. Create a Workout (Need a workout for the split)
    print("Creating a workout...")
    workout_id = None
    try:
        workout_data = {
            "title": "Test Workout",
            "duration": "60 min",
            "difficulty": "Intermediate",
            "exercises": []
        }
        req = urllib.request.Request(
            f"{BASE_URL}/api/trainer/workouts",
            data=json.dumps(workout_data).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f"Bearer {token}"
            }
        )
        with urllib.request.urlopen(req) as response:
            w_json = json.loads(response.read().decode('utf-8'))
            workout_id = w_json['id']
            print(f"Workout created: {workout_id}")
    except Exception as e:
        print(f"Workout creation failed: {e}")
        return

    # 4. Create a Split
    print("Creating a split...")
    split_id = None
    try:
        # Simulate the structure sent by frontend: { id: "...", title: "..." }
        schedule = {
            "Monday": {"id": workout_id, "title": "Test Workout"},
            "Tuesday": None,
            "Wednesday": {"id": workout_id, "title": "Test Workout"},
            "Thursday": None,
            "Friday": None,
            "Saturday": None,
            "Sunday": None
        }
        
        split_data = {
            "name": "Test Split",
            "description": "Test Description",
            "days_per_week": 7,
            "schedule": schedule
        }
        
        req = urllib.request.Request(
            f"{BASE_URL}/api/trainer/splits",
            data=json.dumps(split_data).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f"Bearer {token}"
            }
        )
        with urllib.request.urlopen(req) as response:
            s_json = json.loads(response.read().decode('utf-8'))
            split_id = s_json['id']
            print(f"Split created: {split_id}")
            
    except Exception as e:
        print(f"Split creation failed: {e}")
        return

    # 5. Assign Split
    print("Assigning split...")
    try:
        assign_data = {
            "split_id": split_id,
            "client_id": client_id,
            "start_date": datetime.now().strftime("%Y-%m-%d")
        }
        
        req = urllib.request.Request(
            f"{BASE_URL}/api/trainer/assign_split",
            data=json.dumps(assign_data).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f"Bearer {token}"
            }
        )
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            print("Assignment Result:")
            print(json.dumps(result, indent=2))
            
    except urllib.error.HTTPError as e:
        print(f"Assignment failed: {e.code}")
        print(e.read().decode('utf-8'))
    except Exception as e:
        print(f"Assignment exception: {e}")

if __name__ == "__main__":
    test_split_assignment()
