from database import SessionLocal
from models_orm import ClientProfileORM

def set_premium():
    db = SessionLocal()
    try:
        target_name = "xax"
        print(f"Searching for user with name: {target_name}")
        
        # Try to find by Profile Name
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.name == target_name).first()
        
        if not profile:
            print(f"User '{target_name}' not found in Client Profiles. Listing all profiles:")
            all_profiles = db.query(ClientProfileORM).all()
            for p in all_profiles:
                print(f"- {p.name} (ID: {p.id})")
        
        if profile:
            profile.is_premium = True
            db.commit()
            print(f"User {profile.id} ({profile.name}) is now PREMIUM.")
        else:
            print("No client profile found to update.")
            
    finally:
        db.close()

if __name__ == "__main__":
    set_premium()
