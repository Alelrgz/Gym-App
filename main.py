import os
import sys
import time
import logging
from dotenv import load_dotenv

load_dotenv()
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
except ImportError as e:
    logger.error(f"Missing dependency: {e}")
    logger.info("Please run: pip install fastapi uvicorn sqlalchemy jinja2 python-multipart")
    sys.exit(1)

app = FastAPI()

# Cache busting - timestamp changes on every server restart
CACHE_BUSTER = str(int(time.time()))

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
    with open("server_debug.log", "a") as f:
        f.write(f"DEBUG: Hit get_trainer_data_direct for {current_user.username}\n")
    data = service.get_trainer(current_user.id)
    with open("server_debug.log", "a") as f:
        f.write(f"DEBUG: get_trainer returned todays_workout: {data.todays_workout}\n")
    return data
# ---------------------------------------------

app.include_router(router)
app.include_router(simple_auth_router, prefix="/auth")

# Include gym assignment router directly
from route_modules.gym_assignment_routes import router as gym_assignment_router
app.include_router(gym_assignment_router)
print("DEBUG: Gym assignment router included directly on app")

# Include message routes
from route_modules.message_routes import router as message_router
app.include_router(message_router)
print("DEBUG: Message router included")

# Include profile routes
from route_modules.profile_routes import router as profile_router
app.include_router(profile_router)
print("DEBUG: Profile router included")

# Include staff routes
from route_modules.staff_routes import router as staff_router
app.include_router(staff_router)
print("DEBUG: Staff router included")


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

    logger.info("Registered Routes:")
    with open("server_debug.log", "a") as f:
        f.write("\n--- REGISTERED ROUTES ---\n")
        for route in app.routes:
            logger.info(f"{route.path} [{route.name}]")
            f.write(f"{route.path} [{route.name}]\n")
        f.write("-------------------------\n")

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    # Try to authenticate user from cookie
    user_id = None
    try:
        token = websocket.cookies.get("access_token")
        if token:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            user_id = payload.get("sub")
            logger.info(f"WebSocket authenticated for user: {user_id}")
    except Exception as e:
        logger.debug(f"WebSocket auth failed (continuing anyway): {e}")

    await manager.connect(websocket, user_id)
    try:
        while True:
            data = await websocket.receive_text()
            # Handle incoming WebSocket messages (for future use)
            try:
                msg = json.loads(data)
                if msg.get("type") == "ping":
                    await websocket.send_json({"type": "pong"})
            except:
                pass
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    with open("server_debug.log", "a") as f:
        f.write(f"MIDDLEWARE: {request.method} {request.url.path} at {time.time()}\n")
    
    try:
        response = await call_next(request)
        with open("server_debug.log", "a") as f:
            f.write(f"COMPLETED: {request.method} {request.url.path} - Status: {response.status_code}\n")
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0, private"
        return response
    except Exception as e:
        with open("server_debug.log", "a") as f:
            f.write(f"ERROR: {request.method} {request.url.path} - Exception: {e}\n")
        raise e

# Removed conflicting login/register routes (now handled by simple_auth with /auth prefix)

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request, gym_id: str = "iron_gym", role: str = "client", mode: str = "dashboard"):
    print("DEBUG: Root hit! Checking tokens...")
    token = request.cookies.get("access_token")
    if not token:
        print("DEBUG: No token found, redirecting...")
        return RedirectResponse(url="/auth/login", status_code=302)
    
    try:
        jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        print("DEBUG: Token valid.")
    except JWTError as e:
        print(f"DEBUG: Token invalid: {e}")
        return RedirectResponse(url="/auth/login", status_code=302)

    # Determine which template to render based on role
    # If role is default (client) but token says otherwise, trust token
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        token_role = payload.get("role")
        if token_role and role == "client": # Only override if default
            role = token_role
            print(f"DEBUG: Overriding role from token: {role}")
    except Exception as e:
        print(f"DEBUG: Could not extract role from token: {e}")

    # CHECK FOR ACCOUNT SETTINGS MODE
    if mode == "account_settings":
        print("ITWORKS1! Account settings page accessed!")
        logger.info("ITWORKS1! Account settings page accessed!")
        with open("server_debug.log", "a") as f:
            f.write("ITWORKS1! Account settings page accessed!\n")

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
        "static_build": False
    }
    logger.info(f"Rendering {template_name} with cache_buster={context['cache_buster']}")
    return templates.TemplateResponse(template_name, context)



@app.post("/api/trainer/events")
async def add_trainer_event_direct(
    event_data: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    with open("server_debug.log", "a") as f:
        f.write(f"DEBUG: Hit add_trainer_event_direct for user {current_user.id}. Data: {event_data}\n")
    return service.add_trainer_event(event_data, current_user.id)

@app.delete("/api/trainer/events/{event_id}")
async def delete_trainer_event_direct(
    event_id: str,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    print(f"DEBUG: Hit delete_trainer_event_direct for {event_id}")
    return service.remove_trainer_event(event_id, current_user.id)

@app.post("/api/trainer/schedule/complete")
async def complete_trainer_schedule_direct(
    payload: dict,
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    print(f"DEBUG: Hit complete_trainer_schedule_direct for {current_user.id}")
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
