"""
Gate Poller — runs on Raspberry Pi alongside the relay service.
Polls the server every second. When access is granted, triggers the relay.

Usage:
    python3 gate_poller.py DEVICE_KEY [SERVER_URL]
"""
import requests
import subprocess
import time
import sys

DEVICE_KEY = sys.argv[1] if len(sys.argv) > 1 else ""
SERVER = sys.argv[2] if len(sys.argv) > 2 else "https://fitos-eu.onrender.com"
RELAY_URL = "http://localhost:5555/trigger"
POLL_INTERVAL = 1.0

if not DEVICE_KEY:
    print("Usage: python3 gate_poller.py DEVICE_KEY [SERVER_URL]")
    sys.exit(1)

print(f"Gate poller started. Server: {SERVER}, Device: {DEVICE_KEY[:8]}...")

while True:
    try:
        resp = requests.get(
            f"{SERVER}/api/device/gate-poll",
            headers={"X-Device-Key": DEVICE_KEY},
            timeout=5,
        )
        if resp.status_code == 200:
            data = resp.json()
            if data.get("gate") == "open":
                print(f"GATE OPEN for {data.get('username', '?')}")
                try:
                    requests.post(RELAY_URL, timeout=3)
                except Exception:
                    # Try direct relay if Flask isn't running
                    try:
                        result = subprocess.run(['usbrelay'], capture_output=True, text=True, timeout=5)
                        for line in result.stdout.strip().splitlines() + result.stderr.strip().splitlines():
                            if '=' in line:
                                relay_id = line.split('=')[0].strip()
                                subprocess.run(['usbrelay', f'{relay_id}=1'], timeout=5)
                                time.sleep(1.5)
                                subprocess.run(['usbrelay', f'{relay_id}=0'], timeout=5)
                                break
                    except Exception as e:
                        print(f"Relay error: {e}")
    except Exception as e:
        pass  # Server unreachable, retry next loop
    time.sleep(POLL_INTERVAL)
