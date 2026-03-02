"""
Kiosk Relay Service — runs on Raspberry Pi alongside the kiosk browser.
Controls a USB HID relay module to open the turnstile on successful QR scan.

Usage:
    python3 relay_service.py

Listens on http://localhost:5555
The kiosk page calls POST /trigger to fire the relay for 1.5 seconds.

Install deps:
    sudo apt install usbrelay
    pip3 install flask
"""

from flask import Flask, jsonify
import subprocess
import time
import threading

app = Flask(__name__)

HOLD_SECONDS = 1.5  # How long the turnstile stays unlocked
relay_lock = threading.Lock()


def find_relay_id():
    """Auto-detect the HID relay ID using usbrelay."""
    try:
        result = subprocess.run(['usbrelay'], capture_output=True, text=True, timeout=5)
        # usbrelay output format: "HURTM_1=0" or "ABCDE_1=0"
        output = result.stdout.strip() + result.stderr.strip()
        for line in output.splitlines():
            if '=' in line:
                relay_id = line.split('=')[0].strip()
                if relay_id:
                    return relay_id
    except Exception as e:
        print(f"Error detecting relay: {e}")
    return None


def trigger_relay(relay_id):
    """Open relay for HOLD_SECONDS then close it."""
    try:
        subprocess.run(['usbrelay', f'{relay_id}=1'], capture_output=True, timeout=5)
        print(f"Relay {relay_id} ON")
        time.sleep(HOLD_SECONDS)
        subprocess.run(['usbrelay', f'{relay_id}=0'], capture_output=True, timeout=5)
        print(f"Relay {relay_id} OFF")
        return True
    except Exception as e:
        print(f"Relay error: {e}")
        # Try to turn off in case ON succeeded
        try:
            subprocess.run(['usbrelay', f'{relay_id}=0'], capture_output=True, timeout=5)
        except Exception:
            pass
        return False


@app.route('/trigger', methods=['POST'])
def trigger():
    """Called by kiosk page when access is granted."""
    if not relay_lock.acquire(blocking=False):
        return jsonify({"status": "busy", "message": "Relay already active"}), 429

    try:
        relay_id = find_relay_id()
        if not relay_id:
            relay_lock.release()
            return jsonify({"status": "error", "message": "No USB relay found"}), 503

        # Run in background thread so response returns immediately
        def fire():
            try:
                trigger_relay(relay_id)
            finally:
                relay_lock.release()

        threading.Thread(target=fire, daemon=True).start()
        return jsonify({"status": "ok", "message": f"Relay triggered for {HOLD_SECONDS}s"})
    except Exception as e:
        relay_lock.release()
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check — also reports if relay is connected."""
    relay_id = find_relay_id()
    return jsonify({
        "status": "ok",
        "relay_connected": relay_id is not None,
        "relay_id": relay_id
    })


if __name__ == '__main__':
    relay_id = find_relay_id()
    if relay_id:
        print(f"USB HID relay found: {relay_id}")
    else:
        print("WARNING: No USB relay detected. Install usbrelay and plug in the relay.")
    print(f"Relay service listening on http://localhost:5555")
    app.run(host='127.0.0.1', port=5555, debug=False)
