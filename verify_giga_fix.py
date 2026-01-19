from services import UserService, get_db_session
from models_orm import UserORM, WeeklySplitORM, ClientScheduleORM
from datetime import date

def verify_giga():
    db = get_db_session()
    service = UserService()
    try:
        client = db.query(UserORM).filter(UserORM.username == "GigaNigga").first()
        if not client:
            print("GigaNigga not found")
            return
            
        split = db.query(WeeklySplitORM).filter(WeeklySplitORM.name.like("%Viagra%")).first()
        if not split:
            print("Split not found")
            return
            
        print(f"Assigning split to {client.username}...")
        service.assign_split({
            "client_id": client.id,
            "split_id": split.id,
            "start_date": date.today().isoformat()
        }, trainer_id="test")
        
        # Verify
        count = db.query(ClientScheduleORM).filter(
            ClientScheduleORM.client_id == client.id,
            ClientScheduleORM.title == "Sex On The Beach"
        ).count()
        
        print(f"Total 'Sex On The Beach' events for {client.username}: {count}")
        if count >= 28:
            print("SUCCESS: Assignment worked for GigaNigga.")
        else:
            print("FAIL: Assignment incomplete.")

    finally:
        db.close()

if __name__ == "__main__":
    verify_giga()
