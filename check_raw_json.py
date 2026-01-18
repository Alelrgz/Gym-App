import requests
from auth import create_access_token
import json
from database import SessionLocal
from models_orm import UserORM

def check_raw_api():
    # 1. Generate Token for a Trainer
    db = SessionLocal()
    trainer = db.query(UserORM).filter(UserORM.role == "trainer").first()
    db.close()
    
    if not trainer:
        print("No trainer found.")
        return

    token = create_access_token({"sub": trainer.username, "role": "trainer"})
    headers = {"Authorization": f"Bearer {token}"}
    
    # 2. Fetch Data assuming server is on port 9007
    url = "http://127.0.0.1:9007/api/trainer/data"
    print(f"Fetching from {url}...")
    
    try:
        res = requests.get(url, headers=headers)
        if res.status_code != 200:
            print(f"Error: {res.status_code} - {res.text}")
            return
            
        data = res.json()
        clients = data.get("clients", [])
        
        print(f"\nFound {len(clients)} clients.")
        
        found_xax = False
        for c in clients:
            if c.get("name") == "xax":
                found_xax = True
                print(f"\n--- CLIENT MATCH: {c.get('name')} ---")
                print(json.dumps(c, indent=2))
                
        if not found_xax:
            print("Client 'xax' not found in response.")
            
    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    check_raw_api()
