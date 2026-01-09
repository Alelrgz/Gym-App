import sys
import os
import json

# Add current directory to path
sys.path.append(os.getcwd())

from services import UserService
from database import GlobalSessionLocal, Base, global_engine
from models_orm import ExerciseORM

def check_video_ids():
    service = UserService()
    
    # Fetch exercises for Trainer A (who inherits from global)
    print("Fetching exercises for Trainer A...")
    exercises = service.get_exercises("trainer_A")
    
    # Convert to dicts (simulating API response)
    exercises_json = []
    for ex in exercises:
        exercises_json.append({
            "id": ex.id,
            "name": ex.name,
            "video_id": ex.video_id
        })
        
    # Check a known global exercise
    face_pull = next((ex for ex in exercises_json if ex["name"] == "Face Pull"), None)
    
    if face_pull:
        print(f"Found 'Face Pull': {face_pull}")
        if face_pull.get("video_id"):
            print("SUCCESS: video_id is present.")
        else:
            print("FAIL: video_id is MISSING or empty.")
    else:
        print("FAIL: 'Face Pull' not found.")

if __name__ == "__main__":
    check_video_ids()
