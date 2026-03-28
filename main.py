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
    from auth import get_current_user, create_access_token
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

@app.get("/join/{gym_code}")
async def join_gym_landing(request: Request, gym_code: str):
    """Magic link landing page — shows gym info + download links."""
    from models_orm import GymORM, UserORM
    from database import get_db_session
    db = get_db_session()
    try:
        gym = db.query(GymORM).filter(GymORM.gym_code == gym_code.strip().upper()).first()
        if not gym:
            return HTMLResponse(f"""
            <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
            <title>FitOS</title><style>body{{background:#111;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;}}
            .card{{text-align:center;padding:2rem;}}</style></head>
            <body><div class="card"><h1>Palestra non trovata</h1><p>Il codice "{gym_code}" non è valido.</p></div></body></html>
            """, status_code=404)
        owner = db.query(UserORM).filter(UserORM.id == gym.owner_id).first()
        gym_name = gym.name or (owner.username if owner else "Palestra")
        logo_url = gym.logo or "/static/fitos-logo.svg"
        import os
        android_url = os.environ.get("FITOS_ANDROID_URL", "")
        ios_url = os.environ.get("FITOS_IOS_URL", "")
        base_url = str(request.base_url).rstrip("/")
        og_image = f"{base_url}{logo_url}" if logo_url.startswith("/") else logo_url
        return HTMLResponse(f"""
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Unisciti a {gym_name} su FitOS</title>
        <meta property="og:title" content="{gym_name} ti invita su FitOS">
        <meta property="og:description" content="Scarica l'app FitOS e unisciti a {gym_name}. Codice: {gym.gym_code}">
        <meta property="og:image" content="{og_image}">
        <meta property="og:type" content="website">
        <style>
            *{{box-sizing:border-box;}}
            body{{background:#111;color:#fff;font-family:-apple-system,BlinkMacSystemFont,sans-serif;margin:0;display:flex;align-items:center;justify-content:center;min-height:100vh;}}
            .card{{text-align:center;padding:2rem;max-width:420px;width:100%;}}
            .logo{{width:80px;height:80px;border-radius:20px;margin-bottom:1rem;object-fit:cover;}}
            h1{{color:#f15a24;font-size:1.6rem;margin:0.5rem 0 0.2rem;}}
            h2{{font-weight:400;color:#999;font-size:1rem;margin:0 0 1.5rem;}}
            .code-box{{background:#1a1a1a;border:1px solid #333;padding:1rem;border-radius:12px;margin:1rem 0;cursor:pointer;transition:border-color 0.2s;}}
            .code-box:hover{{border-color:#f15a24;}}
            .code-box .label{{color:#666;font-size:0.75rem;text-transform:uppercase;letter-spacing:0.05em;margin-bottom:0.3rem;}}
            .code{{font-family:monospace;font-size:1.5rem;color:#f15a24;font-weight:700;letter-spacing:0.1em;}}
            .copied{{color:#4ade80;font-size:0.8rem;margin-top:0.3rem;display:none;}}
            .steps{{text-align:left;margin:1.5rem 0;padding:0;list-style:none;}}
            .steps li{{padding:0.6rem 0;color:#ccc;font-size:0.9rem;display:flex;align-items:center;gap:0.7rem;}}
            .step-num{{background:#f15a24;color:#fff;width:24px;height:24px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:0.75rem;font-weight:700;flex-shrink:0;}}
            .btn{{display:block;padding:1rem;margin:0.5rem 0;border-radius:12px;text-decoration:none;font-weight:700;font-size:1rem;text-align:center;}}
            .btn-android{{background:#f15a24;color:#fff;}}
            .btn-ios{{background:#fff;color:#111;}}
            .btn-disabled{{background:#333;color:#666;pointer-events:none;}}
            .divider{{color:#444;font-size:0.8rem;margin:0.5rem 0;}}
        </style></head>
        <body><div class="card">
            <img src="{logo_url}" class="logo" alt="{gym_name}">
            <h1>{gym_name}</h1>
            <h2>ti invita su FitOS</h2>
            <div class="code-box" onclick="copyCode()">
                <div class="label">Il tuo codice palestra</div>
                <div class="code">{gym.gym_code}</div>
                <div class="copied" id="copied">Copiato!</div>
            </div>
            <ol class="steps">
                <li><span class="step-num">1</span>Scarica l'app FitOS</li>
                <li><span class="step-num">2</span>Accedi con le credenziali ricevute</li>
                <li><span class="step-num">3</span>Inserisci il codice <b style="color:#f15a24">{gym.gym_code}</b> per unirti</li>
            </ol>
            {'<a href="' + android_url + '" class="btn btn-android">📱 Scarica per Android</a>' if android_url else '<a class="btn btn-disabled">Android — Presto disponibile</a>'}
            <div class="divider">oppure</div>
            {'<a href="' + ios_url + '" class="btn btn-ios">🍎 Scarica per iOS</a>' if ios_url else '<a class="btn btn-disabled">iOS — Presto disponibile</a>'}
        </div>
        <script>
        function copyCode(){{
            navigator.clipboard.writeText("{gym.gym_code}").then(function(){{
                var el=document.getElementById("copied");el.style.display="block";
                setTimeout(function(){{el.style.display="none";}},2000);
            }});
        }}
        // Try deep link if app is installed
        (function(){{
            var ua=navigator.userAgent||"";
            if(/android/i.test(ua)||/iphone|ipad/i.test(ua)){{
                var deep="fitos://join/{gym.gym_code}";
                var iframe=document.createElement("iframe");
                iframe.style.display="none";iframe.src=deep;
                document.body.appendChild(iframe);
                setTimeout(function(){{document.body.removeChild(iframe);}},2000);
            }}
        }})();
        </script>
        </body></html>
        """)
    finally:
        db.close()

@app.post("/api/test-push/{user_id}")
async def test_push(user_id: str):
    """Temporary: send a test push notification to a user with full diagnostics."""
    from models_orm import NotificationORM, FCMDeviceTokenORM
    from service_modules.notification_service import send_fcm_push, _get_fcm_access_token, _get_fcm_project_id
    from database import get_db_session
    from datetime import datetime as _dt
    import traceback

    db = get_db_session()
    diag = {}
    try:
        # 1. Check device tokens
        tokens = db.query(FCMDeviceTokenORM).filter(FCMDeviceTokenORM.user_id == user_id).all()
        diag["device_tokens"] = len(tokens)
        diag["tokens"] = [{"platform": getattr(t, "platform", "?"), "token_prefix": t.token[:30]} for t in tokens]

        # 2. Check FCM credentials
        import os
        sa_json_raw = os.environ.get("GOOGLE_SERVICE_ACCOUNT_JSON", "")
        diag["sa_env_set"] = bool(sa_json_raw)
        diag["sa_env_len"] = len(sa_json_raw)
        diag["sa_env_first100"] = sa_json_raw[:100] if sa_json_raw else ""
        try:
            import json as _j
            parsed = _j.loads(sa_json_raw)
            diag["sa_parsed"] = True
            diag["sa_project_id"] = parsed.get("project_id", "MISSING")
            diag["sa_client_email"] = parsed.get("client_email", "MISSING")[:40]
            diag["sa_has_private_key"] = "private_key" in parsed
        except Exception as parse_err:
            diag["sa_parsed"] = False
            diag["sa_parse_error"] = str(parse_err)
        try:
            access_token = _get_fcm_access_token()
        except Exception as e:
            access_token = None
            diag["fcm_token_error"] = str(e)
        try:
            project_id = _get_fcm_project_id()
        except Exception as e:
            project_id = None
            diag["fcm_project_error"] = str(e)
        diag["fcm_access_token"] = "ok" if access_token else "MISSING"
        diag["fcm_project_id"] = project_id or "MISSING"

        # 3. Try direct FCM push (bypass after_insert event)
        if tokens and access_token and project_id:
            import requests as req
            url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
            headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}
            payload = {
                "message": {
                    "token": tokens[0].token,
                    "notification": {"title": "FitOS Test", "body": "Se vedi questo, le notifiche push funzionano!"},
                    "data": {"click_action": "FLUTTER_NOTIFICATION_CLICK"},
                }
            }
            resp = req.post(url, json=payload, headers=headers, timeout=10)
            diag["fcm_response_status"] = resp.status_code
            diag["fcm_response_body"] = resp.text[:300]
        else:
            diag["fcm_skip_reason"] = "no tokens or no credentials"

        return {"status": "sent", "user_id": user_id, "diagnostics": diag}
    except Exception as e:
        diag["error"] = str(e)
        diag["traceback"] = traceback.format_exc()[-500:]
        return {"status": "error", "diagnostics": diag}
    finally:
        db.close()


@app.get("/magic/{token}")
async def magic_login(request: Request, token: str):
    """Magic link login — validates token, creates session, redirects."""
    import hashlib, hmac, os
    from models_orm import MagicLoginTokenORM, UserORM
    from database import get_db_session
    from auth import create_access_token
    from datetime import datetime as _dt, timedelta as _td

    db = get_db_session()
    try:
        secret = os.environ.get("SECRET_KEY", "gym-secret-key-change-me")
        token_hash = hmac.new(secret.encode(), token.encode(), hashlib.sha256).hexdigest()

        magic = db.query(MagicLoginTokenORM).filter(
            MagicLoginTokenORM.token_hash == token_hash,
            MagicLoginTokenORM.used_at == None,
        ).first()

        if not magic or magic.expires_at < _dt.utcnow().isoformat():
            return HTMLResponse("""
            <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
            <title>FitOS</title><style>body{background:#111;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;}
            .card{text-align:center;padding:2rem;}</style></head>
            <body><div class="card"><h2 style="color:#f15a24;">Link scaduto</h2><p style="color:#999;">Questo link non è più valido. Chiedi nuove credenziali alla tua palestra.</p></div></body></html>
            """, status_code=410)

        user = db.query(UserORM).filter(UserORM.id == magic.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # Mark token as used
        magic.used_at = _dt.utcnow().isoformat()

        # Create session
        import secrets as _sec
        session_id = _sec.token_urlsafe(16)
        user.active_session_id = session_id
        db.commit()

        # Create JWT
        jwt_token = create_access_token(
            data={"sub": user.username, "role": user.role, "sid": session_id},
            expires_delta=_td(days=90),
        )

        # Try deep link to app, fallback to web
        return HTMLResponse(f"""
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Accesso FitOS</title>
        <style>body{{background:#111;color:#fff;font-family:-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;}}
        .card{{text-align:center;padding:2rem;max-width:400px;}}
        h2{{color:#22c55e;}} p{{color:#999;}} .spinner{{margin:1rem auto;width:40px;height:40px;border:3px solid #333;border-top-color:#f15a24;border-radius:50%;animation:spin 0.8s linear infinite;}}
        @keyframes spin{{to{{transform:rotate(360deg)}}}}
        </style></head>
        <body><div class="card">
            <div class="spinner"></div>
            <h2>Accesso in corso...</h2>
            <p>Apertura dell'app FitOS</p>
        </div>
        <script>
        var token = "{jwt_token}";
        var deep = "fitos://login?token=" + token;
        window.location.href = deep;
        setTimeout(function(){{
            // If app didn't open, show message
            document.querySelector('.card').innerHTML = '<h2 style="color:#22c55e">✓ Accesso riuscito!</h2><p style="color:#999">Scarica l\\'app FitOS per accedere, oppure usa le credenziali ricevute.</p>';
        }}, 3000);
        </script>
        </body></html>
        """)
    finally:
        db.close()


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

@app.get("/api/trainer/weekly-overview")
async def get_trainer_weekly_overview(
    service: UserService = Depends(get_user_service),
    current_user: UserORM = Depends(get_current_user)
):
    return service.get_trainer_weekly_overview(current_user.id)

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

# Register FCM push listener (fires on every NotificationORM insert)
import service_modules.notification_service  # noqa: F401

# Include message routes
from route_modules.message_routes import router as message_router
app.include_router(message_router)

# Include profile routes
from route_modules.profile_routes import router as profile_router
app.include_router(profile_router)

# Include staff routes
from route_modules.staff_routes import router as staff_router
app.include_router(staff_router)

# ── Remote signing page (phone browser) ────────────────────
from fastapi.responses import HTMLResponse as _HTMLResponse

@app.get("/snap/{token}", response_class=_HTMLResponse)
async def photo_snap_page(token: str):
    """Serve a self-contained camera capture page for phone browser."""
    from models_orm import PhotoSnapSessionORM
    from database import get_db_session
    from datetime import datetime as _dt
    _sdb = get_db_session()
    try:
        session = _sdb.query(PhotoSnapSessionORM).filter(PhotoSnapSessionORM.token == token).first()
    finally:
        _sdb.close()
    if not session or session.status == "uploaded" or session.expires_at < _dt.utcnow().isoformat():
        return _HTMLResponse(content="<html><body style='background:#111;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;'><h2>Sessione scaduta o già usata</h2></body></html>", status_code=404)

    return _HTMLResponse(content=f'''<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>FitOS — Foto Cliente</title>
<style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ background:#111; color:#fff; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; min-height:100dvh; display:flex; flex-direction:column; }}
.header {{ padding:16px 20px; text-align:center; }}
.header h1 {{ font-size:22px; font-weight:800; }}
.header p {{ font-size:13px; color:#999; margin-top:4px; }}
#camera-view {{ flex:1; display:flex; flex-direction:column; align-items:center; justify-content:center; padding:16px; }}
video {{ width:100%; max-width:400px; border-radius:16px; background:#000; }}
canvas {{ display:none; }}
#preview {{ width:100%; max-width:400px; border-radius:16px; }}
.controls {{ padding:16px 20px 32px; display:flex; gap:12px; justify-content:center; }}
.btn {{ padding:14px 28px; border:none; border-radius:14px; font-size:15px; font-weight:700; cursor:pointer; }}
.btn-primary {{ background:#f15a24; color:#fff; }}
.btn-secondary {{ background:#252525; color:#fff; border:1px solid rgba(255,255,255,0.1); }}
.btn-success {{ background:#22c55e; color:#fff; }}
.btn:disabled {{ opacity:0.5; }}
#success {{ display:none; flex:1; flex-direction:column; align-items:center; justify-content:center; text-align:center; padding:20px; }}
#success .checkmark {{ font-size:64px; margin-bottom:16px; }}
#success h2 {{ font-size:22px; margin-bottom:8px; }}
#success p {{ color:#999; font-size:14px; }}
#error-msg {{ color:#ef4444; text-align:center; padding:8px; font-size:13px; display:none; }}
</style>
</head>
<body>
<div class="header">
  <h1>Foto Cliente</h1>
  <p>Scatta una foto per il profilo</p>
</div>

<div id="camera-view">
  <video id="video" autoplay playsinline></video>
  <img id="preview" style="display:none">
  <canvas id="canvas"></canvas>
  <div id="error-msg"></div>
</div>

<div class="controls" id="capture-controls">
  <button class="btn btn-primary" id="captureBtn" onclick="capture()">Scatta Foto</button>
</div>
<div class="controls" id="confirm-controls" style="display:none">
  <button class="btn btn-secondary" onclick="retry()">Riprova</button>
  <button class="btn btn-success" id="confirmBtn" onclick="confirm()">Conferma</button>
</div>

<div id="success">
  <div class="checkmark">✅</div>
  <h2>Foto inviata!</h2>
  <p>Puoi chiudere questa pagina</p>
</div>

<script>
const token = "{token}";
let stream = null;
let photoDataUrl = null;

async function startCamera() {{
  try {{
    stream = await navigator.mediaDevices.getUserMedia({{
      video: {{ facingMode: "environment", width: {{ ideal: 800 }}, height: {{ ideal: 800 }} }}
    }});
    document.getElementById('video').srcObject = stream;
  }} catch(e) {{
    try {{
      stream = await navigator.mediaDevices.getUserMedia({{ video: {{ facingMode: "user" }} }});
      document.getElementById('video').srcObject = stream;
    }} catch(e2) {{
      const errEl = document.getElementById('error-msg');
      errEl.textContent = 'Impossibile accedere alla fotocamera. Verifica i permessi.';
      errEl.style.display = 'block';
    }}
  }}
}}

function capture() {{
  const video = document.getElementById('video');
  const canvas = document.getElementById('canvas');
  const size = Math.min(video.videoWidth, video.videoHeight, 600);
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  const sx = (video.videoWidth - size) / 2;
  const sy = (video.videoHeight - size) / 2;
  ctx.drawImage(video, sx, sy, size, size, 0, 0, size, size);
  photoDataUrl = canvas.toDataURL('image/jpeg', 0.85);

  document.getElementById('preview').src = photoDataUrl;
  document.getElementById('preview').style.display = 'block';
  document.getElementById('video').style.display = 'none';
  document.getElementById('capture-controls').style.display = 'none';
  document.getElementById('confirm-controls').style.display = 'flex';
}}

function retry() {{
  document.getElementById('preview').style.display = 'none';
  document.getElementById('video').style.display = 'block';
  document.getElementById('capture-controls').style.display = 'flex';
  document.getElementById('confirm-controls').style.display = 'none';
  photoDataUrl = null;
}}

async function confirm() {{
  const btn = document.getElementById('confirmBtn');
  btn.disabled = true;
  btn.textContent = 'Invio...';
  try {{
    const resp = await fetch('/api/staff/photo-snap-session/' + token + '/upload', {{
      method: 'POST',
      headers: {{ 'Content-Type': 'application/json' }},
      body: JSON.stringify({{ photo_data: photoDataUrl }})
    }});
    if (!resp.ok) throw new Error('Upload failed');
    if (stream) stream.getTracks().forEach(t => t.stop());
    document.getElementById('camera-view').style.display = 'none';
    document.getElementById('confirm-controls').style.display = 'none';
    document.getElementById('success').style.display = 'flex';
  }} catch(e) {{
    btn.disabled = false;
    btn.textContent = 'Conferma';
    const errEl = document.getElementById('error-msg');
    errEl.textContent = 'Errore durante l\\'invio. Riprova.';
    errEl.style.display = 'block';
  }}
}}

startCamera();
</script>
</body>
</html>''')


@app.get("/sign/{token}", response_class=_HTMLResponse)
async def signing_page(token: str):
    """Serve a self-contained HTML signing page for phone browser."""
    from models_orm import SigningSessionORM
    from database import get_db_session
    from datetime import datetime as _dt
    _sdb = get_db_session()
    try:
        session = _sdb.query(SigningSessionORM).filter(SigningSessionORM.token == token).first()
    finally:
        _sdb.close()
    if not session or session.status == "signed" or session.expires_at < _dt.utcnow().isoformat():
        return _HTMLResponse(content="<html><body style='background:#111;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;'><h2>Sessione scaduta o già firmata</h2></body></html>", status_code=404)

    import html as _html
    client_name = _html.escape(session.client_name or "")
    waiver_text = _html.escape(session.waiver_text or "").replace("\n", "<br>")

    return _HTMLResponse(content=f'''<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>Firma Liberatoria</title>
<style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{ background:#111; color:#fff; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; min-height:100dvh; display:flex; flex-direction:column; overflow:hidden; }}
.header {{ padding:16px 20px; text-align:center; }}
.header h1 {{ font-size:22px; font-weight:800; }}
.header p {{ font-size:13px; color:#999; margin-top:4px; }}
.waiver {{ flex:1; overflow-y:auto; margin:0 16px; padding:16px; background:#1a1a1a; border-radius:12px; border:1px solid rgba(255,255,255,0.06); font-size:13px; color:#999; line-height:1.7; min-height:120px; max-height:35dvh; }}
.checkbox {{ margin:12px 16px; padding:12px 16px; background:#1a1a1a; border-radius:12px; border:1px solid rgba(255,255,255,0.06); display:flex; align-items:center; gap:10px; cursor:pointer; transition:all 0.2s; }}
.checkbox.checked {{ background:rgba(34,197,94,0.08); border-color:rgba(34,197,94,0.3); }}
.checkbox input {{ width:20px; height:20px; accent-color:#22c55e; }}
.checkbox span {{ font-size:14px; }}
.sig-section {{ margin:8px 16px 0; flex:1; display:flex; flex-direction:column; min-height:0; }}
.sig-label {{ font-size:13px; color:#999; margin-bottom:6px; display:flex; justify-content:space-between; align-items:center; }}
.sig-clear {{ font-size:12px; color:#ef4444; cursor:pointer; background:rgba(239,68,68,0.1); padding:3px 10px; border-radius:6px; border:none; }}
canvas {{ flex:1; width:100%; background:#fff; border-radius:10px; border:2px solid rgba(150,150,150,0.3); touch-action:none; cursor:crosshair; min-height:100px; }}
canvas.signed {{ border-color:#22c55e; }}
.hint {{ text-align:center; font-size:11px; color:#666; margin-top:4px; }}
.confirm {{ margin:12px 16px 20px; padding:16px; border:none; border-radius:14px; font-size:17px; font-weight:700; color:#fff; cursor:pointer; transition:all 0.2s; }}
.confirm.ready {{ background:#22c55e; }}
.confirm.not-ready {{ background:#444; pointer-events:none; }}
.done {{ display:none; flex-direction:column; align-items:center; justify-content:center; height:100dvh; text-align:center; padding:40px; }}
.done h2 {{ font-size:28px; font-weight:800; color:#22c55e; margin-bottom:8px; }}
.done p {{ color:#999; font-size:14px; }}
</style>
</head>
<body>
<div id="form">
  <div class="header">
    <h1>{"Ciao " + client_name + "!" if client_name else "Benvenuto!"}</h1>
    <p>Leggi la liberatoria e firma in basso</p>
  </div>
  <div class="waiver">{waiver_text}</div>
  <div class="checkbox" id="cb" onclick="toggleCb()">
    <input type="checkbox" id="cbInput">
    <span>Ho letto e accetto i termini della liberatoria</span>
  </div>
  <div class="sig-section">
    <div class="sig-label">
      <span>Firma qui sotto</span>
      <button class="sig-clear" onclick="clearSig()" id="clearBtn" style="display:none">Cancella</button>
    </div>
    <canvas id="sigCanvas"></canvas>
    <div class="hint" id="sigHint">Usa il dito per firmare</div>
  </div>
  <button class="confirm not-ready" id="confirmBtn" onclick="submit()">Conferma Firma</button>
</div>
<div class="done" id="done">
  <h2>Firma Registrata!</h2>
  <p>Puoi restituire il dispositivo allo staff.<br>Questa pagina si chiuder&agrave; automaticamente.</p>
</div>
<script>
const canvas = document.getElementById('sigCanvas');
const ctx = canvas.getContext('2d');
let drawing = false, hasSigned = false, hasRead = false, strokes = [], current = [];

function resize() {{
  const r = canvas.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  canvas.width = r.width * dpr;
  canvas.height = r.height * dpr;
  ctx.scale(dpr, dpr);
  redraw();
}}
window.addEventListener('resize', resize);
setTimeout(resize, 50);

function getPos(e) {{
  const r = canvas.getBoundingClientRect();
  const t = e.touches ? e.touches[0] : e;
  return {{ x: t.clientX - r.left, y: t.clientY - r.top }};
}}

canvas.addEventListener('pointerdown', e => {{ e.preventDefault(); drawing = true; current = [getPos(e)]; }});
canvas.addEventListener('pointermove', e => {{ if(!drawing) return; e.preventDefault(); current.push(getPos(e)); redraw(); }});
canvas.addEventListener('pointerup', e => {{ if(!drawing) return; drawing = false; if(current.length>1) strokes.push(current); current=[]; hasSigned=strokes.length>0; update(); }});
canvas.addEventListener('pointerleave', e => {{ if(!drawing) return; drawing = false; if(current.length>1) strokes.push(current); current=[]; hasSigned=strokes.length>0; update(); }});

function redraw() {{
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.strokeStyle = '#1a1a1a';
  ctx.lineWidth = 2.5;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  [...strokes, current].forEach(s => {{
    if(s.length<2) return;
    ctx.beginPath();
    ctx.moveTo(s[0].x, s[0].y);
    for(let i=1;i<s.length;i++) ctx.lineTo(s[i].x, s[i].y);
    ctx.stroke();
  }});
}}

function clearSig() {{ strokes=[]; current=[]; hasSigned=false; redraw(); update(); }}

function toggleCb() {{
  hasRead = !hasRead;
  document.getElementById('cbInput').checked = hasRead;
  document.getElementById('cb').classList.toggle('checked', hasRead);
  update();
}}

function update() {{
  const btn = document.getElementById('confirmBtn');
  btn.className = 'confirm ' + (hasSigned && hasRead ? 'ready' : 'not-ready');
  canvas.className = hasSigned ? 'signed' : '';
  document.getElementById('clearBtn').style.display = hasSigned ? '' : 'none';
  document.getElementById('sigHint').style.display = hasSigned ? 'none' : '';
}}

async function submit() {{
  if(!hasSigned || !hasRead) return;
  const btn = document.getElementById('confirmBtn');
  btn.textContent = 'Invio...';
  btn.style.pointerEvents = 'none';

  // Export canvas as base64 PNG
  const dataUrl = canvas.toDataURL('image/png');

  try {{
    const res = await fetch('/api/staff/signing-session/{token}/submit', {{
      method: 'POST',
      headers: {{'Content-Type': 'application/json'}},
      body: JSON.stringify({{ signature_data: dataUrl }})
    }});
    if(res.ok) {{
      document.getElementById('form').style.display = 'none';
      document.getElementById('done').style.display = 'flex';
    }} else {{
      const err = await res.json();
      alert(err.detail || 'Errore');
      btn.textContent = 'Conferma Firma';
      btn.style.pointerEvents = '';
    }}
  }} catch(e) {{
    alert('Errore di rete');
    btn.textContent = 'Conferma Firma';
    btn.style.pointerEvents = '';
  }}
}}
</script>
</body>
</html>''')


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

# Include client import routes
from route_modules.client_import_routes import router as client_import_router
app.include_router(client_import_router)

# Include terminal routes
from route_modules.terminal_routes import router as terminal_router
app.include_router(terminal_router)

from route_modules.notification_settings_routes import router as notification_settings_router
app.include_router(notification_settings_router)

from route_modules.smtp_oauth_routes import router as smtp_oauth_router
app.include_router(smtp_oauth_router)

from route_modules.community_routes import router as community_router
app.include_router(community_router)

from route_modules.consent_routes import consent_router
app.include_router(consent_router)

from route_modules.stripe_connect_routes import stripe_connect_router
app.include_router(stripe_connect_router)


def _safe_add_columns(engine, table_name, columns_list):
    """Add columns to a table using IF NOT EXISTS (PostgreSQL 9.6+) or fallback."""
    from sqlalchemy import text, inspect
    from database import IS_POSTGRES

    # Get existing columns to skip ones that already exist
    try:
        inspector = inspect(engine)
        existing = {col['name'] for col in inspector.get_columns(table_name)}
    except Exception as e:
        logger.warning("Could not inspect columns for table %s: %s", table_name, e)
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
    """Run database migrations to add new columns. Uses _safe_add_columns for all operations."""
    from sqlalchemy import text, inspect

    # exercises
    _safe_add_columns(engine, 'exercises', [
        ('description', 'TEXT'),
        ('default_duration', 'INTEGER'),
        ('difficulty', 'TEXT'),
        ('thumbnail_url', 'TEXT'),
        ('video_url', 'TEXT'),
        ('steps_json', 'TEXT'),
    ])

    # courses
    _safe_add_columns(engine, 'courses', [
        ('days_of_week_json', 'TEXT'),
        ('course_type', 'TEXT'),
        ('cover_image_url', 'TEXT'),
        ('trailer_url', 'TEXT'),
        ('max_capacity', 'INTEGER'),
        ('waitlist_enabled', 'BOOLEAN DEFAULT 1'),
    ])

    # course_lessons
    _safe_add_columns(engine, 'course_lessons', [
        ('max_capacity', 'INTEGER'),
    ])

    # trainer_schedule / client_schedule
    _safe_add_columns(engine, 'trainer_schedule', [('course_id', 'TEXT')])
    _safe_add_columns(engine, 'client_schedule', [('course_id', 'TEXT')])

    # users — all columns
    _safe_add_columns(engine, 'users', [
        ('sub_role', 'TEXT'),
        ('phone', 'TEXT'),
        ('must_change_password', 'BOOLEAN DEFAULT FALSE'),
        ('profile_picture', 'TEXT'),
        ('bio', 'TEXT'),
        ('specialties', 'TEXT'),
        ('settings', 'TEXT'),
        ('gym_name', 'TEXT'),
        ('gym_logo', 'TEXT'),
        ('session_rate', 'DOUBLE PRECISION'),
        ('commission_rate', 'DOUBLE PRECISION'),
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
        ('turnstile_gate_seconds', 'INTEGER'),
        ('smtp_host', 'TEXT'),
        ('smtp_port', 'INTEGER'),
        ('smtp_user', 'TEXT'),
        ('smtp_password', 'TEXT'),
        ('smtp_from_email', 'TEXT'),
        ('smtp_from_name', 'TEXT'),
        ('fcm_server_key', 'TEXT'),
        ('smtp_oauth_provider', 'TEXT'),
        ('smtp_oauth_refresh_token', 'TEXT'),
        ('smtp_oauth_access_token', 'TEXT'),
        ('smtp_oauth_token_expiry', 'TEXT'),
    ])

    # client_diet_settings
    _safe_add_columns(engine, 'client_diet_settings', [
        ('fitness_goal', "TEXT DEFAULT 'maintain'"),
        ('base_calories', 'INTEGER DEFAULT 2000'),
    ])

    # appointments
    _safe_add_columns(engine, 'appointments', [
        ('session_type', 'TEXT'),
        ('price', 'REAL'),
        ('payment_method', 'TEXT'),
        ('payment_status', "TEXT DEFAULT 'free'"),
        ('stripe_payment_intent_id', 'TEXT'),
    ])

    # messages
    _safe_add_columns(engine, 'messages', [
        ('media_type', 'TEXT'),
        ('file_url', 'TEXT'),
        ('file_size', 'INTEGER'),
        ('mime_type', 'TEXT'),
        ('duration', 'DOUBLE PRECISION'),
    ])

    # client_profile
    _safe_add_columns(engine, 'client_profile', [
        ('date_of_birth', 'TEXT'),
        ('emergency_contact_name', 'TEXT'),
        ('emergency_contact_phone', 'TEXT'),
        ('is_premium', 'BOOLEAN DEFAULT FALSE'),
        ('privacy_mode', "TEXT DEFAULT 'public'"),
        ('weight', 'DOUBLE PRECISION'),
        ('body_fat_pct', 'DOUBLE PRECISION'),
        ('fat_mass', 'DOUBLE PRECISION'),
        ('lean_mass', 'DOUBLE PRECISION'),
        ('strength_goal_upper', 'INTEGER'),
        ('strength_goal_lower', 'INTEGER'),
        ('strength_goal_cardio', 'INTEGER'),
        ('health_score', 'INTEGER DEFAULT 0'),
        ('gems', 'INTEGER DEFAULT 0'),
        ('nutritionist_id', 'TEXT'),
        ('weight_goal', 'DOUBLE PRECISION'),
        ('height_cm', 'DOUBLE PRECISION'),
        ('gender', 'TEXT'),
        ('activity_level', 'TEXT'),
        ('allergies', 'TEXT'),
        ('medical_conditions', 'TEXT'),
        ('supplements', 'TEXT'),
        ('sleep_hours', 'DOUBLE PRECISION'),
        ('meal_frequency', 'TEXT'),
        ('food_preferences', 'TEXT'),
        ('occupation_type', 'TEXT'),
        ('current_split_id', 'TEXT'),
        ('split_expiry_date', 'TEXT'),
    ])

    # automated_message_templates
    _safe_add_columns(engine, 'automated_message_templates', [
        ('linked_offer_id', 'TEXT'),
    ])

    # client_daily_diet_summary
    _safe_add_columns(engine, 'client_daily_diet_summary', [
        ('health_score', 'INTEGER DEFAULT 0'),
    ])

    # plan_offers
    _safe_add_columns(engine, 'plan_offers', [
        ('stripe_coupon_id', 'TEXT'),
    ])

    # subscription_plans
    _safe_add_columns(engine, 'subscription_plans', [
        ('annual_price', 'REAL'),
        ('installment_count', 'INTEGER DEFAULT 1'),
        ('billing_type', "VARCHAR DEFAULT 'annual'"),
    ])

    # client_subscriptions
    _safe_add_columns(engine, 'client_subscriptions', [
        ('stripe_payment_intent_id', 'TEXT'),
    ])

    # weight_history
    _safe_add_columns(engine, 'weight_history', [
        ('body_fat_pct', 'REAL'),
        ('fat_mass', 'REAL'),
        ('lean_mass', 'REAL'),
    ])

    # client_exercise_log
    _safe_add_columns(engine, 'client_exercise_log', [
        ('duration', 'REAL'),
        ('distance', 'REAL'),
        ('metric_type', "TEXT DEFAULT 'weight_reps'"),
    ])

    # weekly_meal_plan
    _safe_add_columns(engine, 'weekly_meal_plan', [
        ('alternative_index', 'INTEGER DEFAULT 0'),
    ])

    # --- Multi-gym migration: create gyms table and populate from existing owners ---
    from sqlalchemy import text, inspect
    from models_orm import GymORM
    GymORM.__table__.create(engine, checkfirst=True)

    inspector = inspect(engine)
    if 'gyms' in inspector.get_table_names():
        with engine.connect() as conn:
            # Check if migration already ran (any gym rows exist)
            existing = conn.execute(text("SELECT COUNT(*) FROM gyms")).scalar()
            if existing == 0:
                # Migrate existing owners into gym records (gym.id = owner.id for seamless FK compat)
                owners = conn.execute(text(
                    "SELECT id, gym_name, gym_logo, gym_code, "
                    "shower_timer_minutes, shower_daily_limit, device_api_key, turnstile_gate_seconds, "
                    "smtp_host, smtp_port, smtp_user, smtp_password, smtp_from_email, smtp_from_name, "
                    "smtp_oauth_provider, smtp_oauth_refresh_token, smtp_oauth_access_token, smtp_oauth_token_expiry, "
                    "stripe_account_id, stripe_account_status, stripe_terminal_location_id, stripe_terminal_reader_id, "
                    "fcm_server_key, created_at "
                    "FROM users WHERE role = 'owner'"
                )).fetchall()

                for owner in owners:
                    try:
                        conn.execute(text(
                            "INSERT INTO gyms (id, owner_id, name, logo, gym_code, is_active, created_at, "
                            "shower_timer_minutes, shower_daily_limit, device_api_key, turnstile_gate_seconds, "
                            "smtp_host, smtp_port, smtp_user, smtp_password, smtp_from_email, smtp_from_name, "
                            "smtp_oauth_provider, smtp_oauth_refresh_token, smtp_oauth_access_token, smtp_oauth_token_expiry, "
                            "stripe_account_id, stripe_account_status, stripe_terminal_location_id, stripe_terminal_reader_id, "
                            "fcm_server_key) "
                            "VALUES (:id, :owner_id, :name, :logo, :gym_code, 1, :created_at, "
                            ":shower_timer_minutes, :shower_daily_limit, :device_api_key, :turnstile_gate_seconds, "
                            ":smtp_host, :smtp_port, :smtp_user, :smtp_password, :smtp_from_email, :smtp_from_name, "
                            ":smtp_oauth_provider, :smtp_oauth_refresh_token, :smtp_oauth_access_token, :smtp_oauth_token_expiry, "
                            ":stripe_account_id, :stripe_account_status, :stripe_terminal_location_id, :stripe_terminal_reader_id, "
                            ":fcm_server_key)"
                        ), {
                            "id": owner[0], "owner_id": owner[0],
                            "name": owner[1], "logo": owner[2], "gym_code": owner[3],
                            "created_at": owner[23] or datetime.utcnow().isoformat(),
                            "shower_timer_minutes": owner[4], "shower_daily_limit": owner[5],
                            "device_api_key": owner[6], "turnstile_gate_seconds": owner[7],
                            "smtp_host": owner[8], "smtp_port": owner[9],
                            "smtp_user": owner[10], "smtp_password": owner[11],
                            "smtp_from_email": owner[12], "smtp_from_name": owner[13],
                            "smtp_oauth_provider": owner[14], "smtp_oauth_refresh_token": owner[15],
                            "smtp_oauth_access_token": owner[16], "smtp_oauth_token_expiry": owner[17],
                            "stripe_account_id": owner[18], "stripe_account_status": owner[19],
                            "stripe_terminal_location_id": owner[20], "stripe_terminal_reader_id": owner[21],
                            "fcm_server_key": owner[22],
                        })
                        logger.info(f"Migrated owner {owner[0]} to gyms table")
                    except Exception as e:
                        logger.warning(f"Gym migration for owner {owner[0]} failed: {e}")

                conn.commit()
                logger.info(f"Multi-gym migration complete: {len(owners)} gyms created")


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

    # Run consent table migration and backfill
    try:
        from migrate_consent_tables import run_consent_migration
        run_consent_migration()
    except Exception as e:
        logger.error(f"Consent migration error: {e}")

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

    # --- Data retention cleanup (TODO: move to a scheduled cron job) ---
    try:
        from sqlalchemy import text
        from database import get_db_session
        cleanup_db = get_db_session()
        try:
            now = datetime.utcnow()

            # 1. Delete audit logs older than 90 days
            cutoff_90 = (now - timedelta(days=90)).isoformat()
            deleted_audit = cleanup_db.execute(
                text("DELETE FROM sensitive_data_access_log WHERE accessed_at < :cutoff"),
                {"cutoff": cutoff_90}
            ).rowcount

            # 2. Delete expired password reset tokens (expired and older than 7 days)
            cutoff_7 = (now - timedelta(days=7)).isoformat()
            deleted_tokens = cleanup_db.execute(
                text("DELETE FROM password_reset_tokens WHERE expires_at < :cutoff"),
                {"cutoff": cutoff_7}
            ).rowcount

            # 3. Delete old read notifications (older than 60 days, already read)
            cutoff_60 = (now - timedelta(days=60)).isoformat()
            deleted_notifs = cleanup_db.execute(
                text("DELETE FROM notifications WHERE read = true AND created_at < :cutoff"),
                {"cutoff": cutoff_60}
            ).rowcount

            cleanup_db.commit()
            logger.info(
                f"Data retention cleanup: {deleted_audit} audit logs, "
                f"{deleted_tokens} expired tokens, {deleted_notifs} old notifications deleted"
            )
        except Exception as e:
            logger.warning(f"Data retention cleanup error (non-fatal): {e}")
            cleanup_db.rollback()
        finally:
            cleanup_db.close()
    except Exception as e:
        logger.warning(f"Data retention cleanup setup error (non-fatal): {e}")

    # Start background thread for automated message trigger checking
    import threading
    trigger_thread = threading.Thread(target=background_trigger_checker, daemon=True)
    trigger_thread.start()
    logger.info("Automated message trigger checker started (runs every 15 minutes)")

    logger.info("Registered Routes:")
    for route in app.routes:
        logger.info(f"{route.path} [{route.name}]")

@app.websocket("/ws/gate/{device_key}")
async def gate_websocket(websocket: WebSocket, device_key: str):
    """WebSocket for Pi gate relay. Pi connects and waits for gate-open events."""
    from route_modules.shower_routes import _gate_connections
    db = get_db_session()
    try:
        owner = db.query(UserORM).filter(
            UserORM.device_api_key == device_key,
            UserORM.role == "owner"
        ).first()
    finally:
        db.close()

    if not owner:
        await websocket.close(code=4001, reason="Invalid device key")
        return

    await websocket.accept()
    _gate_connections[owner.id] = websocket
    logger.info(f"Gate WebSocket connected for owner {owner.id}")

    try:
        while True:
            # Keep connection alive — Pi sends pings, we just wait
            await websocket.receive_text()
    except Exception:
        pass
    finally:
        _gate_connections.pop(owner.id, None)
        logger.info(f"Gate WebSocket disconnected for owner {owner.id}")


@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    # Try to authenticate user from cookie
    user_id = None
    username = None
    profile_picture = None
    try:
        # Query param token takes priority (Flutter passes token explicitly)
        token = websocket.query_params.get("token")
        if not token:
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

                # CO-OP Completed: Notify partner that workout is done
                elif msg_type == "coop_completed" and user_id:
                    partner_id = msg.get("partner_id")
                    if partner_id and manager.is_user_online(partner_id):
                        await manager.send_to_user(partner_id, {
                            "type": "coop_completed",
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
        response.headers["Permissions-Policy"] = "geolocation=()"
        return response
    except Exception as e:
        logger.error(f"Request error: {request.method} {request.url.path} - {e}")
        raise e

# Removed conflicting login/register routes (now handled by simple_auth with /auth prefix)

# --- DEV: Modal Preview ---
@app.get("/dev/modals", response_class=HTMLResponse)
async def dev_modals_page(request: Request):
    return templates.TemplateResponse("dev_modals.html", {"request": request})

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
async def read_root(request: Request, gym_id: str = "iron_gym", role: str = "client", mode: str = "dashboard", demo_token: str = None):
    # demo_token allows per-tab auth (demo mode) without relying on the shared cookie
    token = demo_token or request.cookies.get("access_token")
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
    # Always trust the token's role to prevent role mismatch (e.g., owner token on staff page)
    username = None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        token_role = payload.get("role")
        username = payload.get("sub")
        if token_role:
            role = token_role
    except Exception as e:
        logger.warning("Failed to decode JWT for role detection: %s", e)

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


@app.get("/demo", response_class=HTMLResponse)
async def demo_launcher(request: Request, db: Session = Depends(get_db)):
    """Demo launcher: generates per-account tokens and renders a multi-tab launcher page."""
    GYM_OWNER_ID = "gym-owner-001"

    owner = db.query(UserORM).filter(UserORM.id == GYM_OWNER_ID).first()
    if not owner:
        return HTMLResponse("<h1>Demo data not seeded. Run seed_gym_data.py first.</h1>", status_code=404)

    demo_accounts = []
    token_expiry = timedelta(hours=8)

    # Owner
    demo_accounts.append({
        "username": owner.username,
        "role": "owner",
        "display_role": "Proprietario",
        "token": create_access_token({"sub": owner.username, "role": "owner"}, token_expiry),
        "color": "amber",
    })

    # Staff
    for s in db.query(UserORM).filter(UserORM.role == "staff", UserORM.gym_owner_id == GYM_OWNER_ID, UserORM.is_active == True).all():
        demo_accounts.append({
            "username": s.username, "role": "staff", "display_role": "Staff",
            "token": create_access_token({"sub": s.username, "role": "staff"}, token_expiry),
            "color": "blue",
        })

    # Trainers (skip x1/x2 test accounts)
    for t in db.query(UserORM).filter(
        UserORM.role == "trainer", UserORM.gym_owner_id == GYM_OWNER_ID,
        UserORM.is_approved == True, ~UserORM.username.in_(["x1", "x2"])
    ).all():
        demo_accounts.append({
            "username": t.username, "role": "trainer", "display_role": "Trainer",
            "token": create_access_token({"sub": t.username, "role": "trainer"}, token_expiry),
            "color": "green",
        })

    # Nutritionists
    for n in db.query(UserORM).filter(UserORM.role == "nutritionist", UserORM.gym_owner_id == GYM_OWNER_ID).all():
        demo_accounts.append({
            "username": n.username, "role": "nutritionist", "display_role": "Nutrizionista",
            "token": create_access_token({"sub": n.username, "role": "nutritionist"}, token_expiry),
            "color": "purple",
        })

    # Clients (first 3)
    for c in db.query(UserORM).filter(UserORM.role == "client", UserORM.gym_owner_id == GYM_OWNER_ID).limit(3).all():
        demo_accounts.append({
            "username": c.username, "role": "client", "display_role": "Cliente",
            "token": create_access_token({"sub": c.username, "role": "client"}, token_expiry),
            "color": "orange",
        })

    return templates.TemplateResponse("demo.html", {
        "request": request,
        "accounts": demo_accounts,
        "cache_buster": CACHE_BUSTER,
    })


@app.get("/kiosk", response_class=HTMLResponse)
async def kiosk_page(request: Request, key: str = ""):
    """Entrance kiosk for Raspberry Pi + QR scanner. Auth via device API key."""
    if not key:
        return HTMLResponse("<h1>Missing device key. Use /kiosk?key=YOUR_DEVICE_KEY</h1>", status_code=401)

    from database import get_db_session
    db = get_db_session()
    try:
        owner = db.query(UserORM).filter(
            UserORM.device_api_key == key,
            UserORM.role == "owner"
        ).first()

        if not owner:
            return HTMLResponse("<h1>Invalid device key.</h1>", status_code=401)

        gym_name = owner.gym_name or owner.username or "Gym"
    finally:
        db.close()

    try:
        return templates.TemplateResponse(request, "kiosk.html", {
            "device_key": key,
            "gym_name": gym_name,
        })
    except TypeError:
        # Older Starlette signature
        return templates.TemplateResponse("kiosk.html", {
            "request": request,
            "device_key": key,
            "gym_name": gym_name,
        })
    except Exception as e:
        return HTMLResponse(f"<pre>Template error: {type(e).__name__}: {e}</pre>", status_code=500)


# ---- Pi Kiosk Setup Endpoints ----

@app.get("/api/pi-files/{filename}")
async def pi_files(filename: str):
    """Serve Pi kiosk scripts for setup.sh to download."""
    import os
    allowed = {"relay_service.py", "kiosk_scanner.py"}
    if filename not in allowed:
        return HTMLResponse("Not found", status_code=404)
    path = os.path.join(os.path.dirname(__file__), "raspberry_pi", filename)
    if not os.path.exists(path):
        return HTMLResponse("File not found", status_code=404)
    with open(path) as f:
        content = f.read()
    return HTMLResponse(content, media_type="text/plain")


@app.get("/api/pi-setup/{device_key}")
async def pi_setup(request: Request, device_key: str, db: Session = Depends(get_db)):
    """Serve the setup.sh script with SERVER and DEVICE_KEY pre-filled.
    Electrician runs: curl http://SERVER:9008/api/pi-setup/DEVICE_KEY | sudo bash
    """
    import os
    owner = db.query(UserORM).filter(
        UserORM.device_api_key == device_key,
        UserORM.role == "owner"
    ).first()
    if not owner:
        return HTMLResponse("echo 'ERROR: Invalid device key'; exit 1", status_code=401, media_type="text/plain")

    server_url = str(request.base_url).rstrip("/")
    path = os.path.join(os.path.dirname(__file__), "raspberry_pi", "setup.sh")
    with open(path) as f:
        script = f.read()
    script = script.replace("__SERVER__", server_url)
    script = script.replace("__DEVICE_KEY__", device_key)
    return HTMLResponse(script, media_type="text/plain")


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
