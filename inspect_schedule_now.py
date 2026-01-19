from services import get_db_session
from models_orm import UserORM, ClientScheduleORM
from datetime import date, timedelta

def inspect_now():
    db = get_db_session()
    try:
        # 1. Find Client
        client = db.query(UserORM).filter(UserORM.username == "GigaNigga1").first()
        if not client:
            print("Client 'GigaNigga1' not found.")
            return

        print(f"Client: {client.username} ({client.id})")
        
        # 2. Check Schedule for +/- 3 days from today
        today = date.today()
        start = today - timedelta(days=3)
        end = today + timedelta(days=7)
        
        print(f"Checking schedule from {start} to {end}...")
        
        events = db.query(ClientScheduleORM).filter(
            ClientScheduleORM.client_id == client.id,
            ClientScheduleORM.date >= start.isoformat(),
            ClientScheduleORM.date <= end.isoformat()
        ).order_by(ClientScheduleORM.date).all()
        
        if not events:
            print("No events found in this range.")
        else:
            for e in events:
                print(f"[{e.date}] Type: {e.type}, Title: {e.title}, Completed: {e.completed}, WorkoutID: {e.workout_id}")

    finally:
        db.close()

if __name__ == "__main__":
    inspect_now()
