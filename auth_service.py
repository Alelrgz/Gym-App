from datetime import datetime, timedelta
from typing import Optional
from fastapi import Depends, HTTPException, status, Request, Response
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from database import get_db, get_client_session
from models_client_orm import User
import os

# --- CONFIGURATION ---
SECRET_KEY = os.getenv("SECRET_KEY", "dev_secret_key_123")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 # 1 day

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

class AuthService:
    def verify_password(self, plain_password, hashed_password):
        return pwd_context.verify(plain_password, hashed_password)

    def get_password_hash(self, password):
        return pwd_context.hash(password)

    def create_access_token(self, data: dict, expires_delta: Optional[timedelta] = None):
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=15)
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return encoded_jwt

    def get_user_by_username(self, db: Session, username: str):
        return db.query(User).filter(User.username == username).first()

    def create_user(self, db: Session, user: User):
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

# --- DEPENDENCIES ---

async def get_current_user(request: Request, db: Session = Depends(get_db)):
    token = request.cookies.get("access_token")
    if not token:
        # Fallback to Authorization header for API calls
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
    
    if not token:
        return None 
        # We don't raise here to allow optional auth or redirect handling in routes
        # Or we can raise if we strictly want to protect. 
        # User implies "authenticated user".
    
    # Actually, for get_current_user, if it fails, we usually want to raise 401
    # unless it's get_current_user_optional.
    # But for a login page redirect flow, raising 401 might not trigger redirect.
    # We will raise HTTPException and let route handle or use exception handler.

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    
    # We need a session to query user. 
    # Note: access_token usually has user info, but let's query DB to be safe/fresh.
    # Problem: `get_db` yields a session for `GLOBAL_DB_PATH`. 
    # But User model is in... wait, where `User` table is created?
    # db.py -> `Base.metadata.create_all(bind=trainer_engine)` or `client_engine`.
    # We need a shared DB for Users or sync them.
    # GymApp seems to have `global.db` (exercises) and client specific DBs.
    # `User` should probably be in `global.db` OR a new `users.db`.
    # Let's assume `global.db` for now as it makes most sense for a centralized User table.
    
    user = db.query(User).filter(User.username == username).first()
    if user is None:
         raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)):
    if not current_user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return current_user
