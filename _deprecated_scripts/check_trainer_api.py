import sys
import os
from fastapi.testclient import TestClient

# Add project root to path
sys.path.append(os.getcwd())

from main import app

def check_trainer_api():
    client = TestClient(app)
    print("Testing /api/trainer/data...")
    
    try:
        response = client.get("/api/trainer/data")
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"Clients found: {len(data['clients'])}")
            if len(data['clients']) > 0:
                print(f"First client: {data['clients'][0]}")
                if 'id' in data['clients'][0]:
                    print("SUCCESS: 'id' field is present in API response.")
                else:
                    print("FAIL: 'id' field is MISSING in API response.")
        else:
            print("Response Text:")
            print(response.text)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_trainer_api()
