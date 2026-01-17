from database import SessionLocal, engine, Base
from models_orm import ClientDietSettingsORM

def update_hydration():
    db = SessionLocal()
    try:
        print("Updating hydration targets to 2000ml...")
        settings = db.query(ClientDietSettingsORM).all()
        count = 0
        for s in settings:
            if s.hydration_target != 2000:
                s.hydration_target = 2000
                count += 1
        
        db.commit()
        print(f"Updated {count} user(s).")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    update_hydration()
