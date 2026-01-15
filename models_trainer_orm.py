from sqlalchemy import Column, String, Integer
from database import Base

class TrainerClientLinkORM(Base):
    __tablename__ = "trainer_clients"

    id = Column(String, primary_key=True, index=True) # client_id
    name = Column(String)
    status = Column(String)
    plan = Column(String)
    last_seen = Column(String)
