from services import UserService
from database import get_db_session
from models_orm import UserORM, ClientScheduleORM, WeeklySplitORM
from sqlalchemy import desc

def inspect_recent():
    db = get_db_session()
    try:
        print("--- MOST RECENT SCHEDULE ITEMS (Last 20) ---")
        # Order by ID desc (assuming auto-increment ID implies recency)
        items = db.query(ClientScheduleORM).order_by(desc(ClientScheduleORM.id)).limit(20).all()
        
        if not items:
            print("No schedule items found.")
            
        for i in items:
            print(f"ID: {i.id} | Client: {i.client_id} | Date: {i.date} | Title: {i.title} | WorkoutID: {i.workout_id}")
            
        print("\n--- CLIENTS ---")
        clients = db.query(UserORM).filter(UserORM.role == "client").all()
        for c in clients:
             print(f"Client ID: {c.id} | Username: {c.username}")

    finally:
        db.close()

if __name__ == "__main__":
    inspect_recent()
