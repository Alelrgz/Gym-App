import requests
import sys

BASE_URL = "http://127.0.0.1:9007"
LOGIN_URL = f"{BASE_URL}/auth/login"

def test_hybrid_login():
    print("--- Testing Hybrid Login ---")
    
    # 1. Test JSON Login (Simulating Mobile)
    print("\n1. Testing JSON Login...")
    payload = {"username": "trainerdev", "password": "password123"}
    headers = {"Content-Type": "application/json"}
    try:
        resp = requests.post(LOGIN_URL, json=payload, headers=headers)
        print(f"Status: {resp.status_code}")
        if resp.status_code == 200 and "access_token" in resp.json():
            print("SUCCESS: JSON Login works!")
            print(f"Token: {resp.json().get('access_token')[:20]}...")
        else:
            print(f"FAILURE: JSON Login failed. Body: {resp.text}")
    except Exception as e:
         print(f"ERROR: {e}")

    # 2. Test Form Login (Simulating Browser)
    print("\n2. Testing Form Login...")
    data = {"username": "trainerdev", "password": "password123"}
    # requests automatically sends 'application/x-www-form-urlencoded' when using 'data='
    try:
        resp = requests.post(LOGIN_URL, data=data, allow_redirects=False)
        print(f"Status: {resp.status_code}")
        
        if resp.status_code == 302:
            print("SUCCESS: Form Login redirects as expected!")
            print(f"Location: {resp.headers.get('Location')}")
            print(f"Cookies: {resp.cookies.get_dict()}")
        else:
            print(f"FAILURE: Form Login did not redirect. Status: {resp.status_code}")
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    test_hybrid_login()
