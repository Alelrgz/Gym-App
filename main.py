import os
import sys
import time
import json
import logging
from dotenv import load_dotenv

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
    allow_methods=["*"],
    allow_headers=["*"],
)

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

    # Add new columns to client_profile
    if 'client_profile' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('client_profile')]
        profile_new_cols = [
            ("date_of_birth", "TEXT"),
            ("emergency_contact_name", "TEXT"),
            ("emergency_contact_phone", "TEXT"),
            ("is_premium", "BOOLEAN DEFAULT 0"),
            ("privacy_mode", "TEXT DEFAULT 'public'"),
            ("weight", "REAL"),
            ("body_fat_pct", "REAL"),
            ("fat_mass", "REAL"),
            ("lean_mass", "REAL"),
            ("strength_goal_upper", "INTEGER"),
            ("strength_goal_lower", "INTEGER"),
            ("strength_goal_cardio", "INTEGER"),
        ]
        for col_name, col_type in profile_new_cols:
            if col_name not in columns:
                with engine.connect() as conn:
                    try:
                        conn.execute(text(f"ALTER TABLE client_profile ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                        logger.info(f"Added column {col_name} to client_profile table")
                    except Exception as e:
                        logger.debug(f"Column {col_name} may already exist: {e}")

    # Add phone and must_change_password to users table
    if 'users' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('users')]
        user_new_cols = [
            ('phone', 'TEXT'),
            ('must_change_password', 'BOOLEAN DEFAULT 0'),
        ]
        for col_name, col_type in user_new_cols:
            if col_name not in columns:
                with engine.connect() as conn:
                    try:
                        conn.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                        logger.info(f"Added column {col_name} to users table")
                    except Exception as e:
                        logger.debug(f"Column {col_name} may already exist: {e}")

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
    try:
        # Create tables if they don't exist
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables verified/created.")

        # Run migrations for new columns
        run_migrations(engine)

        # Log DB info (safe to log dialect)
        db_url = str(engine.url)
        if "sqlite" in db_url:
            logger.info("Using SQLite Database (Development)")
        elif "postgresql" in db_url:
            logger.info("Using PostgreSQL Database (Production)")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")

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
        return response
    except Exception as e:
        logger.error(f"Request error: {request.method} {request.url.path} - {e}")
        raise e

# Removed conflicting login/register routes (now handled by simple_auth with /auth prefix)

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
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        token_role = payload.get("role")
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
    
    context = {
        "request": request,
        "gym_id": gym_id,
        "role": role,
        "mode": mode,
        "token": token,
        "cache_buster": str(int(time.time())),  # Use timestamp directly
        "static_build": False,
        "stripe_publishable_key": os.getenv("STRIPE_PUBLISHABLE_KEY", "")
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
