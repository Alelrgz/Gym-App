"""
SMTP OAuth Routes - Google and Microsoft OAuth2 for automated email sending.

Flow:
1. Owner clicks "Sign in with Google/Microsoft" in Flutter settings
2. Flutter calls GET /api/owner/smtp-oauth/{provider}/authorize
3. Backend returns an auth URL → Flutter opens it in browser
4. User grants permission → provider redirects to callback URL
5. Backend exchanges code for tokens, stores them, shows success page
6. Flutter reloads SMTP settings to see OAuth is connected

Environment variables needed:
  GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET
  MICROSOFT_OAUTH_CLIENT_ID, MICROSOFT_OAUTH_CLIENT_SECRET
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from database import get_db
from auth import get_current_user
from models_orm import UserORM
from datetime import datetime, timedelta
import os
import logging
import json
import base64
import hashlib
import secrets

logger = logging.getLogger("gym_app")

router = APIRouter()

# ── Provider configs ─────────────────────────────────────────

PROVIDERS = {
    "google": {
        "auth_url": "https://accounts.google.com/o/oauth2/v2/auth",
        "token_url": "https://oauth2.googleapis.com/token",
        "scopes": "https://mail.google.com/",
        "client_id_env": "GOOGLE_OAUTH_CLIENT_ID",
        "client_secret_env": "GOOGLE_OAUTH_CLIENT_SECRET",
    },
    "microsoft": {
        "auth_url": "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
        "token_url": "https://login.microsoftonline.com/common/oauth2/v2.0/token",
        "scopes": "https://outlook.office365.com/SMTP.Send offline_access",
        "client_id_env": "MICROSOFT_OAUTH_CLIENT_ID",
        "client_secret_env": "MICROSOFT_OAUTH_CLIENT_SECRET",
    },
}

# Temporary state store for CSRF protection (in-memory, cleared on restart)
_oauth_states: dict[str, dict] = {}


def _get_callback_url(request: Request, provider: str) -> str:
    """Build the OAuth callback URL from the current request."""
    base = str(request.base_url).rstrip("/")
    return f"{base}/api/owner/smtp-oauth/{provider}/callback"


def _get_provider_creds(provider: str) -> tuple[str, str]:
    """Get client ID and secret for a provider from env vars."""
    cfg = PROVIDERS[provider]
    client_id = os.getenv(cfg["client_id_env"], "")
    client_secret = os.getenv(cfg["client_secret_env"], "")
    return client_id, client_secret


# ── Authorize endpoint ───────────────────────────────────────

@router.get("/api/owner/smtp-oauth/{provider}/authorize")
async def smtp_oauth_authorize(
    provider: str,
    request: Request,
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Generate an OAuth authorization URL for the given provider."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    if provider not in PROVIDERS:
        raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")

    client_id, client_secret = _get_provider_creds(provider)
    if not client_id or not client_secret:
        raise HTTPException(
            status_code=400,
            detail=f"OAuth non configurato per {provider}. Chiedi all'amministratore di impostare le credenziali."
        )

    cfg = PROVIDERS[provider]
    callback_url = _get_callback_url(request, provider)

    # Generate CSRF state token that encodes the owner's user ID
    state = secrets.token_urlsafe(32)
    _oauth_states[state] = {
        "user_id": user.id,
        "provider": provider,
        "created": datetime.utcnow().isoformat(),
    }

    # Build authorization URL
    params = {
        "client_id": client_id,
        "redirect_uri": callback_url,
        "response_type": "code",
        "scope": cfg["scopes"],
        "state": state,
        "access_type": "offline",  # Google: get refresh token
        "prompt": "consent",       # Force consent to always get refresh token
    }

    if provider == "microsoft":
        # Microsoft uses different param names
        params.pop("access_type", None)

    query = "&".join(f"{k}={_url_encode(v)}" for k, v in params.items())
    auth_url = f"{cfg['auth_url']}?{query}"

    return {"url": auth_url, "provider": provider}


# ── Callback endpoint ────────────────────────────────────────

@router.get("/api/owner/smtp-oauth/{provider}/callback", response_class=HTMLResponse)
async def smtp_oauth_callback(
    provider: str,
    request: Request,
    code: str = None,
    state: str = None,
    error: str = None,
    db: Session = Depends(get_db)
):
    """Handle the OAuth callback from Google/Microsoft."""
    if error:
        return _render_result_page(False, f"Autorizzazione rifiutata: {error}")

    if not code or not state:
        return _render_result_page(False, "Parametri mancanti nella risposta OAuth.")

    # Validate state
    state_data = _oauth_states.pop(state, None)
    if not state_data or state_data["provider"] != provider:
        return _render_result_page(False, "Stato OAuth non valido. Riprova.")

    # Check state is not too old (10 min max)
    created = datetime.fromisoformat(state_data["created"])
    if (datetime.utcnow() - created).total_seconds() > 600:
        return _render_result_page(False, "Sessione OAuth scaduta. Riprova.")

    user_id = state_data["user_id"]
    user = db.query(UserORM).filter(UserORM.id == user_id).first()
    if not user:
        return _render_result_page(False, "Utente non trovato.")

    # Exchange code for tokens
    client_id, client_secret = _get_provider_creds(provider)
    callback_url = _get_callback_url(request, provider)

    try:
        tokens = await _exchange_code(provider, code, client_id, client_secret, callback_url)
    except Exception as e:
        logger.error(f"OAuth token exchange failed for {provider}: {e}")
        return _render_result_page(False, f"Errore nello scambio token: {e}")

    access_token = tokens.get("access_token")
    refresh_token = tokens.get("refresh_token")
    expires_in = tokens.get("expires_in", 3600)

    if not access_token:
        return _render_result_page(False, "Token di accesso non ricevuto.")

    if not refresh_token:
        return _render_result_page(False, "Refresh token non ricevuto. Riprova e assicurati di concedere tutti i permessi.")

    # Get the user's email from the token (for SMTP sender address)
    email = await _get_user_email(provider, access_token)

    # Store everything on the owner record
    expiry = (datetime.utcnow() + timedelta(seconds=int(expires_in))).isoformat()

    user.smtp_oauth_provider = provider
    user.smtp_oauth_refresh_token = refresh_token
    user.smtp_oauth_access_token = access_token
    user.smtp_oauth_token_expiry = expiry

    # Auto-fill SMTP settings for the provider
    if provider == "google":
        user.smtp_host = "smtp.gmail.com"
        user.smtp_port = 587
    elif provider == "microsoft":
        user.smtp_host = "smtp.office365.com"
        user.smtp_port = 587

    if email:
        user.smtp_user = email
        if not user.smtp_from_email:
            user.smtp_from_email = email

    # Clear manual password since we're using OAuth now
    user.smtp_password = None

    db.commit()

    provider_name = "Google" if provider == "google" else "Microsoft"
    return _render_result_page(True, f"Email {provider_name} collegata con successo! Puoi chiudere questa pagina.")


# ── Disconnect endpoint ──────────────────────────────────────

@router.delete("/api/owner/smtp-oauth")
async def smtp_oauth_disconnect(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Disconnect OAuth and clear tokens."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    user.smtp_oauth_provider = None
    user.smtp_oauth_refresh_token = None
    user.smtp_oauth_access_token = None
    user.smtp_oauth_token_expiry = None
    db.commit()

    return {"status": "disconnected"}


# ── Status endpoint ──────────────────────────────────────────

@router.get("/api/owner/smtp-oauth/status")
async def smtp_oauth_status(
    user: UserORM = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Check if OAuth is configured and which provider."""
    if user.role != "owner":
        raise HTTPException(status_code=403, detail="Owner access only")

    # Check which providers are available (have env vars set)
    available = {}
    for name in PROVIDERS:
        client_id, client_secret = _get_provider_creds(name)
        available[name] = bool(client_id and client_secret)

    return {
        "connected": bool(user.smtp_oauth_provider and user.smtp_oauth_refresh_token),
        "provider": user.smtp_oauth_provider,
        "email": user.smtp_user if user.smtp_oauth_provider else None,
        "available_providers": available,
    }


# ══════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════

def _url_encode(value: str) -> str:
    from urllib.parse import quote
    return quote(value, safe="")


async def _exchange_code(provider: str, code: str, client_id: str, client_secret: str, redirect_uri: str) -> dict:
    """Exchange an authorization code for access + refresh tokens."""
    import httpx

    cfg = PROVIDERS[provider]
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "client_id": client_id,
        "client_secret": client_secret,
        "redirect_uri": redirect_uri,
    }

    async with httpx.AsyncClient() as client:
        resp = await client.post(cfg["token_url"], data=data)
        resp.raise_for_status()
        return resp.json()


async def _get_user_email(provider: str, access_token: str) -> str | None:
    """Fetch the user's email address from the OAuth provider."""
    import httpx

    try:
        if provider == "google":
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    "https://www.googleapis.com/oauth2/v2/userinfo",
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                resp.raise_for_status()
                return resp.json().get("email")
        elif provider == "microsoft":
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    "https://graph.microsoft.com/v1.0/me",
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                resp.raise_for_status()
                data = resp.json()
                return data.get("mail") or data.get("userPrincipalName")
    except Exception as e:
        logger.warning(f"Failed to get email from {provider}: {e}")
    return None


def refresh_oauth_token(provider: str, refresh_token: str) -> dict | None:
    """Synchronously refresh an OAuth access token. Used by email_service."""
    import requests

    if provider not in PROVIDERS:
        return None

    cfg = PROVIDERS[provider]
    client_id, client_secret = _get_provider_creds(provider)
    if not client_id or not client_secret:
        return None

    data = {
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "client_id": client_id,
        "client_secret": client_secret,
    }

    if provider == "microsoft":
        data["scope"] = cfg["scopes"]

    try:
        resp = requests.post(cfg["token_url"], data=data, timeout=10)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        logger.error(f"OAuth token refresh failed for {provider}: {e}")
        return None


def _render_result_page(success: bool, message: str) -> str:
    """Render a simple HTML page shown after OAuth callback."""
    color = "#4ADE80" if success else "#F87171"
    icon = "&#10003;" if success else "&#10007;"
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>FitOS - Configurazione Email</title>
        <style>
            body {{
                background: #0f0f17;
                color: white;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                display: flex;
                align-items: center;
                justify-content: center;
                min-height: 100vh;
                margin: 0;
            }}
            .card {{
                background: rgba(255,255,255,0.04);
                border: 1px solid rgba(255,255,255,0.06);
                border-radius: 16px;
                padding: 40px;
                text-align: center;
                max-width: 400px;
            }}
            .icon {{
                width: 64px;
                height: 64px;
                border-radius: 50%;
                background: {color}22;
                color: {color};
                font-size: 32px;
                line-height: 64px;
                margin: 0 auto 20px;
            }}
            .message {{
                color: #9ca3af;
                font-size: 15px;
                line-height: 1.5;
            }}
            .close-hint {{
                color: #4b5563;
                font-size: 12px;
                margin-top: 20px;
            }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="icon">{icon}</div>
            <p class="message">{message}</p>
            <p class="close-hint">Puoi chiudere questa pagina e tornare all'app.</p>
        </div>
    </body>
    </html>
    """
