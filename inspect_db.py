from services import UserService
from database import get_db_session
from models_orm import UserORM, ClientScheduleORM, WeeklySplitORM

def inspect_db():
    db = get_db_session()
    try:
        print("--- USERS ---")
        users = db.query(UserORM).all()
        for u in users:
            print(f"ID: {u.id} | User: {u.username} | Role: {u.role}")
            
        print("\n--- SCHEDULE ITEMS ---")
        items = db.query(ClientScheduleORM).all()
        if not items:
            print("No schedule items found.")
        for i in items:
            print(f"Client: {i.client_id} | Date: {i.date} | Title: {i.title} | WorkoutID: {i.workout_id}")
            
        print("\n--- SPLITS ---")
        splits = db.query(WeeklySplitORM).all()
        for s in splits:
            print(f"ID: {s.id} | Name: {s.name} | Owner: {s.owner_id}")
            
    finally:
        db.close()

if __name__ == "__main__":
    inspect_db()
