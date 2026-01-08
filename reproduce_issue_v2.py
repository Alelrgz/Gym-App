import urllib.request
import urllib.parse
import json
import uuid

BASE_URL = "http://127.0.0.1:9007"
TRAINER_ID = "trainer_repro_1"

def make_request(method, endpoint, data=None, headers=None):
    url = BASE_URL + endpoint
    if headers is None:
        headers = {}
    headers["x-trainer-id"] = TRAINER_ID
    headers["Content-Type"] = "application/json"
    
    if data:
        data_bytes = json.dumps(data).encode('utf-8')
    else:
        data_bytes = None

    req = urllib.request.Request(url, data=data_bytes, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8')), response.status
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode('utf-8')), e.code
    except Exception as e:
        print(f"Request failed: {e}")
        return None, 0

def run():
    print("--- Reproduction Script (urllib) ---")
    
    # 1. Get initial exercises
    print("\n1. Fetching exercises...")
    exercises, status = make_request("GET", "/api/trainer/exercises")
    if status != 200:
        print(f"Failed to fetch exercises: {status}")
        return
    
    print(f"Found {len(exercises)} exercises.")
    if not exercises:
        print("No exercises found.")
        return

    target_ex = exercises[0]
    print(f"Target Exercise: {target_ex['name']} (ID: {target_ex['id']})")
    
    # 2. Update the exercise
    print("\n2. Updating exercise with video...")
    new_video_id = "test_video_" + str(uuid.uuid4())[:8]
    payload = {
        "name": target_ex["name"],
        "muscle": target_ex["muscle"],
        "type": target_ex["type"],
        "video_id": new_video_id
    }
    
    updated_ex, status = make_request("PUT", f"/api/trainer/exercises/{target_ex['id']}", payload)
    if status == 200:
        print(f"Update successful. New ID: {updated_ex['id']}")
        print(f"New Video ID: {updated_ex['video_id']}")
    else:
        print(f"Update failed: {status} - {updated_ex}")
        return

    # 3. Fetch exercises again
    print("\n3. Fetching exercises again...")
    exercises_after, status = make_request("GET", "/api/trainer/exercises")
    print(f"Found {len(exercises_after)} exercises.")
    
    # 4. Check for duplicates
    matches = [ex for ex in exercises_after if ex['name'] == target_ex['name']]
    print(f"\nFound {len(matches)} exercises with name '{target_ex['name']}':")
    for ex in matches:
        print(f" - ID: {ex['id']}, Video: {ex.get('video_id')}, Owner: {ex.get('owner_id', 'Global')}")

    if len(matches) > 1:
        print("\nISSUE REPRODUCED: Duplicate exercises found.")
    else:
        print("\nIssue not reproduced (no duplicates).")

if __name__ == "__main__":
    run()
