import bcrypt

def test_bcrypt(password):
    print(f"Testing bcrypt with password: {password}")
    try:
        # Encode password to bytes
        pwd_bytes = password.encode('utf-8')
        # Hash
        hashed = bcrypt.hashpw(pwd_bytes, bcrypt.gensalt())
        print(f"Success! Hash: {hashed}")
        # Verify
        if bcrypt.checkpw(pwd_bytes, hashed):
            print("Verification successful")
        else:
            print("Verification failed")
    except Exception as e:
        print(f"Error: {e}")

test_bcrypt("password123")
