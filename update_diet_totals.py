"""Update today's diet totals from logged meals"""
from database import SessionLocal
from models_orm import ClientDietLogORM, ClientDietSettingsORM, UserORM
from datetime import datetime

db = SessionLocal()

try:
    # Get client
    client = db.query(UserORM).filter(UserORM.username == "client").first()
    if not client:
        print("[ERROR] Client not found")
        exit(1)

    client_id = client.id
    today = datetime.now().date().isoformat()

    print(f"Updating diet totals for client {client.username}")
    print(f"Today's date: {today}")
    print("=" * 60)

    # Get today's diet logs
    today_logs = db.query(ClientDietLogORM).filter(
        ClientDietLogORM.client_id == client_id,
        ClientDietLogORM.date == today
    ).all()

    print(f"\nFound {len(today_logs)} meals for today:")

    # Calculate totals
    total_calories = 0
    for log in today_logs:
        total_calories += log.calories
        print(f"  - {log.meal_name}: {log.calories} kcal")

    print(f"\nTotal calories: {total_calories} kcal")

    # Get or create diet settings
    diet_settings = db.query(ClientDietSettingsORM).filter(
        ClientDietSettingsORM.id == client_id
    ).first()

    if not diet_settings:
        print("\n[INFO] Creating new diet settings...")
        diet_settings = ClientDietSettingsORM(
            id=client_id,
            calories_target=2000,
            protein_target=150,
            carbs_target=200,
            fat_target=70,
            hydration_target=2000,
            consistency_target=80,
            calories_current=0,
            protein_current=0,
            carbs_current=0,
            fat_current=0,
            hydration_current=1000,
            last_reset_date=today
        )
        db.add(diet_settings)

    # Update current values
    diet_settings.calories_current = total_calories
    diet_settings.last_reset_date = today

    db.commit()

    print(f"\n[SUCCESS] Updated diet settings!")
    print(f"  Calories: {diet_settings.calories_current}/{diet_settings.calories_target}")
    print(f"  Hydration: {diet_settings.hydration_current}/{diet_settings.hydration_target}")
    print("=" * 60)
    print("\nRefresh the client dashboard to see the updated data!")

except Exception as e:
    print(f"[ERROR] {e}")
    import traceback
    traceback.print_exc()
    db.rollback()
finally:
    db.close()
