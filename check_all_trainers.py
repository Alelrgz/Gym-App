from services import UserService
import os

service = UserService()
trainers = ["trainer_default", "trainer_A", "trainer_B", "trainer_C"]

print("--- Checking Face Pull for all trainers ---")

for tid in trainers:
    exercises = service.get_exercises(tid)
    face_pull = next((e for e in exercises if e.name == "Face Pull"), None)
    
    if face_pull:
        vid_id = face_pull.video_id
        print(f"\n[{tid}]")
        print(f"  ID: {face_pull.id}")
        print(f"  Video ID: {vid_id}")
        
        # Check if file exists
        if vid_id:
            # Handle full path or filename
            if vid_id.startswith("/static/"):
                # relative to app root?
                # Assuming script runs in e:/Antigravity/gym_app_prototype/
                # and /static/ maps to ./static/
                path = "." + vid_id
            else:
                path = f"./static/videos/{vid_id}.mp4"
                
            exists = os.path.exists(path)
            print(f"  Path: {path}")
            print(f"  Exists: {exists}")
    else:
        print(f"\n[{tid}] Face Pull NOT found")
