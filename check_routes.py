
import sys
import os

# Add current directory to path
sys.path.append(os.getcwd())

try:
    from main import app
    print("--- ROUTES DUMP ---")
    for route in app.routes:
        print(f"{route.path} [{route.name}]")
    print("-------------------")
    
    # Check specifically for the toggle premium route
    found = False
    for route in app.routes:
        if "toggle_premium" in route.path:
            found = True
            print(f"FOUND: {route.path}")
            break
            
    if not found:
        print("CRITICAL: toggle_premium route NOT FOUND in app.routes")
            
except Exception as e:
    print(f"Error importing app: {e}")
