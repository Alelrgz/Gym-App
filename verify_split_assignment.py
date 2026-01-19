from services import UserService, get_db_session
from models_orm import UserORM, WeeklySplitORM, ClientScheduleORM
from datetime import date, timedelta
import json

def reproduce_issue():
    db = get_db_session()
    service = UserService()
    
    try:
        # 1. Find Client 'GigaNigga1'
        client = db.query(UserORM).filter(UserORM.username == "GigaNigga1").first()
        if not client:
            print("Client 'GigaNigga1' not found.")
            return
        
        print(f"Found Client: {client.username} ({client.id})")
        
        # 2. Find 'Viagra Split'
        split = None
        splits = db.query(WeeklySplitORM).all()
        for s in splits:
            if "viagra" in s.name.lower():
                split = s
                break
        
        if not split:
            print("'Viagra Split' not found.")
            return
            
        print(f"Found Split: {split.name} ({split.id})")
        
        # 3. Simulate Assignment (starting today)
        today = date.today()
        print(f"Assigning split starting {today}...")
        
        try:
            result = service.assign_split({
                "client_id": client.id,
                "split_id": split.id,
                "start_date": today.isoformat()
            }, trainer_id="any") # Trainer ID check skipped in service for now or not strict
            print("Assignment Result:", result["message"])
        except Exception as e:
            print(f"Assignment Failed: {e}")
            
        # 4. Inspect Schedule for next 7 days
        print("\n--- Schedule Inspection ---")
        for i in range(7):
            day = today + timedelta(days=i)
            events = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == client.id,
                ClientScheduleORM.date == day.isoformat()
            ).all()
            
            print(f"Date: {day} - Found {len(events)} events:")
            for e in events:
                print(f"  - ID: {e.id}, Type: {e.type}, Title: {e.title}, WorkoutID: {e.workout_id}")
                
    finally:
        db.close()

if __name__ == "__main__":
    reproduce_issue()
