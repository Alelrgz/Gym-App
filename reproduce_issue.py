import urllib.request
import json
import sqlite3

# 1. Get ID for Walking Lunge
conn = sqlite3.connect('db/global.db')
cursor = conn.cursor()
cursor.execute("SELECT id FROM exercises WHERE name = 'Walking Lunge'")
result = cursor.fetchone()
conn.close()

if not result:
    print("Walking Lunge not found in global DB")
    # Try to find in trainer DB?
    # For now assume it's global as per screenshot implies standard exercise
    exit(1)

ex_id = result[0]
print(f"Found Walking Lunge ID: {ex_id}")

# 2. Try to update it via API
url = f'http://127.0.0.1:9007/api/trainer/exercises/{ex_id}'
data = {
    'name': 'Walking Lunge',
    'muscle': 'Legs',
    'type': 'Compound',
    'video_id': 'blob:http://192.168.1.60:9007/3857dc...'
}

req = urllib.request.Request(
    url, 
    data=json.dumps(data).encode(), 
    headers={'Content-Type': 'application/json', 'x-trainer-id': 'trainer_default'}, 
    method='PUT'
)

try:
    with urllib.request.urlopen(req) as res:
        print(f"Response Code: {res.getcode()}")
        print(res.read().decode())
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    print(e.read().decode())
except Exception as e:
    print(f"Error: {e}")
