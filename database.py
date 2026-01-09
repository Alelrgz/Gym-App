from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# Global database (exercises only)
GLOBAL_DB_PATH = "sqlite:///./db/global.db"
global_engine = create_engine(GLOBAL_DB_PATH, connect_args={"check_same_thread": False})
GlobalSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=global_engine)

# Base for ORM models
Base = declarative_base()

# Function to get trainer-specific database
def get_trainer_db_path(trainer_id: str):
    """Get the database path for a specific trainer"""
    db_folder = os.path.join(os.path.dirname(__file__), "db")
    os.makedirs(db_folder, exist_ok=True)
    return f"sqlite:///{db_folder}/trainer_{trainer_id}.db"

def get_trainer_session(trainer_id: str):
    """Get a database session for a specific trainer"""
    db_path = get_trainer_db_path(trainer_id)
    trainer_engine = create_engine(db_path, connect_args={"check_same_thread": False})
    # Create tables if they don't exist
    Base.metadata.create_all(bind=trainer_engine)
    TrainerSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=trainer_engine)
    return TrainerSessionLocal()

# Dependency for FastAPI
def get_db():
    """Legacy function - now returns global DB for exercises"""
    db = GlobalSessionLocal()
    try:
        yield db
    finally:
        db.close()

# Function to get client-specific database
def get_client_db_path(client_id: str):
    """Get the database path for a specific client"""
    db_folder = os.path.join(os.path.dirname(__file__), "db")
    os.makedirs(db_folder, exist_ok=True)
    return f"sqlite:///{db_folder}/client_{client_id}.db"

def get_client_session(client_id: str):
    """Get a database session for a specific client"""
    db_path = get_client_db_path(client_id)
    client_engine = create_engine(db_path, connect_args={"check_same_thread": False})
    # Create tables if they don't exist
    # Note: We need to import the client models before calling create_all
    # to ensure they are registered with Base. Or we can pass the specific tables.
    # For now, we'll assume Base contains all models, but we might want to separate Bases later.
    # To avoid issues, we will import models inside the function or ensure they are imported at top level of app.
    # A better approach for separate DBs is to have separate Bases, but sharing Base is okay for simple cases
    # as long as we don't mind empty tables being created if we used create_all(engine).
    # However, since we are using the SAME Base for all, create_all will try to create ALL tables.
    # This is fine for SQLite as separate files mean separate schemas.
    
    Base.metadata.create_all(bind=client_engine)
    ClientSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=client_engine)
    return ClientSessionLocal()
