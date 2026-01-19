
import requests
import json
import uuid

BASE_URL = "http://127.0.0.1:9007"

def test_split_isolation():
    # 1. Login/Create Trainer
    trainer_id = "test_trainer_" + str(uuid.uuid4())
    # We can use the existing 'trainer_default' if auth is disabled or mocked, 
    # but let's try to simulate a real scenario.
    # Actually, the app allows auth bypass or simple auth.
    # Let's assume we can hit the endpoints if we provide a valid trainer ID header.
    
    headers = {
        "x-trainer-id": trainer_id,
        "Content-Type": "application/json"
    }

    # 2. Create Split A
    print("Creating Split A...")
    split_a_data = {
        "name": "Split A",
        "description": "First split",
        "schedule": [] 
    }
    response = requests.post(f"{BASE_URL}/api/trainer/splits", json=split_a_data, headers=headers)
    if response.status_code != 200:
        print(f"Failed to create Split A: {response.text}")
        return
    split_a_id = response.json()["id"]
    print(f"Split A created: {split_a_id}")

    # 3. Create Split B
    print("Creating Split B...")
    split_b_data = {
        "name": "Split B",
        "description": "Second split",
        "schedule": []
    }
    response = requests.post(f"{BASE_URL}/api/trainer/splits", json=split_b_data, headers=headers)
    if response.status_code != 200:
        print(f"Failed to create Split B: {response.text}")
        return
    split_b_id = response.json()["id"]
    print(f"Split B created: {split_b_id}")

    # 4. Modify Split A (Add workout to Monday)
    print("Modifying Split A...")
    # Get a workout ID first
    workouts_res = requests.get(f"{BASE_URL}/api/trainer/workouts", headers=headers)
    workouts = workouts_res.json()
    if not workouts:
        print("No workouts found to assign.")
        return
    workout_id = workouts[0]["id"]
    
    update_data = {
        "name": "Split A Modified",
        "schedule": [
            {"day": "Monday", "workout_id": workout_id}
        ]
    }
    response = requests.put(f"{BASE_URL}/api/trainer/splits/{split_a_id}", json=update_data, headers=headers)
    if response.status_code != 200:
        print(f"Failed to update Split A: {response.text}")
        return
    print("Split A updated.")

    # 5. Check Split B
    print("Checking Split B...")
    response = requests.get(f"{BASE_URL}/api/trainer/splits", headers=headers)
    splits = response.json()
    
    split_b = next((s for s in splits if s["id"] == split_b_id), None)
    split_a = next((s for s in splits if s["id"] == split_a_id), None)
    
    print("\n--- RESULTS ---")
    print(f"Split A Schedule: {split_a['schedule']}")
    print(f"Split B Schedule: {split_b['schedule']}")
    
    if len(split_b['schedule']) > 0:
        print("\nFAILURE: Split B has items! It should be empty.")
    else:
        print("\nSUCCESS: Split B is empty.")

if __name__ == "__main__":
    test_split_isolation()
