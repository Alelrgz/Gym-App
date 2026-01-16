import subprocess
import re

# Get all LISTENING processes on port 9007
result = subprocess.run(["netstat", "-ano"], capture_output=True, text=True)
pids = set()

for line in result.stdout.split('\n'):
    if ':9007' in line and 'LISTENING' in line:
        parts = line.split()
        if parts:
            pid = parts[-1]
            if pid != '0':
                pids.add(pid)

print(f"Found {len(pids)} PIDs listening on port 9007: {pids}")

# Kill each PID
for pid in pids:
    try:
        subprocess.run(["taskkill", "/F", "/PID", pid], capture_output=True)
        print(f"Killed PID {pid}")
    except Exception as e:
        print(f"Error killing PID {pid}: {e}")

print("Done!")
