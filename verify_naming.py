from services import UserService, get_db_session
from models_orm import UserORM, ClientProfileORM
import uuid

def repro_naming():
    db = get_db_session()
    service = UserService()
    
    # 1. Register New User
    username = f"TestUser_{uuid.uuid4().hex[:6]}"
    print(f"Registering user: {username}")
    
    try:
        # Simulate registration
        user_id = str(uuid.uuid4())
        user = UserORM(
            id=user_id,
            username=username,
            role="client",
            hashed_password="hash"
        )
        db.add(user)
        db.commit()
        
        print(f"User created with ID: {user_id}")
        
        # 2. Call get_client (triggers seeding)
        print("Calling get_client...")
        client_data = service.get_client(user_id)
        
        print(f"Client Name: '{client_data.name}'")
        
        if client_data.name == "New User":
            print("FAIL: Name is 'New User'")
        elif client_data.name == username:
            print("SUCCESS: Name matches username")
        else:
            print(f"UNKNOWN: Name is '{client_data.name}'")
            
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    repro_naming()
