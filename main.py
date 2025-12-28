from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import uvicorn
import time
from routes import router

app = FastAPI()
templates = Jinja2Templates(directory="templates")

app.mount("/static", StaticFiles(directory="static"), name="static")
app.include_router(router)

from fastapi import WebSocket, WebSocketDisconnect
from sockets import manager

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
    # Aggressive cache prevention for all responses
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0, private"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers["X-Accel-Expires"] = "0"
    response.headers["Surrogate-Control"] = "no-store"
    return response

# --- FRONTEND ---
@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request, gym_id: str = "iron_gym", role: str = "client", mode: str = "dashboard"):
    context = {"request": request, "gym_id": gym_id, "role": role, "mode": mode}
    
    if mode == "workout":
        template_name = "workout.html"
    elif role == "client":
        template_name = "client.html"
    elif role == "trainer":
        template_name = "trainer.html"
    elif role == "owner":
        template_name = "owner.html"
    else:
        template_name = "client.html"

    response = templates.TemplateResponse(template_name, context)
    
    # Add timestamp-based headers to force browser to detect changes
    timestamp = str(time.time())
    response.headers["ETag"] = f'"{timestamp}"'
    response.headers["Last-Modified"] = time.strftime('%a, %d %b %Y %H:%M:%S GMT', time.gmtime())
    
    return response

if __name__ == "__main__":
    import os
    from sockets import start_file_watcher
    
    # Start the file watcher in a background thread
    start_file_watcher()
    
    port = int(os.environ.get("PORT", 9007))
    uvicorn.run(app, host="0.0.0.0", port=port)
