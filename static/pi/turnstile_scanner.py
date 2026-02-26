#!/usr/bin/env python3
"""
Gym Turnstile QR Scanner — Raspberry Pi
Reads QR codes from a USB/Pi camera, sends them to the server for verification,
and controls a relay + LEDs + buzzer based on the response.
"""

import json
import os
import signal
import sys
import time
import logging
from pathlib import Path

import cv2
from pyzbar.pyzbar import decode as pyzbar_decode
import requests

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("turnstile")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONFIG_PATH = Path(__file__).parent / "config.json"

DEFAULT_CONFIG = {
    "server_url": "http://localhost:9008",
    "device_api_key": "",
    "relay_pin": 17,
    "green_led_pin": 27,
    "red_led_pin": 22,
    "buzzer_pin": 23,
    "camera_index": 0,
}


def load_config():
    if not CONFIG_PATH.exists():
        log.error(f"Config file not found: {CONFIG_PATH}")
        sys.exit(1)

    with open(CONFIG_PATH) as f:
        cfg = json.load(f)

    merged = {**DEFAULT_CONFIG, **cfg}

    if not merged.get("device_api_key"):
        log.error("device_api_key is empty in config.json")
        sys.exit(1)

    return merged


# ---------------------------------------------------------------------------
# GPIO Controller (with simulation fallback for non-Pi systems)
# ---------------------------------------------------------------------------
class GPIOController:
    def __init__(self, relay_pin, green_pin, red_pin, buzzer_pin):
        self.relay_pin = relay_pin
        self.green_pin = green_pin
        self.red_pin = red_pin
        self.buzzer_pin = buzzer_pin
        self.simulation = False

        try:
            import RPi.GPIO as GPIO
            self.GPIO = GPIO
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            for pin in (relay_pin, green_pin, red_pin, buzzer_pin):
                GPIO.setup(pin, GPIO.OUT)
                GPIO.output(pin, GPIO.LOW)
            log.info("GPIO initialized (BCM mode)")
        except (ImportError, RuntimeError):
            self.GPIO = None
            self.simulation = True
            log.warning("GPIO unavailable — running in SIMULATION mode")

    def _set(self, pin, state):
        if self.GPIO:
            self.GPIO.output(pin, self.GPIO.HIGH if state else self.GPIO.LOW)
        else:
            name = {
                self.relay_pin: "RELAY",
                self.green_pin: "GREEN",
                self.red_pin: "RED",
                self.buzzer_pin: "BUZZER",
            }.get(pin, str(pin))
            log.debug(f"  [SIM] {name} -> {'ON' if state else 'OFF'}")

    def idle(self):
        """Green LED on, everything else off — ready state."""
        self._set(self.green_pin, True)
        self._set(self.red_pin, False)
        self._set(self.relay_pin, False)
        self._set(self.buzzer_pin, False)

    def grant(self, gate_seconds):
        """Open gate, green LED stays on, double beep."""
        self._set(self.relay_pin, True)
        self._set(self.green_pin, True)
        self._set(self.red_pin, False)
        # Double beep
        for _ in range(2):
            self._set(self.buzzer_pin, True)
            time.sleep(0.12)
            self._set(self.buzzer_pin, False)
            time.sleep(0.08)
        # Keep relay open for gate_seconds
        time.sleep(gate_seconds)
        self._set(self.relay_pin, False)

    def deny(self):
        """Red LED on, triple short beep."""
        self._set(self.green_pin, False)
        self._set(self.red_pin, True)
        # Triple beep
        for _ in range(3):
            self._set(self.buzzer_pin, True)
            time.sleep(0.08)
            self._set(self.buzzer_pin, False)
            time.sleep(0.06)
        time.sleep(1.5)
        self._set(self.red_pin, False)

    def cleanup(self):
        if self.GPIO:
            self.GPIO.cleanup()


# ---------------------------------------------------------------------------
# Server Client
# ---------------------------------------------------------------------------
class ServerClient:
    def __init__(self, server_url, api_key):
        self.url = server_url.rstrip("/")
        self.headers = {
            "X-Device-Key": api_key,
            "Content-Type": "application/json",
        }
        self.timeout = 8

    def verify(self, qr_data):
        """POST qr_data to server, return response dict or None on error."""
        try:
            r = requests.post(
                f"{self.url}/api/device/turnstile-verify",
                json={"qr_data": qr_data},
                headers=self.headers,
                timeout=self.timeout,
            )
            if r.status_code == 200:
                return r.json()
            log.warning(f"Server returned {r.status_code}: {r.text[:200]}")
            return None
        except requests.RequestException as e:
            log.error(f"Server unreachable: {e}")
            return None

    def ping(self):
        try:
            r = requests.get(
                f"{self.url}/api/device/ping",
                headers=self.headers,
                timeout=5,
            )
            return r.status_code == 200
        except requests.RequestException:
            return False


# ---------------------------------------------------------------------------
# QR Scanner
# ---------------------------------------------------------------------------
class QRScanner:
    def __init__(self, camera_index=0):
        self.camera_index = camera_index
        self.cap = None
        self.last_qr = None
        self.last_qr_time = 0
        self.cooldown = 5  # seconds before same QR is accepted again

    def open(self):
        self.cap = cv2.VideoCapture(self.camera_index)
        if not self.cap.isOpened():
            log.error(f"Cannot open camera {self.camera_index}")
            return False
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        log.info(f"Camera {self.camera_index} opened (640x480)")
        return True

    def read(self):
        """Return decoded QR string or None. Enforces cooldown."""
        if not self.cap:
            return None
        ret, frame = self.cap.read()
        if not ret:
            return None

        codes = pyzbar_decode(frame)
        for code in codes:
            data = code.data.decode("utf-8", errors="ignore")
            if not data.startswith("GYMACCESS"):
                continue

            now = time.time()
            if data == self.last_qr and (now - self.last_qr_time) < self.cooldown:
                return None  # same QR within cooldown

            self.last_qr = data
            self.last_qr_time = now
            return data

        return None

    def close(self):
        if self.cap:
            self.cap.release()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    cfg = load_config()

    gpio = GPIOController(
        cfg["relay_pin"], cfg["green_pin"], cfg["red_pin"], cfg["buzzer_pin"]
    )
    server = ServerClient(cfg["server_url"], cfg["device_api_key"])
    scanner = QRScanner(cfg["camera_index"])

    running = True

    def shutdown(signum, frame):
        nonlocal running
        log.info("Shutting down...")
        running = False

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    # Check server connectivity
    if server.ping():
        log.info(f"Server reachable at {cfg['server_url']}")
    else:
        log.warning(f"Server not reachable at {cfg['server_url']} — will keep trying")

    if not scanner.open():
        gpio.cleanup()
        sys.exit(1)

    gpio.idle()
    log.info("Scanner ready — waiting for QR codes...")

    try:
        while running:
            qr_data = scanner.read()
            if qr_data is None:
                time.sleep(0.05)  # ~20 fps scan rate
                continue

            log.info(f"QR scanned: {qr_data[:20]}...")

            result = server.verify(qr_data)
            if result is None:
                # Server unreachable — fail-secure: deny
                log.warning("Server unreachable — access DENIED")
                gpio.deny()
                gpio.idle()
                continue

            if result.get("access"):
                name = result.get("member_name", "?")
                gate_sec = result.get("gate_seconds", 5)
                log.info(f"ACCESS GRANTED: {name} (gate {gate_sec}s)")
                gpio.grant(gate_sec)
            else:
                reason = result.get("reason", "unknown")
                log.info(f"ACCESS DENIED: {reason}")
                gpio.deny()

            gpio.idle()

    finally:
        scanner.close()
        gpio.cleanup()
        log.info("Turnstile scanner stopped.")


if __name__ == "__main__":
    main()
