/*
 * FitOS NFC Shower Controller
 * ESP32 + RC522 NFC Reader + Relay
 *
 * Hardware connections:
 *   RC522 SDA  → GPIO 5  (SPI CS)
 *   RC522 SCK  → GPIO 18 (SPI CLK)
 *   RC522 MOSI → GPIO 23
 *   RC522 MISO → GPIO 19
 *   RC522 RST  → GPIO 22
 *   Relay IN   → GPIO 26 (active HIGH)
 *   Green LED  → GPIO 32 (ready)
 *   Blue LED   → GPIO 33 (session active)
 *   Red LED    → GPIO 25 (denied)
 *   Buzzer     → GPIO 27
 *
 * Required libraries (install via Arduino Library Manager):
 *   - MFRC522 by GithubCommunity
 *   - ArduinoJson by Benoit Blanchon
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>

// ============================================================
// CONFIGURATION — Edit these values for your gym
// ============================================================
const char* WIFI_SSID     = "YOUR_GYM_WIFI";
const char* WIFI_PASS     = "YOUR_WIFI_PASSWORD";
const char* SERVER_URL    = "http://YOUR_SERVER_IP:9008";  // FitOS server URL
const char* DEVICE_API_KEY = "YOUR_DEVICE_API_KEY";        // From owner settings
const char* SHOWER_ID     = "shower-1";                    // Unique ID for this shower

// ============================================================
// PIN DEFINITIONS
// ============================================================
#define RC522_SDA   5
#define RC522_RST   22
#define RELAY_PIN   26
#define LED_GREEN   32
#define LED_BLUE    33
#define LED_RED     25
#define BUZZER_PIN  27

// ============================================================
// GLOBALS
// ============================================================
MFRC522 mfrc522(RC522_SDA, RC522_RST);

enum State { IDLE, ACTIVE, WARNING };
State currentState = IDLE;

unsigned long sessionStartMs = 0;
unsigned long timerSeconds   = 0;
int           sessionId      = -1;
unsigned long lastWarningBeep = 0;
unsigned long lastWifiCheck   = 0;

// ============================================================
// SETUP
// ============================================================
void setup() {
    Serial.begin(115200);
    Serial.println("\n=== FitOS Shower Controller ===");

    // Pin setup
    pinMode(RELAY_PIN, OUTPUT);
    pinMode(LED_GREEN, OUTPUT);
    pinMode(LED_BLUE, OUTPUT);
    pinMode(LED_RED, OUTPUT);
    pinMode(BUZZER_PIN, OUTPUT);

    digitalWrite(RELAY_PIN, LOW);  // Shower OFF

    // Init SPI and NFC reader
    SPI.begin();
    mfrc522.PCD_Init();
    delay(100);

    // Check NFC reader
    byte version = mfrc522.PCD_ReadRegister(mfrc522.VersionReg);
    if (version == 0x00 || version == 0xFF) {
        Serial.println("ERROR: RC522 not detected! Check wiring.");
        // Blink red rapidly
        for (int i = 0; i < 20; i++) {
            setLED(LED_RED, i % 2 == 0);
            delay(200);
        }
    } else {
        Serial.print("RC522 firmware version: 0x");
        Serial.println(version, HEX);
    }

    // Connect to WiFi
    connectWiFi();

    // Ping the server
    pingServer();

    // Ready!
    setAllLEDs(false);
    setLED(LED_GREEN, true);
    beep(100);
    delay(100);
    beep(100);
    Serial.println("Ready — waiting for NFC tag...");
}

// ============================================================
// MAIN LOOP
// ============================================================
void loop() {
    // Periodic WiFi check (every 30s)
    if (millis() - lastWifiCheck > 30000) {
        lastWifiCheck = millis();
        if (WiFi.status() != WL_CONNECTED) {
            Serial.println("WiFi lost — reconnecting...");
            setLED(LED_GREEN, false);
            connectWiFi();
            setLED(LED_GREEN, currentState == IDLE);
        }
    }

    switch (currentState) {
        case IDLE:
            handleIdle();
            break;
        case ACTIVE:
            handleActive();
            break;
        case WARNING:
            handleWarning();
            break;
    }

    delay(100);  // Prevent tight loop
}

// ============================================================
// STATE HANDLERS
// ============================================================

void handleIdle() {
    // Check for NFC tag
    if (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial()) {
        return;
    }

    // Read UID
    String uid = readTagUID();
    mfrc522.PICC_HaltA();
    mfrc522.PCD_StopCrypto1();

    Serial.println("Tag detected: " + uid);

    // Visual feedback — blue while validating
    setAllLEDs(false);
    setLED(LED_BLUE, true);
    beep(50);

    // Call server to validate
    if (validateTag(uid)) {
        startShower();
    } else {
        denyAccess();
    }
}

void handleActive() {
    unsigned long elapsedSec = (millis() - sessionStartMs) / 1000;
    unsigned long remainingSec = (elapsedSec < timerSeconds) ? (timerSeconds - elapsedSec) : 0;

    // Check for early tag tap to end session
    if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
        mfrc522.PICC_HaltA();
        mfrc522.PCD_StopCrypto1();
        Serial.println("Tag re-tapped — ending session early");
        endShower(elapsedSec);
        return;
    }

    // Enter warning zone at 60 seconds remaining
    if (remainingSec <= 60 && remainingSec > 0) {
        currentState = WARNING;
        Serial.println("Warning zone — " + String(remainingSec) + "s remaining");
        return;
    }

    // Timer expired
    if (elapsedSec >= timerSeconds) {
        endShower(elapsedSec);
        return;
    }

    // Print countdown every 30 seconds
    static unsigned long lastPrint = 0;
    if (millis() - lastPrint > 30000) {
        lastPrint = millis();
        Serial.println("Shower active — " + String(remainingSec) + "s remaining");
    }
}

void handleWarning() {
    unsigned long elapsedSec = (millis() - sessionStartMs) / 1000;

    // Blink blue LED
    setLED(LED_BLUE, (millis() / 500) % 2 == 0);

    // Beep every 10 seconds
    if (millis() - lastWarningBeep > 10000) {
        beep(200);
        lastWarningBeep = millis();
    }

    // Timer expired
    if (elapsedSec >= timerSeconds) {
        endShower(elapsedSec);
        return;
    }

    // Check for early tag tap
    if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
        mfrc522.PICC_HaltA();
        mfrc522.PCD_StopCrypto1();
        Serial.println("Tag re-tapped during warning — ending session");
        endShower(elapsedSec);
        return;
    }
}

// ============================================================
// SHOWER CONTROL
// ============================================================

void startShower() {
    currentState = ACTIVE;
    sessionStartMs = millis();
    lastWarningBeep = millis();

    // Turn on relay → shower ON
    digitalWrite(RELAY_PIN, HIGH);

    // Blue LED solid
    setAllLEDs(false);
    setLED(LED_BLUE, true);

    // Double beep = access granted
    beep(100);
    delay(100);
    beep(100);

    Serial.println("SHOWER ON — timer: " + String(timerSeconds) + "s");
}

void endShower(unsigned long durationSeconds) {
    // Turn off relay → shower OFF
    digitalWrite(RELAY_PIN, LOW);

    // Report to server (non-blocking — if it fails, we still turn off)
    reportCompletion(durationSeconds);

    // Visual: red + long beep = session ended
    setAllLEDs(false);
    setLED(LED_RED, true);
    beep(500);

    Serial.println("SHOWER OFF — duration: " + String(durationSeconds) + "s");

    delay(3000);  // Show red for 3 seconds

    // Return to idle
    currentState = IDLE;
    sessionId = -1;
    setAllLEDs(false);
    setLED(LED_GREEN, true);
    Serial.println("Ready — waiting for NFC tag...");
}

void denyAccess() {
    setAllLEDs(false);
    setLED(LED_RED, true);

    // Three short beeps = denied
    beep(100);
    delay(100);
    beep(100);
    delay(100);
    beep(100);

    Serial.println("ACCESS DENIED");

    delay(3000);

    // Return to idle
    setAllLEDs(false);
    setLED(LED_GREEN, true);
    currentState = IDLE;
}

// ============================================================
// SERVER COMMUNICATION
// ============================================================

bool validateTag(String uid) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi not connected — cannot validate");
        return false;
    }

    HTTPClient http;
    String url = String(SERVER_URL) + "/api/device/nfc-validate";

    http.begin(url);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-Key", DEVICE_API_KEY);
    http.setTimeout(5000);  // 5 second timeout

    // Build JSON
    StaticJsonDocument<256> doc;
    doc["nfc_uid"] = uid;
    doc["shower_id"] = SHOWER_ID;

    String payload;
    serializeJson(doc, payload);

    Serial.println("Validating: " + url);

    int httpCode = http.POST(payload);

    if (httpCode != 200) {
        Serial.println("HTTP error: " + String(httpCode));
        if (httpCode > 0) {
            Serial.println("Response: " + http.getString());
        }
        http.end();
        return false;
    }

    String response = http.getString();
    http.end();

    // Parse response
    StaticJsonDocument<512> resp;
    DeserializationError err = deserializeJson(resp, response);
    if (err) {
        Serial.println("JSON parse error: " + String(err.c_str()));
        return false;
    }

    bool access = resp["access"] | false;

    if (access) {
        timerSeconds = resp["timer_seconds"] | 480;
        sessionId = resp["session_id"] | -1;
        String memberName = resp["member_name"] | "Unknown";
        int remaining = resp["remaining_sessions"] | 0;

        Serial.println("ACCESS GRANTED: " + memberName);
        Serial.println("  Timer: " + String(timerSeconds) + "s");
        Serial.println("  Remaining today: " + String(remaining));
        return true;
    } else {
        String reason = resp["reason"] | "unknown";
        String message = resp["message"] | "Access denied";

        Serial.println("ACCESS DENIED: " + reason + " — " + message);
        return false;
    }
}

void reportCompletion(unsigned long durationSeconds) {
    if (sessionId < 0) return;

    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi not connected — cannot report completion");
        return;
    }

    HTTPClient http;
    String url = String(SERVER_URL) + "/api/device/shower-complete";

    http.begin(url);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-Key", DEVICE_API_KEY);
    http.setTimeout(5000);

    StaticJsonDocument<128> doc;
    doc["session_id"] = sessionId;
    doc["duration_seconds"] = (unsigned long)durationSeconds;

    String payload;
    serializeJson(doc, payload);

    int httpCode = http.POST(payload);

    if (httpCode == 200) {
        Serial.println("Session reported to server OK");
    } else {
        Serial.println("Failed to report session: HTTP " + String(httpCode));
    }
    http.end();
}

void pingServer() {
    if (WiFi.status() != WL_CONNECTED) return;

    HTTPClient http;
    String url = String(SERVER_URL) + "/api/device/ping";

    http.begin(url);
    http.addHeader("X-Device-Key", DEVICE_API_KEY);
    http.setTimeout(3000);

    int httpCode = http.GET();

    if (httpCode == 200) {
        Serial.println("Server ping OK");
    } else {
        Serial.println("Server ping failed: HTTP " + String(httpCode));
    }
    http.end();
}

// ============================================================
// UTILITY FUNCTIONS
// ============================================================

String readTagUID() {
    String uid = "";
    for (byte i = 0; i < mfrc522.uid.size; i++) {
        if (i > 0) uid += ":";
        if (mfrc522.uid.uidByte[i] < 0x10) uid += "0";
        uid += String(mfrc522.uid.uidByte[i], HEX);
    }
    uid.toUpperCase();
    return uid;
}

void connectWiFi() {
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASS);

    Serial.print("Connecting to WiFi");
    int attempts = 0;

    while (WiFi.status() != WL_CONNECTED && attempts < 40) {
        delay(500);
        Serial.print(".");
        attempts++;

        // Alternate red/green while connecting
        setLED(LED_RED, attempts % 2 == 0);
        setLED(LED_GREEN, attempts % 2 == 1);
    }

    setAllLEDs(false);

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi connected!");
        Serial.println("  IP: " + WiFi.localIP().toString());
        Serial.println("  RSSI: " + String(WiFi.RSSI()) + " dBm");
    } else {
        Serial.println("\nWiFi FAILED after " + String(attempts) + " attempts");
        Serial.println("Restarting in 5 seconds...");
        setLED(LED_RED, true);
        delay(5000);
        ESP.restart();
    }
}

void setLED(int pin, bool on) {
    digitalWrite(pin, on ? HIGH : LOW);
}

void setAllLEDs(bool on) {
    setLED(LED_GREEN, on);
    setLED(LED_BLUE, on);
    setLED(LED_RED, on);
}

void beep(int durationMs) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(durationMs);
    digitalWrite(BUZZER_PIN, LOW);
}
