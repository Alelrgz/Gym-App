import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add project root to path
sys.path.append(os.getcwd())

from database import Base, get_client_session
from models_client_orm import ClientScheduleORM, ClientProfileORM, ClientDietSettingsORM
from services import UserService

def reproduce_all_nulls():
    print("Reproducing 500 Error with NULLs in various fields...")
    
    client_id = "test_user_nulls"
    db = get_client_session(client_id)
    service = UserService()
    
    def test_case(name, setup_func):
        print(f"\n--- Testing {name} ---")
        try:
            # Cleanup
            db.query(ClientScheduleORM).delete()
            db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).delete()
            db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).delete()
            db.commit()
            
            # Setup
            setup_func(db)
            db.commit()
            
            # Execute
            service.get_client(client_id)
            print("SUCCESS: Handled NULLs correctly")
        except Exception as e:
            print(f"FAILED: {e}")

    # 1. Profile Name is None
    def setup_profile_name_none(db):
        profile = ClientProfileORM(id=client_id, name=None, streak=0, gems=0, health_score=0)
        db.add(profile)
    test_case("Profile Name=None", setup_profile_name_none)

    # 2. Profile Stats are None
    def setup_profile_stats_none(db):
        profile = ClientProfileORM(id=client_id, name="Test", streak=None, gems=None, health_score=None)
        db.add(profile)
    test_case("Profile Stats=None", setup_profile_stats_none)

    # 3. Schedule Title/Type are None
    def setup_schedule_none(db):
        profile = ClientProfileORM(id=client_id, name="Test", streak=0, gems=0, health_score=0)
        db.add(profile)
        event = ClientScheduleORM(
            date="2023-10-27",
            title=None, # Error?
            type=None,  # Error?
            completed=False,
            workout_id="w1",
            details=""
        )
        db.add(event)
    test_case("Schedule Title/Type=None", setup_schedule_none)

    db.close()

if __name__ == "__main__":
    reproduce_all_nulls()
