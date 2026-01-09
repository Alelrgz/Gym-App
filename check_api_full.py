import sys
import os
from fastapi.testclient import TestClient

# Add project root to path
sys.path.append(os.getcwd())

from main import app

def test_api():
    client = TestClient(app)
    print("Testing /api/trainer/client/user_456...")
    
    try:
        response = client.get("/api/trainer/client/user_456")
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            print("Response JSON:")
            print(response.json())
        else:
            print("Response Text:")
            print(response.text)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_api()
