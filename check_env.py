
import sys
import subprocess

required = ["fastapi", "uvicorn", "jinja2", "pydantic", "sqlalchemy"]

print(f"Python version: {sys.version}")
print("Checking dependencies...")

missing = []
for lib in required:
    try:
        __import__(lib)
        print(f"[OK] {lib}")
    except ImportError:
        print(f"[MISSING] {lib}")
        missing.append(lib)

if missing:
    print(f"\nInstalling missing: {', '.join(missing)}")
    subprocess.check_call([sys.executable, "-m", "pip", "install", *missing])
    print("Dependencies installed successfully.")
else:
    print("\nAll dependencies found.")
