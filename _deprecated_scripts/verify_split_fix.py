"""
Test script to verify the split edit fix for non-default trainers.
This script tests that trainers can edit global splits and the changes are saved correctly.
"""

import requests
import json

BASE_URL = "http://localhost:5000"

def test_split_edit_with_different_trainers():
    """Test editing splits with different trainer IDs"""
    
    # Test with trainer_alpha (non-default trainer)
    trainer_id = "trainer_alpha"
    
    print(f"\n{'='*60}")
    print(f"Testing split editing with trainer: {trainer_id}")
    print(f"{'='*60}\n")
    
    # 1. Get all splits for this trainer
    print("1. Fetching splits...")
    response = requests.get(
        f"{BASE_URL}/api/trainer/splits",
        headers={"x-trainer-id": trainer_id}
    )
    
    if response.status_code != 200:
        print(f"❌ Failed to fetch splits: {response.status_code}")
        print(response.text)
        return
    
    splits = response.json()
    print(f"✓ Found {len(splits)} splits")
    
    if not splits:
        print("❌ No splits found to test with")
        return
    
    # Use the first split for testing
    test_split = splits[0]
    split_id = test_split["id"]
    print(f"✓ Testing with split: {test_split['name']} (ID: {split_id})")
    
    # 2. Try to update the split
    print(f"\n2. Updating split...")
    update_data = {
        "name": f"{test_split['name']} - EDITED BY {trainer_id}",
        "description": f"Updated by {trainer_id} at test time",
        "days_per_week": test_split.get("days_per_week", 7),
        "schedule": test_split.get("schedule", {})
    }
    
    response = requests.put(
        f"{BASE_URL}/api/trainer/splits/{split_id}",
        headers={
            "x-trainer-id": trainer_id,
            "Content-Type": "application/json"
        },
        json=update_data
    )
    
    if response.status_code != 200:
        print(f"❌ Failed to update split: {response.status_code}")
        print(response.text)
        return
    
    result = response.json()
    print(f"✓ Split updated successfully!")
    print(f"  New name: {result['name']}")
    print(f"  New description: {result['description']}")
    
    # 3. Verify the update persisted
    print(f"\n3. Verifying update persisted...")
    response = requests.get(
        f"{BASE_URL}/api/trainer/splits",
        headers={"x-trainer-id": trainer_id}
    )
    
    if response.status_code != 200:
        print(f"❌ Failed to fetch splits after update: {response.status_code}")
        return
    
    splits = response.json()
    updated_split = next((s for s in splits if s["id"] == split_id), None)
    
    if not updated_split:
        print(f"❌ Could not find updated split")
        return
    
    if updated_split["name"] == update_data["name"]:
        print(f"✓ Update persisted correctly!")
    else:
        print(f"❌ Update did not persist")
        print(f"  Expected: {update_data['name']}")
        print(f"  Got: {updated_split['name']}")
        return
    
    print(f"\n{'='*60}")
    print(f"✅ ALL TESTS PASSED!")
    print(f"{'='*60}\n")

if __name__ == "__main__":
    try:
        test_split_edit_with_different_trainers()
    except requests.exceptions.ConnectionError:
        print("\n❌ Could not connect to the server.")
        print("Please make sure the Flask app is running on http://localhost:5000")
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
