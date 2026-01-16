import requests
import sys

BASE_URL = "http://127.0.0.1:9007"
SESSION = requests.Session()

def test_auth():
    print(f"Testing Auth on {BASE_URL}...")
    
    # 1. Access protected route without login
    try:
        resp = SESSION.get(BASE_URL + "/", allow_redirects=False)
        if resp.status_code == 307 or resp.status_code == 302:
            print("PASS: Redirected when not logged in.")
        else:
            print(f"FAIL: Expected redirect (302/307), got {resp.status_code}")
            # If it returns 200, maybe it's the login page being rendered directly?
            # My code does `RedirectResponse("/auth/login")`.
            # Note: RedirectResponse is 307 by default unless specified differently, I used 302 or default?
            # I used `RedirectResponse("/auth/login")` without status code in main.py, default is 307 Temporary Redirect.
            pass
    except Exception as e:
        print(f"FAIL: Connection error: {e}")
        return

    # 2. Register
    username = "test_user_v1"
    password = "password123"
    print(f"Registering user {username}...")
    resp = SESSION.post(f"{BASE_URL}/auth/register", data={"username": username, "password": password, "role": "client"}, allow_redirects=False)
    
    # Register redirects to login (302)
    if resp.status_code == 302:
         print("PASS: Registration successful (Redirected).")
    elif resp.status_code == 200 and "Username already taken" in resp.text:
         print("WARN: User already exists. Proceeding to login.")
    else:
         print(f"FAIL: Registration failed. Status: {resp.status_code}, Content: {resp.text[:100]}")

    # 3. Login
    print(f"Logging in user {username}...")
    resp = SESSION.post(f"{BASE_URL}/auth/login", data={"username": username, "password": password}, allow_redirects=False)
    
    if resp.status_code == 302:
        print("PASS: Login successful (Redirected).")
        # Check cookies
        if "access_token" in resp.cookies:
            print("PASS: access_token cookie set.")
        else:
            print("FAIL: No access_token cookie found.")
            # Requests Session automatically handles cookies, so subsequent requests should work.
    else:
        print(f"FAIL: Login failed. Status: {resp.status_code}, Content: {resp.text[:100]}")
        return

    # 4. Access protected route WITH login
    print("Accessing protected route with cookie...")
    resp = SESSION.get(BASE_URL + "/", allow_redirects=False)
    
    if resp.status_code == 200:
        print("PASS: Access granted to protected route.")
    else:
        # Check if redirected again
        if resp.status_code in [302, 307]:
             print(f"FAIL: Redirected again (Cookie not working?). Location: {resp.headers.get('Location')}")
        else:
             print(f"FAIL: Unexpected status {resp.status_code}")

if __name__ == "__main__":
    test_auth()
