from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# --- CONFIGURATION ---
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{os.path.join(os.path.dirname(__file__), 'db', 'gym_app.db')}")

# Fix for Render/Heroku: SQLAlchemy requires postgresql://, but Render might provide postgres://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

IS_POSTGRES = DATABASE_URL.startswith("postgresql")

# --- ENGINE & SESSION ---
if IS_POSTGRES:
    # Production: PostgreSQL with connection pooling
    engine = create_engine(
        DATABASE_URL,
        pool_size=20,
        max_overflow=10,
        pool_timeout=30,
        pool_recycle=1800
    )
else:
    # Development: SQLite (no connection pooling)
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False}
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# --- EARLY MIGRATIONS (runs at import time, before FastAPI starts) ---
# This ensures columns exist before any ORM query can reference them
def _run_early_migrations():
    """Add missing columns to existing tables. Runs once at import time."""
    from sqlalchemy import text
    try:
        with engine.connect() as conn:
            # Check if users table exists first
            if IS_POSTGRES:
                result = conn.execute(text(
                    "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'users')"
                ))
                if not result.scalar():
                    return  # Table doesn't exist yet, create_all will handle it

                # Get existing columns
                result = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns WHERE table_name = 'users'"
                ))
                existing = {row[0] for row in result}

                needed_columns = [
                    ('phone', 'TEXT'),
                    ('must_change_password', 'BOOLEAN DEFAULT FALSE'),
                    ('profile_picture', 'TEXT'),
                    ('bio', 'TEXT'),
                    ('specialties', 'TEXT'),
                    ('settings', 'TEXT'),
                    ('gym_name', 'TEXT'),
                    ('gym_logo', 'TEXT'),
                    ('session_rate', 'DOUBLE PRECISION'),
                    ('stripe_account_id', 'TEXT'),
                    ('stripe_account_status', 'TEXT'),
                    ('spotify_access_token', 'TEXT'),
                    ('spotify_refresh_token', 'TEXT'),
                    ('spotify_token_expires_at', 'TEXT'),
                    ('terms_agreed_at', 'TEXT'),
                    ('shower_timer_minutes', 'INTEGER'),
                    ('shower_daily_limit', 'INTEGER'),
                    ('device_api_key', 'TEXT'),
                ]

                for col_name, col_type in needed_columns:
                    if col_name not in existing:
                        try:
                            conn.execute(text(
                                f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {col_name} {col_type}"
                            ))
                            conn.commit()
                        except Exception:
                            try:
                                conn.rollback()
                            except Exception:
                                pass
    except Exception:
        pass  # Database might not be ready yet — startup_event will retry

_run_early_migrations()

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
def get_db_session():
    return SessionLocal()
