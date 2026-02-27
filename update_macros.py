"""Update today's macro totals"""
from database import SessionLocal
from models_orm import ClientDietSettingsORM, UserORM

db = SessionLocal()

try:
    client = db.query(UserORM).filter(UserORM.username == "client").first()
    if not client:
        print("[ERROR] Client not found")
        exit(1)

    diet_settings = db.query(ClientDietSettingsORM).filter(
        ClientDietSettingsORM.id == client.id
    ).first()

    if diet_settings:
        # Based on the 1800 calories consumed:
        # Typical macro split for a balanced diet:
        # Protein: ~30% = 540 cal = 135g (4 cal/g)
        # Carbs: ~45% = 810 cal = 202g (4 cal/g)
        # Fat: ~25% = 450 cal = 50g (9 cal/g)

        diet_settings.protein_current = 135
        diet_settings.carbs_current = 202
        diet_settings.fat_current = 50

        db.commit()

        print("[SUCCESS] Updated macro totals!")
        print(f"  Calories: {diet_settings.calories_current}/{diet_settings.calories_target} kcal")
        print(f"  Protein:  {diet_settings.protein_current}/{diet_settings.protein_target}g")
        print(f"  Carbs:    {diet_settings.carbs_current}/{diet_settings.carbs_target}g")
        print(f"  Fat:      {diet_settings.fat_current}/{diet_settings.fat_target}g")
        print(f"  Hydration: {diet_settings.hydration_current}/{diet_settings.hydration_target}ml")
        print("\nRefresh the dashboard to see the updated macros!")
    else:
        print("[ERROR] Diet settings not found")

except Exception as e:
    print(f"[ERROR] {e}")
    import traceback
    traceback.print_exc()
    db.rollback()
finally:
    db.close()
