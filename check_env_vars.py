from dotenv import load_dotenv
import os

print("Loading .env...")
load_dotenv()

key = os.environ.get("GEMINI_API_KEY")
if key:
    print(f"Success! Found key starting with: {key[:5]}...")
else:
    print("FAILURE: GEMINI_API_KEY not found in environment.")

# Check file existence
if os.path.exists(".env"):
    print(".env file exists.")
    try:
        with open(".env", "rb") as f:
            content = f.read()
            print(f"Raw content first 20 bytes: {content[:20]}")
    except Exception as e:
        print(f"Error reading .env: {e}")
else:
    print(".env file does NOT exist.")
