from services import get_db_session
from models_orm import UserORM, ClientScheduleORM

def inspect_giga():
    db = get_db_session()
    try:
        client = db.query(UserORM).filter(UserORM.username == "GigaNigga").first()
        if not client:
            print("GigaNigga not found")
            return
            
        events = db.query(ClientScheduleORM).filter(
            ClientScheduleORM.client_id == client.id
        ).all()
        
        print(f"Events for {client.username}:")
        for e in events:
            print(f"  {e.date}: {e.title} ({e.type})")
            
    finally:
        db.close()

if __name__ == "__main__":
    inspect_giga()
