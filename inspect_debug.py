from services import UserService
from database import get_db_session, engine
from models_orm import UserORM, ClientScheduleORM

def inspect_debug():
    print(f"DB URL: {engine.url}")
    db = get_db_session()
    try:
        count = db.query(ClientScheduleORM).count()
        print(f"Total Schedule Items: {count}")
        
        items = db.query(ClientScheduleORM).all()
        print(f"Items found: {len(items)}")
        for i in items:
            print(f" - {i.id}: {i.client_id} {i.date} {i.title}")
            
        print("\n--- CLIENTS ---")
        clients = db.query(UserORM).filter(UserORM.role == "client").all()
        print(f"Total Clients: {len(clients)}")

    except Exception as e:
        print(f"ERROR: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    inspect_debug()
