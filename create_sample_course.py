"""Create a sample course with exercises and music playlists for testing"""
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
    print("Creating Sample Course: Morning Flow Yoga")
    print("=" * 60)

    # Define exercises for the course
    exercises = [
        {"name": "Warm Up - Deep Breathing", "duration": 60, "type": "warmup", "description": "Start with deep breathing exercises"},
        {"name": "Cat-Cow Stretch", "duration": 45, "type": "yoga", "description": "Gentle spine warmup"},
        {"name": "Downward Facing Dog", "duration": 60, "type": "yoga", "description": "Full body stretch"},
        {"name": "Warrior I", "duration": 45, "type": "yoga", "description": "Strength and balance"},
        {"name": "Warrior II", "duration": 45, "type": "yoga", "description": "Hip opening pose"},
        {"name": "Triangle Pose", "duration": 40, "type": "yoga", "description": "Side body stretch"},
        {"name": "Tree Pose", "duration": 50, "type": "yoga", "description": "Balance practice"},
        {"name": "Child's Pose", "duration": 60, "type": "yoga", "description": "Resting pose"},
        {"name": "Seated Forward Fold", "duration": 60, "type": "stretch", "description": "Hamstring stretch"},
        {"name": "Savasana - Final Relaxation", "duration": 120, "type": "cooldown", "description": "Deep relaxation"}
    ]

    # Define music playlists
    music_playlists = [
        {
            "title": "Peaceful Morning Yoga",
            "url": "https://open.spotify.com/playlist/37i9dQZF1DWZqd5JICZI0u",
            "type": "spotify"
        },
        {
            "title": "Relaxing Yoga Music",
            "url": "https://www.youtube.com/playlist?list=PLQkQfzsIUwRa6GCUoDP0IiDjE-eAuQhKC",
            "type": "youtube"
        }
    ]

    # Create the course
    course_id = str(uuid.uuid4())

    new_course = CourseORM(
        id=course_id,
        name="Morning Flow Yoga",
        description="A gentle 45-minute yoga flow perfect for starting your day. Includes breathwork, standing poses, and deep relaxation. Suitable for all levels.",
        course_type="yoga",
        exercises_json=json.dumps(exercises),
        music_links_json=json.dumps(music_playlists),
        day_of_week=1,  # Monday
        time_slot="09:00",
        duration=45,
        owner_id=trainer_id,
        gym_id=gym_id,
        is_shared=True,  # Share with gym so clients can see it
        max_capacity=20,
        waitlist_enabled=True,
        cover_image_url="https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=800",
        trailer_url=None
    )

    db.add(new_course)
    db.commit()
    db.refresh(new_course)

    print("\n[SUCCESS] Course created successfully!")
    print(f"\nCourse ID: {course_id}")
    print(f"Course Name: {new_course.name}")
    print(f"Exercises: {len(exercises)} exercises")
    print(f"Total Duration: ~{sum(ex['duration'] for ex in exercises) // 60} minutes")
    print(f"Music Playlists: {len(music_playlists)}")
    print("\nPlaylists:")
    for playlist in music_playlists:
        print(f"  - {playlist['title']} ({playlist['type'].capitalize()})")

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
    print(f"2. Go to Courses section to view/edit the course")
    print(f"\n3. To start the workout player, visit:")
    print(f"   http://127.0.0.1:9008/course/workout/{course_id}")
    print(f"\n4. Or use this one-liner:")
    print(f"   start http://127.0.0.1:9008/course/workout/{course_id}")
    print("\n" + "=" * 60)

except Exception as e:
    print(f"\n[ERROR] {e}")
    import traceback
    traceback.print_exc()
    db.rollback()
finally:
    db.close()
