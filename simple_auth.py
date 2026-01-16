"""
Simple Authentication System - Clean Implementation
This is a fresh login system that works around the broken routes.
"""
from fastapi import APIRouter, Request, Form, Response, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from jose import jwt
from datetime import datetime, timedelta
import os

# Setup
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
templates = Jinja2Templates(directory="templates")
simple_auth_router = APIRouter()

# Config
SECRET_KEY = os.getenv("SECRET_KEY", "dev_secret_key_123")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

# Import database and models
from database import get_db
from models_orm import UserORM as User

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_token(username: str, role: str) -> str:
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"sub": username, "role": role, "exp": expire}
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# --- LOGIN PAGE ---
@simple_auth_router.get("/login", response_class=HTMLResponse)
async def show_login(request: Request):
    return templates.TemplateResponse("login.html", {
        "request": request,
        "gym_id": "iron_gym",
        "role": "client",
        "mode": "auth"
    })

# --- LOGIN POST ---
@simple_auth_router.post("/login")
async def do_login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    # Find user
    user = db.query(User).filter(User.username == username).first()
    
    if not user or not verify_password(password, user.hashed_password):
        return templates.TemplateResponse("login.html", {
            "request": request,
            "error": "Invalid username or password",
            "gym_id": "iron_gym",
            "role": "client",
            "mode": "auth"
        })
    
    # Create token and redirect
    token = create_token(user.username, user.role)
    response = RedirectResponse(url=f"/?role={user.role}", status_code=302)
    response.set_cookie(key="access_token", value=token, httponly=True)
    return response

# --- REGISTER PAGE ---
@simple_auth_router.get("/register", response_class=HTMLResponse)
async def show_register(request: Request):
    return templates.TemplateResponse("register.html", {
        "request": request,
        "gym_id": "iron_gym",
        "role": "client",
        "mode": "auth"
    })

# --- REGISTER POST ---
@simple_auth_router.post("/register")
async def do_register(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    role: str = Form("client"),
    secret_key: str = Form(None),
    db: Session = Depends(get_db)
):
    import uuid
    
    # Validate owner registration
    OWNER_SECRET = os.getenv("OWNER_SECRET_KEY", "gymowner123")
    if role == "owner":
        if not secret_key or secret_key != OWNER_SECRET:
            return templates.TemplateResponse("register.html", {
                "request": request,
                "error": "Invalid owner secret key",
                "gym_id": "iron_gym",
                "role": "client",
                "mode": "auth"
            })
    
    # Check if username exists
    existing = db.query(User).filter(User.username == username).first()
    if existing:
        return templates.TemplateResponse("register.html", {
            "request": request,
            "error": "Username already taken",
            "gym_id": "iron_gym",
            "role": "client",
            "mode": "auth"
        })
    
    # Create user
    new_user = User(
        id=str(uuid.uuid4()),
        username=username,
        hashed_password=hash_password(password),
        role=role
    )
    db.add(new_user)
    db.commit()
    
    # Redirect to login
    return RedirectResponse(url="/auth/login?registered=true", status_code=302)

# --- LOGOUT ---
@simple_auth_router.get("/logout")
async def do_logout():
    response = RedirectResponse(url="/auth/login", status_code=302)
    response.delete_cookie("access_token")
    return response
