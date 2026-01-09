import urllib.request
import urllib.parse
import json
import sys

BASE_URL = "http://127.0.0.1:8000"

def get(url):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())

def post(url, data):
    data = json.dumps(data).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())

def test_flow():
    print("--- Testing Workout Assignment Flow (urllib) ---")
    client_id = "user_456"

    # 1. Fetch
    print(f"\n1. Fetching data for {client_id}...")
    try:
        data = get(f"{BASE_URL}/api/trainer/client/{client_id}")
        print(f"   SUCCESS: Fetched data for {data['name']}")
    except Exception as e:
        print(f"   FAILURE: {e}")
        return

    # 2. Assign
    print(f"\n2. Assigning Workout to {client_id}...")
    payload = {"client_id": client_id, "workout_id": "w1", "date": "2026-02-01"}
    try:
        res = post(f"{BASE_URL}/api/trainer/assign_workout", payload)
        print(f"   SUCCESS: {res}")
    except Exception as e:
        print(f"   FAILURE: {e}")
        return

    # 3. Verify
    print(f"\n3. Verifying...")
    try:
        data = get(f"{BASE_URL}/api/trainer/client/{client_id}")
        found = any(e['date'] == "2026-02-01" for e in data['calendar']['events'])
        if found:
            print("   SUCCESS: Verified!")
        else:
            print("   FAILURE: Not found")
    except Exception as e:
        print(f"   FAILURE: {e}")

if __name__ == "__main__":
    test_flow()
