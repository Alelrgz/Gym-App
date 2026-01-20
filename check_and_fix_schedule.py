from database import get_db_session
from models_orm import TrainerScheduleORM, UserORM, WorkoutORM
from datetime import datetime

def check_schedule():
    db = get_db_session()
    try:
        # Get ALL trainers
        trainers = db.query(UserORM).filter(UserORM.role == 'trainer').all()
        if not trainers:
            print("No trainers found.")
            return

        today_str = datetime.now().strftime("%Y-%m-%d")
        print(f"Today's date: {today_str}")

        # Ensure a workout exists
        workout = db.query(WorkoutORM).first()
        if not workout:
            print("No workouts available. Creating one...")
            # Use the first trainer as owner if needed, or just a placeholder
            owner_id = trainers[0].id
            workout = WorkoutORM(id="test_workout", title="Test Workout", duration="60 min", difficulty="Intermediate", owner_id=owner_id)
            db.add(workout)
            db.commit()
            print("Created test workout.")

        for trainer in trainers:
            print(f"Checking schedule for trainer: {trainer.username} ({trainer.id})")
            
            event = db.query(TrainerScheduleORM).filter(
                TrainerScheduleORM.trainer_id == trainer.id,
                TrainerScheduleORM.date == today_str
            ).first()

            if event:
                print(f"  - Found event: {event.title}, Type: {event.type}, Workout ID: {event.workout_id}")
                if not event.workout_id:
                     print("  - Event has no workout linked. Updating...")
                     event.workout_id = workout.id
                     db.commit()
            else:
                print("  - No event found. Creating one...")
                new_event = TrainerScheduleORM(
                    trainer_id=trainer.id,
                    date=today_str,
                    time="09:00",
                    title="My Training",
                    type="personal",
                    workout_id=workout.id,
                    duration=60
                )
                db.add(new_event)
                db.commit()
                print("  - Test event created.")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    check_schedule()
