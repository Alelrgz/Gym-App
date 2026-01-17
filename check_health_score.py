import os
import sys
from dotenv import load_dotenv

# Load env vars
load_dotenv()

# Mock DB session for standalone test if needed, or just use the real one
from database import SessionLocal, engine, Base
from services import UserService
from models_orm import ClientProfileORM, ClientDietSettingsORM

# Ensure tables exist
Base.metadata.create_all(bind=engine)

def test_health_score():
    print("--- Starting Health Score Test ---")
    service = UserService()
    db = SessionLocal()
    
    client_id = "test_user_health_score"
    
    try:
        # 1. Setup Test Data
        # Check if profile exists, else create
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_id).first()
        if not profile:
            print("Creating test profile...")
            profile = ClientProfileORM(id=client_id, name="Test User", health_score=0)
            db.add(profile)
            
        # Setup Diet Settings
        diet = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == client_id).first()
        if not diet:
            print("Creating test diet settings...")
            diet = ClientDietSettingsORM(
                id=client_id,
                calories_target=2000, calories_current=0,
                protein_target=150, protein_current=0,
                carbs_target=200, carbs_current=0,
                fat_target=70, fat_current=0,
                hydration_target=2500, hydration_current=0
            )
            db.add(diet)
        
        db.commit()
        
        # 2. Simulate Progress
        print("\n--- Simulating 50% Progress ---")
        diet.calories_current = 1000 # 50%
        diet.protein_current = 75    # 50%
        diet.carbs_current = 100     # 50%
        diet.fat_current = 35        # 50%
        diet.hydration_current = 1250 # 50%
        db.commit()
        
        # 3. Trigger Calculation via get_client
        # The calculation happens inside get_client
        print("Calling get_client to trigger calculation...")
        client_data = service.get_client(client_id)
        
        print(f"\nResulting Health Score: {client_data.health_score}")
        
        # 4. Simulate 100% Progress
        print("\n--- Simulating 100% Progress ---")
        diet.calories_current = 2000
        diet.protein_current = 150
        diet.carbs_current = 200
        diet.fat_current = 70
        diet.hydration_current = 2500
        db.commit()
        
        client_data = service.get_client(client_id)
        print(f"Resulting Health Score: {client_data.health_score}")

    except Exception as e:
        print(f"Test Failed: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    test_health_score()
