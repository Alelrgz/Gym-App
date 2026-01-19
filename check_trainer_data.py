"""
Quick diagnostic script to check trainer client data
"""
import sys
sys.path.insert(0, '.')

from services import UserService
from database import get_db_session
from models_orm import UserORM

service = UserService()
db = get_db_session()

try:
    # Get first trainer
    trainer = db.query(UserORM).filter(UserORM.role=='trainer').first()
    
    if not trainer:
        print("[ERROR] No trainers found in database")
        sys.exit(1)
    
    print(f"[OK] Found trainer: {trainer.username} (ID: {trainer.id})")
    print()
    
    # Get trainer data
    data = service.get_trainer(trainer.id)
    
    print(f"[DATA] Trainer Data Summary:")
    print(f"   - Active Clients: {data.active_clients}")
    print(f"   - At Risk Clients: {data.at_risk_clients}")
    print(f"   - Total Clients in Array: {len(data.clients)}")
    print()
    
    if len(data.clients) > 0:
        print(f"[CLIENTS] First 5 Clients:")
        for i, client in enumerate(data.clients[:5], 1):
            # ClientSummary is a Pydantic model, access attributes directly
            print(f"   {i}. {client.name} (ID: {client.id}) - {client.status}")
    else:
        print("[WARNING] No clients in the array!")
        
        # Check if there are any clients in the database
        all_clients = db.query(UserORM).filter(UserORM.role=='client').all()
        print(f"\n[CHECK] Total clients in database: {len(all_clients)}")
        if len(all_clients) > 0:
            print("   First 3:")
            for c in all_clients[:3]:
                print(f"   - {c.username} (ID: {c.id})")
    
finally:
    db.close()
