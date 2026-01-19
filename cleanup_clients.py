from database import SessionLocal
from models_orm import UserORM, ClientProfileORM, ClientScheduleORM, ClientDietSettingsORM, ClientDietLogORM, ClientExerciseLogORM

def cleanup():
    db = SessionLocal()
    try:
        # 1. Identify Clients to Delete
        # Keep: GigaNigga, GigaNigga1
        # Role must be 'client'
        
        keepers = ["GigaNigga", "GigaNigga1"]
        
        clients_to_delete = db.query(UserORM).filter(
            UserORM.role == "client",
            UserORM.username.notin_(keepers)
        ).all()
        
        if not clients_to_delete:
            print("No clients found to delete.")
            return

        print(f"Found {len(clients_to_delete)} clients to delete.")
        
        ids_to_delete = [u.id for u in clients_to_delete]
        
        # 2. Delete Related Data (Manual Cascade to be safe)
        
        # ClientExerciseLogORM
        deleted_logs = db.query(ClientExerciseLogORM).filter(ClientExerciseLogORM.client_id.in_(ids_to_delete)).delete(synchronize_session=False)
        print(f"Deleted {deleted_logs} exercise logs.")

        # ClientDietLogORM
        deleted_diet_logs = db.query(ClientDietLogORM).filter(ClientDietLogORM.client_id.in_(ids_to_delete)).delete(synchronize_session=False)
        print(f"Deleted {deleted_diet_logs} diet logs.")

        # ClientDietSettingsORM
        deleted_diet_settings = db.query(ClientDietSettingsORM).filter(ClientDietSettingsORM.id.in_(ids_to_delete)).delete(synchronize_session=False)
        print(f"Deleted {deleted_diet_settings} diet settings.")

        # ClientScheduleORM
        deleted_schedules = db.query(ClientScheduleORM).filter(ClientScheduleORM.client_id.in_(ids_to_delete)).delete(synchronize_session=False)
        print(f"Deleted {deleted_schedules} schedule items.")

        # ClientProfileORM
        deleted_profiles = db.query(ClientProfileORM).filter(ClientProfileORM.id.in_(ids_to_delete)).delete(synchronize_session=False)
        print(f"Deleted {deleted_profiles} client profiles.")
        
        # 3. Delete Users
        deleted_users = db.query(UserORM).filter(UserORM.id.in_(ids_to_delete)).delete(synchronize_session=False)
        print(f"Deleted {deleted_users} users.")
        
        db.commit()
        print("Cleanup complete.")
        
    except Exception as e:
        print(f"Error during cleanup: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    cleanup()
