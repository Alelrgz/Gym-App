"""
Gate WebSocket Client — runs on Raspberry Pi.
Connects to the server via WebSocket. When access is granted,
triggers the relay to open the turnstile. Zero polling.

Usage:
    python3 gate_ws.py DEVICE_KEY [SERVER_URL]

Install:
    pip3 install websocket-client requests
"""
import websocket
import json
import requests
import subprocess
import time
import sys
import threading

DEVICE_KEY = sys.argv[1] if len(sys.argv) > 1 else ""
SERVER = sys.argv[2] if len(sys.argv) > 2 else "https://fitos-eu.onrender.com"
RELAY_URL = "http://localhost:5555/trigger"

if not DEVICE_KEY:
    print("Usage: python3 gate_ws.py DEVICE_KEY [SERVER_URL]")
    sys.exit(1)

WS_URL = SERVER.replace("https://", "wss://").replace("http://", "ws://") + f"/ws/gate/{DEVICE_KEY}"


def trigger_relay():
    """Fire the relay via the local relay service, or directly if unavailable."""
    try:
        requests.post(RELAY_URL, timeout=3)
        print("Relay triggered via service")
    except Exception:
        try:
            result = subprocess.run(['usbrelay'], capture_output=True, text=True, timeout=5)
            for line in (result.stdout.strip() + result.stderr.strip()).splitlines():
                if '=' in line:
                    relay_id = line.split('=')[0].strip()
                    subprocess.run(['usbrelay', f'{relay_id}=1'], timeout=5)
                    time.sleep(1.5)
                    subprocess.run(['usbrelay', f'{relay_id}=0'], timeout=5)
                    print(f"Relay triggered directly: {relay_id}")
                    break
        except Exception as e:
            print(f"Relay error: {e}")


def on_message(ws, message):
    try:
        data = json.loads(message)
        if data.get("gate") == "open":
            username = data.get("username", "?")
            print(f"GATE OPEN for {username}")
            threading.Thread(target=trigger_relay, daemon=True).start()
    except Exception as e:
        print(f"Message parse error: {e}")


def on_error(ws, error):
    print(f"WebSocket error: {error}")


def on_close(ws, close_status_code, close_msg):
    print(f"WebSocket closed: {close_status_code} {close_msg}")


def on_open(ws):
    print("Connected to server")
    # Send periodic pings to keep connection alive
    def ping():
        while True:
            try:
                ws.send("ping")
            except Exception:
                break
            time.sleep(30)
    threading.Thread(target=ping, daemon=True).start()


print(f"Gate WS client starting. Server: {WS_URL}")

while True:
    try:
        ws = websocket.WebSocketApp(
            WS_URL,
            on_message=on_message,
            on_error=on_error,
            on_close=on_close,
            on_open=on_open,
        )
        ws.run_forever(ping_interval=30, ping_timeout=10)
    except Exception as e:
        print(f"Connection error: {e}")
    print("Reconnecting in 3s...")
    time.sleep(3)
