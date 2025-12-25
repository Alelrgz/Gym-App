# Gym App Prototype

A high-fidelity, white-label gym application prototype built with FastAPI and Vanilla JS.

## Architecture

- **Backend**: FastAPI (Python) with Pydantic models for strict data validation.
- **Frontend**: Vanilla JS (ES Modules) with Tailwind CSS.
- **Design**: "Dark Glass" aesthetic with Bento Grid layouts.

## Features

- **Role-Based Views**: Client, Trainer, and Owner dashboards.
- **Interactive Workout Mode**: Real-time rep counting, set progression, and rest timers.
- **Gamification**: Daily quests, XP, and leaderboards.
- **Progress Tracking**: Hydration, macros, and physique photo gallery.

## Setup

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Run the server:
   ```bash
   python main.py
   ```

3. Open in browser:
   - `http://127.0.0.1:9007`

## API Documentation

Interactive API documentation is available at:
- `http://127.0.0.1:9007/docs` (Swagger UI)
- `http://127.0.0.1:9007/redoc` (ReDoc)

## Testing

Run the automated test suite:
```bash
pytest
```
