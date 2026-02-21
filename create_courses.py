"""
Create the 8 standard course types for the gym.
Run this script to populate courses: python create_courses.py
"""
from database import get_db_session
from models_orm import UserORM, CourseORM
import uuid
from datetime import datetime

# Course definitions with emoji icons matching the UI
COURSES = [
    {
        "name": "Yoga",
        "course_type": "yoga",
        "description": "Find your balance with mindful movement and breathwork",
        "duration": 60,
        "days_of_week": [1, 3, 5],  # Mon, Wed, Fri
        "time_slot": "7:00 AM"
    },
    {
        "name": "Pilates",
        "course_type": "pilates",
        "description": "Core-focused exercises for strength and flexibility",
        "duration": 45,
        "days_of_week": [1, 3],  # Mon, Wed
        "time_slot": "10:00 AM"
    },
    {
        "name": "HIIT",
        "course_type": "hiit",
        "description": "High-intensity interval training to torch calories",
        "duration": 30,
        "days_of_week": [0, 2, 4],  # Mon, Wed, Fri
        "time_slot": "6:00 AM"
    },
    {
        "name": "Dance",
        "course_type": "dance",
        "description": "Fun cardio dance routines to your favorite music",
        "duration": 60,
        "days_of_week": [2, 4],  # Wed, Fri
        "time_slot": "6:00 PM"
    },
    {
        "name": "Spinning",
        "course_type": "spin",
        "description": "High-energy indoor cycling for all fitness levels",
        "duration": 45,
        "days_of_week": [0, 2, 4],  # Mon, Wed, Fri
        "time_slot": "7:00 AM"
    },
    {
        "name": "Strength",
        "course_type": "strength",
        "description": "Build muscle and power with weight training",
        "duration": 60,
        "days_of_week": [1, 3, 5],  # Tue, Thu, Sat
        "time_slot": "5:00 PM"
    },
    {
        "name": "Stretch",
        "course_type": "stretch",
        "description": "Recovery-focused stretching and mobility work",
        "duration": 30,
        "days_of_week": [0, 2, 4, 6],  # Mon, Wed, Fri, Sun
        "time_slot": "8:00 PM"
    },
    {
        "name": "Cardio",
        "course_type": "cardio",
        "description": "Heart-pumping cardio workouts for endurance",
        "duration": 45,
        "days_of_week": [1, 3, 5],  # Tue, Thu, Sat
        "time_slot": "6:00 AM"
    }
]


def create_courses(trainer_username: str = None):
    """Create courses for a trainer. If no username provided, uses first trainer found."""
    db = get_db_session()
    try:
        # Find the trainer
        if trainer_username:
            trainer = db.query(UserORM).filter(
                UserORM.username == trainer_username,
                UserORM.role == "trainer"
            ).first()
        else:
            trainer = db.query(UserORM).filter(UserORM.role == "trainer").first()

        if not trainer:
            print("No trainer found! Please create a trainer account first.")
            return

        print(f"Creating courses for trainer: {trainer.username} (ID: {trainer.id})")
        print(f"Gym ID: {trainer.gym_owner_id}")
        print("-" * 50)

        created = 0
        skipped = 0

        for course_data in COURSES:
            # Check if course already exists
            existing = db.query(CourseORM).filter(
                CourseORM.owner_id == trainer.id,
                CourseORM.course_type == course_data["course_type"]
            ).first()

            if existing:
                print(f"[SKIP] {course_data['name']} - already exists")
                skipped += 1
                continue

            # Create the course
            import json
            course = CourseORM(
                id=str(uuid.uuid4()),
                name=course_data["name"],
                description=course_data["description"],
                course_type=course_data["course_type"],
                duration=course_data["duration"],
                days_of_week_json=json.dumps(course_data["days_of_week"]),
                time_slot=course_data["time_slot"],
                owner_id=trainer.id,
                gym_id=trainer.gym_owner_id,
                is_shared=True,  # Share with gym
                created_at=datetime.utcnow().isoformat()
            )
            db.add(course)
            print(f"[CREATE] {course_data['name']} - {course_data['time_slot']} ({course_data['duration']} min)")
            created += 1

        db.commit()
        print("-" * 50)
        print(f"Done! Created: {created}, Skipped: {skipped}")

    finally:
        db.close()


def list_trainers():
    """List all trainers in the database."""
    db = get_db_session()
    try:
        trainers = db.query(UserORM).filter(UserORM.role == "trainer").all()
        print("Available trainers:")
        for t in trainers:
            print(f"  - {t.username} (ID: {t.id}, Gym: {t.gym_owner_id})")
    finally:
        db.close()


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--list":
        list_trainers()
    elif len(sys.argv) > 1:
        create_courses(sys.argv[1])
    else:
        print("Usage:")
        print("  python create_courses.py              # Create for first trainer")
        print("  python create_courses.py <username>   # Create for specific trainer")
        print("  python create_courses.py --list       # List all trainers")
        print()
        create_courses()
