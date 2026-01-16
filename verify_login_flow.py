import requests
import sys
import uuid

BASE_URL = "http://127.0.0.1:9007"
SESSION = requests.Session()

def test_login_flow():
    print(f"Testing access to {BASE_URL}...")
    try:
        # 1. Request root, expect redirect to /auth/login
        response = SESSION.get(BASE_URL, allow_redirects=False)
        print(f"Root / response code: {response.status_code}")
        
        if response.status_code in [302, 307]:
            location = response.headers.get('Location', '')
            print(f"Redirect location: {location}")
            if "/auth/login" in location:
                print("PASS: Root redirects to login.")
            else:
                print(f"FAIL: Root redirects to {location}")
        elif response.status_code == 200:
            print("FAIL: Root returned 200 OK (User might be already logged in or auth missing).")
            print("Headers:", response.headers)
            print("Content:", response.text[:500])
        else:
            print(f"FAIL: Root returned {response.status_code}")

        # 2. Request login page directly
        login_url = f"{BASE_URL}/auth/login"
        print(f"\nTesting access to {login_url}...")
        response = SESSION.get(login_url)
        print(f"Login page response code: {response.status_code}")
        
        if response.status_code == 200:
            if "Sign In" in response.text or "Welcome Back" in response.text:
                print("PASS: Login page loaded and contains expected text.")
            else:
                print("FAIL: Login page loaded but missing expected text.")
                print("Content preview:", response.text[:200])
        else:
            print(f"FAIL: Login page returned {response.status_code}")
            return

        # 3. Test Invalid Login
        print(f"\nTesting invalid login...")
        login_data = {"username": "invalid_user", "password": "wrong_password"}
        response = SESSION.post(login_url, data=login_data)
        if response.status_code == 200 and ("Invalid credentials" in response.text or "error" in response.text.lower()):
            print("PASS: Invalid login handled correctly.")
        else:
            print(f"FAIL: Invalid login response unexpected. Code: {response.status_code}")

        # 4. Register a Test User (if needed) and Login
        test_username = f"test_user_{uuid.uuid4().hex[:6]}"
        test_password = "password123"
        print(f"\nRegistering test user: {test_username}...")
        
        register_url = f"{BASE_URL}/auth/register"
        reg_data = {"username": test_username, "password": test_password, "role": "client"}
        # Note: Depending on implementation, register might redirect to login
        response = SESSION.post(register_url, data=reg_data, allow_redirects=True)
        
        if response.status_code == 200:
             print("Registration request completed (200).")
        else:
             print(f"Registration status: {response.status_code}")

        # 5. Test Valid Login
        print(f"\nTesting valid login for {test_username}...")
        login_data = {"username": test_username, "password": test_password}
        response = SESSION.post(login_url, data=login_data, allow_redirects=False)
        
        if response.status_code == 302:
            print("PASS: Valid login redirects.")
            if "access_token" in response.cookies or "access_token" in SESSION.cookies:
                 print("PASS: Access token cookie set.")
            else:
                 print("FAIL: Access token cookie MISSING.")
        else:
            print(f"FAIL: Valid login did not redirect. Code: {response.status_code}")
            print(response.text[:500])

    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    test_login_flow()
