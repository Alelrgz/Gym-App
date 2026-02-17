"""
Populate comprehensive nutritionist data for the 'client' user.
Fills: health profile, body composition, weight history (3 months),
diet settings, daily diet summaries, and diet logs.
"""
import random
from datetime import datetime, timedelta, date
from database import SessionLocal
from models_orm import (
    UserORM, ClientProfileORM, ClientDietSettingsORM,
    ClientDailyDietSummaryORM, ClientDietLogORM, WeightHistoryORM
)


def populate():
    db = SessionLocal()
    try:
        client = db.query(UserORM).filter(UserORM.username == "client").first()
        if not client:
            print("[ERROR] Client user not found. Run create_test_accounts.py first.")
            return
        cid = client.id
        print(f"Client: {client.username} ({cid})")
        print("=" * 60)

        # ── 1. Health Profile ──────────────────────────────────
        print("\n1. Setting health profile...")
        profile = db.query(ClientProfileORM).filter(ClientProfileORM.id == cid).first()
        if not profile:
            print("[ERROR] ClientProfile not found.")
            return

        profile.height_cm = 178.0
        profile.gender = "male"
        profile.date_of_birth = "2000-06-15"
        profile.activity_level = "moderate"
        profile.allergies = "Lactose intolerance"
        profile.medical_conditions = "None"
        profile.supplements = "Whey Protein, Creatine, Multivitamin, Omega-3"
        profile.sleep_hours = 7.5
        profile.meal_frequency = "5_small"
        profile.food_preferences = "none"
        profile.occupation_type = "sedentary"

        # Current body composition
        profile.weight = 80.2
        profile.body_fat_pct = 18.3
        profile.fat_mass = round(80.2 * 0.183, 1)   # 14.7 kg
        profile.lean_mass = round(80.2 * (1 - 0.183), 1)  # 65.5 kg
        profile.weight_goal = 76.0

        db.commit()
        print("   [OK] Height: 178cm, Male, DOB: 2000-06-15")
        print("   [OK] Weight: 80.2kg, BF: 18.3%, Goal: 76kg")
        print("   [OK] Activity: moderate, Sleep: 7.5h")
        print("   [OK] Allergies: Lactose intolerance")
        print("   [OK] Supplements: Whey, Creatine, Multi, Omega-3")

        # ── 2. Weight History (3 months) ──────────────────────
        print("\n2. Creating weight history (90 days)...")

        # Clear existing weight history
        db.query(WeightHistoryORM).filter(WeightHistoryORM.client_id == cid).delete()
        db.commit()

        today = date.today()
        start_weight = 85.0
        start_bf = 22.0
        current_weight = 80.2
        current_bf = 18.3

        entries = []
        # ~2 entries per week over 90 days = ~26 entries
        day = 0
        while day < 90:
            record_date = today - timedelta(days=90 - day)
            progress = day / 90.0  # 0.0 to 1.0

            # Weight decreases from 85 to 80.2 with natural fluctuation
            target_w = start_weight - (start_weight - current_weight) * progress
            w = round(target_w + random.uniform(-0.4, 0.4), 1)

            # Body fat decreases from 22% to 18.3%
            target_bf = start_bf - (start_bf - current_bf) * progress
            bf = round(target_bf + random.uniform(-0.3, 0.3), 1)

            fm = round(w * bf / 100, 1)
            lm = round(w - fm, 1)

            entry = WeightHistoryORM(
                client_id=cid,
                weight=w,
                body_fat_pct=bf,
                fat_mass=fm,
                lean_mass=lm,
                recorded_at=datetime(record_date.year, record_date.month, record_date.day, 8, 0).isoformat()
            )
            db.add(entry)
            entries.append((record_date, w, bf))

            # Next entry in 2-4 days
            day += random.randint(2, 4)

        # Ensure today has the exact current values
        latest = WeightHistoryORM(
            client_id=cid,
            weight=80.2,
            body_fat_pct=18.3,
            fat_mass=14.7,
            lean_mass=65.5,
            recorded_at=datetime(today.year, today.month, today.day, 8, 0).isoformat()
        )
        db.add(latest)
        db.commit()
        print(f"   [OK] Added {len(entries) + 1} weight entries over 90 days")
        print(f"   [OK] Start: {start_weight}kg @ {start_bf}% BF -> Now: {current_weight}kg @ {current_bf}% BF")

        # ── 3. Diet Settings ──────────────────────────────────
        print("\n3. Setting diet targets (cutting phase)...")

        diet = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id == cid).first()
        if not diet:
            diet = ClientDietSettingsORM(id=cid)
            db.add(diet)

        diet.fitness_goal = "cut"
        diet.base_calories = 2500
        diet.calories_target = 2200
        diet.protein_target = 180
        diet.carbs_target = 220
        diet.fat_target = 60
        diet.hydration_target = 3000
        diet.consistency_target = 85

        # Simulate today's partial intake
        diet.calories_current = 1450
        diet.protein_current = 120
        diet.carbs_current = 145
        diet.fat_current = 38
        diet.hydration_current = 1800
        diet.last_reset_date = today.isoformat()

        db.commit()
        print("   [OK] Goal: Cut | Cal: 2200 | P: 180g | C: 220g | F: 60g")
        print("   [OK] Hydration: 3000ml | Consistency target: 85%")

        # ── 4. Daily Diet Summaries (30 days) ─────────────────
        print("\n4. Creating daily diet summaries (30 days)...")

        db.query(ClientDailyDietSummaryORM).filter(
            ClientDailyDietSummaryORM.client_id == cid
        ).delete()
        db.commit()

        meal_plans = [
            # (name, calories, protein, carbs, fat, type, time)
            ("Scrambled Eggs & Toast", 380, 28, 30, 16, "breakfast", "07:30"),
            ("Greek Yogurt & Granola", 320, 22, 40, 8, "breakfast", "07:45"),
            ("Protein Oatmeal", 350, 30, 42, 8, "breakfast", "08:00"),
            ("Avocado Toast with Egg", 400, 18, 35, 22, "breakfast", "07:15"),
            ("Grilled Chicken & Rice", 520, 42, 55, 10, "lunch", "12:30"),
            ("Turkey Wrap", 450, 35, 40, 15, "lunch", "13:00"),
            ("Tuna Salad Bowl", 420, 38, 30, 18, "lunch", "12:15"),
            ("Salmon Poke Bowl", 480, 36, 48, 14, "lunch", "12:45"),
            ("Steak & Sweet Potato", 580, 45, 42, 20, "dinner", "19:00"),
            ("Chicken Stir-fry", 500, 40, 50, 12, "dinner", "19:30"),
            ("Grilled Fish & Veggies", 420, 38, 25, 18, "dinner", "18:45"),
            ("Lean Beef Burrito Bowl", 550, 42, 52, 16, "dinner", "19:15"),
            ("Protein Shake", 180, 30, 8, 3, "snack", "10:30"),
            ("Mixed Nuts & Apple", 250, 8, 28, 14, "snack", "15:30"),
            ("Rice Cakes & PB", 200, 6, 22, 10, "snack", "16:00"),
            ("Cottage Cheese & Berries", 160, 20, 14, 3, "snack", "21:00"),
        ]

        for day_offset in range(30, 0, -1):
            d = today - timedelta(days=day_offset)
            d_str = d.isoformat()

            # Simulate varying adherence (some days better than others)
            adherence = random.uniform(0.7, 1.1)
            target_cal = 2200
            target_p = 180
            target_c = 220
            target_f = 60

            # Pick 4-5 meals for this day
            breakfast = random.choice([m for m in meal_plans if m[5] == "breakfast"])
            lunch = random.choice([m for m in meal_plans if m[5] == "lunch"])
            dinner = random.choice([m for m in meal_plans if m[5] == "dinner"])
            snacks = random.sample([m for m in meal_plans if m[5] == "snack"], random.randint(1, 3))

            day_meals = [breakfast, lunch, dinner] + snacks
            total_cal = sum(m[1] for m in day_meals)
            total_p = sum(m[2] for m in day_meals)
            total_c = sum(m[3] for m in day_meals)
            total_f = sum(m[4] for m in day_meals)
            total_hydration = random.randint(2200, 3200)

            # Health score based on adherence
            cal_diff = abs(total_cal - target_cal) / target_cal
            health = max(40, min(100, int(100 - cal_diff * 100 + random.randint(-5, 5))))

            summary = ClientDailyDietSummaryORM(
                client_id=cid,
                date=d_str,
                total_calories=total_cal,
                total_protein=total_p,
                total_carbs=total_c,
                total_fat=total_f,
                total_hydration=total_hydration,
                target_calories=target_cal,
                target_protein=target_p,
                target_carbs=target_c,
                target_fat=target_f,
                meal_count=len(day_meals),
                health_score=health
            )
            db.add(summary)

            # Add individual meal logs
            for meal in day_meals:
                log = ClientDietLogORM(
                    client_id=cid,
                    date=d_str,
                    meal_name=meal[0],
                    calories=meal[1],
                    meal_type=meal[5],
                    time=meal[6]
                )
                db.add(log)

        db.commit()
        print(f"   [OK] Added 30 daily diet summaries")
        print(f"   [OK] Added ~130 individual meal logs")

        # ── 5. Update profile stats ───────────────────────────
        print("\n5. Updating profile stats...")
        profile.streak = 12
        profile.gems = 450
        profile.health_score = 88
        profile.status = "Active"
        profile.last_seen = datetime.now().isoformat()
        db.commit()
        print("   [OK] Streak: 12, Gems: 450, Health: 88")

        # ── Summary ───────────────────────────────────────────
        print("\n" + "=" * 60)
        print("[SUCCESS] All nutritionist data populated!")
        print("\nClient Profile:")
        print(f"  Name: client | Male, 25y | 178cm")
        print(f"  Weight: 80.2kg (Goal: 76kg) | BF: 18.3%")
        print(f"  BMI: {round(80.2 / (1.78 ** 2), 1)} | Activity: Moderate")
        print(f"  Diet: Cutting at 2200 cal (P:180 C:220 F:60)")
        print(f"\nData Range:")
        print(f"  Weight history: 90 days ({len(entries)+1} entries)")
        print(f"  Diet summaries: 30 days")
        print(f"  Meal logs: ~130 entries")
        print("=" * 60)

    except Exception as e:
        print(f"\n[ERROR] {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    populate()
