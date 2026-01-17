import os
import subprocess
import re

def kill_port(port):
    print(f"Checking port {port}...")
    try:
        # Run netstat to find the PID
        output = subprocess.check_output(f"netstat -ano | findstr :{port}", shell=True).decode()
        lines = output.strip().split('\n')
        pids = set()
        for line in lines:
            parts = line.strip().split()
            if len(parts) > 4:
                pid = parts[-1]
                pids.add(pid)
        
        if not pids:
            print(f"No process found on port {port}.")
            return

        for pid in pids:
            if pid != "0": # Don't kill system idle process
                print(f"Killing PID {pid} on port {port}...")
                os.system(f"taskkill /F /PID {pid}")
    except subprocess.CalledProcessError:
        print(f"No process listening on port {port}.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    kill_port(9007)
    kill_port(9008)
    print("Done.")
