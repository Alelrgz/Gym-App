import requests
import json

BASE_URL = "http://127.0.0.1:9007"

def test_get_splits():
    print("Testing GET /api/trainer/splits...")
    try:
        res = requests.get(f"{BASE_URL}/api/trainer/splits", headers={"x-trainer-id": "trainer_default"})
        if res.status_code == 200:
            print("SUCCESS: Fetched splits")
            print(res.json())
        else:
            print(f"FAILURE: Status {res.status_code}")
            print(res.text)
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    test_get_splits()
