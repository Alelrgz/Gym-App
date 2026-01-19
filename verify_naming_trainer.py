from services import UserService, get_db_session
from models_orm import UserORM, ClientProfileORM
import uuid

def verify_naming_trainer_view():
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
        
        # 2. Call get_trainer (simulating dashboard view)
        print("Calling get_trainer...")
        trainer_data = service.get_trainer("trainer_id") # ID doesn't matter for this call
        
        # Find our client
        client_in_list = next((c for c in trainer_data.clients if c.id == user_id), None)
        
        if not client_in_list:
            print("FAIL: Client not found in trainer list")
            return

        print(f"Client Name in Trainer View: '{client_in_list.name}'")
        
        if client_in_list.name == "New User":
            print("FAIL: Name is 'New User'")
        elif client_in_list.name == username:
            print("SUCCESS: Name matches username")
        else:
            print(f"UNKNOWN: Name is '{client_in_list.name}'")
            
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    verify_naming_trainer_view()
