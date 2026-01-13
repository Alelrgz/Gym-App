from services import UserService

service = UserService()

print("--- Fetching for trainer_default ---")
exercises_default = service.get_exercises("trainer_default")
face_pull_default = next((e for e in exercises_default if e.name == "Face Pull"), None)
print(f"Default sees: {face_pull_default.name if face_pull_default else 'None'} (ID: {face_pull_default.id if face_pull_default else 'None'}, Video: {face_pull_default.video_id if face_pull_default else 'None'})")

print("\n--- Fetching for trainer_A ---")
exercises_A = service.get_exercises("trainer_A")
face_pull_A = next((e for e in exercises_A if e.name == "Face Pull"), None)
print(f"A sees: {face_pull_A.name if face_pull_A else 'None'} (ID: {face_pull_A.id if face_pull_A else 'None'}, Video: {face_pull_A.video_id if face_pull_A else 'None'})")

print("\n--- Fetching for trainer_B ---")
exercises_B = service.get_exercises("trainer_B")
face_pull_B = next((e for e in exercises_B if e.name == "Face Pull"), None)
print(f"B sees: {face_pull_B.name if face_pull_B else 'None'} (ID: {face_pull_B.id if face_pull_B else 'None'}, Video: {face_pull_B.video_id if face_pull_B else 'None'})")

if not face_pull_B:
    print("\nDEBUG: Listing all exercises for B:")
    for e in exercises_B:
        print(f"- {e.name}")
