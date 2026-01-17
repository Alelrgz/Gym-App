import requests
import uuid

BASE_URL = "http://127.0.0.1:9007"
REGISTER_URL = f"{BASE_URL}/auth/register"

def test_register():
    username = f"test_user_{uuid.uuid4().hex[:8]}"
    password = "password123"
    
    print(f"Attempting to register user: {username}")
    
    payload = {
        "username": username,
        "password": password,
        "role": "client"
    }
    
    try:
        # Don't follow redirects automatically to check the 302 status
        response = requests.post(REGISTER_URL, data=payload, allow_redirects=False)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 302:
            print("Success! Redirected to login.")
            print(f"Location: {response.headers.get('Location')}")
        else:
            print("Failed.")
            print(response.text)
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_register()
