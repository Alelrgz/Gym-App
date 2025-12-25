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

class LeaderboardService:
    def get_leaderboard(self) -> LeaderboardData:
        return LeaderboardData(**LEADERBOARD_DATA)
