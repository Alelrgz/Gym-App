import os
import sys

# Ensure db directory exists
if not os.path.exists("db"):
    os.makedirs("db")

# Clean up old test db
if os.path.exists("db/test_tenancy.db"):
    try:
        os.remove("db/test_tenancy.db")
    except Exception as e:
        print(f"Warning: could not remove old db: {e}")

# Set ENV to force use of test DB
# We must do this BEFORE importing database or services
os.environ["DATABASE_URL"] = f"sqlite:///db/test_tenancy.db"

try:
    from services import UserService
    from database import Base, engine, SessionLocal
    from models_orm import ExerciseORM, WorkoutORM
except ImportError as e:
    print(f"Import Error: {e}")
    sys.exit(1)

# Init DB
print("Initializing Test DB...")
Base.metadata.create_all(bind=engine)

# Seed Data
db = SessionLocal()

# Global Exercise
ex_global = ExerciseORM(id="ex_g", name="Global Pushup", owner_id=None)
# Trainer A Exercise
ex_a = ExerciseORM(id="ex_a", name="Trainer A Pushup", owner_id="trainer_a")
# Trainer B Exercise
ex_b = ExerciseORM(id="ex_b", name="Trainer B Pushup", owner_id="trainer_b")

# Trainer A Workout
w_a = WorkoutORM(id="w_a", title="Workout A", owner_id="trainer_a", exercises_json="[]")
# Trainer B Workout
w_b = WorkoutORM(id="w_b", title="Workout B", owner_id="trainer_b", exercises_json="[]")

db.add_all([ex_global, ex_a, ex_b, w_a, w_b])
db.commit()
db.close()

service = UserService()

print("\n--- Testing get_exercises ---")
exercises_a = service.get_exercises("trainer_a")
ids_a = [e.id for e in exercises_a]
print(f"Trainer A sees: {ids_a}")

if "ex_b" in ids_a:
    print("FAIL: Trainer A saw Trainer B's exercise!")
    sys.exit(1)
if "ex_g" not in ids_a:
    print("FAIL: Trainer A did not see Global exercise!")
    sys.exit(1)
if "ex_a" not in ids_a:
    print("FAIL: Trainer A did not see own exercise!")
    sys.exit(1)

print("PASS: get_exercises isolation verification")

print("\n--- Testing get_workouts ---")
workouts_a = service.get_workouts("trainer_a")
w_ids_a = [w["id"] for w in workouts_a]
print(f"Trainer A sees workouts: {w_ids_a}")

if "w_b" in w_ids_a:
    print("FAIL: Trainer A saw Trainer B's workout!")
    sys.exit(1)
if "w_a" not in w_ids_a:
    print("FAIL: Trainer A did not see own workout!")
    sys.exit(1)

print("PASS: get_workouts isolation verification")

print("\nALL TESTS PASSED")
