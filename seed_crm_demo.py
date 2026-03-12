"""
Seed script: Creates 10 diverse test clients for CRM demo.
Mix of new, active, at-risk, churning, and ex-clients with realistic data.
"""
import uuid
import random
from datetime import datetime, timedelta, date
from database import get_db_session
from models_orm import (
    UserORM, ClientProfileORM, ClientScheduleORM,
    ClientSubscriptionORM, ClientDailyDietSummaryORM,
    ClientExerciseLogORM, WeightHistoryORM
)
from simple_auth import hash_password

# ── Config ───────────────────────────────────────────────
OWNER_ID = "f8cabf90-f8bd-4df8-9e9f-b904084ab740"
TRAINER_ID = "15fc203a-8386-4f4c-af77-1c56136a40e4"
PLAN_BASE_ID = "0fc5666d-679d-4279-ad5b-c2fe233053ea"
PLAN_ANNUAL_ID = "4fe0a575-de4e-489f-acf2-4b9285c6eff6"
PASSWORD = hash_password("demo1234")
TODAY = date.today()

EXERCISES = [
    ("Panca Piana", "weight_reps"),
    ("Squat", "weight_reps"),
    ("Stacco", "weight_reps"),
    ("Military Press", "weight_reps"),
    ("Lat Machine", "weight_reps"),
    ("Curl Bilanciere", "weight_reps"),
    ("Leg Press", "weight_reps"),
    ("Crunch", "weight_reps"),
    ("Corsa", "duration"),
    ("Cyclette", "duration"),
]

# ── Client Profiles ──────────────────────────────────────
CLIENTS = [
    # (username, name, email, phone, category, streak, health, weight, days_since_join, days_inactive, sub_status, trainer)
    ("marco_rossi",     "Marco Rossi",     "marco@test.it",     "+393201234501", "active",   12, 85, 78.0, 60,  1, "active",   True),
    ("giulia_bianchi",  "Giulia Bianchi",  "giulia@test.it",    "+393201234502", "active",   8,  72, 62.5, 90,  3, "active",   True),
    ("luca_ferrari",    "Luca Ferrari",    "luca@test.it",      "+393201234503", "active",   25, 92, 85.0, 120, 0, "active",   True),
    ("sofia_romano",    "Sofia Romano",    "sofia@test.it",     "+393201234504", "new",      3,  60, 58.0, 7,   2, "active",   True),
    ("alessandro_conti","Alessandro Conti","alessandro@test.it", "+393201234505", "new",      1,  45, 92.0, 5,   1, "active",   False),
    ("chiara_moretti",  "Chiara Moretti",  "chiara@test.it",    "+393201234506", "at_risk",  0,  30, 65.0, 45,  10,"active",   True),
    ("davide_colombo",  "Davide Colombo",  "davide@test.it",    "+393201234507", "at_risk",  0,  25, 88.0, 80,  12,"active",   False),
    ("elena_greco",     "Elena Greco",     "elena@test.it",     "+393201234508", "churning", 0,  15, 70.0, 150, 30,"active",   True),
    ("matteo_gallo",    "Matteo Gallo",    "matteo@test.it",    "+393201234509", "churning", 0,  10, 95.0, 200, 45,"canceled", False),
    ("francesca_costa", "Francesca Costa", "francesca@test.it", "+393201234510", "ex",       0,  5,  55.0, 180, 60,"canceled", False),
]


def create_user(db, username, name, email, phone, days_since_join):
    uid = str(uuid.uuid4())
    created = (datetime.utcnow() - timedelta(days=days_since_join)).isoformat()
    user = UserORM(
        id=uid,
        username=username,
        email=email,
        phone=phone,
        hashed_password=PASSWORD,
        role="client",
        is_active=True,
        created_at=created,
        gym_owner_id=OWNER_ID,
    )
    db.add(user)
    return uid


def create_profile(db, uid, name, email, streak, health, weight, has_trainer):
    profile = ClientProfileORM(
        id=uid,
        name=name,
        email=email,
        gym_id=OWNER_ID,
        trainer_id=TRAINER_ID if has_trainer else None,
        streak=streak,
        health_score=health,
        weight=weight,
        last_seen=(TODAY - timedelta(days=random.randint(0, 5))).isoformat(),
        is_premium=random.choice([True, False]),
    )
    db.add(profile)


def create_subscription(db, uid, plan_id, status, days_since_join):
    sub_id = str(uuid.uuid4())
    start = (TODAY - timedelta(days=days_since_join)).isoformat()
    canceled_at = None
    if status == "canceled":
        canceled_at = (TODAY - timedelta(days=random.randint(5, 30))).isoformat()

    sub = ClientSubscriptionORM(
        id=sub_id,
        client_id=uid,
        plan_id=plan_id,
        gym_id=OWNER_ID,
        status=status,
        start_date=start,
        current_period_start=start,
        current_period_end=(TODAY + timedelta(days=30)).isoformat() if status == "active" else start,
        canceled_at=canceled_at,
        created_at=start,
    )
    db.add(sub)


def create_workouts(db, uid, num_workouts, days_inactive):
    """Create completed workout schedule entries + exercise logs."""
    for i in range(num_workouts):
        workout_date = (TODAY - timedelta(days=days_inactive + i * random.randint(1, 3))).isoformat()

        # Schedule entry
        schedule = ClientScheduleORM(
            client_id=uid,
            date=workout_date,
            title=random.choice(["Push Day", "Pull Day", "Leg Day", "Full Body", "Cardio", "Upper Body"]),
            type="workout",
            completed=True,
        )
        db.add(schedule)

        # Exercise log (2-4 exercises per workout)
        num_exercises = random.randint(2, 4)
        for j in range(num_exercises):
            ex_name, metric_type = random.choice(EXERCISES)
            num_sets = random.randint(3, 5)
            for s in range(1, num_sets + 1):
                log = ClientExerciseLogORM(
                    client_id=uid,
                    date=workout_date,
                    exercise_name=ex_name,
                    set_number=s,
                    reps=random.randint(6, 15) if metric_type == "weight_reps" else 0,
                    weight=round(random.uniform(20, 120), 1) if metric_type == "weight_reps" else 0,
                    duration=round(random.uniform(10, 45), 1) if metric_type == "duration" else None,
                    metric_type=metric_type,
                )
                db.add(log)


def create_courses(db, uid, num_courses, days_inactive):
    """Create completed course schedule entries."""
    for i in range(num_courses):
        course_date = (TODAY - timedelta(days=days_inactive + i * random.randint(2, 7))).isoformat()
        schedule = ClientScheduleORM(
            client_id=uid,
            date=course_date,
            title=random.choice(["Yoga", "Pilates", "Spinning", "CrossFit", "Zumba", "Boxe"]),
            type="course",
            completed=True,
        )
        db.add(schedule)


def create_diet_data(db, uid, num_days, quality):
    """Create diet summary entries. quality: 'good', 'medium', 'poor'."""
    for i in range(num_days):
        d = (TODAY - timedelta(days=i)).isoformat()
        if quality == "good":
            cals = random.randint(1800, 2400)
            protein = random.randint(120, 180)
            score = random.randint(70, 95)
        elif quality == "medium":
            cals = random.randint(1500, 2800)
            protein = random.randint(80, 150)
            score = random.randint(40, 75)
        else:
            cals = random.randint(1200, 3200)
            protein = random.randint(40, 120)
            score = random.randint(10, 45)

        entry = ClientDailyDietSummaryORM(
            client_id=uid,
            date=d,
            total_calories=cals,
            total_protein=protein,
            total_carbs=random.randint(150, 350),
            total_fat=random.randint(40, 100),
            total_hydration=random.randint(1000, 3000),
            meal_count=random.randint(2, 5),
            health_score=score,
            target_calories=2200,
            target_protein=150,
            target_carbs=250,
            target_fat=70,
        )
        db.add(entry)


def create_weight_history(db, uid, base_weight, num_entries, trend):
    """Create weight history entries. trend: 'down', 'up', 'stable'."""
    for i in range(num_entries):
        d = (datetime.utcnow() - timedelta(days=i * 3)).isoformat()
        if trend == "down":
            w = base_weight + (i * 0.15)  # older = heavier (losing weight)
        elif trend == "up":
            w = base_weight - (i * 0.1)   # older = lighter (gaining weight)
        else:
            w = base_weight + random.uniform(-0.5, 0.5)

        w = round(w + random.uniform(-0.3, 0.3), 1)
        bf = round(random.uniform(12, 28), 1)
        entry = WeightHistoryORM(
            client_id=uid,
            weight=w,
            body_fat_pct=bf,
            fat_mass=round(w * bf / 100, 1),
            lean_mass=round(w * (100 - bf) / 100, 1),
            recorded_at=d,
        )
        db.add(entry)


def seed():
    db = get_db_session()
    try:
        # Check if already seeded
        existing = db.query(UserORM).filter(UserORM.username == "marco_rossi").first()
        if existing:
            print("Demo data already exists. Skipping.")
            return

        print("Creating 10 demo clients...")

        for (username, name, email, phone, category, streak, health,
             weight, days_join, days_inactive, sub_status, has_trainer) in CLIENTS:

            uid = create_user(db, username, name, email, phone, days_join)
            create_profile(db, uid, name, email, streak, health, weight, has_trainer)

            # Subscription
            plan = random.choice([PLAN_BASE_ID, PLAN_ANNUAL_ID])
            create_subscription(db, uid, plan, sub_status, days_join)

            # Workouts (more for active, fewer for at-risk/churning)
            if category == "active":
                create_workouts(db, uid, random.randint(15, 30), days_inactive)
                create_courses(db, uid, random.randint(3, 8), days_inactive)
                create_diet_data(db, uid, 30, "good")
                create_weight_history(db, uid, weight, 15, "down")
            elif category == "new":
                create_workouts(db, uid, random.randint(2, 6), days_inactive)
                create_courses(db, uid, random.randint(0, 2), days_inactive)
                create_diet_data(db, uid, 7, "medium")
                create_weight_history(db, uid, weight, 3, "stable")
            elif category == "at_risk":
                create_workouts(db, uid, random.randint(5, 12), days_inactive)
                create_courses(db, uid, random.randint(1, 3), days_inactive)
                create_diet_data(db, uid, 14, "medium")
                create_weight_history(db, uid, weight, 8, "up")
            elif category == "churning":
                create_workouts(db, uid, random.randint(2, 5), days_inactive)
                create_courses(db, uid, random.randint(0, 1), days_inactive)
                create_diet_data(db, uid, 5, "poor")
                create_weight_history(db, uid, weight, 5, "up")
            elif category == "ex":
                create_workouts(db, uid, random.randint(1, 3), days_inactive)
                create_diet_data(db, uid, 3, "poor")
                create_weight_history(db, uid, weight, 3, "stable")

            print(f"  + {name} ({category}, {sub_status}, streak={streak})")

        db.commit()
        print("\nDone! 10 demo clients created.")
        print("Pipeline should now show: ~2 New, ~3 Active, ~2 At Risk, ~2 Churning, ~1 Ex-Client")

    except Exception as e:
        db.rollback()
        print(f"Error: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed()
