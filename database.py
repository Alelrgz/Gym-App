from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# --- CONFIGURATION ---
# Use environment variable for DB URL (Render provides this)
# Default to local unified SQLite file for development
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{os.path.join(os.path.dirname(__file__), 'db', 'gym_app.db')}")

# Fix for Render/Heroku: SQLAlchemy requires postgresql://, but Render might provide postgres://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

# Adjust connection args for SQLite (not needed for Postgres)
connect_args = {}
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

# --- ENGINE & SESSION ---
# Optimize connection pooling for Scale (1000+ users)
engine = create_engine(
    DATABASE_URL, 
    connect_args=connect_args,
    pool_size=20,          # Keep 20 connections open
    max_overflow=10,       # Allow 10 more during spikes
    pool_timeout=30,       # Wait 30s before giving up
    pool_recycle=1800      # Recycle connections every 30 mins
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# --- DEPENDENCY ---
def get_db():
    """
    Dependency for FastAPI Routes.
    Yields a database session and closes it after the request.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- UTILS ---
# Helper to get raw session (for background tasks/scripts)
def get_db_session():
    return SessionLocal()

