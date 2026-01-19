from database import get_db_session
from models_orm import TrainerScheduleORM

def check_schedule():
    db = get_db_session()
    try:
        events = db.query(TrainerScheduleORM).all()
        print(f"Found {len(events)} events.")
        for e in events:
            print(f"ID: {e.id}, TrainerID: {e.trainer_id}, Title: {e.title}, Duration: {e.duration}")
    finally:
        db.close()

if __name__ == "__main__":
    check_schedule()
