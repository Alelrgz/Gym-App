import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Add project root to path
sys.path.append(os.getcwd())

from database import Base, get_client_session
from models_client_orm import ClientDietSettingsORM, ClientProfileORM
from services import UserService

def verify_fix():
    print("Verifying Client Data Fix...")
    
    client_id = "test_user_500"
    db = get_client_session(client_id)
    
    try:
        # 1. Clean up
        db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).delete()
        db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).delete()
        db.commit()
        
        # 2. Insert problematic data (NULLs for currents)
        # Note: We need a profile too otherwise get_client might try to seed
        profile = ClientProfileORM(id=client_id, name="Test User", streak=0, gems=0, health_score=0)
        db.add(profile)
        
        diet = ClientDietSettingsORM(
            id=client_id,
            calories_target=2000,
            # currents are None by default or explicitly None
            calories_current=None,
            protein_current=None,
            carbs_current=None,
            fat_current=None,
            hydration_current=None
        )
        db.add(diet)
        db.commit()
        
        # 3. Call Service
        service = UserService()
        try:
            # We need to mock the client_id usage in get_client, but get_client uses "user_123" hardcoded in the prototype
            # Let's temporarily modify the service or just test the logic if we can inject client_id
            # The current get_client implementation has client_id="user_123" as default but accepts an argument.
            # Wait, looking at routes.py:
            # @router.get("/api/client/data", response_model=ClientData)
            # async def get_client_data(service: UserService = Depends(get_user_service)):
            #     return service.get_client()
            # And service.get_client(self, client_id: str = "user_123")
            
            # So we can call it with our test ID
            data = service.get_client(client_id)
            print("Successfully fetched client data!")
            
            # Verify values are 0 not None
            macros = data.progress.macros
            print(f"Calories Current: {macros.calories.current}")
            assert macros.calories.current == 0
            print("Verification PASSED: NULLs handled correctly.")
            
        except Exception as e:
            print(f"Verification FAILED: {e}")
            import traceback
            traceback.print_exc()
            
    finally:
        # Cleanup
        db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).delete()
        db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).delete()
        db.commit()
        db.close()

if __name__ == "__main__":
    verify_fix()
