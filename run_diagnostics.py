import sys
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("gym_app")

try:
    from services import UserService
    # Initialize DB by calling seed? services.py usually seeds on import or usage.
    print("Initalizing UserService...")
    service = UserService()
    print("Calling get_client()...")
    data = service.get_client()
    print("Success! Data received.")
except Exception as e:
    print("CAUGHT EXCEPTION:")
    import traceback
    traceback.print_exc()
