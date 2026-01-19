from services import UserService
from database import get_db_session
from models_orm import UserORM

def check_trainer_data():
    service = UserService()
    trainer_id = "ffcc52af-8aaa-4c8e-840f-1ef82440484c"
    
    print(f"Checking data for trainer ID: {trainer_id}")
    try:
        data = service.get_trainer(trainer_id)
        
        print("Schedule:")
        for event in data.schedule:
            print(f"ID: {event.id}, Title: {event.title}, Duration: {event.duration}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_trainer_data()
