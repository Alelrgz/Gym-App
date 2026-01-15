import urllib.request
import urllib.parse
import json
import uuid
import sys

BASE_URL = "http://localhost:9007"

def make_request(url, method="GET", data=None, headers=None):
    if headers is None:
        headers = {}
    
    if data:
        data_bytes = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    else:
        data_bytes = None

    req = urllib.request.Request(url, data=data_bytes, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            return {
                "status": response.status,
                "body": response.read().decode('utf-8')
            }
    except urllib.error.HTTPError as e:
        return {
            "status": e.code,
            "body": e.read().decode('utf-8')
        }
    except Exception as e:
        print(f"Request failed: {e}")
        return None

def run_test():
    username = f"trainer_test_{uuid.uuid4().hex[:8]}"
    password = "password123"
    email = f"{username}@example.com"
    
    print(f"Testing full flow for {username}...")
    
    # 1. Register
    print("1. Registering...")
    payload = {
        "username": username,
        "password": password,
        "email": email,
        "role": "trainer"
    }
    
    resp = make_request(f"{BASE_URL}/api/auth/register", method="POST", data=payload)
    if not resp: return
    
    print(f"Register Status: {resp['status']}")
    print(f"Register Response: {resp['body']}")
    
    if resp['status'] != 200:
        return

    # 2. Login
    print("2. Logging in...")
    # Login expects form data, not JSON? 
    # routes.py: async def login(form_data: OAuth2PasswordRequestForm = Depends()...)
    # OAuth2PasswordRequestForm expects form-urlencoded
    
    login_data = urllib.parse.urlencode({
        "username": username,
        "password": password
    }).encode('utf-8')
    
    req = urllib.request.Request(f"{BASE_URL}/api/auth/login", data=login_data, method="POST")
    # Content-Type is automatically set to application/x-www-form-urlencoded
    
    try:
        with urllib.request.urlopen(req) as response:
            login_resp = {
                "status": response.status,
                "body": response.read().decode('utf-8')
            }
    except urllib.error.HTTPError as e:
        login_resp = {
            "status": e.code,
            "body": e.read().decode('utf-8')
        }
        
    print(f"Login Status: {login_resp['status']}")
    if login_resp['status'] != 200:
        print(f"Login Response: {login_resp['body']}")
        return
        
    token_data = json.loads(login_resp['body'])
    token = token_data.get("access_token")
    print(f"Got Token: {token[:10]}...")

    # 3. Get Trainer Data
    print("3. Fetching Trainer Data...")
    headers = {"Authorization": f"Bearer {token}"}
    
    resp = make_request(f"{BASE_URL}/api/trainer/data", method="GET", headers=headers)
    if not resp: return
    
    print(f"Get Data Status: {resp['status']}")
    print(f"Get Data Response: {resp['body']}")

if __name__ == "__main__":
    run_test()
