from services import UserService, get_db_session
from models_orm import UserORM, WeeklySplitORM, ClientScheduleORM
from datetime import date, timedelta
import json

def reproduce_conflict():
    db = get_db_session()
    service = UserService()
    
    try:
        # 1. Setup Client
        client = db.query(UserORM).filter(UserORM.username == "GigaNigga1").first()
        if not client:
            print("Client not found")
            return
            
        today = date.today().isoformat()
        
        # 2. Clear existing for today
        db.query(ClientScheduleORM).filter(
            ClientScheduleORM.client_id == client.id,
            ClientScheduleORM.date == today
        ).delete()
        db.commit()
        
        # 3. Create a "Rest" event
        rest_event = ClientScheduleORM(
            client_id=client.id,
            date=today,
            title="Rest Day",
            type="rest",
            completed=False
        )
        db.add(rest_event)
        db.commit()
        print(f"Created 'Rest' event for {today}")
        
        # 4. Assign Workout (Simulate Split Assignment)
        # We need a valid workout ID. Let's use the one from Viagra Split or find one.
        workout = db.query(WeeklySplitORM).filter(WeeklySplitORM.name.like("%Viagra%")).first()
        if workout:
            schedule = json.loads(workout.schedule_json)
            # Assuming Monday has a workout
            workout_id = schedule["Monday"]["id"]
        else:
            print("Viagra split not found, cannot get workout ID")
            return

        print(f"Assigning workout {workout_id} to {today}...")
        service.assign_workout({
            "client_id": client.id,
            "workout_id": workout_id,
            "date": today
        })
        
        # 5. Verify Result
        events = db.query(ClientScheduleORM).filter(
            ClientScheduleORM.client_id == client.id,
            ClientScheduleORM.date == today
        ).all()
        
        print(f"Found {len(events)} events for {today}:")
        for e in events:
            print(f"  - Type: {e.type}, Title: {e.title}")
            
        if len(events) > 1:
            print("FAIL: Duplicate events found! Conflict confirmed.")
        elif len(events) == 1 and events[0].type == "workout":
            print("SUCCESS: Only workout event remains.")
        else:
            print("UNKNOWN STATE")

    finally:
        db.close()

if __name__ == "__main__":
    reproduce_conflict()
