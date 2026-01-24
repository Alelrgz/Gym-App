"""
Diet Daily Summary Migration
Adds last_reset_date column and creates daily summary table for tracking metrics.
"""
import os
import sys
from dotenv import load_dotenv

load_dotenv()

from database import engine, Base, get_db_session
from models_orm import ClientDietSettingsORM, ClientDailyDietSummaryORM
from sqlalchemy import text


def migrate():
    print("\n" + "=" * 60)
    print("DIET DAILY SUMMARY MIGRATION")
    print("=" * 60)

    print("\nDatabase URL:", os.getenv("DATABASE_URL", "sqlite:///db/gym_app.db"))

    # Add last_reset_date column to client_diet_settings
    print("\nAdding last_reset_date column to client_diet_settings...")
    db = get_db_session()
    try:
        try:
            db.execute(text("ALTER TABLE client_diet_settings ADD COLUMN last_reset_date VARCHAR"))
            db.commit()
            print("[OK] last_reset_date column added successfully!")
        except Exception as e:
            if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                print("[INFO] last_reset_date column already exists, skipping...")
            else:
                raise
    finally:
        db.close()

    # Create all tables (will create client_daily_diet_summary if it doesn't exist)
    print("\nCreating client_daily_diet_summary table...")
    Base.metadata.create_all(bind=engine)
    print("[OK] Tables created/verified!")

    # List table schema
    print("\nClient Diet Settings table now includes:")
    from sqlalchemy import inspect
    inspector = inspect(engine)

    if inspector.has_table('client_diet_settings'):
        columns = inspector.get_columns('client_diet_settings')
        for col in columns:
            print(f"  - {col['name']}: {col['type']}")

    print("\nClient Daily Diet Summary table:")
    if inspector.has_table('client_daily_diet_summary'):
        columns = inspector.get_columns('client_daily_diet_summary')
        for col in columns:
            print(f"  - {col['name']}: {col['type']}")
    else:
        print("  [WARNING] Table not found!")

    print("\n" + "=" * 60)
    print("MIGRATION COMPLETE!")
    print("=" * 60)
    print("\nThe system will now:")
    print("  1. Track daily consumption in client_diet_settings (current_* fields)")
    print("  2. At midnight (first meal of new day), save totals to client_daily_diet_summary")
    print("  3. Reset current_* fields for the new day")
    print("  4. Use daily summaries for metrics and historical analysis")
    print("\n")


if __name__ == "__main__":
    migrate()
