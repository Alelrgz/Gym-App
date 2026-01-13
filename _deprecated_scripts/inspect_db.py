from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text

# Path to the database
DB_PATH = "sqlite:///./db/client_user_123.db"

def inspect_db():
    engine = create_engine(DB_PATH)
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        print("--- Inspecting Client Profile ---")
        # Assuming table name is 'client_profiles' or similar based on models_orm
        # Use simple SQL to avoid importing models if possible, or print tables first
        result = session.execute(text("SELECT name FROM sqlite_master WHERE type='table';"))
        tables = [row[0] for row in result]
        print(f"Tables: {tables}")

        if 'client_profile' in tables:
            profiles = session.execute(text("SELECT * FROM client_profile")).fetchall()
            print(f"Profiles count: {len(profiles)}")
            for p in profiles:
                print(p)
        
        if 'client_schedule' in tables:
            events = session.execute(text("SELECT * FROM client_schedule")).fetchall()
            print(f"Schedule events count: {len(events)}")
            for e in events[:5]: # Show first 5
                print(e)

    except Exception as e:
        print(f"Error inspecting DB: {e}")
    finally:
        session.close()

if __name__ == "__main__":
    inspect_db()
