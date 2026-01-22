import os
import sys
import time
import logging
from dotenv import load_dotenv

load_dotenv()
# Trigger reload v6.3 - forcing reload for services

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
    from models import TrainerData # Import TrainerData
    from services import UserService, get_user_service
    from auth import get_current_user
    from fastapi import Depends
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

# --- OVERRIDE ROUTES BEFORE ROUTER INCLUSION ---
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


@app.on_event("startup")
async def startup_event():
    logger.info("Initializing Database...")
    try:
        # Create tables if they don't exist
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables verified/created.")
        
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
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
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

    template_name = "client.html"
    if mode == "workout":
        template_name = "workout.html"
    elif role == "trainer":
        template_name = "trainer.html"
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



# --- DIRECT INJECTION OF ROUTES TO FIX 404 ---
from services import UserService, get_user_service # Import dependencies
from models_orm import UserORM # Import UserORM
from auth import get_current_user # Import auth dependency
from fastapi import Depends

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

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 9007))
    logger.info(f"Starting server on port {port}...")
    try:
        uvicorn.run("main:app", host="0.0.0.0", port=port, log_level="info", reload=True)
    except Exception as e:
        logger.error(f"Failed to start uvicorn: {e}")
