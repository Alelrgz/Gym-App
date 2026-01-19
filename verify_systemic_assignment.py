from services import UserService, get_db_session
from models_orm import UserORM, ClientProfileORM, WeeklySplitORM, ClientScheduleORM
from datetime import date
import uuid

def test_new_client_assignment():
    db = get_db_session()
    service = UserService()
    
    new_username = f"TestClient_{uuid.uuid4().hex[:8]}"
    print(f"Creating new client: {new_username}")
    
    try:
        # 1. Create User
        user = UserORM(
            id=str(uuid.uuid4()),
            username=new_username,
            role="client",
            hashed_password="fake_hash"
        )
        db.add(user)
        
        # 2. Create Profile (mimic registration/first login)
        profile = ClientProfileORM(
            id=user.id,
            name=new_username,
            status="Active",
            plan="Standard"
        )
        db.add(profile)
        db.commit()
        
        print(f"Client created with ID: {user.id}")
        
        # 3. Find Split
        split = db.query(WeeklySplitORM).filter(WeeklySplitORM.name.like("%Viagra%")).first()
        if not split:
            print("Viagra split not found!")
            return

        print(f"Assigning split '{split.name}'...")
        
        # 4. Assign
        result = service.assign_split({
            "client_id": user.id,
            "split_id": split.id,
            "start_date": date.today().isoformat()
        }, trainer_id="system_test")
        
        print("Assignment Result:", result["message"])
        
        # 5. Verify
        events = db.query(ClientScheduleORM).filter(
            ClientScheduleORM.client_id == user.id
        ).all()
        
        print(f"Found {len(events)} events for new client.")
        if len(events) > 0:
            print("SUCCESS: Events created.")
            # Check first event
            print(f"Sample Event: {events[0].date} - {events[0].title}")
        else:
            print("FAIL: No events created.")

    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    test_new_client_assignment()
