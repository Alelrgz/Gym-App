import requests
import uuid

BASE_URL = "http://localhost:9007"

def verify_data_presence():
    # 1. Register Trainer
    trainer_username = f"trainer_btn_test_{uuid.uuid4().hex[:6]}"
    trainer_password = "password123"
    print(f"Registering trainer: {trainer_username}")
    
    res = requests.post(f"{BASE_URL}/api/auth/register", json={
        "username": trainer_username,
        "password": trainer_password,
        "role": "trainer"
    })
    if res.status_code != 200:
        print(f"Registration failed: {res.text}")
        return
    
    # Login
    res = requests.post(f"{BASE_URL}/api/auth/login", data={
        "username": trainer_username,
        "password": trainer_password
    })
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("Logged in.")

    # 2. Create Dummy Workout & Split
    print("Creating workout...")
    workout_payload = {
        "title": "Button Test Workout",
        "duration": "30 min",
        "difficulty": "Easy",
        "exercises": [{"name": "Jumping Jacks", "sets": 3, "reps": 20, "rest": 30, "video_id": "jj"}]
    }
    requests.post(f"{BASE_URL}/api/trainer/workouts", json=workout_payload, headers=headers)

    print("Creating split...")
    split_payload = {
        "name": "Button Test Split",
        "description": "Testing buttons",
        "days_per_week": 3,
        "schedule": {"Monday": "rest"}
    }
    requests.post(f"{BASE_URL}/api/trainer/splits", json=split_payload, headers=headers)

    # 3. Fetch Data
    print("Fetching trainer data...")
    res = requests.get(f"{BASE_URL}/api/trainer/data", headers=headers)
    data = res.json()
    
    workouts = data.get("workouts", [])
    splits = data.get("splits", [])
    
    print(f"Workouts found: {len(workouts)}")
    print(f"Splits found: {len(splits)}")
    
    if len(workouts) > 0 and len(splits) > 0:
        print("SUCCESS: Data is present for frontend to render.")
    else:
        print("FAILURE: Missing data.")

if __name__ == "__main__":
    verify_data_presence()
