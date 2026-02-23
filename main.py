import os
import sys
import time
import json
import logging
import base64
import secrets
import urllib.parse
from datetime import datetime, timedelta
from dotenv import load_dotenv
import httpx

# Load .env from the same directory as main.py
load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))
# Trigger reload v6.5 - friend routes added

# Set up logging to see errors in the console
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("gym_app")

# Ensure the DB directory exists
if not os.path.exists("db"):
    os.makedirs("db")
    logger.info("Created 'db' directory")

try:
    from fastapi import FastAPI, Request
    from fastapi.responses import HTMLResponse, RedirectResponse
    from fastapi.staticfiles import StaticFiles
    from fastapi.templating import Jinja2Templates
    from fastapi import WebSocket, WebSocketDisconnect
    import uvicorn
    from fastapi.middleware.cors import CORSMiddleware
    from routes import router
    from sockets import manager, start_file_watcher
    from simple_auth import simple_auth_router, SECRET_KEY, ALGORITHM
    from jose import jwt, JWTError
    from database import engine, Base
    import models_orm # Register models
    from models import TrainerData, JoinGymRequest, SelectTrainerRequest # Import models
    from services import UserService, get_user_service
    from service_modules.gym_assignment_service import get_gym_assignment_service, GymAssignmentService
    from auth import get_current_user
    from fastapi import Depends, HTTPException
    from models_orm import UserORM
    # Rate limiting
    from slowapi import Limiter, _rate_limit_exceeded_handler
    from slowapi.util import get_remote_address
    from slowapi.errors import RateLimitExceeded
except ImportError as e:
    logger.error(f"Missing dependency: {e}")
    logger.info("Please run: pip install fastapi uvicorn sqlalchemy jinja2 python-multipart slowapi")
    sys.exit(1)

# Rate limiter instance
limiter = Limiter(key_func=get_remote_address)

app = FastAPI()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Cache busting - timestamp changes on every server restart
CACHE_BUSTER = str(int(time.time()))

# CORS configuration
from database import IS_POSTGRES
cors_origins_str = os.getenv("CORS_ORIGINS", "")
if cors_origins_str:
    cors_origins = [o.strip() for o in cors_origins_str.split(",")]
elif IS_POSTGRES:
    logger.warning("CORS_ORIGINS not set in production — defaulting to same-origin only")
    cors_origins = []
else:
    cors_origins = ["*"]  # Allow all in local dev

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# Production security middleware: HTTPS redirect + HSTS header
if IS_POSTGRES:
    from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware
    from starlette.middleware.base import BaseHTTPMiddleware

    class HSTSMiddleware(BaseHTTPMiddleware):
        async def dispatch(self, request, call_next):
            response = await call_next(request)
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
            return response

    # Note: on Render/Railway, the platform terminates TLS at the load balancer
    # and forwards requests as HTTP internally. X-Forwarded-Proto tells us the
    # original protocol. We skip HTTPSRedirectMiddleware here because the platform
    # handles HTTPS enforcement. We still add HSTS so browsers remember to use HTTPS.
    app.add_middleware(HSTSMiddleware)
    logger.info("Production security: HSTS enabled")

# Global error handler - prevent stack trace leaks in production
from fastapi.responses import JSONResponse

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled error on {request.method} {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})

# App info
APP_NAME = "FitOS"
APP_VERSION = "1.0.0"

# Health check endpoint for monitoring
@app.get("/health")
async def health_check():
    """Health check endpoint for load balancers and monitoring."""
    return {"status": "ok"}

@app.get("/api/version")
async def get_version():
    """Get app version info for debugging deployed instances."""
    from service_modules.storage_service import get_storage_info
    storage = get_storage_info()
    return {
        "name": APP_NAME,
        "version": APP_VERSION,
        "environment": "production" if os.getenv("DATABASE_URL", "").startswith("postgres") else "development",
        "storage": storage["provider"]
    }

# Mount static and templates
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")
templates.env.auto_reload = True

# --- ROUTES DEFINED DIRECTLY ON APP ---
# (Removed - now using gym_assignment_router included directly)

@app.get("/api/trainer/data", response_model=TrainerData)
async def get_trainer_data_direct(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    data = service.get_trainer(current_user.id)
    return data

@app.get("/api/stripe/publishable-key")
async def get_stripe_publishable_key():
    """Get Stripe publishable key for frontend."""
    key = os.getenv("STRIPE_PUBLISHABLE_KEY", "")
    if not key or key.startswith("your_"):
        raise HTTPException(status_code=400, detail="Stripe not configured")
    return {"publishable_key": key}
# ---------------------------------------------

app.include_router(router)
app.include_router(simple_auth_router, prefix="/auth")

# Include gym assignment router directly
from route_modules.gym_assignment_routes import router as gym_assignment_router
app.include_router(gym_assignment_router)

# Include message routes
from route_modules.message_routes import router as message_router
app.include_router(message_router)

# Include profile routes
from route_modules.profile_routes import router as profile_router
app.include_router(profile_router)

# Include staff routes
from route_modules.staff_routes import router as staff_router
app.include_router(staff_router)

# Include automated message routes
from route_modules.automated_message_routes import router as auto_msg_router
app.include_router(auto_msg_router)

# Include course routes
from route_modules.course_routes import router as course_router
app.include_router(course_router)

# Include trainer matching routes (module not yet available)
# from route_modules.trainer_matching_routes import router as trainer_matching_router
# app.include_router(trainer_matching_router)
# print("DEBUG: Trainer matching router included")

# Include CRM routes
from route_modules.crm_routes import router as crm_router
app.include_router(crm_router)

# Include NFC shower routes
from route_modules.shower_routes import router as shower_router
app.include_router(shower_router)

from route_modules.terminal_routes import router as terminal_router
app.include_router(terminal_router)


def _safe_add_columns(engine, table_name, columns_list):
    """Add columns to a table using IF NOT EXISTS (PostgreSQL 9.6+) or fallback."""
    from sqlalchemy import text, inspect
    from database import IS_POSTGRES

    # Get existing columns to skip ones that already exist
    try:
        inspector = inspect(engine)
        existing = {col['name'] for col in inspector.get_columns(table_name)}
    except Exception:
        existing = set()

    for col_name, col_type in columns_list:
        if col_name in existing:
            continue  # Already exists, skip
        try:
            with engine.begin() as conn:
                if IS_POSTGRES:
                    conn.execute(text(f"ALTER TABLE {table_name} ADD COLUMN IF NOT EXISTS {col_name} {col_type}"))
                else:
                    conn.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {col_name} {col_type}"))
            logger.info(f"Migration: added {col_name} to {table_name}")
        except Exception as e:
            logger.warning(f"Migration: {col_name} on {table_name} failed: {e}")


def run_migrations(engine):
    """Run database migrations to add new columns."""
    from sqlalchemy import text, inspect

    inspector = inspect(engine)

    # Check if exercises table exists and add new columns if needed
    if 'exercises' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('exercises')]

        new_columns = [
            ('description', 'TEXT'),
            ('default_duration', 'INTEGER'),
            ('difficulty', 'TEXT'),
            ('thumbnail_url', 'TEXT'),
            ('video_url', 'TEXT'),
            ('steps_json', 'TEXT')
        ]

        with engine.connect() as conn:
            for col_name, col_type in new_columns:
                if col_name not in columns:
                    try:
                        conn.execute(text(f'ALTER TABLE exercises ADD COLUMN {col_name} {col_type}'))
                        conn.commit()
                        logger.info(f"Added column {col_name} to exercises table")
                    except Exception as e:
                        logger.debug(f"Column {col_name} may already exist: {e}")

    # Check if courses table exists and add new columns if needed
    if 'courses' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('courses')]

        course_columns = [
            ('days_of_week_json', 'TEXT'),
            ('course_type', 'TEXT'),
            ('cover_image_url', 'TEXT'),
            ('trailer_url', 'TEXT'),
        ]

        with engine.connect() as conn:
            for col_name, col_type in course_columns:
                if col_name not in columns:
                    try:
                        conn.execute(text(f'ALTER TABLE courses ADD COLUMN {col_name} {col_type}'))
                        conn.commit()
                        logger.info(f"Added column {col_name} to courses table")
                    except Exception as e:
                        logger.debug(f"Column {col_name} may already exist: {e}")

    # Check if trainer_schedule table exists and add course_id column if needed
    if 'trainer_schedule' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('trainer_schedule')]

        if 'course_id' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text('ALTER TABLE trainer_schedule ADD COLUMN course_id TEXT'))
                    conn.commit()
                    logger.info("Added column course_id to trainer_schedule table")
                except Exception as e:
                    logger.debug(f"Column course_id may already exist: {e}")

    # Check if client_schedule table exists and add course_id column if needed
    if 'client_schedule' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('client_schedule')]

        if 'course_id' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text('ALTER TABLE client_schedule ADD COLUMN course_id TEXT'))
                    conn.commit()
                    logger.info("Added column course_id to client_schedule table")
                except Exception as e:
                    logger.debug(f"Column course_id may already exist: {e}")

    # Check if users table exists and add sub_role column if needed
    if 'users' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('users')]

        if 'sub_role' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text('ALTER TABLE users ADD COLUMN sub_role TEXT'))
                    conn.commit()
                    logger.info("Added column sub_role to users table")
                except Exception as e:
                    logger.debug(f"Column sub_role may already exist: {e}")

    # Add fitness_goal and base_calories to client_diet_settings
    if 'client_diet_settings' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('client_diet_settings')]

        if 'fitness_goal' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE client_diet_settings ADD COLUMN fitness_goal TEXT DEFAULT 'maintain'"))
                    conn.commit()
                    logger.info("Added column fitness_goal to client_diet_settings table")
                except Exception as e:
                    logger.debug(f"Column fitness_goal may already exist: {e}")

        if 'base_calories' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE client_diet_settings ADD COLUMN base_calories INTEGER DEFAULT 2000"))
                    conn.commit()
                    logger.info("Added column base_calories to client_diet_settings table")
                except Exception as e:
                    logger.debug(f"Column base_calories may already exist: {e}")

    # Add session_type to appointments
    if 'appointments' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('appointments')]
        if 'session_type' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE appointments ADD COLUMN session_type TEXT"))
                    conn.commit()
                    logger.info("Added column session_type to appointments table")
                except Exception as e:
                    logger.debug(f"Column session_type may already exist: {e}")

    # Add new columns to client_profile (PostgreSQL-safe)
    _safe_add_columns(engine, 'client_profile', [
        ("date_of_birth", "TEXT"),
        ("emergency_contact_name", "TEXT"),
        ("emergency_contact_phone", "TEXT"),
        ("is_premium", "BOOLEAN DEFAULT FALSE"),
        ("privacy_mode", "TEXT DEFAULT 'public'"),
        ("weight", "DOUBLE PRECISION"),
        ("body_fat_pct", "DOUBLE PRECISION"),
        ("fat_mass", "DOUBLE PRECISION"),
        ("lean_mass", "DOUBLE PRECISION"),
        ("strength_goal_upper", "INTEGER"),
        ("strength_goal_lower", "INTEGER"),
        ("strength_goal_cardio", "INTEGER"),
        ("health_score", "INTEGER DEFAULT 0"),
        ("gems", "INTEGER DEFAULT 0"),
        ("nutritionist_id", "TEXT"),
        ("weight_goal", "DOUBLE PRECISION"),
        ("current_split_id", "TEXT"),
        ("split_expiry_date", "TEXT"),
    ])

    # Add all potentially missing columns to users table (PostgreSQL-safe with IF NOT EXISTS)
    _safe_add_columns(engine, 'users', [
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
        ('stripe_terminal_location_id', 'TEXT'),
        ('stripe_terminal_reader_id', 'TEXT'),
        ('spotify_access_token', 'TEXT'),
        ('spotify_refresh_token', 'TEXT'),
        ('spotify_token_expires_at', 'TEXT'),
        ('terms_agreed_at', 'TEXT'),
        ('shower_timer_minutes', 'INTEGER'),
        ('shower_daily_limit', 'INTEGER'),
        ('device_api_key', 'TEXT'),
    ])

    # Add health_score to client_daily_diet_summary
    if 'client_daily_diet_summary' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('client_daily_diet_summary')]

        if 'health_score' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE client_daily_diet_summary ADD COLUMN health_score INTEGER DEFAULT 0"))
                    conn.commit()
                    logger.info("Added column health_score to client_daily_diet_summary table")
                except Exception as e:
                    logger.debug(f"Column health_score may already exist: {e}")

    # Add capacity columns to courses table
    if 'courses' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('courses')]
        capacity_cols = [
            ('max_capacity', 'INTEGER'),
            ('waitlist_enabled', 'BOOLEAN DEFAULT 1'),
        ]
        for col_name, col_type in capacity_cols:
            if col_name not in columns:
                with engine.connect() as conn:
                    try:
                        conn.execute(text(f"ALTER TABLE courses ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                        logger.info(f"Added column {col_name} to courses table")
                    except Exception as e:
                        logger.debug(f"Column {col_name} may already exist: {e}")

    # Add max_capacity to course_lessons table
    if 'course_lessons' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('course_lessons')]
        if 'max_capacity' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE course_lessons ADD COLUMN max_capacity INTEGER"))
                    conn.commit()
                    logger.info("Added column max_capacity to course_lessons table")
                except Exception as e:
                    logger.debug(f"Column max_capacity may already exist: {e}")

    # Add stripe_coupon_id to plan_offers table
    if 'plan_offers' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('plan_offers')]
        if 'stripe_coupon_id' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE plan_offers ADD COLUMN stripe_coupon_id TEXT"))
                    conn.commit()
                    logger.info("Added column stripe_coupon_id to plan_offers table")
                except Exception as e:
                    logger.debug(f"Column stripe_coupon_id may already exist: {e}")

    # Add stripe_payment_intent_id to client_subscriptions table
    if 'client_subscriptions' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('client_subscriptions')]
        if 'stripe_payment_intent_id' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE client_subscriptions ADD COLUMN stripe_payment_intent_id TEXT"))
                    conn.commit()
                    logger.info("Added column stripe_payment_intent_id to client_subscriptions table")
                except Exception as e:
                    logger.debug(f"Column stripe_payment_intent_id may already exist: {e}")

    # Add session_rate to users table
    if 'users' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('users')]
        if 'session_rate' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE users ADD COLUMN session_rate REAL"))
                    conn.commit()
                    logger.info("Added column session_rate to users table")
                except Exception as e:
                    logger.debug(f"Column session_rate may already exist: {e}")

    # Add gym_name and gym_logo columns to users table (for owners)
    if 'users' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('users')]
        gym_cols = {'gym_name': 'TEXT', 'gym_logo': 'TEXT'}
        for col_name, col_type in gym_cols.items():
            if col_name not in columns:
                with engine.connect() as conn:
                    try:
                        conn.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                        logger.info(f"Added column {col_name} to users table")
                    except Exception as e:
                        logger.debug(f"Column {col_name} may already exist: {e}")

    # Add payment columns to appointments table
    if 'appointments' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('appointments')]
        appt_new_cols = {
            'price': 'REAL',
            'payment_method': 'TEXT',
            'payment_status': "TEXT DEFAULT 'free'",
            'stripe_payment_intent_id': 'TEXT'
        }
        for col_name, col_type in appt_new_cols.items():
            if col_name not in columns:
                with engine.connect() as conn:
                    try:
                        conn.execute(text(f"ALTER TABLE appointments ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                        logger.info(f"Added column {col_name} to appointments table")
                    except Exception as e:
                        logger.debug(f"Column {col_name} may already exist: {e}")

    # Add body_fat_pct/fat_mass/lean_mass columns to weight_history if missing
    if 'weight_history' in inspector.get_table_names():
        columns = [c['name'] for c in inspector.get_columns('weight_history')]
        wh_cols = {
            'body_fat_pct': 'REAL',
            'fat_mass': 'REAL',
            'lean_mass': 'REAL',
        }
        for col_name, col_type in wh_cols.items():
            if col_name not in columns:
                with engine.connect() as conn:
                    try:
                        conn.execute(text(f"ALTER TABLE weight_history ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                        logger.info(f"Added column {col_name} to weight_history table")
                    except Exception as e:
                        logger.debug(f"Column {col_name} may already exist: {e}")

    # Add duration/distance/metric_type columns to client_exercise_log if missing
    inspector = inspect(engine)
    if 'client_exercise_log' in inspector.get_table_names():
        columns = [c['name'] for c in inspector.get_columns('client_exercise_log')]
        exercise_log_cols = {
            'duration': 'REAL',
            'distance': 'REAL',
            'metric_type': "TEXT DEFAULT 'weight_reps'"
        }
        for col_name, col_type in exercise_log_cols.items():
            if col_name not in columns:
                with engine.connect() as conn:
                    try:
                        conn.execute(text(f"ALTER TABLE client_exercise_log ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                        logger.info(f"Added column {col_name} to client_exercise_log table")
                    except Exception as e:
                        logger.debug(f"Column {col_name} may already exist: {e}")

    # Add alternative_index to weekly_meal_plan table
    if 'weekly_meal_plan' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('weekly_meal_plan')]
        if 'alternative_index' not in columns:
            with engine.connect() as conn:
                try:
                    conn.execute(text("ALTER TABLE weekly_meal_plan ADD COLUMN alternative_index INTEGER DEFAULT 0"))
                    conn.commit()
                    logger.info("Added column alternative_index to weekly_meal_plan table")
                except Exception as e:
                    logger.debug(f"Column alternative_index may already exist: {e}")

def background_trigger_checker():
    """Background thread that periodically checks for automated message triggers."""
    import time
    from service_modules.trigger_check_service import get_trigger_check_service

    # Wait 60 seconds before first check to let the app fully initialize
    time.sleep(60)

    while True:
        try:
            logger.info("Running automated message trigger check...")
            trigger_service = get_trigger_check_service()
            results = trigger_service.check_all_triggers()
            logger.info(f"Trigger check complete: {results['messages_sent']} sent, {results['messages_skipped']} skipped")
        except Exception as e:
            logger.error(f"Background trigger check error: {e}")

        # Sleep for 15 minutes between checks
        time.sleep(900)


@app.on_event("startup")
async def startup_event():
    logger.info("Initializing Database...")

    # Create any new tables (nfc_tags, shower_usage, etc.)
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables verified/created.")
    except Exception as e:
        logger.error(f"create_all error: {e}")

    # Run remaining migrations (client_profile, exercises, etc.)
    # Note: users columns are already handled by _run_early_migrations() in database.py
    try:
        run_migrations(engine)
    except Exception as e:
        logger.error(f"run_migrations error: {e}")

    # Log DB info
    db_url = str(engine.url)
    if "sqlite" in db_url:
        logger.info("Using SQLite Database (Development)")
    elif "postgresql" in db_url:
        logger.info("Using PostgreSQL Database (Production)")

    # Log storage provider
    from service_modules.upload_helper import _is_cloudinary_ready
    if _is_cloudinary_ready():
        logger.info("File Storage: Cloudinary (Production)")
    else:
        logger.info("File Storage: Local Filesystem (Development)")

    # Start background thread for automated message trigger checking
    import threading
    trigger_thread = threading.Thread(target=background_trigger_checker, daemon=True)
    trigger_thread.start()
    logger.info("Automated message trigger checker started (runs every 15 minutes)")

    logger.info("Registered Routes:")
    for route in app.routes:
        logger.info(f"{route.path} [{route.name}]")

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    # Try to authenticate user from cookie
    user_id = None
    username = None
    profile_picture = None
    try:
        token = websocket.cookies.get("access_token")
        if token:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            # Note: "sub" contains the USERNAME, not the user_id
            token_username = payload.get("sub")
            logger.info(f"WebSocket token for username: {token_username}")
            # Look up actual user_id (UUID) from database
            from database import get_db_session
            from models_orm import UserORM
            db = get_db_session()
            user = db.query(UserORM).filter(UserORM.username == token_username).first()
            if user:
                user_id = user.id  # The actual UUID
                username = user.username
                profile_picture = user.profile_picture
                logger.info(f"WebSocket authenticated - user_id: {user_id}, username: {username}")
            db.close()
    except Exception as e:
        logger.debug(f"WebSocket auth failed (continuing anyway): {e}")

    await manager.connect(websocket, user_id)
    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
                msg_type = msg.get("type")

                if msg_type == "ping":
                    await websocket.send_json({"type": "pong"})

                # CO-OP Invitation: Inviter sends this to invite a friend
                elif msg_type == "coop_invite" and user_id:
                    partner_id = msg.get("partner_id")
                    logger.info(f"CO-OP Invite: {username} (id={user_id}) inviting partner_id={partner_id}")
                    logger.info(f"CO-OP Invite: Online users = {list(manager.user_connections.keys())}")
                    if partner_id and manager.is_user_online(partner_id):
                        logger.info(f"CO-OP Invite: Partner {partner_id} is online, sending invite with from_id={user_id}")
                        # Send invitation to the partner
                        await manager.send_to_user(partner_id, {
                            "type": "coop_invite",
                            "from_id": user_id,
                            "from_name": username,
                            "from_picture": profile_picture
                        })
                        await websocket.send_json({"type": "coop_invite_sent", "partner_id": partner_id})
                    else:
                        logger.info(f"CO-OP Invite: Partner {partner_id} NOT online")
                        await websocket.send_json({"type": "coop_invite_failed", "reason": "Friend is offline"})

                # CO-OP Accept: Friend accepts the invitation
                elif msg_type == "coop_accept" and user_id:
                    inviter_id = msg.get("inviter_id")
                    logger.info(f"CO-OP Accept: {username} accepting invite from inviter_id={inviter_id}")
                    logger.info(f"CO-OP Accept: Online users = {list(manager.user_connections.keys())}")
                    if inviter_id and manager.is_user_online(inviter_id):
                        logger.info(f"CO-OP Accept: Inviter {inviter_id} is online, sending coop_accepted")
                        await manager.send_to_user(inviter_id, {
                            "type": "coop_accepted",
                            "partner_id": user_id,
                            "partner_name": username,
                            "partner_picture": profile_picture
                        })
                        await websocket.send_json({"type": "coop_accept_confirmed"})
                    else:
                        logger.info(f"CO-OP Accept: Inviter {inviter_id} NOT online or inviter_id is None")

                # CO-OP Decline: Friend declines the invitation
                elif msg_type == "coop_decline" and user_id:
                    inviter_id = msg.get("inviter_id")
                    if inviter_id and manager.is_user_online(inviter_id):
                        await manager.send_to_user(inviter_id, {
                            "type": "coop_declined",
                            "partner_name": username
                        })

            except json.JSONDecodeError:
                pass
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    try:
        response = await call_next(request)
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0, private"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "SAMEORIGIN"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(self), microphone=(), geolocation=()"
        return response
    except Exception as e:
        logger.error(f"Request error: {request.method} {request.url.path} - {e}")
        raise e

# Removed conflicting login/register routes (now handled by simple_auth with /auth prefix)

# --- LEGAL PAGES ---
@app.get("/terms", response_class=HTMLResponse)
async def terms_page(request: Request):
    return templates.TemplateResponse("legal.html", {"request": request, "title": "Termini di Servizio | Terms of Service", "page": "terms"})

@app.get("/privacy", response_class=HTMLResponse)
async def privacy_page(request: Request):
    return templates.TemplateResponse("legal.html", {"request": request, "title": "Informativa sulla Privacy | Privacy Policy", "page": "privacy"})

@app.get("/cookies", response_class=HTMLResponse)
async def cookies_page(request: Request):
    return templates.TemplateResponse("legal.html", {"request": request, "title": "Politica sui Cookie | Cookie Policy", "page": "cookies"})

# --- GDPR DATA EXPORT ---
from sqlalchemy.orm import Session
from database import get_db

@app.get("/api/gdpr/export-data")
async def gdpr_export_data(request: Request, current_user: UserORM = Depends(get_current_user), db: Session = Depends(get_db)):
    """GDPR Art. 20 - Data portability. Returns all user data as JSON."""
    from models_orm import (ClientProfileORM, WeightHistoryORM, ClientDietLogORM,
        ClientDailyDietSummaryORM, ClientDietSettingsORM, ClientExerciseLogORM,
        ClientScheduleORM, AppointmentORM, CheckInORM, PhysiquePhotoORM,
        MedicalCertificateORM, ClientDocumentORM, MessageORM, NotificationORM,
        ClientSubscriptionORM, PaymentORM, DailyQuestCompletionORM,
        LessonEnrollmentORM, FriendshipORM, NfcTagORM, ShowerUsageORM)

    user = db.query(UserORM).filter(UserORM.id == current_user.id).first()
    uid = user.id

    def rows_to_list(rows, exclude=None):
        exclude = exclude or {"hashed_password"}
        result = []
        for r in rows:
            d = {c.name: getattr(r, c.name) for c in r.__table__.columns if c.name not in exclude}
            result.append(d)
        return result

    data = {
        "export_date": datetime.utcnow().isoformat(),
        "account": rows_to_list([user])[0] if user else {},
        "profile": rows_to_list(db.query(ClientProfileORM).filter(ClientProfileORM.id == uid).all()),
        "weight_history": rows_to_list(db.query(WeightHistoryORM).filter(WeightHistoryORM.client_id == uid).all()),
        "diet_settings": rows_to_list(db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == uid).all()),
        "diet_logs": rows_to_list(db.query(ClientDietLogORM).filter(ClientDietLogORM.client_id == uid).all()),
        "diet_summaries": rows_to_list(db.query(ClientDailyDietSummaryORM).filter(ClientDailyDietSummaryORM.client_id == uid).all()),
        "exercise_logs": rows_to_list(db.query(ClientExerciseLogORM).filter(ClientExerciseLogORM.client_id == uid).all()),
        "schedule": rows_to_list(db.query(ClientScheduleORM).filter(ClientScheduleORM.client_id == uid).all()),
        "appointments": rows_to_list(db.query(AppointmentORM).filter(AppointmentORM.client_id == uid).all()),
        "checkins": rows_to_list(db.query(CheckInORM).filter(CheckInORM.member_id == uid).all()),
        "physique_photos": rows_to_list(db.query(PhysiquePhotoORM).filter(PhysiquePhotoORM.client_id == uid).all()),
        "medical_certificates": rows_to_list(db.query(MedicalCertificateORM).filter(MedicalCertificateORM.client_id == uid).all()),
        "documents": rows_to_list(db.query(ClientDocumentORM).filter(ClientDocumentORM.client_id == uid).all()),
        "messages_sent": rows_to_list(db.query(MessageORM).filter(MessageORM.sender_id == uid).all()),
        "notifications": rows_to_list(db.query(NotificationORM).filter(NotificationORM.user_id == uid).all()),
        "subscriptions": rows_to_list(db.query(ClientSubscriptionORM).filter(ClientSubscriptionORM.client_id == uid).all()),
        "payments": rows_to_list(db.query(PaymentORM).filter(PaymentORM.client_id == uid).all()),
        "quest_completions": rows_to_list(db.query(DailyQuestCompletionORM).filter(DailyQuestCompletionORM.client_id == uid).all()),
        "lesson_enrollments": rows_to_list(db.query(LessonEnrollmentORM).filter(LessonEnrollmentORM.client_id == uid).all()),
        "friendships": rows_to_list(db.query(FriendshipORM).filter(
            (FriendshipORM.user1_id == uid) | (FriendshipORM.user2_id == uid)
        ).all()),
        "nfc_tags": rows_to_list(db.query(NfcTagORM).filter(NfcTagORM.member_id == uid).all()),
        "shower_usage": rows_to_list(db.query(ShowerUsageORM).filter(ShowerUsageORM.member_id == uid).all()),
    }

    from fastapi.responses import Response
    return Response(
        content=json.dumps(data, indent=2, default=str),
        media_type="application/json",
        headers={"Content-Disposition": f"attachment; filename=fitos_data_export_{uid}.json"}
    )

# --- GDPR ACCOUNT DELETION ---
@app.post("/api/gdpr/delete-account")
async def gdpr_delete_account(request: Request, current_user: UserORM = Depends(get_current_user), db: Session = Depends(get_db)):
    """GDPR Art. 17 - Right to erasure. Permanently deletes user account and all associated data."""
    from models_orm import (ClientProfileORM, WeightHistoryORM, ClientDietLogORM,
        ClientDailyDietSummaryORM, ClientDietSettingsORM, ClientExerciseLogORM,
        ClientScheduleORM, AppointmentORM, CheckInORM, PhysiquePhotoORM,
        MedicalCertificateORM, ClientDocumentORM, MessageORM, NotificationORM,
        ClientSubscriptionORM, PaymentORM, DailyQuestCompletionORM,
        LessonEnrollmentORM, FriendshipORM, ConversationORM, ChatRequestORM,
        AutomatedMessageLogORM, NfcTagORM, ShowerUsageORM)
    import bcrypt

    body = await request.json()
    password = body.get("password", "")

    # Verify password before deletion
    user = db.query(UserORM).filter(UserORM.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if not bcrypt.checkpw(password.encode('utf-8'), user.hashed_password.encode('utf-8')):
        raise HTTPException(status_code=403, detail="Incorrect password")

    uid = user.id

    # Delete all associated data (order matters for FK constraints)
    db.query(ShowerUsageORM).filter(ShowerUsageORM.member_id == uid).delete()
    db.query(NfcTagORM).filter(NfcTagORM.member_id == uid).delete()
    db.query(AutomatedMessageLogORM).filter(AutomatedMessageLogORM.client_id == uid).delete()
    db.query(DailyQuestCompletionORM).filter(DailyQuestCompletionORM.client_id == uid).delete()
    db.query(LessonEnrollmentORM).filter(LessonEnrollmentORM.client_id == uid).delete()
    db.query(NotificationORM).filter(NotificationORM.user_id == uid).delete()
    db.query(MessageORM).filter(MessageORM.sender_id == uid).delete()
    db.query(ConversationORM).filter(
        (ConversationORM.client_id == uid) | (ConversationORM.user1_id == uid) | (ConversationORM.user2_id == uid)
    ).delete(synchronize_session=False)
    db.query(ChatRequestORM).filter(
        (ChatRequestORM.from_user_id == uid) | (ChatRequestORM.to_user_id == uid)
    ).delete(synchronize_session=False)
    db.query(FriendshipORM).filter(
        (FriendshipORM.user1_id == uid) | (FriendshipORM.user2_id == uid)
    ).delete(synchronize_session=False)
    db.query(PaymentORM).filter(PaymentORM.client_id == uid).delete()
    db.query(ClientSubscriptionORM).filter(ClientSubscriptionORM.client_id == uid).delete()
    db.query(PhysiquePhotoORM).filter(PhysiquePhotoORM.client_id == uid).delete()
    db.query(MedicalCertificateORM).filter(MedicalCertificateORM.client_id == uid).delete()
    db.query(ClientDocumentORM).filter(ClientDocumentORM.client_id == uid).delete()
    db.query(CheckInORM).filter(CheckInORM.member_id == uid).delete()
    db.query(AppointmentORM).filter(AppointmentORM.client_id == uid).delete()
    db.query(ClientScheduleORM).filter(ClientScheduleORM.client_id == uid).delete()
    db.query(ClientExerciseLogORM).filter(ClientExerciseLogORM.client_id == uid).delete()
    db.query(ClientDailyDietSummaryORM).filter(ClientDailyDietSummaryORM.client_id == uid).delete()
    db.query(ClientDietLogORM).filter(ClientDietLogORM.client_id == uid).delete()
    db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == uid).delete()
    db.query(WeightHistoryORM).filter(WeightHistoryORM.client_id == uid).delete()
    db.query(ClientProfileORM).filter(ClientProfileORM.id == uid).delete()
    db.query(UserORM).filter(UserORM.id == uid).delete()

    db.commit()
    logger.info(f"GDPR: Account deleted for user {uid}")

    response = JSONResponse(content={"detail": "Account deleted successfully"})
    response.delete_cookie("access_token")
    return response

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request, gym_id: str = "iron_gym", role: str = "client", mode: str = "dashboard"):
    token = request.cookies.get("access_token")
    if not token:
        return RedirectResponse(url="/auth/login", status_code=302)

    try:
        jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        return RedirectResponse(url="/auth/login", status_code=302)

    # Redirect legacy automation mode to dashboard (merged)
    if mode == "automation":
        mode = "dashboard"

    # Determine which template to render based on role
    # If role is default (client) but token says otherwise, trust token
    username = None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        token_role = payload.get("role")
        username = payload.get("sub")
        if token_role and role == "client":
            role = token_role
    except Exception:
        pass

    template_name = "client.html"
    if mode == "workout":
        template_name = "workout.html"
    elif role == "trainer":
        template_name = "trainer.html"
    elif role == "staff":
        template_name = "staff.html"
    elif role == "owner":
        template_name = "owner.html"
    elif role == "nutritionist":
        template_name = "nutritionist.html"

    # Pre-load trainer name for client home to avoid loading flash
    server_trainer_name = None
    server_trainer_picture = None
    if role == "client" and username and template_name == "client.html":
        try:
            from database import get_db_session
            from models_orm import UserORM as _UserORM, ClientProfileORM
            _db = get_db_session()
            client_user = _db.query(_UserORM).filter(_UserORM.username == username).first()
            if client_user:
                client_profile = _db.query(ClientProfileORM).filter(ClientProfileORM.id == client_user.id).first()
                if client_profile and client_profile.trainer_id:
                    trainer = _db.query(_UserORM).filter(_UserORM.id == client_profile.trainer_id).first()
                    if trainer:
                        server_trainer_name = trainer.username
                        server_trainer_picture = trainer.profile_picture
            _db.close()
        except Exception as e:
            logger.warning(f"Failed to pre-load trainer name: {e}")

    logger.info(f"server_trainer_name={server_trainer_name} for username={username}")
    context = {
        "request": request,
        "gym_id": gym_id,
        "role": role,
        "mode": mode,
        "token": token,
        "cache_buster": str(int(time.time())),  # Use timestamp directly
        "static_build": False,
        "stripe_publishable_key": os.getenv("STRIPE_PUBLISHABLE_KEY", ""),
        "server_trainer_name": server_trainer_name,
        "server_trainer_picture": server_trainer_picture,
    }
    logger.info(f"Rendering {template_name} with cache_buster={context['cache_buster']}")
    return templates.TemplateResponse(template_name, context)



@app.post("/api/trainer/events")
async def add_trainer_event_direct(
    event_data: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.add_trainer_event(event_data, current_user.id)

@app.delete("/api/trainer/events/{event_id}")
async def delete_trainer_event_direct(
    event_id: str,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.remove_trainer_event(event_id, current_user.id)

@app.post("/api/trainer/schedule/complete")
async def complete_trainer_schedule_direct(
    payload: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.complete_trainer_schedule_item(payload, current_user.id)

# Moved to top
# ---------------------------------------------

@app.get("/trainer/personal", response_class=HTMLResponse)
async def read_trainer_personal(request: Request, gym_id: str = "default"):
    return templates.TemplateResponse("trainer_personal.html", {"request": request, "gym_id": gym_id, "role": "trainer", "mode": "personal", "cache_buster": CACHE_BUSTER})

@app.get("/trainer/courses", response_class=HTMLResponse)
async def read_trainer_courses(request: Request, gym_id: str = "default"):
    return templates.TemplateResponse("trainer_courses.html", {"request": request, "gym_id": gym_id, "role": "trainer", "mode": "courses", "cache_buster": CACHE_BUSTER})

@app.get("/course/workout/{course_id}", response_class=HTMLResponse)
async def course_workout_player(request: Request, course_id: str, gym_id: str = "default", current_user: UserORM = Depends(get_current_user)):
    """Course workout player with music integration"""
    return templates.TemplateResponse("course_workout.html", {
        "request": request,
        "course_id": course_id,
        "gym_id": gym_id,
        "role": current_user.role,
        "cache_buster": CACHE_BUSTER
    })

# ======================
# SPOTIFY OAUTH INTEGRATION
# ======================

# Spotify configuration
SPOTIFY_CLIENT_ID = os.environ.get("SPOTIFY_CLIENT_ID")
SPOTIFY_CLIENT_SECRET = os.environ.get("SPOTIFY_CLIENT_SECRET")
SPOTIFY_REDIRECT_URI = os.environ.get("SPOTIFY_REDIRECT_URI", "")  # Auto-detected from request if empty

def _get_spotify_redirect_uri(request: Request) -> str:
    """Build Spotify redirect URI from the incoming request's origin."""
    if SPOTIFY_REDIRECT_URI:
        return SPOTIFY_REDIRECT_URI
    base = str(request.base_url).rstrip("/")
    return f"{base}/api/spotify/callback"
SPOTIFY_SCOPES = "streaming user-read-email user-read-private user-modify-playback-state user-read-playback-state"

@app.get("/api/spotify/authorize")
async def spotify_authorize(request: Request, current_user: UserORM = Depends(get_current_user)):
    """Redirect user to Spotify authorization page"""
    if not SPOTIFY_CLIENT_ID:
        raise HTTPException(status_code=500, detail="Spotify client ID not configured")

    # Store user ID in state for callback
    state = base64.urlsafe_b64encode(current_user.id.encode()).decode()

    # Build authorization URL
    redirect_uri = _get_spotify_redirect_uri(request)
    auth_url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode({
        "response_type": "code",
        "client_id": SPOTIFY_CLIENT_ID,
        "scope": SPOTIFY_SCOPES,
        "redirect_uri": redirect_uri,
        "state": state
    })

    return RedirectResponse(url=auth_url)

@app.get("/api/spotify/callback")
async def spotify_callback(
    request: Request,
    code: str,
    state: str,
    user_service: UserService = Depends(get_user_service)
):
    """Handle Spotify OAuth callback"""
    if not SPOTIFY_CLIENT_ID or not SPOTIFY_CLIENT_SECRET:
        raise HTTPException(status_code=500, detail="Spotify credentials not configured")

    try:
        # Decode user ID from state
        user_id = base64.urlsafe_b64decode(state.encode()).decode()
        redirect_uri = _get_spotify_redirect_uri(request)

        # Exchange code for tokens
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://accounts.spotify.com/api/token",
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri
                },
                headers={
                    "Authorization": f"Basic {base64.b64encode(f'{SPOTIFY_CLIENT_ID}:{SPOTIFY_CLIENT_SECRET}'.encode()).decode()}"
                }
            )

            if response.status_code != 200:
                logger.error(f"Spotify token exchange failed: {response.text}")
                raise HTTPException(status_code=400, detail="Failed to exchange code for tokens")

            tokens = response.json()

        # Calculate expiration time
        expires_at = datetime.utcnow() + timedelta(seconds=tokens["expires_in"])

        # Update user with tokens
        success = user_service.update_spotify_tokens(
            user_id=user_id,
            access_token=tokens["access_token"],
            refresh_token=tokens["refresh_token"],
            expires_at=expires_at.isoformat()
        )

        if not success:
            raise HTTPException(status_code=500, detail="Failed to save Spotify tokens")

        # Redirect back to dashboard (use request origin to preserve cookies)
        base = str(request.base_url).rstrip("/")
        return RedirectResponse(url=f"{base}/?spotify_connected=true")

    except Exception as e:
        logger.error(f"Spotify callback error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/spotify/refresh")
async def spotify_refresh_token(
    current_user: UserORM = Depends(get_current_user),
    user_service: UserService = Depends(get_user_service)
):
    """Refresh Spotify access token"""
    if not current_user.spotify_refresh_token:
        raise HTTPException(status_code=400, detail="No refresh token available")

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://accounts.spotify.com/api/token",
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": current_user.spotify_refresh_token
                },
                headers={
                    "Authorization": f"Basic {base64.b64encode(f'{SPOTIFY_CLIENT_ID}:{SPOTIFY_CLIENT_SECRET}'.encode()).decode()}"
                }
            )

            if response.status_code != 200:
                logger.error(f"Spotify token refresh failed: {response.text}")
                raise HTTPException(status_code=400, detail="Failed to refresh token")

            tokens = response.json()

        # Calculate new expiration time
        expires_at = datetime.utcnow() + timedelta(seconds=tokens["expires_in"])

        # Update user with new access token
        success = user_service.update_spotify_tokens(
            user_id=current_user.id,
            access_token=tokens["access_token"],
            refresh_token=tokens.get("refresh_token", current_user.spotify_refresh_token),
            expires_at=expires_at.isoformat()
        )

        if not success:
            raise HTTPException(status_code=500, detail="Failed to save refreshed token")

        return {"access_token": tokens["access_token"], "expires_in": tokens["expires_in"]}

    except Exception as e:
        logger.error(f"Spotify refresh error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/spotify/disconnect")
async def spotify_disconnect(
    current_user: UserORM = Depends(get_current_user),
    user_service: UserService = Depends(get_user_service)
):
    """Disconnect Spotify account"""
    success = user_service.update_spotify_tokens(
        user_id=current_user.id,
        access_token=None,
        refresh_token=None,
        expires_at=None
    )

    if not success:
        raise HTTPException(status_code=500, detail="Failed to disconnect Spotify")

    return {"message": "Spotify disconnected successfully"}

@app.get("/api/spotify/status")
async def spotify_status(current_user: UserORM = Depends(get_current_user)):
    """Check if user has Spotify connected and token is valid"""
    if not current_user.spotify_access_token:
        return {"connected": False}

    # Check if token is expired
    if current_user.spotify_token_expires_at:
        expires_at = datetime.fromisoformat(current_user.spotify_token_expires_at)
        if datetime.utcnow() >= expires_at:
            return {"connected": True, "expired": True}

    return {
        "connected": True,
        "expired": False,
        "expires_at": current_user.spotify_token_expires_at,
        "access_token": current_user.spotify_access_token
    }

@app.post("/api/spotify/play")
async def spotify_play(
    request: Request,
    current_user: UserORM = Depends(get_current_user)
):
    """Start Spotify playback (proxied to avoid CORS issues)"""
    if not current_user.spotify_access_token:
        raise HTTPException(status_code=400, detail="Spotify not connected")

    data = await request.json()
    device_id = data.get("device_id")
    context_uri = data.get("context_uri")

    if not device_id or not context_uri:
        raise HTTPException(status_code=400, detail="Missing device_id or context_uri")

    try:
        async with httpx.AsyncClient() as client:
            response = await client.put(
                f"https://api.spotify.com/v1/me/player/play?device_id={device_id}",
                json={"context_uri": context_uri},
                headers={"Authorization": f"Bearer {current_user.spotify_access_token}"}
            )

            if response.status_code not in [200, 202, 204]:
                logger.error(f"Spotify play failed: {response.status_code} - {response.text}")
                raise HTTPException(status_code=response.status_code, detail=response.text)

        return {"success": True}
    except httpx.HTTPError as e:
        logger.error(f"Spotify play error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=int(os.environ.get("PORT", 9008)), help="Port to run the server on")
    args = parser.parse_args()

    port = args.port
    logger.info(f"Starting server on port {port}...")
    try:
        uvicorn.run("main:app", host="0.0.0.0", port=port, log_level="info", reload=False)
    except Exception as e:
        logger.error(f"Failed to start uvicorn: {e}")
