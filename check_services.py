from services import UserService
import logging

# Configure logging to stdout
logging.basicConfig(level=logging.INFO)

def debug_get_exercises():
    service = UserService()
    trainer_id = "trainer_repro_1"
    
    print(f"Fetching exercises for {trainer_id}...")
    exercises = service.get_exercises(trainer_id)
    
    print(f"Found {len(exercises)} exercises.")
    
    # Check for duplicates
    names = [ex.name for ex in exercises]
    from collections import Counter
    counts = Counter(names)
    
    duplicates = {name: count for name, count in counts.items() if count > 1}
    
    if duplicates:
        print("Duplicates found in get_exercises output:")
        for name, count in duplicates.items():
            print(f"  '{name}': {count}")
    else:
        print("No duplicates found in get_exercises output.")

    # Inspect specific exercise
    target_name = "Barbell Bench Press"
    matches = [ex for ex in exercises if ex.name == target_name]
    print(f"\nDetails for '{target_name}':")
    for ex in matches:
        print(f" - ID: {ex.id}, Video: {ex.video_id}, Owner: {ex.owner_id}")

if __name__ == "__main__":
    debug_get_exercises()
