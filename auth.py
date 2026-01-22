from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt

from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from database import get_db
from models_orm import UserORM

# SECRET_KEY should be in env, but for prototype we hardcode
import os
SECRET_KEY = os.getenv("SECRET_KEY", "dev_secret_key_123")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30


import bcrypt
import logging

logger = logging.getLogger("gym_app")

def verify_password(plain_password, hashed_password):
    # bcrypt requires bytes for both
    pwd_bytes = plain_password.encode('utf-8')
    hashed_bytes = hashed_password.encode('utf-8')
    return bcrypt.checkpw(pwd_bytes, hashed_bytes)

def get_password_hash(password):
    # bcrypt requires bytes, returns bytes. We store as string.
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/auth/login", auto_error=False)

async def get_current_user(request: Request, db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # Get token from Authorization header or cookie
    token = None
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.replace("Bearer ", "")
        logger.info(f"AUTH: Got token from Authorization header")
    else:
        token = request.cookies.get("access_token")
        logger.info(f"DEBUG: Got token from cookie: {token[:20] if token else 'None'}...")

    if not token:
        logger.info("DEBUG: No token found in header or cookie")
        raise credentials_exception

    logger.info(f"DEBUG: Validating token: {token[:20]}...")

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            logger.info("DEBUG: Token missing 'sub' (username)")
            raise credentials_exception
    except JWTError as e:
        logger.info(f"DEBUG: JWT Validation Error: {e}")
        raise credentials_exception
    except Exception as e:
        logger.info(f"DEBUG: Unexpected Token Error: {e}")
        raise credentials_exception

    user = db.query(UserORM).filter(UserORM.username == username).first()
    if user is None:
        logger.info(f"DEBUG: User {username} not found in DB")
        raise credentials_exception

    logger.info(f"DEBUG: Successfully authenticated user: {username}")
    return user
