import urllib.request
import json
import urllib.error

def register(username, password, email):
    url = "http://127.0.0.1:9007/api/auth/register"
    payload = {
        "username": username,
        "password": password,
        "email": email,
        "role": "trainer"
    }
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
    
    try:
        with urllib.request.urlopen(req) as response:
            print(f"Success: {response.status}")
            print(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f"Error {e.code}: {e.reason}")
        print(e.read().decode('utf-8'))
    except Exception as e:
        print(f"Exception: {e}")

register("user_urllib_1", "pass", "")
