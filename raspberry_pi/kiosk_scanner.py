"""
Headless Kiosk Scanner — reads DS barcode reader directly, no display needed.
Processes QR codes, verifies with server, triggers relay.

Config is read from /etc/kiosk.conf (created by setup.sh).
"""

import evdev
from evdev import ecodes
import requests
import os
import sys

# ---- CONFIG (from environment or /etc/kiosk.conf) ----
def load_config():
    """Load config from /etc/kiosk.conf into environment."""
    conf = '/etc/kiosk.conf'
    if os.path.exists(conf):
        with open(conf) as f:
            for line in f:
                line = line.strip()
                if '=' in line and not line.startswith('#'):
                    key, val = line.split('=', 1)
                    os.environ.setdefault(key.strip(), val.strip().strip('"'))

load_config()

SERVER = os.environ.get('KIOSK_SERVER', 'http://192.168.1.8:9008')
DEVICE_KEY = os.environ.get('KIOSK_DEVICE_KEY', '')
RELAY_URL = os.environ.get('KIOSK_RELAY_URL', 'http://localhost:5555/trigger')

# Key-to-character map (normal, shifted)
CHAR_MAP = {
    ecodes.KEY_A: ('a', 'A'), ecodes.KEY_B: ('b', 'B'), ecodes.KEY_C: ('c', 'C'),
    ecodes.KEY_D: ('d', 'D'), ecodes.KEY_E: ('e', 'E'), ecodes.KEY_F: ('f', 'F'),
    ecodes.KEY_G: ('g', 'G'), ecodes.KEY_H: ('h', 'H'), ecodes.KEY_I: ('i', 'I'),
    ecodes.KEY_J: ('j', 'J'), ecodes.KEY_K: ('k', 'K'), ecodes.KEY_L: ('l', 'L'),
    ecodes.KEY_M: ('m', 'M'), ecodes.KEY_N: ('n', 'N'), ecodes.KEY_O: ('o', 'O'),
    ecodes.KEY_P: ('p', 'P'), ecodes.KEY_Q: ('q', 'Q'), ecodes.KEY_R: ('r', 'R'),
    ecodes.KEY_S: ('s', 'S'), ecodes.KEY_T: ('t', 'T'), ecodes.KEY_U: ('u', 'U'),
    ecodes.KEY_V: ('v', 'V'), ecodes.KEY_W: ('w', 'W'), ecodes.KEY_X: ('x', 'X'),
    ecodes.KEY_Y: ('y', 'Y'), ecodes.KEY_Z: ('z', 'Z'),
    ecodes.KEY_0: ('0', ')'), ecodes.KEY_1: ('1', '!'), ecodes.KEY_2: ('2', '@'),
    ecodes.KEY_3: ('3', '#'), ecodes.KEY_4: ('4', '$'), ecodes.KEY_5: ('5', '%'),
    ecodes.KEY_6: ('6', '^'), ecodes.KEY_7: ('7', '&'), ecodes.KEY_8: ('8', '*'),
    ecodes.KEY_9: ('9', '('),
    ecodes.KEY_MINUS: ('-', '_'), ecodes.KEY_SPACE: (' ', ' '),
}
SHIFT_KEYS = {ecodes.KEY_LEFTSHIFT, ecodes.KEY_RIGHTSHIFT}


def find_scanner():
    """Find the DS barcode reader input device."""
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        name = dev.name.lower()
        if 'sm-2d' in name or 'barcode' in name or 'scanner' in name:
            return dev
    # Fallback: list all devices
    print("Scanner not found. Available input devices:")
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        print(f"  {path}: {dev.name}")
    return None


def hex_to_uuid(h):
    """Convert 32 hex chars to UUID format."""
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"


def process_qr(raw):
    """Process a scanned QR code."""
    raw = raw.strip()
    if not raw:
        return

    print(f"[SCAN] {raw[:30]}{'...' if len(raw) > 30 else ''}")

    if not raw.startswith('GYMACCESS'):
        print("[DENY] Not a gym QR code")
        return

    payload = raw[9:]  # Strip 'GYMACCESS'
    if len(payload) < 44:
        print("[DENY] QR code too short")
        return

    user_id = hex_to_uuid(payload[:32])
    token = payload[32:44]

    try:
        res = requests.post(
            f"{SERVER}/api/device/verify-access",
            json={"user_id": user_id, "token": token},
            headers={"X-Device-Key": DEVICE_KEY, "Content-Type": "application/json"},
            timeout=5
        )

        if res.status_code == 200:
            data = res.json()
            name = data.get('username', 'Unknown')
            print(f"[OK] ACCESS GRANTED — {name}")
            try:
                requests.post(RELAY_URL, timeout=3)
                print("[OK] Relay triggered")
            except Exception:
                print("[WARN] Relay trigger failed")
        else:
            detail = "Unknown"
            try:
                detail = res.json().get('detail', 'Unknown')
            except Exception:
                pass
            print(f"[DENY] {detail}")
    except requests.ConnectionError:
        print("[ERR] Cannot reach server")
    except Exception as e:
        print(f"[ERR] {e}")


def main():
    if not DEVICE_KEY:
        print("ERROR: No KIOSK_DEVICE_KEY configured. Run setup.sh first.")
        sys.exit(1)

    print("=" * 50)
    print("  Gym Kiosk Scanner (headless)")
    print(f"  Server: {SERVER}")
    print("=" * 50)

    scanner = find_scanner()
    if not scanner:
        sys.exit(1)

    print(f"Scanner: {scanner.name} ({scanner.path})")
    print("Grabbing exclusive access...")
    scanner.grab()
    print("Waiting for QR scans...\n")

    buffer = ""
    shift_held = False

    try:
        for event in scanner.read_loop():
            if event.type == ecodes.EV_KEY:
                if event.code in SHIFT_KEYS:
                    shift_held = (event.value != 0)
                elif event.value == 1:  # Key down
                    if event.code == ecodes.KEY_ENTER:
                        process_qr(buffer)
                        buffer = ""
                    elif event.code in CHAR_MAP:
                        char = CHAR_MAP[event.code][1 if shift_held else 0]
                        buffer += char
    except KeyboardInterrupt:
        print("\nStopping...")
    finally:
        scanner.ungrab()
        print("Scanner released.")


if __name__ == '__main__':
    main()
