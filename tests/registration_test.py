import pytest
from fastapi.testclient import TestClient
import sys
import os

# Add parent directory to path to import main
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from models_orm import UserORM
from database import GlobalSessionLocal
import uuid

client = TestClient(app)

def test_register_user():
    # unique username
    username = f"testuser_{uuid.uuid4()}"
    email = f"{username}@example.com"
    password = "password123"
    
    response = client.post("/api/auth/register", json={
        "username": username,
        "email": email,
        "password": password,
        "role": "client"
    })
    
    assert response.status_code == 200
    assert response.json()["status"] == "success"
    
    # Verify in DB
    db = GlobalSessionLocal()
    user = db.query(UserORM).filter(UserORM.username == username).first()
    assert user is not None
    assert user.email == email
    db.close()

def test_register_existing_user():
    # Create a user first
    username = f"testuser_{uuid.uuid4()}"
    client.post("/api/auth/register", json={
        "username": username,
        "password": "password123"
    })
    
    # Try to register again
    response = client.post("/api/auth/register", json={
        "username": username,
        "password": "password123"
    })
    
    assert response.status_code == 400
    assert "already registered" in response.json()["detail"]
