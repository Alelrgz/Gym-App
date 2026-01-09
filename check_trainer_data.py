import sys
import os
import json

# Add project root to path
sys.path.append(os.getcwd())

from services import UserService
from models import TrainerData

def check_trainer_data():
    print("Fetching trainer data...")
    service = UserService()
    trainer_data = service.get_trainer()
    
    # Convert to dict to see what's actually serialized
    data_dict = trainer_data.model_dump()
    
    print(f"Clients found: {len(data_dict['clients'])}")
    if len(data_dict['clients']) > 0:
        first_client = data_dict['clients'][0]
        print(f"First client data: {first_client}")
        if 'id' not in first_client:
            print("\n!!! FAIL: 'id' field is MISSING in ClientSummary !!!")
        else:
            print(f"\nSUCCESS: 'id' field is present: {first_client['id']}")

if __name__ == "__main__":
    check_trainer_data()
