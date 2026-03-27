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


@app.after_request
def add_cors_headers(response):
    """Allow requests from any origin (kiosk runs on HTTPS, relay on HTTP)."""
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    return response

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


@app.route('/kiosk', methods=['GET'])
def kiosk_proxy():
    """Serve the kiosk page from Render through localhost (avoids all CORS/mixed-content issues)."""
    import requests as req
    from flask import request as flask_req, Response

    device_key = flask_req.args.get('key', '')
    server = REMOTE_SERVER
    try:
        resp = req.get(f"{server}/kiosk?key={device_key}", timeout=10)
        html = resp.text
        # Keep API_BASE empty — all API calls will be proxied through localhost too
        return Response(html, content_type='text/html')
    except Exception as e:
        return f"<html><body style='background:#111;color:#fff;'><h2>Errore connessione server: {e}</h2></body></html>", 503


@app.route('/api/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'])
def api_proxy(path):
    """Proxy all /api/* calls to Render so the kiosk page stays same-origin."""
    import requests as req
    from flask import request as flask_req, Response

    url = f"{REMOTE_SERVER}/api/{path}"
    headers = {k: v for k, v in flask_req.headers if k.lower() not in ('host', 'content-length')}

    try:
        resp = req.request(
            method=flask_req.method,
            url=url,
            headers=headers,
            data=flask_req.get_data(),
            params=flask_req.args,
            timeout=15,
        )
        return Response(resp.content, status=resp.status_code,
                        headers={'Content-Type': resp.headers.get('Content-Type', 'application/json')})
    except Exception as e:
        return jsonify({"detail": f"Proxy error: {e}"}), 502


REMOTE_SERVER = "https://fitos-eu.onrender.com"
DEVICE_KEY = ""
_pending_triggers = []


@app.route('/relay-trigger', methods=['POST'])
def relay_trigger_from_server():
    """Called by the kiosk page JS — queues a relay trigger."""
    _pending_triggers.append(True)
    return jsonify({"status": "queued"})


def _poll_and_trigger():
    """Background thread: watch for pending triggers and fire the relay."""
    import time as _t
    while True:
        if _pending_triggers:
            _pending_triggers.clear()
            relay_id = find_relay_id()
            if relay_id:
                trigger_relay(relay_id)
        _t.sleep(0.3)


if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:
        REMOTE_SERVER = sys.argv[1]

    relay_id = find_relay_id()
    if relay_id:
        print(f"USB HID relay found: {relay_id}")
    else:
        print("WARNING: No USB relay detected. Install usbrelay and plug in the relay.")

    # Start relay trigger thread
    trigger_thread = threading.Thread(target=_poll_and_trigger, daemon=True)
    trigger_thread.start()

    print(f"Relay service listening on http://localhost:5555")
    print(f"Kiosk page: http://localhost:5555/kiosk?key=YOUR_DEVICE_KEY")
    app.run(host='0.0.0.0', port=5555, debug=False)
