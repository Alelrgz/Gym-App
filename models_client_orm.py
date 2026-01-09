from sqlalchemy import Column, Integer, String, Boolean, Float, Date
from database import Base

class ClientProfileORM(Base):
    __tablename__ = "client_profile"

    id = Column(String, primary_key=True, index=True) # client_id
    name = Column(String)
    streak = Column(Integer, default=0)
    gems = Column(Integer, default=0)
    health_score = Column(Integer, default=0)
    plan = Column(String, nullable=True)
    status = Column(String, nullable=True)
    last_seen = Column(String, nullable=True)

class ClientScheduleORM(Base):
    __tablename__ = "client_schedule"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    date = Column(String, index=True) # ISO format YYYY-MM-DD
    title = Column(String)
    type = Column(String) # workout, rest, etc.
    completed = Column(Boolean, default=False)
    details = Column(String, nullable=True)

class ClientDietSettingsORM(Base):
    __tablename__ = "client_diet_settings"

    id = Column(String, primary_key=True, index=True) # client_id
    calories_target = Column(Integer, default=2000)
    protein_target = Column(Integer, default=150)
    carbs_target = Column(Integer, default=200)
    fat_target = Column(Integer, default=70)
    hydration_target = Column(Integer, default=2500)
    consistency_target = Column(Integer, default=80)

    # Current values (for progress tracking) - simplified for now, usually calculated from logs
    calories_current = Column(Integer, default=0)
    protein_current = Column(Integer, default=0)
    carbs_current = Column(Integer, default=0)
    fat_current = Column(Integer, default=0)
    hydration_current = Column(Integer, default=0)

class ClientDietLogORM(Base):
    __tablename__ = "client_diet_log"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    date = Column(String, index=True) # ISO format YYYY-MM-DD
    meal_type = Column(String) # Breakfast, Lunch, etc.
    meal_name = Column(String)
    calories = Column(Integer)
    time = Column(String)
