from database import SessionLocal
from models_orm import WeeklySplitORM
import json

db = SessionLocal()
splits = db.query(WeeklySplitORM).all()

print(f"{'ID':<36} {'Name':<20} {'Description':<30}")
print("-" * 90)

target_split = None

for s in splits:
    print(f"{s.id:<36} {s.name:<20} {s.description:<30}")
    if "viagra" in s.name.lower():
        target_split = s

if target_split:
    print("\n--- Target Split Details ---")
    print(f"Name: {target_split.name}")
    print("Schedule JSON:")
    try:
        schedule = json.loads(target_split.schedule_json)
        print(json.dumps(schedule, indent=2))
    except Exception as e:
        print(f"Error parsing JSON: {e}")
        print(target_split.schedule_json)
else:
    print("\n'viagra' split not found.")
