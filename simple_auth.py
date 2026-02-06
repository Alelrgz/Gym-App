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

# Alias for compatibility
get_password_hash = hash_password

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

    # Check if user must change password (first login after staff registration)
    if hasattr(user, 'must_change_password') and user.must_change_password:
        # Create token but redirect to setup-account
        token = create_token(user.username, user.role)

        if is_json:
            from fastapi.responses import JSONResponse
            return JSONResponse(content={
                "access_token": token,
                "token_type": "bearer",
                "role": user.role,
                "username": user.username,
                "user_id": user.id,
                "must_change_password": True,
                "redirect": "/auth/setup-account"
            })

        response = RedirectResponse(url="/auth/setup-account", status_code=302)
        response.set_cookie(key="access_token", value=token, httponly=True)
        return response

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
    sub_role: str = Form(None),
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

    # Staff members register with role="owner" but sub_role="staff"
    is_staff = (role == "owner" and sub_role == "staff")

    # Handle registration based on role
    if role == "owner" and sub_role != "staff":
        # Generate a unique 6-character gym code for owners
        while True:
            generated_gym_code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
            existing_code = db.query(User).filter(User.gym_code == generated_gym_code).first()
            if not existing_code:
                break

    elif is_staff:
        # Staff MUST have a gym code and need approval
        if not gym_code or not gym_code.strip():
            return templates.TemplateResponse("register.html", {
                "request": request,
                "error": "Gym code is required for staff members. Please get the code from your gym owner.",
                "gym_id": "iron_gym",
                "role": "client",
                "mode": "auth"
            })

        # Look up the gym owner by gym code
        # Only actual owners have gym_code set, so this is sufficient
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
        is_approved = False  # Staff need owner approval
        role = "staff"  # Change role to staff

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
        sub_role=sub_role,  # Store sub-role (trainer/nutritionist/both or owner/staff)
        gym_code=generated_gym_code,  # Only set for owners
        gym_owner_id=gym_owner_id,  # Set for trainers/clients/staff joining a gym
        is_approved=is_approved
    )
    db.add(new_user)
    db.commit()

    # If owner, show them their gym code
    if role == "owner" and generated_gym_code:
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

    # For staff pending approval
    if role == "staff":
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


# --- SETUP ACCOUNT (First Login Password Change) ---
@simple_auth_router.get("/setup-account", response_class=HTMLResponse)
async def show_setup_account(request: Request, db: Session = Depends(get_db)):
    """Show the setup account page for users who need to change their password"""
    # Get current user from token
    token = request.cookies.get("access_token")
    if not token:
        return RedirectResponse(url="/auth/login", status_code=302)

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if not username:
            return RedirectResponse(url="/auth/login", status_code=302)

        user = db.query(User).filter(User.username == username).first()
        if not user:
            return RedirectResponse(url="/auth/login", status_code=302)

        # If user doesn't need to change password, redirect to dashboard
        if not getattr(user, 'must_change_password', False):
            return RedirectResponse(url=f"/?role={user.role}", status_code=302)

        return templates.TemplateResponse("setup_account.html", {
            "request": request,
            "current_username": user.username,
            "gym_id": user.gym_owner_id or "iron_gym",
            "role": user.role,
            "mode": "auth"
        })
    except jwt.ExpiredSignatureError:
        return RedirectResponse(url="/auth/login", status_code=302)
    except jwt.InvalidTokenError:
        return RedirectResponse(url="/auth/login", status_code=302)


@simple_auth_router.post("/setup-account")
async def do_setup_account(request: Request, db: Session = Depends(get_db)):
    """Handle setup account form submission"""
    # Get current user from token
    token = request.cookies.get("access_token")
    if not token:
        return RedirectResponse(url="/auth/login", status_code=302)

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if not username:
            return RedirectResponse(url="/auth/login", status_code=302)

        user = db.query(User).filter(User.username == username).first()
        if not user:
            return RedirectResponse(url="/auth/login", status_code=302)

        # Parse form data
        form = await request.form()
        new_username = form.get("new_username", "").strip()
        new_password = form.get("new_password", "").strip()
        confirm_password = form.get("confirm_password", "").strip()

        # Validation
        errors = []
        if not new_username:
            errors.append("Username is required")
        elif len(new_username) < 3:
            errors.append("Username must be at least 3 characters")
        elif new_username != username:
            # Check if new username is taken
            existing = db.query(User).filter(User.username == new_username).first()
            if existing:
                errors.append("Username already taken")

        if not new_password:
            errors.append("Password is required")
        elif len(new_password) < 12:
            errors.append("Password must be at least 12 characters")
        elif new_password != confirm_password:
            errors.append("Passwords do not match")

        if errors:
            return templates.TemplateResponse("setup_account.html", {
                "request": request,
                "current_username": user.username,
                "error": ". ".join(errors),
                "gym_id": user.gym_owner_id or "iron_gym",
                "role": user.role,
                "mode": "auth"
            })

        # Update user
        user.username = new_username
        user.hashed_password = get_password_hash(new_password)
        user.must_change_password = False
        db.commit()

        # Create new token with updated username
        new_token = create_token(new_username, user.role)

        # Redirect to dashboard
        response = RedirectResponse(url=f"/?role={user.role}", status_code=302)
        response.set_cookie(key="access_token", value=new_token, httponly=True)
        return response

    except jwt.ExpiredSignatureError:
        return RedirectResponse(url="/auth/login", status_code=302)
    except jwt.InvalidTokenError:
        return RedirectResponse(url="/auth/login", status_code=302)
