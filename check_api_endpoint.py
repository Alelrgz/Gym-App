import urllib.request
import urllib.error
import json

url = "http://127.0.0.1:9007/api/client/schedule?date=2026-01-10"

print(f"Testing URL: {url}")

try:
    with urllib.request.urlopen(url) as response:
        print(f"Status: {response.status}")
        data = response.read()
        print(f"Response: {data.decode('utf-8')}")
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code} - {e.reason}")
    print(e.read().decode('utf-8'))
except urllib.error.URLError as e:
    print(f"URL Error: {e.reason}")
except Exception as e:
    print(f"Error: {e}")
