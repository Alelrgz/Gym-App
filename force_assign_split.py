from services import UserService, get_db_session
from models_orm import UserORM, WeeklySplitORM
from datetime import date

def force_assign():
    db = get_db_session()
    service = UserService()
    try:
        # 1. Find Client
        client = db.query(UserORM).filter(UserORM.username == "GigaNigga1").first()
        if not client:
            print("Client not found")
            return

        # 2. Find Split
        split = None
        splits = db.query(WeeklySplitORM).all()
        for s in splits:
            if "viagra" in s.name.lower():
                split = s
                break
        
        if not split:
            print("Split not found")
            return

        print(f"Assigning '{split.name}' to '{client.username}' starting TODAY...")
        
        # 3. Assign
        result = service.assign_split({
            "client_id": client.id,
            "split_id": split.id,
            "start_date": date.today().isoformat()
        }, trainer_id="manual_override")
        
        print("Result:", result)

    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    force_assign()
