import sys
import os
from datetime import date

# Add current directory to path
sys.path.append(os.getcwd())

from services import UserService
from database import get_client_session
from models_client_orm import ClientScheduleORM

def check_schedule():
    print("Checking Schedule for Today...")
    client_id = "user_123"
    today_str = date.today().isoformat()
    print(f"Date: {today_str}")
    
    db = get_client_session(client_id)
    try:
        events = db.query(ClientScheduleORM).filter(
            ClientScheduleORM.date == today_str
        ).all()
        
        print(f"Found {len(events)} events for today:")
        for e in events:
            print(f" - ID: {e.id}, Title: {e.title}, Type: {e.type}, WorkoutID: {e.workout_id}")
            
    finally:
        db.close()

if __name__ == "__main__":
    check_schedule()
