"""
Simple Authentication System - Clean Implementation
This is a fresh login system that works around the broken routes.
"""
from fastapi import APIRouter, Request, Form, Response, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
import bcrypt
from jose import jwt
from datetime import datetime, timedelta
import os
from typing import Optional

# Setup
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
    # bcrypt requires bytes, returns bytes. We store as string.
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    # bcrypt requires bytes for both
    pwd_bytes = plain_password.encode('utf-8')
    hashed_bytes = hashed_password.encode('utf-8')
    return bcrypt.checkpw(pwd_bytes, hashed_bytes)

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
async def do_login(request: Request, db: Session = Depends(get_db)):
    # 1. Manually parse body based on Content-Type
    content_type = request.headers.get("Content-Type", "")
    username = None
    password = None
    is_json = False

    try:
        if "application/json" in content_type:
            is_json = True
            body = await request.json()
            username = body.get("username")
            password = body.get("password")
        else:
            # Assume Form
            form = await request.form()
            username = form.get("username")
            password = form.get("password")
    except Exception as e:
        # Parsing failed
        pass

    # 2. Authenticate
    user = None
    if username:
        user = db.query(User).filter(User.username == username).first()
    
    if not user or not verify_password(password, user.hashed_password):
        error_msg = "Invalid username or password"
        if is_json:
            from fastapi.responses import JSONResponse
            return JSONResponse(status_code=401, content={"detail": error_msg})
        
        return templates.TemplateResponse("login.html", {
            "request": request,
            "error": error_msg,
            "gym_id": "iron_gym",
            "role": "client",
            "mode": "auth"
        })
    
    # 3. Success - Create token
    token = create_token(user.username, user.role)
    
    # 4. Return response based on client type
    if is_json:
        from fastapi.responses import JSONResponse
        return JSONResponse(content={
            "access_token": token,
            "token_type": "bearer",
            "role": user.role,
            "username": user.username
        })
    
    # Default: Browser Redirect
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
