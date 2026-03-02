"""
Populate client account with a week's worth of data for graphs and progress tracking
"""
import os
import sys
import uuid
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from database import SessionLocal
from models_orm import (
    UserORM, ClientProfileORM, ClientScheduleORM,
    ClientExerciseLogORM, WeightHistoryORM, ClientDietLogORM
)
import json
import random

def populate_week_data():
    """Add a week's worth of data for the client user"""
    db = SessionLocal()

    try:
        # Get the client user
        client = db.query(UserORM).filter(UserORM.username == "client").first()
        if not client:
            print("[ERROR] Client user not found. Run create_test_accounts.py first.")
            return

        client_id = client.id
        print(f"Populating data for client: {client.username} ({client_id})")
        print("=" * 60)

        # Get trainer for workout assignments
        trainer = db.query(UserORM).filter(UserORM.username == "trainer").first()
        trainer_id = trainer.id if trainer else None

        # Define the date range (last 7 days)
        today = datetime.utcnow()
        dates = [(today - timedelta(days=i)) for i in range(6, -1, -1)]

        print("\n1. Adding weight entries...")
        # Add weight entries (gradual decrease from 180 to 177 lbs)
        starting_weight = 180.0
        for i, date in enumerate(dates):
            # Simulate gradual weight loss with some variation
            weight = starting_weight - (i * 0.5) + random.uniform(-0.3, 0.3)

            # Add weight entry
            weight_entry = WeightHistoryORM(
                client_id=client_id,
                weight=round(weight, 1),
                recorded_at=date.isoformat()
            )
            db.add(weight_entry)
            print(f"   [OK] {date.date()}: {round(weight, 1)} lbs")

        db.commit()

        print("\n2. Adding workout completions...")
        # Add workout completions for strength progress
        exercises = [
            {"name": "Bench Press", "muscle": "Chest"},
            {"name": "Squats", "muscle": "Legs"},
            {"name": "Deadlift", "muscle": "Back"},
            {"name": "Overhead Press", "muscle": "Shoulders"}
        ]

        workout_count = 0
        for i, date in enumerate(dates):
            # Skip 2 days (rest days)
            if i in [2, 5]:
                print(f"   [SKIP] {date.date()}: Rest day")
                continue

            # Create workout completion
            exercise = exercises[i % len(exercises)]

            # Progressive overload: increasing weight or reps each week
            base_weight = 135 if exercise["name"] == "Bench Press" else 185
            weight = base_weight + (i * 5)
            sets_completed = 3
            reps = [8, 8, 7] if i < 3 else [9, 8, 8]  # Show progression

            workout_id = f"workout_{exercise['name'].lower().replace(' ', '_')}"

            # Create schedule item for this workout
            schedule_item = ClientScheduleORM(
                client_id=client_id,
                date=date.date().isoformat(),
                type="workout",
                title=f"{exercise['name']} Day",
                workout_id=workout_id,
                completed=True
            )
            db.add(schedule_item)

            # Create exercise log for strength tracking
            for set_num in range(sets_completed):
                exercise_log = ClientExerciseLogORM(
                    client_id=client_id,
                    exercise_name=exercise["name"],
                    weight=weight,
                    reps=reps[set_num],
                    set_number=set_num + 1,
                    date=date.date().isoformat(),
                    workout_id=workout_id
                )
                db.add(exercise_log)
            workout_count += 1
            print(f"   [OK] {date.date()}: {exercise['name']} - {sets_completed}x{reps[0]} @ {weight}lbs")

        db.commit()

        print("\n3. Adding diet logs...")
        # Add diet/meal logs
        meals = [
            {"name": "Oatmeal with Berries", "calories": 350, "type": "breakfast"},
            {"name": "Grilled Chicken Salad", "calories": 450, "type": "lunch"},
            {"name": "Salmon with Rice", "calories": 550, "type": "dinner"},
            {"name": "Protein Shake", "calories": 200, "type": "snack"},
        ]

        meal_count = 0
        for date in dates:
            # Add 3-4 meals per day
            daily_meals = random.randint(3, 4)
            for meal_num in range(daily_meals):
                meal = random.choice(meals)
                meal_time = f"{8 + (meal_num * 4):02d}:{random.randint(0, 59):02d}"

                diet_log = ClientDietLogORM(
                    client_id=client_id,
                    meal_name=meal["name"],
                    calories=meal["calories"],
                    meal_type=meal["type"],
                    time=meal_time,
                    date=date.date().isoformat()
                )
                db.add(diet_log)
                meal_count += 1

        db.commit()
        print(f"   [OK] Added {meal_count} meal entries")

        # Update client profile with current stats
        print("\n4. Updating client profile...")
        client_profile = db.query(ClientProfileORM).filter(
            ClientProfileORM.id == client_id
        ).first()

        if client_profile:
            client_profile.current_weight = 177.0
            client_profile.streak = 5  # 5-day workout streak
            client_profile.gems = 250  # Earned gems from workouts
            client_profile.xp = 450  # XP from activities
            client_profile.health_score = 85  # Improved health score
            db.commit()
            print(f"   [OK] Updated profile: weight=177.0, streak=5, gems=250")

        print("\n" + "=" * 60)
        print("[SUCCESS] Client data populated successfully!")
        print("\nSummary:")
        print(f"  - Weight entries: 7 days")
        print(f"  - Workouts completed: {workout_count}")
        print(f"  - Meals logged: {meal_count}")
        print(f"  - Current streak: 5 days")
        print("\nRefresh the client dashboard to see the data!")
        print("=" * 60)

    except Exception as e:
        print(f"\n[ERROR] Failed to populate data: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    populate_week_data()
