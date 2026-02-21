"""
Create test accounts for all user roles with simple credentials
Username: owner, trainer, client, staff
Password: 1234 (for all)
"""
import os
import sys
import uuid
import random
import string
from sqlalchemy.orm import Session
from database import SessionLocal, engine
from models_orm import UserORM, ClientProfileORM
from simple_auth import hash_password

def create_test_accounts():
    """Create test accounts for each role type"""
    db = SessionLocal()

    try:
        # Password for all accounts
        password = "1234"
        hashed_pwd = hash_password(password)

        print("Creating test accounts...")
        print("=" * 50)

        # 1. Create Owner account
        print("\n1. Creating OWNER account...")

        # Check if owner already exists
        existing_owner = db.query(UserORM).filter(UserORM.username == "owner").first()
        if existing_owner:
            print(f"   [OK] Owner already exists (gym_code: {existing_owner.gym_code})")
            owner = existing_owner
        else:
            # Generate gym code
            gym_code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))

            owner = UserORM(
                id=str(uuid.uuid4()),
                username="owner",
                email="owner@test.com",
                hashed_password=hashed_pwd,
                role="owner",
                sub_role="owner",
                gym_code=gym_code,
                is_approved=True,
                gym_name="Test Gym"
            )
            db.add(owner)
            db.commit()
            db.refresh(owner)
            print(f"   [OK] Created owner (gym_code: {owner.gym_code})")

        gym_code = owner.gym_code
        owner_id = owner.id

        # 2. Create Trainer account
        print("\n2. Creating TRAINER account...")
        existing_trainer = db.query(UserORM).filter(UserORM.username == "trainer").first()
        if existing_trainer:
            print(f"   [OK] Trainer already exists")
        else:
            trainer = UserORM(
                id=str(uuid.uuid4()),
                username="trainer",
                email="trainer@test.com",
                hashed_password=hashed_pwd,
                role="trainer",
                sub_role="trainer",
                gym_owner_id=owner_id,
                is_approved=True,  # Pre-approved for testing
                session_rate=50.0
            )
            db.add(trainer)
            db.commit()
            print(f"   [OK] Created trainer (approved)")

        # 3. Create Client account
        print("\n3. Creating CLIENT account...")
        existing_client = db.query(UserORM).filter(UserORM.username == "client").first()
        if existing_client:
            print(f"   [OK] Client already exists")
        else:
            client = UserORM(
                id=str(uuid.uuid4()),
                username="client",
                email="client@test.com",
                hashed_password=hashed_pwd,
                role="client",
                gym_owner_id=owner_id,
                is_approved=True
            )
            db.add(client)
            db.commit()
            db.refresh(client)

            # Create client profile
            client_profile = ClientProfileORM(
                id=client.id,
                name="client",
                email="client@test.com",
                gym_id=owner_id,
                streak=0,
                gems=100,
                health_score=75,
                plan="Standard",
                status="Active",
                last_seen="Never",
                is_premium=False
            )
            db.add(client_profile)
            db.commit()
            print(f"   [OK] Created client with profile")

        # 4. Create Staff account
        print("\n4. Creating STAFF account...")
        existing_staff = db.query(UserORM).filter(UserORM.username == "staff").first()
        if existing_staff:
            print(f"   [OK] Staff already exists")
        else:
            staff = UserORM(
                id=str(uuid.uuid4()),
                username="staff",
                email="staff@test.com",
                hashed_password=hashed_pwd,
                role="staff",
                sub_role="staff",
                gym_owner_id=owner_id,
                is_approved=True  # Pre-approved for testing
            )
            db.add(staff)
            db.commit()
            print(f"   [OK] Created staff (approved)")

        print("\n" + "=" * 50)
        print("[SUCCESS] All test accounts created successfully!")
        print("\nLogin Credentials:")
        print("-" * 50)
        print(f"Owner:   username='owner'   password='1234'")
        print(f"Trainer: username='trainer' password='1234'")
        print(f"Client:  username='client'  password='1234'")
        print(f"Staff:   username='staff'   password='1234'")
        print("-" * 50)
        print(f"\nGym Code: {gym_code}")
        print(f"App URL:  http://127.0.0.1:9008")
        print("=" * 50)

    except Exception as e:
        print(f"\n[ERROR] Error creating accounts: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    create_test_accounts()
