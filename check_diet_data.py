"""Check if diet data was saved"""
from database import SessionLocal
from models_orm import ClientDietLogORM, UserORM
from datetime import datetime

db = SessionLocal()

# Get client
client = db.query(UserORM).filter(UserORM.username == "client").first()
if client:
    print(f"Client ID: {client.id}")

    # Check diet logs
    diet_logs = db.query(ClientDietLogORM).filter(
        ClientDietLogORM.client_id == client.id
    ).all()

    print(f"\nDiet logs found: {len(diet_logs)}")

    if diet_logs:
        print("\nFirst few entries:")
        for log in diet_logs[:5]:
            print(f"  Date: {log.date}, Meal: {log.meal_name}, Calories: {log.calories}, Type: {log.meal_type}, Time: {log.time}")

    # Check today's date format
    today = datetime.now().date().isoformat()
    print(f"\nToday's date format: {today}")

    today_meals = db.query(ClientDietLogORM).filter(
        ClientDietLogORM.client_id == client.id,
        ClientDietLogORM.date == today
    ).all()
    print(f"Today's meals: {len(today_meals)}")
else:
    print("Client not found")

db.close()
