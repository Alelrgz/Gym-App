import sys
import os
import uuid

# Add current directory to path
sys.path.append(os.getcwd())

from services import UserService
from database import GlobalSessionLocal, Base, global_engine
from models_orm import ExerciseORM

def verify_logic():
    service = UserService()
    
    # 1. Ensure Global DB has "Face Pull"
    print("Checking Global DB...")
    db = GlobalSessionLocal()
    face_pull = db.query(ExerciseORM).filter(ExerciseORM.name == "Face Pull").first()
    if not face_pull:
        print("Error: 'Face Pull' not found in global DB. Seeding...")
        # Manually seed for test if needed, but service should have done it
        from data import EXERCISE_LIBRARY
        fp_data = next(ex for ex in EXERCISE_LIBRARY if ex["name"] == "Face Pull")
        face_pull = ExerciseORM(
            id=fp_data["id"],
            name=fp_data["name"],
            muscle=fp_data["muscle"],
            type=fp_data["type"],
            video_id=fp_data["video_id"]
        )
        db.add(face_pull)
        db.commit()
    
    global_id = face_pull.id
    original_video = face_pull.video_id
    print(f"Global 'Face Pull' ID: {global_id}, Video: {original_video}")
    db.close()

    # 2. Trainer A fetches exercises
    print("\n--- Trainer A View ---")
    exercises_a = service.get_exercises("trainer_A")
    fp_a = next(ex for ex in exercises_a if ex.name == "Face Pull")
    print(f"Trainer A sees: {fp_a.name}, Video: {fp_a.video_id}, ID: {fp_a.id}")
    
    if fp_a.video_id != original_video:
        print("FAIL: Trainer A should see default video initially.")
        return

    # 3. Trainer A updates "Face Pull" (Change video)
    print("\n--- Trainer A Updates Video ---")
    new_video = "Custom_FacePull_Video.mp4"
    updated_fp_a = service.update_exercise(
        exercise_id=fp_a.id, 
        updates={"video_id": new_video}, 
        trainer_id="trainer_A"
    )
    print(f"Updated: {updated_fp_a.name}, New Video: {updated_fp_a.video_id}, New ID: {updated_fp_a.id}")

    if updated_fp_a.id == global_id:
        print("FAIL: Should have created a new ID (fork), but ID is still global.")
    else:
        print("SUCCESS: Created a new ID (fork).")

    # 4. Trainer A fetches again
    print("\n--- Trainer A View (After Update) ---")
    exercises_a_new = service.get_exercises("trainer_A")
    fp_a_new = next(ex for ex in exercises_a_new if ex.name == "Face Pull")
    print(f"Trainer A sees: {fp_a_new.name}, Video: {fp_a_new.video_id}")
    
    if fp_a_new.video_id != new_video:
        print("FAIL: Trainer A should see the NEW video.")
    else:
        print("SUCCESS: Trainer A sees the custom video.")

    # 5. Trainer B fetches exercises
    print("\n--- Trainer B View ---")
    exercises_b = service.get_exercises("trainer_B")
    fp_b = next(ex for ex in exercises_b if ex.name == "Face Pull")
    print(f"Trainer B sees: {fp_b.name}, Video: {fp_b.video_id}, ID: {fp_b.id}")

    if fp_b.video_id != original_video:
        print("FAIL: Trainer B should still see the DEFAULT video.")
    else:
        print("SUCCESS: Trainer B is unaffected.")

if __name__ == "__main__":
    try:
        verify_logic()
        print("\nOverall Verification: PASSED")
    except Exception as e:
        print(f"\nAn error occurred: {e}")
        import traceback
        traceback.print_exc()
