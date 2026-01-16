import requests
import re
import sys

BASE_URL = "http://127.0.0.1:9007"
LOGIN_URL = f"{BASE_URL}/auth/login"
ROOT_URL = f"{BASE_URL}/"

import random
import string

RANDOM_SUFFIX = ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
USERNAME = f"trainer_verify_{RANDOM_SUFFIX}"
PASSWORD = "test_password"
REGISTER_URL = f"{BASE_URL}/auth/register"

def verify_trainer_flow():
    print(f"--- Verifying Trainer Flow for user: {USERNAME} ---")
    
    session = requests.Session()
    
    # 0. Register
    print(f"0. Registering user at {REGISTER_URL}...")
    try:
        reg_payload = {
            "username": USERNAME,
            "password": PASSWORD,
            "role": "trainer"
        }
        r = session.post(REGISTER_URL, data=reg_payload)
        print(f"   Status Code: {r.status_code}")
        # Registration redirects to login (often with ?registered=true)
        # We don't strictly need to check success here as login will fail if reg failed.
        # But good to know.
        if r.status_code != 200:
             print("   WARNING: Registration might have failed (non-200).")
        else:
             print("   Registration request completed.")
             
    except Exception as e:
        print(f"   FATAL: Could not register: {e}")
        return False
    
    # 1. Login
    print(f"1. Attempting login at {LOGIN_URL}...")
    try:
        login_payload = {
            "username": USERNAME,
            "password": PASSWORD
        }
        # Note: simple_auth often expects form data
        r = session.post(LOGIN_URL, data=login_payload)
        print(f"   Status Code: {r.status_code}")
        
        if r.status_code != 200:
            print("   FAILURE: Login request returned non-200 status.")
            return False
            
        if "/auth/login" in r.url:
             print("   FAILURE: Login failed (Still on login page).")
             if "Invalid username or password" in r.text:
                 print("   Reason: Invalid credentials.")
             return False

        print("   Login successful (Redirected to app).")
        
    except Exception as e:
        print(f"   FATAL: Could not connect or login: {e}")
        return False

    # 2. Access Root
    print(f"2. Accessing Root URL {ROOT_URL}...")
    try:
        r = session.get(ROOT_URL)
        print(f"   Status Code: {r.status_code}")
        print(f"   Current URL: {r.url}")
        print(f"   Session Cookies: {session.cookies.get_dict()}")
        
        if "/auth/login" in r.url:
            print("   FAILURE: Redirected to login page (Session/Cookie lost?).")
            return False
        
        if r.status_code != 200:
            print("   FAILURE: Root access failed or redirected unexpectedly.")
            # Check if we were redirected back to login
            if "/auth/login" in r.url:
                print("   Redirected to Login - Auth State not persisted?")
            return False
            
        content = r.text
        
        # 3. Check for injected APP_CONFIG
        print("3. Checking for APP_CONFIG injection...")
        
        # Look for the simpler 'token' pattern first as per the plan
        # window.APP_CONFIG = { ... token: "..." ... }
        
        if 'window.APP_CONFIG' not in content:
            print("   FAILURE: window.APP_CONFIG not found in response.")
            return False
            
        # Check specific values
        # Simple string checks for robustness vs regex complexity
        token_match = re.search(r'token:\s*"([^"]+)"', content)
        role_match = re.search(r'role:\s*"([^"]+)"', content)
        
        if not token_match:
            print("   FAILURE: 'token' not found in APP_CONFIG.")
            # Debug: find the app config block
            match = re.search(r'window\.APP_CONFIG\s*=\s*{([^}]+)}', content, re.DOTALL)
            if match:
                print(f"   DEBUG: Check APP_CONFIG content:\n{match.group(1)}")
            else:
                print("   DEBUG: regex could not isolate APP_CONFIG block.")
        else:
            token_val = token_match.group(1)
            if len(token_val) > 10 and token_val != "None":
                 print(f"   SUCCESS: Token found in HTML: {token_val[:10]}...")
            else:
                 print(f"   FAILURE: Token appears invalid or empty: '{token_val}'")

        if not role_match:
            print("   FAILURE: 'role' not found in APP_CONFIG.")
        else:
            role_val = role_match.group(1)
            print(f"   Found Role: {role_val}")
            if role_val == "trainer":
                print("   SUCCESS: Role is correctly 'trainer'.")
            else:
                print(f"   FAILURE: Role mismatch. Expected 'trainer', got '{role_val}'.")

        # 4. Check for Template Specifics
        # Trainer dashboard usually has specific visible elements
        if "Trainer Dashboard" in content or "client-list" in content:
             print("   SUCCESS: found trainer specific content (Trainer Dashboard text or client-list id).")
        else:
             print("   WARNING: Could not identify Trainer Dashboard specific content. Check template.")

    except Exception as e:
        print(f"   FATAL: Error accessing root: {e}")
        return False
        
    return True

if __name__ == "__main__":
    success = verify_trainer_flow()
    if not success:
        sys.exit(1)
