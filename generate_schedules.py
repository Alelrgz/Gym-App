"""
Generate schedule entries for all courses.
"""
from database import get_db_session
from models_orm import UserORM, CourseORM
from service_modules.course_service import course_service

def generate_all_schedules():
    db = get_db_session()
    try:
        # Get all courses
        courses = db.query(CourseORM).all()
        print(f"Found {len(courses)} courses")
        print("-" * 50)

        for course in courses:
            print(f"Generating schedule for: {course.name} (type: {course.course_type})")
            try:
                result = course_service.generate_course_schedule(
                    course.id,
                    course.owner_id,
                    weeks_ahead=4
                )
                print(f"  -> Created {result.get('created', 0)} trainer entries, {result.get('client_entries', 0)} client entries")
            except Exception as e:
                print(f"  -> Error: {e}")

        print("-" * 50)
        print("Done!")

    finally:
        db.close()


if __name__ == "__main__":
    generate_all_schedules()
