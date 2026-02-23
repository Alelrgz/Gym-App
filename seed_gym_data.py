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
    ClientExerciseLogORM, ExerciseORM,
    ConversationORM, MessageORM,
    PlanOfferORM, AutomatedMessageTemplateORM, AutomatedMessageLogORM,
    ClientScheduleORM, MedicalCertificateORM,
    ActivityTypeORM, FacilityORM, FacilityAvailabilityORM, FacilityBookingORM
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
# 0. ENSURE OWNER HAS VALID PASSWORD
# ─────────────────────────────────────────────────────────────
owner = db.query(UserORM).filter(UserORM.id == GYM_OWNER_ID).first()
if owner:
    # Always set a proper bcrypt hash so owner can log in
    owner.hashed_password = get_password_hash(DEFAULT_PASSWORD)
    db.commit()
    print(f"[OK] Owner '{owner.username}' password set to '{DEFAULT_PASSWORD}'")
else:
    print(f"[WARN] Owner {GYM_OWNER_ID} not found in DB")

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
# 8. SEED CONVERSATIONS (trainer ↔ client messages)
# ─────────────────────────────────────────────────────────────
print("\n--- Seeding conversations ---")
# Get Marco (trainer) and first two clients
marco = db.query(UserORM).filter(UserORM.username == "Marco", UserORM.role == "trainer").first()
if marco:
    # Find clients assigned to Marco via their profile
    marco_profiles = db.query(ClientProfileORM).filter(
        ClientProfileORM.trainer_id == marco.id
    ).limit(3).all()
    seed_client_ids = [p.id for p in marco_profiles]
    # Fallback: any client in the gym
    if not seed_client_ids:
        gym_profiles = db.query(ClientProfileORM).filter(
            ClientProfileORM.gym_id == GYM_OWNER_ID
        ).limit(3).all()
        seed_client_ids = [p.id for p in gym_profiles]
    seed_clients = db.query(UserORM).filter(UserORM.id.in_(seed_client_ids)).all() if seed_client_ids else []

    messages_data = [
        {"text": "Ciao Marco! Per caso è questa l'inclinazione giusta per l'incline bench? Ho un dubbio [Allegato]", "mins_ago": 12},
        {"text": "Perfetto, grazie mille! Domani ci vediamo alle 10?", "mins_ago": 45},
        {"text": "Ho fatto il PR sullo squat oggi! 120kg x 3!", "mins_ago": 180},
    ]

    conv_count = 0
    for i, client in enumerate(seed_clients):
        # Check if conversation already exists
        existing_conv = db.query(ConversationORM).filter(
            ConversationORM.trainer_id == marco.id,
            ConversationORM.client_id == client.id
        ).first()
        if existing_conv:
            print(f"  Conversation with {client.username} already exists, skipping")
            continue

        msg_data = messages_data[i % len(messages_data)]
        msg_time = (NOW - timedelta(minutes=msg_data["mins_ago"])).isoformat()

        conv = ConversationORM(
            id=str(uuid.uuid4()),
            trainer_id=marco.id,
            client_id=client.id,
            conversation_type="trainer_client",
            last_message_at=msg_time,
            last_message_preview=msg_data["text"][:80],
            trainer_unread_count=1,
            client_unread_count=0,
            created_at=msg_time,
        )
        db.add(conv)
        db.flush()

        msg = MessageORM(
            id=str(uuid.uuid4()),
            conversation_id=conv.id,
            sender_id=client.id,
            sender_role="client",
            content=msg_data["text"],
            is_read=False,
            created_at=msg_time,
        )
        db.add(msg)
        conv_count += 1
        print(f"  Created conversation: {client.username} → Marco: \"{msg_data['text'][:50]}...\"")

    print(f"  Total new conversations: {conv_count}")
else:
    print("  Marco trainer not found, skipping conversations")

# ─────────────────────────────────────────────────────────────
# 10. ADDITIONAL SUBSCRIPTION PLANS
# ─────────────────────────────────────────────────────────────
print("\n--- Seeding additional subscription plans ---")

EXTRA_PLANS = [
    {
        "name": "Piano Premium",
        "price": 79.99,
        "interval": "month",
        "desc": "Accesso completo, corsi di gruppo illimitati, sauna e area relax",
        "features": ["Tutto del Piano Standard", "Corsi di gruppo illimitati", "Accesso sauna", "Area relax", "Armadietto personale"]
    },
    {
        "name": "Piano VIP Annuale",
        "price": 699.99,
        "interval": "year",
        "desc": "Pacchetto annuale all-inclusive con personal training mensile",
        "features": ["Tutto del Piano Premium", "1 seduta PT al mese", "Programma nutrizionale", "Priority booking", "Guest pass x2/mese"]
    },
]

all_plans = [plan]  # 'plan' is the Standard plan from section 8
for p_data in EXTRA_PLANS:
    existing = db.query(SubscriptionPlanORM).filter(
        SubscriptionPlanORM.gym_id == GYM_OWNER_ID,
        SubscriptionPlanORM.name == p_data["name"]
    ).first()
    if existing:
        print(f"  Plan '{p_data['name']}' already exists")
        all_plans.append(existing)
        continue
    new_plan = SubscriptionPlanORM(
        id=uid(),
        gym_id=GYM_OWNER_ID,
        name=p_data["name"],
        price=p_data["price"],
        billing_interval=p_data["interval"],
        description=p_data["desc"],
        is_active=True,
        features_json=json.dumps(p_data["features"]),
    )
    db.add(new_plan)
    all_plans.append(new_plan)
    print(f"  Created plan: {p_data['name']} (€{p_data['price']}/{p_data['interval']})")

db.flush()

# Reassign some clients to premium/VIP plans for variety
for i, (user, profile, c_data) in enumerate(ALL_CLIENTS_FOR_DATA):
    sub = db.query(ClientSubscriptionORM).filter(ClientSubscriptionORM.client_id == user.id).first()
    if sub and len(all_plans) > 1:
        # Every 3rd client → Premium, every 5th → VIP
        if i % 5 == 0 and len(all_plans) > 2:
            sub.plan_id = all_plans[2].id  # VIP
        elif i % 3 == 0:
            sub.plan_id = all_plans[1].id  # Premium

db.flush()

# ─────────────────────────────────────────────────────────────
# 11. PROMOTIONAL OFFERS
# ─────────────────────────────────────────────────────────────
print("\n--- Seeding promotional offers ---")

OFFERS = [
    {
        "title": "Offerta Estate 2025",
        "desc": "Sconto 20% su tutti i piani per i nuovi iscritti",
        "discount_type": "percent",
        "discount_value": 20.0,
        "code": "ESTATE2025",
        "duration": 3,
        "max_redemptions": 50,
        "current": 12,
    },
    {
        "title": "Benvenuto in Palestra",
        "desc": "Primo mese gratuito per chi si iscrive oggi",
        "discount_type": "percent",
        "discount_value": 100.0,
        "code": "BENVENUTO",
        "duration": 1,
        "max_redemptions": 30,
        "current": 8,
    },
]

for o_data in OFFERS:
    existing = db.query(PlanOfferORM).filter(PlanOfferORM.coupon_code == o_data["code"]).first()
    if existing:
        print(f"  Offer '{o_data['code']}' already exists")
        continue
    offer = PlanOfferORM(
        id=uid(),
        gym_id=GYM_OWNER_ID,
        plan_id=all_plans[0].id,
        title=o_data["title"],
        description=o_data["desc"],
        discount_type=o_data["discount_type"],
        discount_value=o_data["discount_value"],
        discount_duration_months=o_data["duration"],
        coupon_code=o_data["code"],
        is_active=True,
        starts_at=date_ago(30),
        expires_at=date_from_now(60),
        max_redemptions=o_data["max_redemptions"],
        current_redemptions=o_data["current"],
    )
    db.add(offer)
    print(f"  Created offer: {o_data['title']} ({o_data['code']})")

db.flush()

# ─────────────────────────────────────────────────────────────
# 12. AUTOMATED MESSAGE TEMPLATES
# ─────────────────────────────────────────────────────────────
print("\n--- Seeding automated message templates ---")

TEMPLATES = [
    {
        "name": "Allenamento Saltato",
        "trigger_type": "missed_workout",
        "trigger_config": json.dumps({"days_threshold": 1}),
        "subject": "Non ti abbiamo visto oggi!",
        "message": "Ciao {client_name}! Abbiamo notato che hai saltato l'allenamento di oggi. Ricorda che la costanza è la chiave del successo! Ti aspettiamo domani 💪",
        "methods": json.dumps(["in_app"]),
    },
    {
        "name": "Inattività Prolungata",
        "trigger_type": "days_inactive",
        "trigger_config": json.dumps({"days_threshold": 5}),
        "subject": "Ci manchi!",
        "message": "Ciao {client_name}, sono passati {days_inactive} giorni dall'ultimo allenamento. Tutto bene? Il tuo trainer {trainer_name} è pronto ad aiutarti a riprendere il ritmo.",
        "methods": json.dumps(["in_app", "email"]),
    },
    {
        "name": "Appuntamento Mancato",
        "trigger_type": "no_show_appointment",
        "trigger_config": json.dumps({}),
        "subject": "Appuntamento Mancato",
        "message": "Ciao {client_name}, notiamo che non sei venuto all'appuntamento di oggi. Vuoi riprogrammarlo? Contatta la reception o il tuo trainer.",
        "methods": json.dumps(["in_app", "email"]),
    },
]

template_ids = []
for t_data in TEMPLATES:
    existing = db.query(AutomatedMessageTemplateORM).filter(
        AutomatedMessageTemplateORM.gym_id == GYM_OWNER_ID,
        AutomatedMessageTemplateORM.trigger_type == t_data["trigger_type"]
    ).first()
    if existing:
        print(f"  Template '{t_data['name']}' already exists")
        template_ids.append(existing.id)
        continue
    t_id = uid()
    template = AutomatedMessageTemplateORM(
        id=t_id,
        gym_id=GYM_OWNER_ID,
        name=t_data["name"],
        trigger_type=t_data["trigger_type"],
        trigger_config=t_data["trigger_config"],
        subject=t_data["subject"],
        message_template=t_data["message"],
        delivery_methods=t_data["methods"],
        is_enabled=True,
        send_delay_hours=0,
    )
    db.add(template)
    template_ids.append(t_id)
    print(f"  Created template: {t_data['name']}")

db.flush()

# ─────────────────────────────────────────────────────────────
# 13. AUTOMATED MESSAGE LOG
# ─────────────────────────────────────────────────────────────
print("\n--- Seeding automated message log ---")

existing_logs = db.query(AutomatedMessageLogORM).filter(
    AutomatedMessageLogORM.gym_id == GYM_OWNER_ID
).count()

if existing_logs > 3:
    print(f"  Already has {existing_logs} log entries, skipping")
else:
    log_entries = 0
    for i in range(10):
        client_user, _, _ = random.choice(ALL_CLIENTS_FOR_DATA)
        t_idx = random.randint(0, len(template_ids) - 1)
        trigger_types = ["missed_workout", "days_inactive", "no_show_appointment"]
        d_back = random.randint(1, 25)
        log = AutomatedMessageLogORM(
            template_id=template_ids[t_idx],
            client_id=client_user.id,
            gym_id=GYM_OWNER_ID,
            trigger_type=trigger_types[t_idx],
            delivery_method=random.choice(["in_app", "email"]),
            status="sent",
            triggered_at=days_ago(d_back),
            sent_at=days_ago(d_back),
        )
        db.add(log)
        log_entries += 1
    print(f"  Added {log_entries} message log entries")

db.flush()

# ─────────────────────────────────────────────────────────────
# 14. CLIENT SCHEDULE ENTRIES (Workout Completions for CRM)
# ─────────────────────────────────────────────────────────────
print("\n--- Seeding client schedule entries ---")

WORKOUT_TITLES = [
    "Push Day", "Pull Day", "Leg Day", "Full Body",
    "Upper Body", "Lower Body", "Cardio & Core", "HIIT"
]

for user, profile, c_data in ALL_CLIENTS_FOR_DATA:
    existing_schedules = db.query(ClientScheduleORM).filter(
        ClientScheduleORM.client_id == user.id,
        ClientScheduleORM.type == "workout"
    ).count()
    if existing_schedules > 5:
        print(f"  {user.username}: Already has {existing_schedules} schedule entries, skipping")
        continue

    sched_count = 0
    for days_back in range(1, 31):
        # ~65% of days have a scheduled workout
        if random.random() > 0.65:
            continue
        completed = random.random() < 0.85  # 85% completion rate
        entry = ClientScheduleORM(
            client_id=user.id,
            date=date_ago(days_back),
            title=random.choice(WORKOUT_TITLES),
            type="workout",
            completed=completed,
        )
        db.add(entry)
        sched_count += 1
    print(f"  {user.username}: Added {sched_count} schedule entries")

db.flush()

# ─────────────────────────────────────────────────────────────
# 15. MEDICAL CERTIFICATES
# ─────────────────────────────────────────────────────────────
print("\n--- Seeding medical certificates ---")

for i, (user, profile, c_data) in enumerate(ALL_CLIENTS_FOR_DATA):
    existing_cert = db.query(MedicalCertificateORM).filter(
        MedicalCertificateORM.client_id == user.id
    ).first()
    if existing_cert:
        print(f"  {user.username}: Already has certificate, skipping")
        continue

    # 10% have no certificate (skip)
    if i % 10 == 9:
        print(f"  {user.username}: No certificate (missing)")
        continue

    # Determine expiry date based on bucket
    bucket = i % 10
    if bucket < 6:
        # 60% valid (3-12 months out)
        exp_date = date_from_now(random.randint(90, 365))
        status_note = "valid"
    elif bucket < 8:
        # 20% expiring soon (within 30 days)
        exp_date = date_from_now(random.randint(3, 28))
        status_note = "expiring"
    else:
        # 10% expired
        exp_date = date_ago(random.randint(5, 60))
        status_note = "expired"

    cert = MedicalCertificateORM(
        client_id=user.id,
        filename=f"certificato_medico_{user.username.lower()}.pdf",
        file_path=f"/uploads/medical/{user.id}/certificato.pdf",
        expiration_date=exp_date,
        uploaded_at=days_ago(random.randint(30, 180)),
    )
    db.add(cert)
    print(f"  {user.username}: Certificate ({status_note}, exp: {exp_date})")

db.flush()

# ─────────────────────────────────────────────────────────────
# 16. ACTIVITY TYPES + FACILITIES
# ─────────────────────────────────────────────────────────────
print("\n--- Seeding activity types and facilities ---")

ACTIVITY_TYPES = [
    {"name": "Sala Pesi", "emoji": "🏋️", "desc": "Area attrezzature e pesi liberi"},
    {"name": "Sala Corsi", "emoji": "🤸", "desc": "Sala per corsi di gruppo e lezioni"},
    {"name": "Area Funzionale", "emoji": "💪", "desc": "Zona crossfit e allenamento funzionale"},
    {"name": "Piscina", "emoji": "🏊", "desc": "Piscina semi-olimpionica 25m"},
]

FACILITIES = {
    "Sala Pesi": [
        {"name": "Sala Pesi Piano Terra", "slot": 90, "price": None, "max": 40},
        {"name": "Sala Pesi Primo Piano", "slot": 90, "price": None, "max": 30},
    ],
    "Sala Corsi": [
        {"name": "Sala A - Corsi Cardio", "slot": 60, "price": 5.0, "max": 25},
        {"name": "Sala B - Yoga & Pilates", "slot": 75, "price": 8.0, "max": 20},
    ],
    "Area Funzionale": [
        {"name": "Box Crossfit", "slot": 60, "price": 10.0, "max": 15},
    ],
    "Piscina": [
        {"name": "Piscina - Corsie Libere", "slot": 60, "price": 8.0, "max": 6},
        {"name": "Piscina - Acquagym", "slot": 45, "price": 12.0, "max": 20},
    ],
}

activity_type_map = {}  # name -> id
facility_ids = []

for idx, at_data in enumerate(ACTIVITY_TYPES):
    existing = db.query(ActivityTypeORM).filter(
        ActivityTypeORM.gym_id == GYM_OWNER_ID,
        ActivityTypeORM.name == at_data["name"]
    ).first()
    if existing:
        print(f"  Activity type '{at_data['name']}' already exists")
        activity_type_map[at_data["name"]] = existing.id
    else:
        at_id = uid()
        at = ActivityTypeORM(
            id=at_id,
            gym_id=GYM_OWNER_ID,
            name=at_data["name"],
            emoji=at_data["emoji"],
            description=at_data["desc"],
            is_active=True,
            sort_order=idx,
        )
        db.add(at)
        activity_type_map[at_data["name"]] = at_id
        print(f"  Created activity type: {at_data['name']}")

    # Create facilities for this type
    for f_data in FACILITIES.get(at_data["name"], []):
        at_id_for_fac = activity_type_map[at_data["name"]]
        existing_fac = db.query(FacilityORM).filter(
            FacilityORM.gym_id == GYM_OWNER_ID,
            FacilityORM.name == f_data["name"]
        ).first()
        if existing_fac:
            facility_ids.append(existing_fac.id)
            continue
        f_id = uid()
        fac = FacilityORM(
            id=f_id,
            activity_type_id=at_id_for_fac,
            gym_id=GYM_OWNER_ID,
            name=f_data["name"],
            slot_duration=f_data["slot"],
            price_per_slot=f_data["price"],
            max_participants=f_data["max"],
            is_active=True,
        )
        db.add(fac)
        facility_ids.append(f_id)
        print(f"    Created facility: {f_data['name']}")

db.flush()

# ─────────────────────────────────────────────────────────────
# 17. FACILITY AVAILABILITY + BOOKINGS
# ─────────────────────────────────────────────────────────────
print("\n--- Seeding facility availability ---")

for f_id in facility_ids:
    existing_avail = db.query(FacilityAvailabilityORM).filter(
        FacilityAvailabilityORM.facility_id == f_id
    ).count()
    if existing_avail > 0:
        continue
    # Mon-Fri 07:00-22:00, Sat 08:00-18:00
    for day in range(6):  # 0=Mon to 5=Sat
        start = "07:00" if day < 5 else "08:00"
        end = "22:00" if day < 5 else "18:00"
        avail = FacilityAvailabilityORM(
            facility_id=f_id,
            day_of_week=day,
            start_time=start,
            end_time=end,
            is_available=True,
        )
        db.add(avail)

db.flush()
print(f"  Added availability for {len(facility_ids)} facilities")

print("\n--- Seeding facility bookings ---")

existing_bookings = db.query(FacilityBookingORM).filter(
    FacilityBookingORM.gym_id == GYM_OWNER_ID
).count()

if existing_bookings > 3:
    print(f"  Already has {existing_bookings} bookings, skipping")
else:
    booking_count = 0
    for days_fwd in range(1, 8):
        # 2-3 bookings per day
        for _ in range(random.randint(2, 3)):
            client_user, _, _ = random.choice(ALL_CLIENTS_FOR_DATA)
            f_id = random.choice(facility_ids)
            fac = db.query(FacilityORM).filter(FacilityORM.id == f_id).first()
            if not fac:
                continue
            h = random.randint(8, 19)
            slot_dur = fac.slot_duration or 60
            end_h = h + (slot_dur // 60)
            end_m = slot_dur % 60
            booking = FacilityBookingORM(
                id=uid(),
                facility_id=f_id,
                activity_type_id=fac.activity_type_id,
                gym_id=GYM_OWNER_ID,
                client_id=client_user.id,
                date=date_from_now(days_fwd),
                start_time=f"{h:02d}:00",
                end_time=f"{end_h:02d}:{end_m:02d}",
                duration=slot_dur,
                title=f"Prenotazione {fac.name}",
                price=fac.price_per_slot,
                payment_status="paid" if fac.price_per_slot else "free",
                status="confirmed",
            )
            db.add(booking)
            booking_count += 1
    print(f"  Added {booking_count} upcoming bookings")

db.flush()

# ─────────────────────────────────────────────────────────────
# COMMIT ALL
# ─────────────────────────────────────────────────────────────
db.commit()
print("\n" + "=" * 60)
print("[OK] All data committed successfully!")
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
