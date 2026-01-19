from services import get_db_session
from models_orm import UserORM, ClientScheduleORM
from datetime import date

def scan_all_clients():
    db = get_db_session()
    try:
        clients = db.query(UserORM).filter(UserORM.role == "client").all()
        print(f"Found {len(clients)} clients.")
        
        today = date.today().isoformat()
        
        for c in clients:
            events = db.query(ClientScheduleORM).filter(
                ClientScheduleORM.client_id == c.id,
                ClientScheduleORM.title == "Sex On The Beach"
            ).count()
            
            print(f"Client: {c.username} (ID: {c.id}) - 'Sex On The Beach' Events: {events}")
            
            if events == 0:
                print(f"  [WARNING] No Viagra Split assignments found for {c.username}")
                # Check if they have ANY events
                total_events = db.query(ClientScheduleORM).filter(ClientScheduleORM.client_id == c.id).count()
                print(f"  Total Events: {total_events}")

    finally:
        db.close()

if __name__ == "__main__":
    scan_all_clients()
