import requests
import sys

# 1. Login as trainer to get token
BASE_URL = "http://localhost:9007"
LOGIN_URL = f"{BASE_URL}/auth/login"
CLIENTS_URL = f"{BASE_URL}/api/trainer/clients"

def check_endpoint():
    # Login
    session = requests.Session()
    # We need a valid trainer. 'trainer' / 'password' is created by seed_users.py or create_trainer_user.py
    # Let's try to login
    try:
        login_payload = {"username": "trainer", "password": "password"}
        resp = session.post(LOGIN_URL, data=login_payload)
        
        # Check if login successful (might be redirect or JSON depending on implementation)
        # The app uses cookies for auth usually, or JWT in headers?
        # The JS uses 'x-trainer-id' header? No, it uses cookies for auth but passes x-trainer-id for context?
        # Wait, app.js says: headers: { 'x-trainer-id': trainerId }
        # But the backend depends on get_current_user which uses token from cookie.
        
        if resp.status_code != 200:
            print(f"Login failed: {resp.status_code}")
            # Try to register a temp trainer if login fails?
            # Assuming 'trainer' exists.
            return

        print("Login successful")
        
        # Get cookies
        cookies = session.cookies.get_dict()
        
        # Call clients endpoint
        # We need to know the trainer ID. 
        # In the app, getCurrentTrainerId() gets it from somewhere.
        # Let's assume the user is the trainer.
        
        # We need to pass x-trainer-id header?
        # The route:
        # @router.get("/api/trainer/clients")
        # async def get_trainer_clients(service: UserService = Depends(get_user_service), current_user: UserORM = Depends(get_current_user)):
        #     data = service.get_trainer(current_user.id)
        #     return data.clients
        
        # It uses current_user.id. It doesn't use the header. The header is extra in JS.
        
        resp = session.get(CLIENTS_URL)
        
        if resp.status_code == 200:
            print("Clients Endpoint Response:")
            print(resp.json())
        else:
            print(f"Clients Endpoint Failed: {resp.status_code}")
            print(resp.text)

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_endpoint()
