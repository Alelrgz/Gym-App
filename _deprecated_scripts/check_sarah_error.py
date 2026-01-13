import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add project root to path
sys.path.append(os.getcwd())

from database import Base, get_client_session
from models_client_orm import ClientScheduleORM, ClientProfileORM, ClientDietSettingsORM
from services import UserService
from data import CLIENT_DATA

def reproduce_sarah_error():
    print("Reproducing Sarah's 500 Error...")
    
    client_id = "user_456"
    db = get_client_session(client_id)
    service = UserService()
    
    try:
        # 1. Clean up
        db.query(ClientScheduleORM).delete()
        db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).delete()
        db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).delete()
        db.commit()
        
        # 2. Seed Data (Simulate what happens when a new user is accessed)
        # The service layer handles seeding if profile doesn't exist.
        # So we just call get_client directly.
        
        print(f"Fetching data for {client_id} (Should trigger seeding)...")
        data = service.get_client(client_id)
        print("Successfully fetched Sarah's data!")
        print(f"Name: {data.name}")
        print(f"Plan: {data.progress}")
        
    except Exception as e:
        print(f"Caught Error: {e}")
        import traceback
        traceback.print_exc()
            
    finally:
        # Cleanup
        db.query(ClientScheduleORM).delete()
        db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).delete()
        db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).delete()
        db.commit()
        db.close()

if __name__ == "__main__":
    reproduce_sarah_error()
