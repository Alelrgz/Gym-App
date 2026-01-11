import requests
import json

BASE_URL = "http://127.0.0.1:9007"

def test_assign_split_error():
    print("Testing assign_split with missing date...")
    
    # payload with missing date
    payload = {
        "client_id": "client_sarah", 
        "split_id": "split_1", 
        "start_date": "" # Empty date
    }
    
    try:
        res = requests.post(f"{BASE_URL}/api/trainer/assign_split", json=payload, headers={"x-trainer-id": "trainer_default"})
        print(f"Status: {res.status_code}")
        print(f"Response: {res.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_assign_split_error()
