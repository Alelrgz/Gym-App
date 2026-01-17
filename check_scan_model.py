from services import UserService
import os
from dotenv import load_dotenv

load_dotenv()

print("Instantiating UserService...")
service = UserService()
print("Calling scan_meal with dummy data...")
# Pass a small valid jpeg header to avoid immediate rejection if validation exists, 
# though the current code doesn't seem to validate image structure before sending to Gemini, 
# Gemini might reject it. But we just want to see the "DEBUG: Initializing..." print.
dummy_bytes = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444\x1f\'9=82<.342\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00\x00\x00?\x00\xbf'

try:
    service.scan_meal(dummy_bytes)
except Exception as e:
    print(f"Caught expected exception (since image is fake): {e}")
