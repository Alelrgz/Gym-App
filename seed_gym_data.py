"""
Seed realistic gym data for IronGym (gym-owner-001)
Creates: 3 new trainers, 1 nutritionist, 4 new clients
Adds 30 days of data for all named IronGym clients
"""
import sys, uuid, random, json
from datetime import datetime, timedelta
sys.path.insert(0, '.')

from database import get_db_session
from models_orm import (
    UserORM, ClientProfileORM, WeightHistoryORM,
    AppointmentORM, CheckInORM, SubscriptionPlanORM,
    ClientSubscriptionORM, TrainerAvailabilityORM,
    ClientExerciseLogORM, ExerciseORM
)
from auth import get_password_hash

db = get_db_session()

GYM_OWNER_ID = "gym-owner-001"
DEFAULT_PASSWORD = "1234"
NOW = datetime.utcnow()
TODAY = NOW.date()

def uid():
    return str(uuid.uuid4())

def days_ago(n):
    return (NOW - timedelta(days=n)).isoformat()

def date_ago(n):
    return str((TODAY - timedelta(days=n)))

def date_from_now(n):
    return str((TODAY + timedelta(days=n)))

def rand_time(start_h=7, end_h=20):
    h = random.randint(start_h, end_h - 1)
    m = random.choice([0, 30])
    return f"{h:02d}:{m:02d}"

print("=" * 60)
print("Seeding IronGym test data")
print("=" * 60)

# ─────────────────────────────────────────────────────────────
# 1. TRAINERS (3 new)
# ─────────────────────────────────────────────────────────────
NEW_TRAINERS = [
    {"username": "Marco",    "email": "marco@irongym.it",   "bio": "Specializzato in bodybuilding e strength training. 8 anni di esperienza.", "specialties": "bodybuilding,strength,hypertrophy"},
    {"username": "Sofia",    "email": "sofia@irongym.it",   "bio": "Personal trainer certificata FIPE. Esperta in functional training e riabilitazione.", "specialties": "functional,rehabilitation,yoga"},
    {"username": "Davide",   "email": "davide@irongym.it",  "bio": "Ex atleta di crossfit. Specializzato in HIIT e performance atletica.", "specialties": "crossfit,hiit,cardio"},
]

created_trainers = []
existing_trainer_ids = []

# Get existing trainers for IronGym
existing_trainers = db.query(UserORM).filter(
    UserORM.role == "trainer",
    UserORM.gym_owner_id == GYM_OWNER_ID
).all()
existing_trainer_ids = [t.id for t in existing_trainers]
print(f"Existing trainers in IronGym: {[t.username for t in existing_trainers]}")

for t_data in NEW_TRAINERS:
    existing = db.query(UserORM).filter(UserORM.username == t_data["username"]).first()
    if existing:
        print(f"  Trainer {t_data['username']} already exists, skipping")
        created_trainers.append(existing)
        continue
    trainer = UserORM(
        id=uid(),
        username=t_data["username"],
        email=t_data["email"],
        hashed_password=get_password_hash(DEFAULT_PASSWORD),
        role="trainer",
        gym_owner_id=GYM_OWNER_ID,
        is_approved=True,
        is_active=True,
        bio=t_data["bio"],
        specialties=t_data["specialties"],
        session_rate=random.choice([45.0, 55.0, 60.0, 70.0]),
        created_at=days_ago(random.randint(60, 180)),
    )
    db.add(trainer)
    created_trainers.append(trainer)
    print(f"  Created trainer: {trainer.username}")

db.flush()

all_trainer_ids = existing_trainer_ids + [t.id for t in created_trainers if t not in existing_trainers]
# Make sure we have the full list
all_trainers = db.query(UserORM).filter(
    UserORM.role == "trainer",
    UserORM.gym_owner_id == GYM_OWNER_ID
).all()
all_trainer_ids = [t.id for t in all_trainers]
print(f"Total trainers for IronGym: {len(all_trainer_ids)}")

# ─────────────────────────────────────────────────────────────
# 2. NUTRITIONIST (1 new)
# ─────────────────────────────────────────────────────────────
nutri_username = "Elena"
existing_nutri = db.query(UserORM).filter(UserORM.username == nutri_username).first()
if existing_nutri:
    nutri = existing_nutri
    print(f"  Nutritionist {nutri_username} already exists")
else:
    nutri = UserORM(
        id=uid(),
        username=nutri_username,
        email="elena@irongym.it",
        hashed_password=get_password_hash(DEFAULT_PASSWORD),
        role="nutritionist",
        gym_owner_id=GYM_OWNER_ID,
        is_approved=True,
        is_active=True,
        bio="Biologa nutrizionista con specializzazione in sport nutrition. Lavoro con atleti e appassionati di fitness per ottimizzare alimentazione e composizione corporea.",
        specialties="sport nutrition,weight loss,muscle gain,meal planning",
        created_at=days_ago(90),
    )
    db.add(nutri)
    db.flush()
    print(f"  Created nutritionist: {nutri.username}")

# ─────────────────────────────────────────────────────────────
# 3. CLIENTS (4 new + existing ones get data)
# ─────────────────────────────────────────────────────────────
NEW_CLIENTS = [
    {"username": "Chiara",     "email": "chiara@mail.it",      "weight": 58.0, "fat": 22.0, "goal_w": 55.0, "trend": -0.15},
    {"username": "Federica",   "email": "federica@mail.it",    "weight": 63.5, "fat": 25.0, "goal_w": 59.0, "trend": -0.20},
    {"username": "Riccardo",   "email": "riccardo@mail.it",    "weight": 82.0, "fat": 16.0, "goal_w": 78.0, "trend": -0.25},
    {"username": "Valentina",  "email": "valentina@mail.it",   "weight": 65.0, "fat": 27.0, "goal_w": 60.0, "trend": -0.18},
]

created_clients = []
for c_data in NEW_CLIENTS:
    existing = db.query(UserORM).filter(UserORM.username == c_data["username"]).first()
    if existing:
        print(f"  Client {c_data['username']} already exists, will add data")
        created_clients.append((existing, c_data))
        continue
    client_user = UserORM(
        id=uid(),
        username=c_data["username"],
        email=c_data["email"],
        hashed_password=get_password_hash(DEFAULT_PASSWORD),
        role="client",
        is_active=True,
        created_at=days_ago(random.randint(30, 45)),
    )
    db.add(client_user)
    db.flush()

    trainer_id = random.choice(all_trainer_ids)
    lean_mass = c_data["weight"] * (1 - c_data["fat"] / 100)
    fat_mass = c_data["weight"] * (c_data["fat"] / 100)

    profile = ClientProfileORM(
        id=client_user.id,
        name=c_data["username"],
        email=c_data["email"],
        gym_id=GYM_OWNER_ID,
        trainer_id=trainer_id,
        nutritionist_id=nutri.id,
        weight=c_data["weight"],
        body_fat_pct=c_data["fat"],
        fat_mass=round(fat_mass, 1),
        lean_mass=round(lean_mass, 1),
        weight_goal=c_data["goal_w"],
        streak=random.randint(2, 21),
        gems=random.randint(50, 400),
        health_score=random.randint(55, 90),
        plan="Premium",
        status="active",
        is_premium=True,
        privacy_mode="public",
        date_of_birth=f"199{random.randint(0,9)}-{random.randint(1,12):02d}-{random.randint(1,28):02d}",
        strength_goal_upper=random.randint(10, 25),
        strength_goal_lower=random.randint(10, 25),
        strength_goal_cardio=random.randint(5, 20),
    )
    db.add(profile)
    db.flush()
    created_clients.append((client_user, c_data))
    print(f"  Created client: {client_user.username}")

# ─────────────────────────────────────────────────────────────
# 4. ADD DATA TO EXISTING NAMED CLIENTS
# ─────────────────────────────────────────────────────────────
EXISTING_CLIENT_DATA = {
    "GigaNigga":   {"weight": 85.0, "fat": 18.0, "goal_w": 80.0, "trend": -0.20},
    "Alessandro":  {"weight": 78.0, "fat": 15.0, "goal_w": 75.0, "trend": -0.15},
    "Giovanni":    {"weight": 90.0, "fat": 20.0, "goal_w": 85.0, "trend": -0.25},
    "Luca":        {"weight": 72.0, "fat": 14.0, "goal_w": 70.0, "trend": -0.10},
    "Marco":       {"weight": 88.0, "fat": 19.0, "goal_w": 83.0, "trend": -0.20},
    "Matteo":      {"weight": 76.0, "fat": 16.0, "goal_w": 73.0, "trend": -0.15},
}

existing_client_pairs = []
for username, c_data in EXISTING_CLIENT_DATA.items():
    user = db.query(UserORM).filter(UserORM.username == username).first()
    if user:
        # Update profile stats if not already set
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == user.id).first()
        if profile:
            if not profile.weight:
                profile.weight = c_data["weight"]
                profile.body_fat_pct = c_data["fat"]
                lean_mass = c_data["weight"] * (1 - c_data["fat"] / 100)
                fat_mass = c_data["weight"] * (c_data["fat"] / 100)
                profile.fat_mass = round(fat_mass, 1)
                profile.lean_mass = round(lean_mass, 1)
            if not profile.weight_goal:
                profile.weight_goal = c_data["goal_w"]
            if not profile.nutritionist_id:
                profile.nutritionist_id = nutri.id
            if not profile.streak:
                profile.streak = random.randint(3, 25)
            if not profile.gems:
                profile.gems = random.randint(100, 600)
            if not profile.strength_goal_upper:
                profile.strength_goal_upper = random.randint(10, 25)
                profile.strength_goal_lower = random.randint(10, 25)
                profile.strength_goal_cardio = random.randint(5, 20)
            existing_client_pairs.append((user, profile, c_data))
            print(f"  Prepped existing client: {username}")

db.flush()

# All clients to generate data for
ALL_CLIENTS_FOR_DATA = []
# Existing clients with profile obj
for user, profile, c_data in existing_client_pairs:
    ALL_CLIENTS_FOR_DATA.append((user, profile, c_data))
# New clients
for client_user, c_data in created_clients:
    profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == client_user.id).first()
    if profile:
        ALL_CLIENTS_FOR_DATA.append((client_user, profile, c_data))

print(f"\nGenerating data for {len(ALL_CLIENTS_FOR_DATA)} clients...")

# ─────────────────────────────────────────────────────────────
# 5. WEIGHT HISTORY (30 days, every 2-3 days)
# ─────────────────────────────────────────────────────────────
WEIGHT_DAYS = [0, 2, 4, 7, 9, 11, 14, 16, 18, 21, 23, 25, 28, 30]

for user, profile, c_data in ALL_CLIENTS_FOR_DATA:
    # Skip if already has weight history
    existing_weights = db.query(WeightHistoryORM).filter(
        WeightHistoryORM.client_id == user.id
    ).count()
    if existing_weights > 5:
        print(f"  {user.username}: Already has {existing_weights} weight entries, skipping")
        continue

    start_weight = c_data["weight"] - (c_data["trend"] * 30)  # Backtrack to 30 days ago
    for day_offset in WEIGHT_DAYS:
        days_back = 30 - day_offset
        w = start_weight + (c_data["trend"] * day_offset) + random.uniform(-0.5, 0.5)
        w = round(max(w, 45.0), 1)
        fat = c_data["fat"] + random.uniform(-0.5, 0.5) - (day_offset * 0.03)
        fat = round(max(fat, 8.0), 1)
        lean = round(w * (1 - fat / 100), 1)
        fat_mass = round(w * (fat / 100), 1)

        entry = WeightHistoryORM(
            client_id=user.id,
            weight=w,
            body_fat_pct=fat,
            fat_mass=fat_mass,
            lean_mass=lean,
            recorded_at=days_ago(days_back),
        )
        db.add(entry)
    print(f"  {user.username}: Added {len(WEIGHT_DAYS)} weight entries")

db.flush()

# ─────────────────────────────────────────────────────────────
# 6. APPOINTMENTS (past + future, mix of statuses)
# ─────────────────────────────────────────────────────────────
SESSION_TYPES = ["bodybuilding", "crossfit", "calisthenics", "cardio", "functional"]

for user, profile, c_data in ALL_CLIENTS_FOR_DATA:
    trainer_id = profile.trainer_id
    if not trainer_id:
        continue

    existing_appts = db.query(AppointmentORM).filter(
        AppointmentORM.client_id == user.id
    ).count()
    if existing_appts > 3:
        print(f"  {user.username}: Already has {existing_appts} appointments, skipping")
        continue

    # Past appointments (completed or cancelled)
    past_days = [28, 24, 21, 17, 14, 10, 7, 3]
    for i, days_back in enumerate(past_days):
        status = "completed" if random.random() > 0.15 else "canceled"
        t = rand_time(9, 19)
        h, m = map(int, t.split(":"))
        end_t = f"{h+1:02d}:{m:02d}"
        appt = AppointmentORM(
            id=uid(),
            client_id=user.id,
            trainer_id=trainer_id,
            date=date_ago(days_back),
            start_time=t,
            end_time=end_t,
            duration=60,
            title="Sessione Personal Training",
            session_type=random.choice(SESSION_TYPES),
            price=random.choice([50.0, 55.0, 60.0, 65.0]),
            payment_method="card",
            payment_status="paid" if status == "completed" else "refunded",
            status=status,
            created_at=days_ago(days_back + 3),
            updated_at=days_ago(days_back),
        )
        db.add(appt)

    # Future appointments (scheduled)
    for days_fwd in [3, 7, 14]:
        t = rand_time(9, 18)
        h, m = map(int, t.split(":"))
        end_t = f"{h+1:02d}:{m:02d}"
        appt = AppointmentORM(
            id=uid(),
            client_id=user.id,
            trainer_id=trainer_id,
            date=date_from_now(days_fwd),
            start_time=t,
            end_time=end_t,
            duration=60,
            title="Sessione Personal Training",
            session_type=random.choice(SESSION_TYPES),
            price=random.choice([50.0, 55.0, 60.0]),
            payment_method="card",
            payment_status="paid",
            status="scheduled",
            created_at=days_ago(2),
            updated_at=days_ago(1),
        )
        db.add(appt)

    print(f"  {user.username}: Added {len(past_days) + 3} appointments")

db.flush()

# ─────────────────────────────────────────────────────────────
# 7. CHECK-INS (gym visits, ~3-4x per week)
# ─────────────────────────────────────────────────────────────
CHECK_IN_DAYS = [1, 2, 4, 5, 7, 8, 9, 11, 12, 14, 15, 16, 18, 19, 21, 22, 23, 25, 26, 28, 29, 30]

for user, profile, c_data in ALL_CLIENTS_FOR_DATA:
    existing_checkins = db.query(CheckInORM).filter(
        CheckInORM.member_id == user.id
    ).count()
    if existing_checkins > 5:
        print(f"  {user.username}: Already has {existing_checkins} check-ins, skipping")
        continue

    # Sample ~70% of possible days
    sampled_days = [d for d in CHECK_IN_DAYS if random.random() > 0.3]
    for days_back in sampled_days:
        checkin = CheckInORM(
            member_id=user.id,
            gym_owner_id=GYM_OWNER_ID,
            checked_in_at=days_ago(days_back),
        )
        db.add(checkin)

    print(f"  {user.username}: Added {len(sampled_days)} check-ins")

db.flush()

# ─────────────────────────────────────────────────────────────
# 8. SUBSCRIPTIONS
# ─────────────────────────────────────────────────────────────
# Find or create a subscription plan for IronGym
plan = db.query(SubscriptionPlanORM).filter(
    SubscriptionPlanORM.gym_id == GYM_OWNER_ID,
    SubscriptionPlanORM.is_active == True
).first()

if not plan:
    plan = SubscriptionPlanORM(
        id=uid(),
        gym_id=GYM_OWNER_ID,
        name="Piano Standard",
        price=49.99,
        billing_interval="month",
        description="Accesso illimitato alla palestra, spogliatoi e attrezzature",
        is_active=True,
        features_json=json.dumps(["Accesso illimitato", "Spogliatoi", "Attrezzature", "Area cardio"]),
    )
    db.add(plan)
    db.flush()
    print(f"  Created subscription plan: {plan.name}")

for user, profile, c_data in ALL_CLIENTS_FOR_DATA:
    existing_sub = db.query(ClientSubscriptionORM).filter(
        ClientSubscriptionORM.client_id == user.id
    ).first()
    if existing_sub:
        continue

    sub = ClientSubscriptionORM(
        id=uid(),
        client_id=user.id,
        plan_id=plan.id,
        gym_id=GYM_OWNER_ID,
        status="active",
        start_date=days_ago(random.randint(30, 60)),
        current_period_start=days_ago(random.randint(1, 30)),
        current_period_end=date_from_now(random.randint(5, 30)),
        created_at=days_ago(random.randint(30, 60)),
        updated_at=days_ago(random.randint(0, 5)),
    )
    db.add(sub)
    print(f"  {user.username}: Added active subscription")

db.flush()

# ─────────────────────────────────────────────────────────────
# 9. EXERCISE LOGS (strength training logs for past 30 days)
# ─────────────────────────────────────────────────────────────
# Find or create some basic exercises
EXERCISE_DEFS = [
    {"name": "Panca Piana",          "muscle": "upper",  "type": "strength"},
    {"name": "Squat",                "muscle": "lower",  "type": "strength"},
    {"name": "Stacco da Terra",      "muscle": "lower",  "type": "strength"},
    {"name": "Trazioni",             "muscle": "upper",  "type": "strength"},
    {"name": "Military Press",       "muscle": "upper",  "type": "strength"},
    {"name": "Leg Press",            "muscle": "lower",  "type": "strength"},
    {"name": "Dumbbell Curl",        "muscle": "upper",  "type": "strength"},
    {"name": "Corsa su Tapis Roulant", "muscle": "cardio", "type": "cardio"},
    {"name": "Rowing Machine",       "muscle": "upper",  "type": "cardio"},
]

exercise_ids = {}
for ex_def in EXERCISE_DEFS:
    ex = db.query(ExerciseORM).filter(ExerciseORM.name == ex_def["name"]).first()
    if not ex:
        ex = ExerciseORM(
            id=uid(),
            name=ex_def["name"],
            muscle=ex_def["muscle"],
            type=ex_def["type"],
            owner_id=None,  # global exercise
        )
        db.add(ex)
        db.flush()
    exercise_ids[ex_def["name"]] = (ex.id, ex_def["muscle"])

UPPER_EXERCISES = ["Panca Piana", "Trazioni", "Military Press", "Dumbbell Curl"]
LOWER_EXERCISES = ["Squat", "Stacco da Terra", "Leg Press"]
CARDIO_EXERCISES = ["Corsa su Tapis Roulant", "Rowing Machine"]

WORKOUT_DAYS = [1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 19, 20, 22, 23, 25, 26, 28, 29]

for user, profile, c_data in ALL_CLIENTS_FOR_DATA:
    existing_logs = db.query(ClientExerciseLogORM).filter(
        ClientExerciseLogORM.client_id == user.id
    ).count()
    if existing_logs > 10:
        print(f"  {user.username}: Already has {existing_logs} exercise logs, skipping")
        continue

    base_weight = c_data["weight"] * 0.5  # Starting bench ~50% bodyweight
    log_count = 0
    for days_back in WORKOUT_DAYS:
        if random.random() < 0.15:
            continue

        workout_type = random.choices(["upper", "lower", "cardio"], weights=[4, 4, 2])[0]
        if workout_type == "upper":
            exercises_today = random.sample(UPPER_EXERCISES, k=random.randint(2, 3))
        elif workout_type == "lower":
            exercises_today = random.sample(LOWER_EXERCISES, k=random.randint(2, 3))
        else:
            exercises_today = random.sample(CARDIO_EXERCISES, k=1)

        for ex_name in exercises_today:
            ex_info = exercise_ids.get(ex_name)
            if not ex_info:
                continue
            ex_id, muscle = ex_info

            progress_factor = 1 + (30 - days_back) * 0.005
            date_str = date_ago(days_back)

            if ex_name in CARDIO_EXERCISES:
                # Cardio: log as duration
                log = ClientExerciseLogORM(
                    client_id=user.id,
                    date=date_str,
                    exercise_name=ex_name,
                    set_number=1,
                    reps=0,
                    weight=0.0,
                    duration=float(random.randint(15, 35)),
                    metric_type="duration",
                )
                db.add(log)
                log_count += 1
            else:
                w = round(base_weight * progress_factor + random.uniform(-2.5, 2.5), 1)
                sets = random.randint(3, 4)
                reps = random.randint(6, 12)
                for set_num in range(1, sets + 1):
                    log = ClientExerciseLogORM(
                        client_id=user.id,
                        date=date_str,
                        exercise_name=ex_name,
                        set_number=set_num,
                        reps=reps,
                        weight=w + random.uniform(-1, 1),
                        metric_type="weight_reps",
                    )
                    db.add(log)
                    log_count += 1

    print(f"  {user.username}: Added {log_count} exercise log entries")

# ─────────────────────────────────────────────────────────────
# COMMIT ALL
# ─────────────────────────────────────────────────────────────
db.commit()
print("\n" + "=" * 60)
print("✓ All data committed successfully!")
print("=" * 60)
print(f"\nSummary:")
print(f"  Gym: IronGym (gym-owner-001), Code: IRON01")
print(f"  Trainers created: {len(NEW_TRAINERS)} new (Marco, Sofia, Davide)")
print(f"  Nutritionist created: Elena")
print(f"  New clients: Chiara, Federica, Riccardo, Valentina")
print(f"  Data added for: GigaNigga, Alessandro, Giovanni, Luca, Marco, Matteo + new clients")
print(f"\n  All passwords: {DEFAULT_PASSWORD}")
print("\nTrainers in IronGym (login with Test1234!):")
for t in db.query(UserORM).filter(UserORM.role == "trainer", UserORM.gym_owner_id == GYM_OWNER_ID).all():
    print(f"  - {t.username}")
print(f"  - Elena (nutritionist)")
db.close()
