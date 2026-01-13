import requests
import json

BASE_URL = "http://localhost:9007"

# Test 1: Get all splits
print("Testing GET /api/trainer/splits...")
response = requests.get(
    f"{BASE_URL}/api/trainer/splits",
    headers={"x-trainer-id": "trainer_default"}
)
print(f"Status: {response.status_code}")
print(f"Response: {response.text}\n")

if response.status_code == 200:
    splits = response.json()
    print(f"Found {len(splits)} splits\n")
    
    if splits:
        # Test 2: Update an existing split
        split_id = splits[0]['id']
        print(f"Testing PUT /api/trainer/splits/{split_id}...")
        update_response = requests.put(
            f"{BASE_URL}/api/trainer/splits/{split_id}",
            headers={
                "x-trainer-id": "trainer_default",
                "Content-Type": "application/json"
            },
            json={
                "name": "Updated Split Name",
                "description": "Updated description",
                "days_per_week": 7,
                "schedule": {"Monday": "some-workout-id"}
            }
        )
        print(f"Status: {update_response.status_code}")
        print(f"Response: {update_response.text}\n")
else:
    print("Could not fetch splits to test update")

# Test 3: Try to update a non-existent split
print("Testing PUT /api/trainer/splits/nonexistent...")
response = requests.put(
    f"{BASE_URL}/api/trainer/splits/nonexistent",
    headers={
        "x-trainer-id": "trainer_default",
        "Content-Type": "application/json"
    },
    json={
        "name": "Test Split",
        "description": "Test",
        "days_per_week": 7,
        "schedule": {}
    }
)
print(f"Status: {response.status_code}")
print(f"Response: {response.text}")
