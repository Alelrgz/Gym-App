from fastapi import HTTPException
from data import GYMS_DB, CLIENT_DATA, TRAINER_DATA, OWNER_DATA, LEADERBOARD_DATA
from models import GymConfig, ClientData, TrainerData, OwnerData, LeaderboardData, WorkoutAssignment

class GymService:
    def get_gym(self, gym_id: str) -> GymConfig:
        gym = GYMS_DB.get(gym_id)
        if not gym:
            raise HTTPException(status_code=404, detail="Gym not found")
        return GymConfig(**gym)

class UserService:
    def get_client(self) -> ClientData:
        # In a real app, this would take a user_id
        user = CLIENT_DATA.get("user_123")
        if not user:
            raise HTTPException(status_code=404, detail="Client not found")
        return ClientData(**user)

    def assign_workout(self, assignment: WorkoutAssignment) -> dict:
        # Mock logic: Update the client's workout based on type
        client = CLIENT_DATA["user_123"]
        
        new_workout = {
            "title": f"Coach Assigned: {assignment.workout_type}",
            "duration": "60 min",
            "difficulty": "Hard",
            "exercises": []
        }

        if assignment.workout_type == "Push":
            new_workout["exercises"] = [
                {"name": "Incline DB Press", "sets": 4, "reps": "8-10", "rest": 90, "video_id": "InclineDBPress"},
                {"name": "Seated Shoulder Press", "sets": 4, "reps": "8-10", "rest": 90, "video_id": "SeatedShoulderPress"},
                {"name": "Machine Chest Fly", "sets": 3, "reps": "10-12", "rest": 60, "video_id": "MachineFly"},
                {"name": "Tricep Rope Pushdown", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown"}
            ]
        elif assignment.workout_type == "Pull":
             new_workout["exercises"] = [
                {"name": "Lat Pulldown", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown"}, # Placeholder
                {"name": "Cable Row", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown"}
            ]
        elif assignment.workout_type == "Legs":
             new_workout["exercises"] = [
                {"name": "Squat", "sets": 4, "reps": "5-8", "rest": 120, "video_id": "InclineDBPress"}, # Placeholder
                {"name": "Leg Extension", "sets": 3, "reps": "12-15", "rest": 60, "video_id": "InclineDBPress"}
            ]
        elif assignment.workout_type == "Cardio":
             new_workout["exercises"] = [
                {"name": "Treadmill Run", "sets": 1, "reps": "30 min", "rest": 0, "video_id": "InclineDBPress"} # Placeholder
            ]
        
        client["todays_workout"] = new_workout
        return {"status": "success", "message": f"Assigned {assignment.workout_type} to {assignment.client_name}"}

    def get_trainer(self) -> TrainerData:
        return TrainerData(**TRAINER_DATA)

    def get_owner(self) -> OwnerData:
        return OwnerData(**OWNER_DATA)

    def get_exercises(self) -> list:
        from data import EXERCISE_LIBRARY
        return EXERCISE_LIBRARY

    def create_exercise(self, exercise: dict) -> dict:
        from data import EXERCISE_LIBRARY
        # Generate ID
        new_id = f"ex_{len(EXERCISE_LIBRARY) + 1}"
        exercise["id"] = new_id
        # Default video if not provided
        if not exercise.get("video_id"):
            exercise["video_id"] = "InclineDBPress" # Fallback
        
        EXERCISE_LIBRARY.insert(0, exercise) # Add to top
        return exercise

    def get_workouts(self) -> list:
        from data import WORKOUTS_DB
        return list(WORKOUTS_DB.values())

    def create_workout(self, workout: dict) -> dict:
        from data import WORKOUTS_DB
        # Generate ID
        new_id = f"w{len(WORKOUTS_DB) + 1}"
        workout["id"] = new_id
        WORKOUTS_DB[new_id] = workout
        return workout

    def assign_workout(self, assignment: dict) -> dict:
        from data import CLIENT_DATA, WORKOUTS_DB
        
        client_id = assignment.get("client_id")
        workout_id = assignment.get("workout_id")
        date_str = assignment.get("date")

        # In a real app, validate IDs
        if client_id not in CLIENT_DATA:
            return {"error": "Client not found"}
        
        workout = WORKOUTS_DB.get(workout_id)
        if not workout:
            return {"error": "Workout not found"}

        # Create event
        new_event = {
            "date": date_str,
            "title": workout["title"],
            "type": "workout",
            "completed": False,
            "details": workout["difficulty"]
        }

        # Add to client's calendar
        if "calendar" not in CLIENT_DATA[client_id]:
            CLIENT_DATA[client_id]["calendar"] = {"events": []}
        
        CLIENT_DATA[client_id]["calendar"]["events"].append(new_event)
        return {"status": "success", "event": new_event}

class LeaderboardService:
    def get_leaderboard(self) -> LeaderboardData:
        return LeaderboardData(**LEADERBOARD_DATA)
