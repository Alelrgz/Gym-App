import requests

def register(username, password, email):
    url = "http://127.0.0.1:9007/api/auth/register"
    payload = {
        "username": username,
        "password": password,
        "email": email,
        "role": "trainer"
    }
    try:
        response = requests.post(url, json=payload)
        print(f"Registering {username} with email '{email}': Status {response.status_code}")
        if response.status_code != 200:
            print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

# Try registering with empty email string
register("user_empty_email_1", "pass", "")
register("user_empty_email_2", "pass", "")
