from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_main():
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]

def test_get_gym_config():
    response = client.get("/api/config/iron_gym")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Iron Paradise Gym"
    assert "primary_color" in data

def test_get_client_data():
    response = client.get("/api/client/data")
    assert response.status_code == 200
    data = response.json()
    assert "name" in data
    assert "todays_workout" in data
    assert len(data["todays_workout"]["exercises"]) > 0

def test_get_trainer_data():
    response = client.get("/api/trainer/data")
    assert response.status_code == 200
    data = response.json()
    assert "clients" in data
    assert "video_library" in data

def test_get_owner_data():
    response = client.get("/api/owner/data")
    assert response.status_code == 200
    data = response.json()
    assert "revenue_today" in data
    assert "active_members" in data

def test_get_leaderboard_data():
    response = client.get("/api/leaderboard/data")
    assert response.status_code == 200
    data = response.json()
    assert "users" in data
    assert "weekly_challenge" in data

def test_get_gym_config_not_found():
    response = client.get("/api/config/invalid_gym_id")
    assert response.status_code == 404
    assert response.json()["detail"] == "Gym not found"
