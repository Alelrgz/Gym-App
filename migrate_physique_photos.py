"""
Migration script to add the physique_photos table.
Run this once to create the table.
"""
from database import engine
from models_orm import Base, PhysiquePhotoORM

def migrate():
    print("Creating physique_photos table...")

    # Create only the physique_photos table
    PhysiquePhotoORM.__table__.create(engine, checkfirst=True)

    print("Done! physique_photos table created.")

if __name__ == "__main__":
    migrate()
