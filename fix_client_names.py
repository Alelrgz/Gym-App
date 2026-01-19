from database import get_db_session
from models_orm import ClientProfileORM, UserORM

def fix_client_names():
    db = get_db_session()
    try:
        # Fetch all profiles with name "New User"
        profiles = db.query(ClientProfileORM).filter(ClientProfileORM.name == "New User").all()
        print(f"Found {len(profiles)} profiles with name 'New User'")
        
        count = 0
        for profile in profiles:
            # Get corresponding user
            user = db.query(UserORM).filter(UserORM.id == profile.id).first()
            if user:
                print(f"Updating profile {profile.id}: 'New User' -> '{user.username}'")
                profile.name = user.username
                count += 1
            else:
                print(f"Warning: No user found for profile {profile.id}")
                
        db.commit()
        print(f"Successfully updated {count} profiles.")
        
    except Exception as e:
        db.rollback()
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    fix_client_names()
