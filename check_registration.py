import urllib.request
import urllib.error
import json
import uuid

url = "http://127.0.0.1:9007/api/auth/register"

def register(username, email, role="trainer"):
    data = {
        "username": username,
        "password": "password123",
        "email": email,
        "role": role
    }
    print(f"Registering {username} with email '{email}'...")
    try:
        req = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req) as response:
            print(f"Success: {response.getcode()}")
            print(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code}")
        print(e.read().decode('utf-8'))
    except Exception as e:
        print(f"Error: {e}")

# 1. Register first user with empty email
u1 = f"user_{uuid.uuid4().hex[:8]}"
register(u1, "")

# 2. Register second user with empty email
u2 = f"user_{uuid.uuid4().hex[:8]}"
register(u2, "")
