"""
Database Migration - Update TrainerSchedule Table
Adds client_id and appointment_id columns to link calendar events to appointments.
"""
import os
import sys
from dotenv import load_dotenv

load_dotenv()

from database import engine, Base
from models_orm import TrainerScheduleORM


def migrate():
    print("\n" + "=" * 60)
    print("TRAINER SCHEDULE UPDATE MIGRATION")
    print("=" * 60)

    print("\nDatabase URL:", os.getenv("DATABASE_URL", "sqlite:///db/gym_app.db"))

    # Create all tables (this will add the new columns)
    print("\nUpdating trainer_schedule table...")
    Base.metadata.create_all(bind=engine)

    print("\n[OK] Table updated successfully!")

    print("\n" + "=" * 60)
    print("MIGRATION COMPLETE")
    print("=" * 60)
    print("\nChanges:")
    print("- Added client_id column to trainer_schedule")
    print("- Added appointment_id column to trainer_schedule")
    print("- Appointments now automatically appear in trainer calendars")
    print("\n")


if __name__ == "__main__":
    try:
        migrate()
    except Exception as e:
        print(f"\n[ERROR] Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
