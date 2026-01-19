from database import SessionLocal
from models_orm import UserORM, ClientProfileORM

db = SessionLocal()
users = db.query(UserORM).all()

print(f"{'ID':<36} {'Username':<20} {'Role':<10} {'Trainer ID':<36}")
print("-" * 110)
for u in users:
    trainer_id = "N/A"
    if u.role == "client":
        client = db.query(ClientProfileORM).filter(ClientProfileORM.id == u.id).first()
        if client and client.trainer_id:
            trainer_id = str(client.trainer_id)
        elif client:
             trainer_id = "None"
        else:
             trainer_id = "No Client Profile"
            
    print(f"{u.id:<36} {u.username:<20} {u.role:<10} {trainer_id:<36}")
