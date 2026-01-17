from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def test_hash(password):
    print(f"Testing password of length {len(password)}")
    try:
        hashed = pwd_context.hash(password)
        print("Success!")
    except Exception as e:
        print(f"Error: {e}")

test_hash("password123")
test_hash("a" * 71)
test_hash("a" * 72)
test_hash("a" * 73)
