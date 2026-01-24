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

    # Check if trainer is approved
    if user.role == "trainer" and hasattr(user, 'is_approved') and user.is_approved == False:
        error_msg = "Your account is pending approval from your gym owner. Please wait for them to approve your registration."
        if is_json:
            from fastapi.responses import JSONResponse
            return JSONResponse(status_code=403, content={"detail": error_msg})

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
            "username": user.username,
            "user_id": user.id
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
    email: str = Form(None),
    role: str = Form("client"),
    secret_key: str = Form(None),
    gym_code: str = Form(None),
    db: Session = Depends(get_db)
):
    import uuid
    import random
    import string

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

    # Initialize variables
    generated_gym_code = None
    gym_owner_id = None
    is_approved = True  # Default to approved

    # Handle registration based on role
    if role == "owner":
        # Generate a unique 6-character gym code for owners
        while True:
            generated_gym_code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
            existing_code = db.query(User).filter(User.gym_code == generated_gym_code).first()
            if not existing_code:
                break

    elif role == "trainer":
        # Trainers MUST have a gym code
        if not gym_code or not gym_code.strip():
            return templates.TemplateResponse("register.html", {
                "request": request,
                "error": "Gym code is required for trainers. Please get the code from your gym owner.",
                "gym_id": "iron_gym",
                "role": "client",
                "mode": "auth"
            })

        # Look up the gym owner by gym code
        gym_owner = db.query(User).filter(
            User.gym_code == gym_code.strip().upper(),
            User.role == "owner"
        ).first()

        if not gym_owner:
            return templates.TemplateResponse("register.html", {
                "request": request,
                "error": "Invalid gym code. Please check with your gym owner.",
                "gym_id": "iron_gym",
                "role": "client",
                "mode": "auth"
            })

        gym_owner_id = gym_owner.id
        is_approved = False  # Trainers need owner approval

    elif role == "client" and gym_code and gym_code.strip():
        # Clients can optionally join a gym
        gym_owner = db.query(User).filter(
            User.gym_code == gym_code.strip().upper(),
            User.role == "owner"
        ).first()

        if gym_owner:
            gym_owner_id = gym_owner.id
        # If invalid code, just ignore for clients (they can join later)

    # Create user
    new_user = User(
        id=str(uuid.uuid4()),
        username=username,
        email=email if email else None,
        hashed_password=hash_password(password),
        role=role,
        gym_code=generated_gym_code,  # Only set for owners
        gym_owner_id=gym_owner_id,  # Set for trainers/clients joining a gym
        is_approved=is_approved
    )
    db.add(new_user)
    db.commit()

    # If owner, show them their gym code
    if role == "owner":
        return templates.TemplateResponse("register.html", {
            "request": request,
            "success": f"Registration successful! Your Gym Code is: {generated_gym_code}",
            "gym_code": generated_gym_code,
            "show_gym_code": True,
            "gym_id": "iron_gym",
            "role": "client",
            "mode": "auth"
        })

    # For trainers pending approval
    if role == "trainer":
        return templates.TemplateResponse("register.html", {
            "request": request,
            "error": "Registration submitted! Please wait for your gym owner to approve your account.",
            "gym_id": "iron_gym",
            "role": "client",
            "mode": "auth"
        })

    # For clients, redirect to login
    return RedirectResponse(url="/auth/login?registered=true", status_code=302)

# --- LOGOUT ---
@simple_auth_router.get("/logout")
async def do_logout():
    response = RedirectResponse(url="/auth/login", status_code=302)
    response.delete_cookie("access_token")
    return response
