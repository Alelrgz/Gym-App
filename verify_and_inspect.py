from database import get_db_session, engine
from models_orm import ClientScheduleORM, UserORM, WeeklySplitORM, WorkoutORM
from services import UserService
import uuid
from datetime import date
import json

def verify_and_inspect():
    print(f"DB URL: {engine.url}")
    
    db = get_db_session()
    service = UserService()
    
    try:
        # 1. Create Data
        trainer_id = str(uuid.uuid4())
        client_id = str(uuid.uuid4())
        workout_id = str(uuid.uuid4())
        split_id = str(uuid.uuid4())
        
        # User
        db.add(UserORM(id=client_id, username=f"test_{client_id[:8]}", role="client"))
        
        # Workout
        db.add(WorkoutORM(id=workout_id, title="Test Workout", duration="60", difficulty="Easy", exercises_json="[]", owner_id=trainer_id))
        
        # Split
        schedule = {"Monday": {"id": workout_id, "name": "Test"}}
        db.add(WeeklySplitORM(id=split_id, name="Test Split", description="Desc", days_per_week=7, schedule_json=json.dumps(schedule), owner_id=trainer_id))
        
        db.commit()
        
        # 2. Assign
        print("Assigning...")
        service.assign_split({
            "client_id": client_id,
            "split_id": split_id,
            "start_date": date.today().isoformat()
        }, trainer_id)
        
        # 3. Inspect IMMEDIATELY via DB
        print("Inspecting DB...")
        items = db.query(ClientScheduleORM).filter(ClientScheduleORM.client_id == client_id).all()
        print(f"Found {len(items)} items for client {client_id}")
        for i in items:
            print(f" - {i.date}: {i.title}")
            
        # 4. Verify via Service (Mimic API)
        print("\n--- Verifying via Service Layer ---")
        client_data = service.get_client(client_id)
        print(f"Service returned client: {client_data.name}")
        
        if client_data.calendar:
            print(f"Calendar events count: {len(client_data.calendar.events)}")
            found = False
            for event in client_data.calendar.events:
                print(f" - Event: {event.title}, Date: '{event.date}' (Type: {type(event.date)})")
                if event.date == date.today().isoformat():
                    print(f"   MATCH FOUND!")
                    found = True
            
            if found:
                print("SUCCESS: Event found in Service response.")
            else:
                print("FAILURE: Event NOT found in Service response.")
        else:
            print("FAILURE: No calendar data in Service response.")

    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    verify_and_inspect()
