"""Set hydration for today"""
from database import SessionLocal
from models_orm import ClientDietSettingsORM, UserORM

db = SessionLocal()

try:
    client = db.query(UserORM).filter(UserORM.username == "client").first()
    if client:
        diet_settings = db.query(ClientDietSettingsORM).filter(
            ClientDietSettingsORM.id == client.id
        ).first()

        if diet_settings:
            diet_settings.hydration_current = 1000
            db.commit()
            print(f"[OK] Set hydration to 1000/{diet_settings.hydration_target} ml")
        else:
            print("[ERROR] Diet settings not found")
    else:
        print("[ERROR] Client not found")
except Exception as e:
    print(f"[ERROR] {e}")
    db.rollback()
finally:
    db.close()
