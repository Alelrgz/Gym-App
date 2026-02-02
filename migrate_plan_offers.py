"""
Migration script to create plan_offers table
"""
import sqlite3
import os

def migrate():
    db_path = os.path.join(os.path.dirname(__file__), 'db', 'gym_app.db')
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Check if table exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='plan_offers'")
    if cursor.fetchone():
        print("Table plan_offers already exists")
        conn.close()
        return

    print("Creating plan_offers table...")
    cursor.execute("""
        CREATE TABLE plan_offers (
            id TEXT PRIMARY KEY,
            gym_id TEXT NOT NULL,
            plan_id TEXT,
            title TEXT NOT NULL,
            description TEXT,
            discount_type TEXT NOT NULL,
            discount_value REAL NOT NULL,
            discount_duration_months INTEGER DEFAULT 1,
            coupon_code TEXT,
            is_active INTEGER DEFAULT 1,
            starts_at TEXT NOT NULL,
            expires_at TEXT,
            max_redemptions INTEGER,
            current_redemptions INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (gym_id) REFERENCES users(id),
            FOREIGN KEY (plan_id) REFERENCES subscription_plans(id)
        )
    """)

    # Create indexes
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_plan_offers_gym ON plan_offers(gym_id)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_plan_offers_coupon ON plan_offers(coupon_code)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_plan_offers_plan ON plan_offers(plan_id)")

    conn.commit()
    conn.close()
    print("Migration complete!")

if __name__ == "__main__":
    migrate()
