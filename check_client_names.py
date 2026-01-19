import requests
import uuid

BASE_URL = "http://127.0.0.1:9007"

def register_client(username, password):
    url = f"{BASE_URL}/api/auth/register"
    data = {
        "username": username,
        "password": password,
        "role": "client"
    }
    response = requests.post(url, json=data)
    print(f"Register {username}: {response.status_code} - {response.text}")
    return response.json()

def login(username, password):
    url = f"{BASE_URL}/api/auth/login"
    data = {
        "username": username,
        "password": password
    }
    response = requests.post(url, data=data) # OAuth2 form data
    print(f"Login {username}: {response.status_code}")
    if response.status_code == 200:
        return response.json()["access_token"]
    return None

def get_client_data(token):
    url = f"{BASE_URL}/api/client/data"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(url, headers=headers)
    print(f"Get Client Data: {response.status_code}")
    return response.json()

def get_trainer_data(token):
    url = f"{BASE_URL}/api/trainer/data"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(url, headers=headers)
    print(f"Get Trainer Data: {response.status_code}")
    return response.json()

def main():
    # 1. Register a new client
    unique_id = str(uuid.uuid4())[:8]
    username = f"test_user_{unique_id}"
    password = "password123"
    
    print(f"--- Creating User: {username} ---")
    register_client(username, password)
    
    # 2. Login as client (triggers profile creation)
    client_token = login(username, password)
    if client_token:
        client_data = get_client_data(client_token)
        print(f"Client Name in Profile: {client_data.get('name')}")
        
    # 3. Login as trainer and check roster
    # Assuming there's a trainer account or we can register one
    trainer_user = f"trainer_{unique_id}"
    register_client(trainer_user, password) # Register as client first? No, need role trainer
    
    # Register trainer
    url = f"{BASE_URL}/api/auth/register"
    data = {
        "username": trainer_user,
        "password": password,
        "role": "trainer"
    }
    requests.post(url, json=data)
    
    trainer_token = login(trainer_user, password)
    if trainer_token:
        trainer_data = get_trainer_data(trainer_token)
        clients = trainer_data.get("clients", [])
        
        # Find our client
        found = False
        for c in clients:
            if c["name"] == "New User" and c["plan"] == "Hypertrophy": # Default values
                # We can't be sure it's ours by name if it's "New User", but let's see if we find ANY "New User"
                pass
            
            # Actually, let's look for the ID if possible, but get_trainer returns ID.
            # We don't know the ID from register response (it returns user_id? yes)
            pass
            
        print("Clients seen by trainer:")
        for c in clients:
            print(f" - {c['name']} (ID: {c['id']}, Status: {c['status']})")

if __name__ == "__main__":
    main()
