from services import UserService, get_db_session
from models_orm import UserORM, WorkoutORM, ClientScheduleORM
from datetime import date
import uuid

def setup():
    db = get_db_session()
    try:
        # 1. Get Trainer
        trainer = db.query(UserORM).filter(UserORM.role == "trainer").first()
        if not trainer:
            print("No trainer found.")
            return
        
        print(f"Using trainer: {trainer.username}")

        # 2. Get Workout
        workout = db.query(WorkoutORM).first()
        if not workout:
            print("No workouts found.")
            return
            
        print(f"Using workout: {workout.title}")

        # 3. Assign to Trainer (as client)
        today = date.today().isoformat()
        
        # Clear existing
        db.query(ClientScheduleORM).filter(
            ClientScheduleORM.client_id == trainer.id,
            ClientScheduleORM.date == today
        ).delete()
        
        # Assign
        event = ClientScheduleORM(
            client_id=trainer.id,
            date=today,
            title=workout.title,
            type="workout",
            workout_id=workout.id,
            details=workout.difficulty
        )
        db.add(event)
        db.commit()
        print(f"Assigned workout to trainer for {today}")
        
    finally:
        db.close()

if __name__ == "__main__":
    setup()
