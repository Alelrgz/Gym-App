import requests

def verify_login():
    url = "http://127.0.0.1:9007/auth/login"
    
    # 1. Check GET (should return HTML)
    try:
        r = requests.get(url)
        print(f"GET {url}: {r.status_code}")
        if "Login - Iron Gym" in r.text:
            print("SUCCESS: Login page loaded.")
        else:
            print("FAILURE: Login page content mismatch.")
    except Exception as e:
        print(f"FAILURE: Could not connect to {url}: {e}")
        return

    # 2. Check POST (should fail with invalid credentials but return HTML, or redirect on success)
    # We don't valid credentials handy maybe, checking invalid first
    data = {"username": "wrong_user", "password": "wrong_password"}
    r = requests.post(url, data=data)
    print(f"POST {url} (Invalid): {r.status_code}")
    if "Invalid username or password" in r.text:
        print("SUCCESS: correctly rejected invalid credentials.")
    else:
        print("FAILURE: Did not see error message.")

if __name__ == "__main__":
    verify_login()
