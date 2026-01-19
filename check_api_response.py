from services import UserService, get_db_session
from models_orm import UserORM
import json

def check_api():
    db = get_db_session()
    service = UserService()
    try:
        # 1. Find Client
        client = db.query(UserORM).filter(UserORM.username == "GigaNigga1").first()
        if not client:
            print("Client not found")
            return

        print(f"Fetching data for client: {client.id}")
        
        # 2. Call Service Method (mimic API)
        client_data = service.get_client(client.id)
        
        # 3. Inspect Calendar
        calendar = client_data.calendar
        # print(f"Calendar Month: {calendar.current_month}")
        events = calendar.events
        print(f"Total Events: {len(events)}")
        
        # Filter for Jan 2026
        jan_events = [e for e in events if e.date.startswith("2026-01")]
        print(f"Events in Jan 2026: {len(jan_events)}")
        
        for e in jan_events:
            print(f"  - {e.date}: {e.title} (ID: {e.id})")

    finally:
        db.close()

if __name__ == "__main__":
    check_api()
