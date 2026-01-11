import os
import database

print(f"Global DB Path: {database.GLOBAL_DB_PATH}")
print(f"Trainer DB Path: {database.get_trainer_db_path('test')}")
print(f"Client DB Path: {database.get_client_db_path('test')}")

# Check if files exist at these paths
global_path = database.GLOBAL_DB_PATH.replace("sqlite:///", "")
if os.path.exists(global_path):
    print(f"Global DB exists at: {global_path}")
else:
    print(f"Global DB NOT found at: {global_path}")
