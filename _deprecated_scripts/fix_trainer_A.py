from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models_orm import ExerciseORM
import os

# Path for Trainer A
TRAINER_A_DB_PATH = "sqlite:///./db/trainer_trainer_A.db"

def fix_trainer_A():
    print("--- Removing Face Pull Override for Trainer A ---")
    
    if not os.path.exists("./db/trainer_trainer_A.db"):
        print("Trainer A DB not found.")
        return

    engine = create_engine(TRAINER_A_DB_PATH)
    Session = sessionmaker(bind=engine)
    session = Session()
    
    # Find the personal override
    # We look for name="Face Pull"
    override = session.query(ExerciseORM).filter(ExerciseORM.name == "Face Pull").first()
    
    if override:
        print(f"Found override: {override.name} (ID: {override.id}, Video: {override.video_id})")
        session.delete(override)
        session.commit()
        print("Override deleted. Trainer A should now see Global version.")
    else:
        print("No override found for Trainer A.")
        
    session.close()

if __name__ == "__main__":
    fix_trainer_A()
