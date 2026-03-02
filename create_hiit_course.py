"""Create a HIIT course with YouTube music playlist for testing"""
from database import SessionLocal
from models_orm import UserORM, CourseORM
import uuid
import json

db = SessionLocal()

try:
    # Get trainer user
    trainer = db.query(UserORM).filter(UserORM.username == "trainer").first()
    if not trainer:
        print("[ERROR] Trainer not found. Run create_test_accounts.py first.")
        exit(1)

    trainer_id = trainer.id
    gym_id = trainer.gym_owner_id

    print("=" * 60)
    print("Creating Sample Course: Energizing HIIT Workout")
    print("=" * 60)

    # Define exercises for the course
    exercises = [
        {"name": "Warm Up - Jumping Jacks", "duration": 30, "type": "warmup", "description": "Get your heart rate up"},
        {"name": "High Knees", "duration": 45, "type": "cardio", "description": "Drive knees up high"},
        {"name": "Mountain Climbers", "duration": 45, "type": "cardio", "description": "Fast alternating leg drives"},
        {"name": "Burpees", "duration": 40, "type": "hiit", "description": "Full body explosive movement"},
        {"name": "Jump Squats", "duration": 40, "type": "hiit", "description": "Explosive squat jumps"},
        {"name": "Rest Break", "duration": 30, "type": "rest", "description": "Catch your breath"},
        {"name": "Plank to Push-Up", "duration": 45, "type": "strength", "description": "Alternate between plank and push-up position"},
        {"name": "Bicycle Crunches", "duration": 45, "type": "cardio", "description": "Alternating elbow to knee"},
        {"name": "Star Jumps", "duration": 40, "type": "hiit", "description": "Jump and spread arms and legs"},
        {"name": "Cool Down - Stretching", "duration": 60, "type": "cooldown", "description": "Full body stretch"}
    ]

    # Define YouTube music playlists
    music_playlists = [
        {
            "title": "Epic Workout Mix",
            "url": "https://music.youtube.com/watch?v=A8FUNP5HM_g&list=RDTMAK5uy_nilrsVWxrKskY0ZUpVZ3zpB0u4LwWTVJ4",
            "type": "youtube"
        }
    ]

    # Create the course
    course_id = str(uuid.uuid4())

    new_course = CourseORM(
        id=course_id,
        name="Energizing HIIT Workout",
        description="A high-intensity 30-minute workout to burn calories and build endurance. Perfect for all fitness levels with YouTube workout music!",
        course_type="hiit",
        exercises_json=json.dumps(exercises),
        music_links_json=json.dumps(music_playlists),
        day_of_week=2,  # Tuesday
        time_slot="18:00",
        duration=30,
        owner_id=trainer_id,
        gym_id=gym_id,
        is_shared=True,
        max_capacity=25,
        waitlist_enabled=True,
        cover_image_url="https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=800",
        trailer_url=None
    )

    db.add(new_course)
    db.commit()
    db.refresh(new_course)

    print("\n[SUCCESS] HIIT Course created successfully!")
    print(f"\nCourse ID: {course_id}")
    print(f"Course Name: {new_course.name}")
    print(f"Exercises: {len(exercises)} exercises")
    print(f"Total Duration: ~{sum(ex['duration'] for ex in exercises) // 60} minutes")
    print(f"Music Playlists: {len(music_playlists)} YouTube videos")
    print("\nPlaylists:")
    for playlist in music_playlists:
        print(f"  - {playlist['title']} (YouTube)")

    print("\nExercise Sequence:")
    total_time = 0
    for i, ex in enumerate(exercises, 1):
        total_time += ex['duration']
        mins = total_time // 60
        secs = total_time % 60
        print(f"  {i:2d}. {ex['name']:<35} {ex['duration']}s (at {mins}:{secs:02d})")

    print("\n" + "=" * 60)
    print("HOW TO TEST:")
    print("=" * 60)
    print(f"\n1. Login as trainer (username: trainer, password: 1234)")
    print(f"2. Go to Courses section")
    print(f"3. Find 'Energizing HIIT Workout' and click 'Start Class'")
    print(f"4. Click the green 'Open in YouTube' button to play music!")
    print("\n" + "=" * 60)

except Exception as e:
    print(f"\n[ERROR] {e}")
    import traceback
    traceback.print_exc()
    db.rollback()
finally:
    db.close()
