"""
Database migration script to create subscription and billing tables.
Run this script to add the new subscription functionality to your database.
"""
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from database import Base, engine
from models_orm import (
    UserORM, ExerciseORM, WorkoutORM, WeeklySplitORM,
    ClientProfileORM, ClientScheduleORM, ClientDietSettingsORM,
    ClientDietLogORM, ClientExerciseLogORM, TrainerScheduleORM,
    TrainerNoteORM, SubscriptionPlanORM, ClientSubscriptionORM, PaymentORM
)

def migrate():
    """Create all database tables (including new subscription tables)."""
    print("=" * 60)
    print("DATABASE MIGRATION - Adding Subscription Tables")
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

    subscription_tables = ["subscription_plans", "client_subscriptions", "payments"]

    for table in sorted(tables):
        if table in subscription_tables:
            print(f"  [NEW] {table}")
        else:
            print(f"       {table}")

    print("\n" + "=" * 60)
    print("MIGRATION COMPLETE")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Get your Stripe API keys from https://dashboard.stripe.com/apikeys")
    print("2. Update the .env file with your Stripe keys")
    print("3. Restart your app to load the new subscription routes")
    print("\n")

if __name__ == "__main__":
    try:
        migrate()
    except Exception as e:
        print(f"\n[ERROR] Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
