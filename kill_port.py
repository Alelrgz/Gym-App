
import subprocess
import re
import os
import time

def kill_port_9007():
    print("Finding processes on port 9007...")
    # Run netstat
    output = subprocess.check_output("netstat -ano | findstr :9007", shell=True).decode()
    
    # Parse PIDs
    pids = set()
    for line in output.splitlines():
        parts = line.strip().split()
        if len(parts) >= 5:
            pid = parts[-1]
            pids.add(pid)
            
    if not pids:
        print("No processes found on port 9007.")
        return

    print(f"Found PIDs: {pids}")
    
    for pid in pids:
        if pid == "0": continue
        print(f"Killing PID {pid}...")
        os.system(f"taskkill /F /PID {pid}")
        
    time.sleep(2)
    print("Done.")

if __name__ == "__main__":
    kill_port_9007()
