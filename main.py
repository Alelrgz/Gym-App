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
    from fastapi.responses import HTMLResponse
    from fastapi.staticfiles import StaticFiles
    from fastapi.templating import Jinja2Templates
    from fastapi import WebSocket, WebSocketDisconnect
    import uvicorn
    from fastapi.middleware.cors import CORSMiddleware
    from routes import router
    from sockets import manager, start_file_watcher
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

@app.on_event("startup")
async def startup_event():
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
async def add_no_cache_header(request, call_next):
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0, private"
    return response

@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.get("/register", response_class=HTMLResponse)
async def register_page(request: Request):
    return templates.TemplateResponse("register.html", {"request": request})

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request, gym_id: str = "iron_gym", role: str = "client", mode: str = "dashboard"):
    context = {"request": request, "gym_id": gym_id, "role": role, "mode": mode}
    
    template_map = {
        "workout": "workout.html",
        "client": "client.html",
        "trainer": "trainer.html",
        "owner": "owner.html"
    }
    template_name = template_map.get(mode if mode == "workout" else role, "client.html")

    try:
        return templates.TemplateResponse(template_name, context)
    except Exception as e:
        logger.error(f"Template error: {e}")
        return HTMLResponse(content=f"Error loading template: {e}", status_code=500)

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

# Force reload: v7
