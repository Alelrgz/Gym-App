import os
import sys
import time
import logging

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
except ImportError as e:
    logger.error(f"Missing dependency: {e}")
    logger.info("Please run: pip install fastapi uvicorn sqlalchemy jinja2 python-multipart")
    sys.exit(1)

app = FastAPI()

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
    for route in app.routes:
        logger.info(f"{route.path} [{route.name}]")

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
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0, private"
    return response

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
    if role == "trainer":
        template_name = "trainer.html"
    elif role == "owner":
        template_name = "owner.html"
    
    return templates.TemplateResponse(template_name, {
        "request": request,
        "gym_id": gym_id,
        "role": role,
        "mode": mode,
        "token": token
    })

if __name__ == "__main__":
    # Start the file watcher
    try:
        start_file_watcher()
    except Exception as e:
        logger.warning(f"File watcher failed to start: {e}")
    
    port = int(os.environ.get("PORT", 9007))
    logger.info(f"Starting server on port {port}...")
    
    try:
        uvicorn.run("main:app", host="0.0.0.0", port=port, log_level="info", reload=True)
    except Exception as e:
        logger.error(f"Failed to start uvicorn: {e}")

# Force reload: v8
