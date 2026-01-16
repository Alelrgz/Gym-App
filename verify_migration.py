import requests
import sys

BASE_URL = "http://localhost:9007"

def test_migration():
    print("Content-Type: text/plain\n")
    print("--- Starting Migration Verification ---")

    # 1. Register User A
    user_a = "user_a_" + str(hash(str(sys.argv)))[-5:]
    pwd = "password123"
    print(f"Registering User A: {user_a}")
    resp_a = requests.post(f"{BASE_URL}/api/auth/register", json={"username": user_a, "password": pwd})
    if resp_a.status_code != 200:
        print(f"FAIL: Register A failed: {resp_a.text}")
        return
    print("PASS: Register User A")

    # Login User A
    resp_login_a = requests.post(f"{BASE_URL}/api/auth/login", data={"username": user_a, "password": pwd}, headers={"Content-Type": "application/x-www-form-urlencoded"})
    token_a = resp_login_a.json().get("access_token")
    if not token_a:
        print(f"FAIL: Login A failed: {resp_login_a.text}")
        return
    headers_a = {"Authorization": f"Bearer {token_a}"}

    # 2. Register User B
    user_b = "user_b_" + str(hash(str(sys.argv)))[-5:]
    print(f"Registering User B: {user_b}")
    resp_b = requests.post(f"{BASE_URL}/api/auth/register", json={"username": user_b, "password": pwd})
    if resp_b.status_code != 200:
        print(f"FAIL: Register B failed: {resp_b.text}")
        return
    print("PASS: Register User B")

    # Login User B
    resp_login_b = requests.post(f"{BASE_URL}/api/auth/login", data={"username": user_b, "password": pwd}, headers={"Content-Type": "application/x-www-form-urlencoded"})
    token_b = resp_login_b.json().get("access_token")
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # 3. User A checks profile
    print("Checking Profile A...")
    # Using headers as this is API
    prof_a = requests.get(f"{BASE_URL}/api/client/data", headers=headers_a)
    if prof_a.status_code != 200:
         print(f"FAIL: Get Profile A failed: {prof_a.status_code} {prof_a.text}")
         return

    print("PASS: Profile A access")
    
    # 4. Data Isolation Check
    prof_b = requests.get(f"{BASE_URL}/api/client/data", headers=headers_b)
    data_b = prof_b.json()
    data_a = prof_a.json()

    print(f"User A Name in DB: {data_a.get('name')}")
    print(f"User B Name in DB: {data_b.get('name')}")
    
    # Update User A's name
    print("Updating User A profile name to 'UniqueUserA'")
    resp_update = requests.put(f"{BASE_URL}/api/client/profile", json={"name": "UniqueUserA"}, headers=headers_a)
    if resp_update.status_code != 200:
        print(f"FAIL: Update A failed: {resp_update.text}")
        return

    # Verify A changed
    prof_a_new = requests.get(f"{BASE_URL}/api/client/data", headers=headers_a).json()
    if prof_a_new.get("name") != "UniqueUserA":
        print(f"FAIL: Name update A failed. Got {prof_a_new.get('name')}")
        return
    print("PASS: User A data updated")

    # Verify B did NOT change
    prof_b_new = requests.get(f"{BASE_URL}/api/client/data", headers=headers_b).json()
    if prof_b_new.get("name") == "UniqueUserA":
        print("FAIL: DATA LEAK! User B sees User A's name!")
        return
    print("PASS: User B data isolated (Name is still original default)")

    print("\n--- MIGRATION SUCCESS: Multi-tenant isolation verified ---")

if __name__ == "__main__":
    try:
        test_migration()
    except Exception as e:
        print(f"ERROR: {e}")
