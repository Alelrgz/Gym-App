"""
One-time migration script: loads migration_data.json into PostgreSQL.
Run on Render via: python migrate_data.py
"""
import json
import os
import sys

def migrate():
    db_url = os.environ.get("DATABASE_URL", "")
    if not db_url.startswith("postgresql"):
        print("ERROR: DATABASE_URL must be PostgreSQL")
        sys.exit(1)

    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql://", 1)

    # Create schema first
    from sqlalchemy import create_engine, text
    from database import Base
    import models_orm

    engine = create_engine(db_url)
    Base.metadata.create_all(engine)
    print("Schema created.")

    # Load migration data
    data_path = os.path.join(os.path.dirname(__file__), "db", "migration_data.json")
    if not os.path.exists(data_path):
        print(f"ERROR: {data_path} not found")
        sys.exit(1)

    with open(data_path, "r") as f:
        dump = json.load(f)

    total = 0
    errors = []

    # Order tables: users first (foreign keys depend on it)
    priority = ["users", "gyms", "client_profile", "exercises", "workouts"]
    ordered_tables = []
    for t in priority:
        if t in dump:
            ordered_tables.append(t)
    for t in dump:
        if t not in ordered_tables:
            ordered_tables.append(t)

    with engine.connect() as conn:
        for table in ordered_tables:
            info = dump[table]
            cols = info["columns"]
            rows = info["rows"]

            col_names = ", ".join([f'"{c}"' for c in cols])
            placeholders = ", ".join([f":{c}" for c in cols])

            count = 0
            for row in rows:
                params = {}
                for i, c in enumerate(cols):
                    val = row[i]
                    # Convert Python booleans stored as 0/1 in SQLite
                    params[c] = val

                try:
                    conn.execute(
                        text(f'INSERT INTO "{table}" ({col_names}) VALUES ({placeholders}) ON CONFLICT DO NOTHING'),
                        params
                    )
                    count += 1
                except Exception as e:
                    conn.rollback()
                    if count == 0:
                        errors.append(f"{table}: {str(e)[:100]}")
                        break

            if count > 0:
                conn.commit()
                print(f"  {table}: {count}/{len(rows)} rows")
                total += count

        # Fix PostgreSQL sequences (auto-increment counters)
        print("\nFixing sequences...")
        try:
            conn.execute(text("SELECT setval('users_id_seq', (SELECT COALESCE(MAX(id), 0) FROM users))"))
            conn.commit()
        except Exception:
            try:
                conn.rollback()
            except Exception:
                pass

        # Fix other sequences
        seq_tables = ["client_profile", "exercises", "appointments", "notifications",
                      "medical_certificates", "community_posts", "community_comments",
                      "messages", "conversations", "workouts", "courses", "course_lessons",
                      "checkins", "payments", "subscriptions", "gyms"]
        for t in seq_tables:
            try:
                conn.execute(text(f"SELECT setval('{t}_id_seq', (SELECT COALESCE(MAX(id), 0) FROM \"{t}\"))"))
                conn.commit()
            except Exception:
                try:
                    conn.rollback()
                except Exception:
                    pass

    print(f"\nDone! {total} total rows migrated.")
    if errors:
        print(f"\nErrors ({len(errors)}):")
        for e in errors:
            print(f"  {e}")

if __name__ == "__main__":
    migrate()
