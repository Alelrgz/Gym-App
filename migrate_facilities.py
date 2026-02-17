"""
Migration script for facility/field/room booking tables.
Run once to create the new tables: activity_types, facilities, facility_availability, facility_bookings
"""
from database import engine, Base
from models_orm import ActivityTypeORM, FacilityORM, FacilityAvailabilityORM, FacilityBookingORM

def migrate():
    print("Creating facility booking tables...")
    Base.metadata.create_all(bind=engine)
    print("Done! Tables created: activity_types, facilities, facility_availability, facility_bookings")

if __name__ == "__main__":
    migrate()
