from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models_orm import ExerciseORM, Base
import os

# Paths
GLOBAL_DB_PATH = "sqlite:///./db/global.db"
TRAINER_DEFAULT_DB_PATH = "sqlite:///./db/trainer_trainer_default.db"

def promote_face_pull():
    print("--- Promoting Face Pull from Default to Global ---")
    
    # 1. Get Source (Default Trainer)
    engine_def = create_engine(TRAINER_DEFAULT_DB_PATH)
    SessionDef = sessionmaker(bind=engine_def)
    session_def = SessionDef()
    
    source_ex = session_def.query(ExerciseORM).filter(ExerciseORM.name == "Face Pull").first()
    if not source_ex:
        print("Error: Face Pull not found in Default Trainer DB")
        return
    
    print(f"Source found: {source_ex.name} (Video: {source_ex.video_id})")
    
    # 2. Update Target (Global)
    engine_glob = create_engine(GLOBAL_DB_PATH)
    SessionGlob = sessionmaker(bind=engine_glob)
    session_glob = SessionGlob()
    
    target_ex = session_glob.query(ExerciseORM).filter(ExerciseORM.name == "Face Pull").first()
    if not target_ex:
        print("Target Face Pull not found in Global DB. Creating new...")
        # If not found, we could create it, but we expect it to exist as ex_18
        target_ex = ExerciseORM(id="ex_face_pull_global", name="Face Pull")
        session_glob.add(target_ex)
    
    print(f"Target before update: {target_ex.name} (Video: {target_ex.video_id})")
    
    # Update fields
    target_ex.video_id = source_ex.video_id
    target_ex.muscle = source_ex.muscle
    target_ex.type = source_ex.type
    # We don't update ID to preserve references if any, though ex_18 is likely used.
    
    session_glob.commit()
    print(f"Target after update: {target_ex.name} (Video: {target_ex.video_id})")
    
    session_def.close()
    session_glob.close()
    print("Promotion complete.")

if __name__ == "__main__":
    promote_face_pull()
