from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models_orm import ExerciseORM, Base

# Paths
GLOBAL_DB_PATH = "sqlite:///./db/global.db"
TRAINER_DEFAULT_DB_PATH = "sqlite:///./db/trainer_trainer_default.db" # Note: get_trainer_db_path adds 'trainer_' prefix, and ID is 'trainer_default' -> 'trainer_trainer_default.db'? 
# Wait, let's check how the ID is passed. 
# routes.py: trainer_id: str = Header("trainer_default", alias="x-trainer-id")
# database.py: return f"sqlite:///{db_folder}/trainer_{trainer_id}.db"
# So if ID is "trainer_default", file is "trainer_trainer_default.db".
# But if ID is just "default", file is "trainer_default.db".
# Let's check what the actual file names are in the directory.

import os
print("DB Files:", os.listdir("./db"))

def check_db(name, path):
    print(f"--- Checking {name} ({path}) ---")
    if not os.path.exists(path.replace("sqlite:///", "")):
        print("File does not exist.")
        return

    engine = create_engine(path)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        exercises = session.query(ExerciseORM).filter(ExerciseORM.name.ilike("%face pull%")).all()
        if exercises:
            for ex in exercises:
                print(f"Found: {ex.name} (ID: {ex.id}, Type: {ex.type})")
        else:
            print("Face Pull NOT found.")
            
        # Also list all for context
        # all_ex = session.query(ExerciseORM).limit(5).all()
        # print("First 5 exercises:", [e.name for e in all_ex])
    except Exception as e:
        print(f"Error reading DB: {e}")
    finally:
        session.close()

# Check Global
check_db("Global", GLOBAL_DB_PATH)

# Check Default Trainer (guessing the ID might be 'trainer_default' or just 'default')
# Based on routes.py default value "trainer_default", the file should be "trainer_trainer_default.db"
check_db("Trainer Default", "sqlite:///./db/trainer_trainer_default.db")
