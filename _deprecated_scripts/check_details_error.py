import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add project root to path
sys.path.append(os.getcwd())

from database import Base, get_client_session
from models_client_orm import ClientScheduleORM, ClientProfileORM, ClientDietSettingsORM
from services import UserService

def reproduce_details_error():
    print("Reproducing 500 Error with details=None...")
    
    client_id = "test_user_details"
    db = get_client_session(client_id)
    
    try:
        # 1. Clean up
        db.query(ClientScheduleORM).delete()
        db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).delete()
        db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).delete()
        db.commit()
        
        # 2. Insert Profile (Required)
        profile = ClientProfileORM(id=client_id, name="Test User", streak=0, gems=0, health_score=0)
        db.add(profile)
        
        # 3. Insert Schedule Item with details=None
        event = ClientScheduleORM(
            date="2023-10-27",
            title="Test Event",
            type="workout",
            completed=False,
            workout_id="w1",
            details=None # This should cause Pydantic error
        )
        db.add(event)
        db.commit()
        
        # 4. Call Service
        service = UserService()
        try:
            data = service.get_client(client_id)
            print("Successfully fetched client data!")
        except Exception as e:
            print(f"Caught Expected Error: {e}")
            # import traceback
            # traceback.print_exc()
            
    finally:
        # Cleanup
        db.query(ClientScheduleORM).delete()
        db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).delete()
        db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).delete()
        db.commit()
        db.close()

if __name__ == "__main__":
    reproduce_details_error()
