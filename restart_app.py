"""
Script to completely restart the GymApp by killing all Python processes and starting fresh
"""
import subprocess
import time
import sys
import os

def kill_all_python():
    """Kill all Python processes"""
    print("Killing all Python processes...")
    try:
        # Use taskkill to kill all python.exe processes
        result = subprocess.run(
            ["taskkill", "/F", "/IM", "python.exe"],
            capture_output=True,
            text=True
        )
        print(result.stdout)
        if result.stderr:
            print(result.stderr)
    except Exception as e:
        print(f"Error killing processes: {e}")
    
    # Wait a moment for processes to fully terminate
    time.sleep(2)

def check_port_9007():
    """Check if port 9007 is still in use"""
    result = subprocess.run(
        ["netstat", "-ano"],
        capture_output=True,
        text=True
    )
    
    lines = [line for line in result.stdout.split('\n') if ':9007' in line and 'LISTENING' in line]
    if lines:
        print(f"Port 9007 still in use by {len(lines)} process(es)")
        return False
    else:
        print("Port 9007 is free")
        return True

def start_app():
    """Start the app"""
    print("Starting app...")
    os.chdir(r"c:\Users\RICCARDO\GymApp")
    subprocess.Popen([sys.executable, "main.py"])
    print("App started. Waiting for it to initialize...")
    time.sleep(5)

if __name__ == "__main__":
    print("=== GymApp Restart Script ===")
    kill_all_python()
    
    if not check_port_9007():
        print("WARNING: Port still in use. Waiting longer...")
        time.sleep(3)
        check_port_9007()
    
    start_app()
    print("Done! App should be running on port 9007")
