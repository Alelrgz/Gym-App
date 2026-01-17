from database import get_db_session, engine, Base
from models_orm import UserORM as User
import bcrypt
import uuid

# Ensure tables exist
Base.metadata.create_all(bind=engine)

def hash_password(password: str) -> str:
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')

def seed():
    session = get_db_session()
    username = "trainerdev"
    password = "password123"
    
    existing = session.query(User).filter(User.username == username).first()
    if existing:
        session.delete(existing)
        session.commit()
        print(f"Removed existing user: {username}")
        
    user = User(
        id=str(uuid.uuid4()),
        username=username,
        hashed_password=hash_password(password),
        role="trainer"
    )
    session.add(user)
    session.commit()
    print(f"Created user: {username} / {password}")
    session.close()

if __name__ == "__main__":
    seed()
