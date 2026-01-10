import urllib.request
import urllib.parse
import json
import sys

BASE_URL = "http://127.0.0.1:9007"
TRAINER_ID = "trainer_default"

def make_request(url, method="GET", data=None, headers=None):
    if headers is None:
        headers = {}
    
    print(f"\n[{method}] {url}")
    print(f"Headers: {headers}")
    
    req = urllib.request.Request(url, method=method)
    for k, v in headers.items():
        req.add_header(k, v)
        
    if data:
        json_data = json.dumps(data).encode('utf-8')
        req.add_header('Content-Type', 'application/json')
        req.data = json_data
        print(f"Payload: {json.dumps(data, indent=2)}")
        
    try:
        with urllib.request.urlopen(req) as response:
            body = response.read().decode('utf-8')
            print(f"[OK] Status: {response.status}")
            print(f"Response: {body[:200]}...")  # First 200 chars
            return json.loads(body)
    except urllib.error.HTTPError as e:
        print(f"[ERROR] HTTP Error: {e.code}")
        error_body = e.read().decode('utf-8')
        print(f"Error Body: {error_body}")
        return None
    except Exception as e:
        print(f"[ERROR] Exception: {e}")
        return None

def test_split_edit():
    print("="*60)
    print("WEEKLY SPLIT EDIT - DIAGNOSTIC TEST")
    print("="*60)
    
    # Step 1: Fetch existing splits
    print("\n### STEP 1: Fetch Existing Splits ###")
    splits = make_request(
        f"{BASE_URL}/api/trainer/splits",
        headers={"x-trainer-id": TRAINER_ID}
    )
    
    if not splits:
        print("\n[ERROR] No splits found or failed to fetch splits.")
        print("Creating a test split first...\n")
        
        # Fetch workouts to use in split
        workouts = make_request(
            f"{BASE_URL}/api/trainer/workouts",
            headers={"x-trainer-id": TRAINER_ID}
        )
        
        if not workouts or len(workouts) == 0:
            print("[ERROR] No workouts available. Cannot create split.")
            sys.exit(1)
        
        workout_id = workouts[0]['id']
        
        # Create a test split
        split_payload = {
            "name": "Test Diagnostic Split",
            "description": "Created by diagnostic script",
            "days_per_week": 7,
            "schedule": {
                "Monday": workout_id,
                "Wednesday": workout_id
            }
        }
        
        print("\n### Creating Test Split ###")
        created_split = make_request(
            f"{BASE_URL}/api/trainer/splits",
            method="POST",
            data=split_payload,
            headers={"x-trainer-id": TRAINER_ID}
        )
        
        if not created_split:
            print("[ERROR] Failed to create test split.")
            sys.exit(1)
        
        split_id = created_split['id']
        print(f"\n[OK] Test split created with ID: {split_id}")
    else:
        split_id = splits[0]['id']
        print(f"\n[OK] Found {len(splits)} split(s). Using first one: {split_id}")
    
    # Step 2: Attempt to UPDATE the split
    print("\n### STEP 2: Update Split (Testing for 404) ###")
    update_payload = {
        "name": "Updated Split Name - TEST",
        "description": "Updated by diagnostic script",
        "days_per_week": 7,
        "schedule": {
            "Tuesday": "some-workout-id",
            "Thursday": "some-workout-id"
        }
    }
    
    updated_split = make_request(
        f"{BASE_URL}/api/trainer/splits/{split_id}",
        method="PUT",
        data=update_payload,
        headers={"x-trainer-id": TRAINER_ID}
    )
    
    if updated_split:
        print("\n[OK] SUCCESS: Split updated successfully!")
        print(f"Updated name: {updated_split.get('name')}")
        return True
    else:
        print("\n[ERROR] FAILURE: Split update returned error (likely 404)")
        return False
    
    # Step 3: Verify the route patterns
    print("\n### STEP 3: Testing Route Patterns ###")
    
    test_urls = [
        f"{BASE_URL}/api/trainer/splits",
        f"{BASE_URL}/api/trainer/splits/{split_id}",
        f"{BASE_URL}/api/trainer/splits/test-fake-id",
    ]
    
    for url in test_urls:
        make_request(url, method="GET", headers={"x-trainer-id": TRAINER_ID})

if __name__ == "__main__":
    try:
        success = test_split_edit()
        print("\n" + "="*60)
        if success:
            print("RESULT: Update endpoint is working correctly")
            print("The 404 error may be frontend-specific or caching issue.")
        else:
            print("RESULT: Update endpoint is returning 404")
            print("This indicates a route registration or matching problem.")
        print("="*60)
    except Exception as e:
        print(f"\n[FATAL ERROR] {e}")
        import traceback
        traceback.print_exc()
