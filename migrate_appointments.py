"""
Database Migration - Create Appointment Tables
Run this script to add trainer_availability and appointments tables to your database.
"""
import os
import sys
from dotenv import load_dotenv

load_dotenv()

from database import engine, Base
from models_orm import TrainerAvailabilityORM, AppointmentORM


def migrate():
    print("\n" + "=" * 60)
    print("APPOINTMENT BOOKING TABLES MIGRATION")
    print("=" * 60)

    print("\nDatabase URL:", os.getenv("DATABASE_URL", "sqlite:///db/gym_app.db"))

    # Create all tables
    print("\nCreating tables...")
    Base.metadata.create_all(bind=engine)

    print("\n[OK] Tables created successfully!")

    # List all tables
    print("\nExisting tables:")
    from sqlalchemy import inspect
    inspector = inspect(engine)
    tables = inspector.get_table_names()

    appointment_tables = ["trainer_availability", "appointments"]

    for table in sorted(tables):
        if table in appointment_tables:
            print(f"  [NEW] {table}")
        else:
            print(f"       {table}")

    print("\n" + "=" * 60)
    print("MIGRATION COMPLETE")
    print("=" * 60)
    print("\nNew Features:")
    print("- Trainers can set their weekly availability")
    print("- Clients can book 1-on-1 appointments")
    print("- View and manage appointments for both roles")
    print("\n")


if __name__ == "__main__":
    try:
        migrate()
    except Exception as e:
        print(f"\n[ERROR] Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
