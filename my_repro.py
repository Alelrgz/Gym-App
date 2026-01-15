import urllib.request
import urllib.error
import json
import uuid

BASE_URL = "http://localhost:9007"

def test_trainer_flow():
    username = f"trainer_{uuid.uuid4().hex[:8]}"
    password = "password123"
    email = f"{username}@example.com"
    
    # 1. Register
    print(f"Registering {username}...")
    reg_data = {
        "username": username,
        "password": password,
        "email": email,
        "role": "trainer"
    }
    try:
        req = urllib.request.Request(
            f"{BASE_URL}/api/auth/register",
            data=json.dumps(reg_data).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req) as response:
            print(f"Registration successful: {response.getcode()}")
            print(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f"Registration failed: {e.code}")
        print(e.read().decode('utf-8'))
        return
    except Exception as e:
        print(f"Registration exception: {e}")
        return

    # 2. Login
    print("Logging in...")
    # Login expects form data, not JSON
    login_data = urllib.parse.urlencode({
        "username": username,
        "password": password
    }).encode('utf-8')
    
    try:
        req = urllib.request.Request(
            f"{BASE_URL}/api/auth/login",
            data=login_data,
            headers={'Content-Type': 'application/x-www-form-urlencoded'}
        )
        with urllib.request.urlopen(req) as response:
            resp_json = json.loads(response.read().decode('utf-8'))
            token = resp_json.get("access_token")
            print("Login successful, token received.")
    except urllib.error.HTTPError as e:
        print(f"Login failed: {e.code}")
        print(e.read().decode('utf-8'))
        return
    except Exception as e:
        print(f"Login exception: {e}")
        return

    # 3. Fetch Trainer Data
    print("Fetching trainer data...")
    try:
        req = urllib.request.Request(
            f"{BASE_URL}/api/trainer/data",
            headers={'Authorization': f"Bearer {token}"}
        )
        with urllib.request.urlopen(req) as response:
            print(f"Trainer Data Status: {response.getcode()}")
            print("Trainer data fetched successfully.")
    except urllib.error.HTTPError as e:
        print(f"Trainer Data Failed: {e.code}")
        print(e.read().decode('utf-8'))
        if e.code == 500:
            print("Reproduced 500 error on /api/trainer/data!")
    except Exception as e:
        print(f"Fetch exception: {e}")

if __name__ == "__main__":
    test_trainer_flow()
