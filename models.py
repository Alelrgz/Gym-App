from pydantic import BaseModel
from typing import List, Optional, Dict, Union

# --- GYM CONFIG ---
class GymConfig(BaseModel):
    name: str
    primary_color: str
    secondary_color: str
    logo_text: str

# --- WORKOUT ---
class Exercise(BaseModel):
    name: str
    sets: int
    reps: Union[str, int]
    rest: int
    video_id: str

class ExerciseTemplate(BaseModel):
    id: str
    name: str
    muscle: str
    type: str
    video_id: str

class Workout(BaseModel):
    title: str
    duration: str
    difficulty: str
    exercises: List[Exercise]

class WorkoutTemplate(BaseModel):
    id: Optional[str] = None
    title: str
    duration: str
    difficulty: str
    exercises: List[Exercise]

# --- PROGRESS ---
class DailyQuest(BaseModel):
    text: str
    xp: int
    completed: bool

class Macro(BaseModel):
    current: int
    target: int

class Macros(BaseModel):
    calories: Macro
    protein: Macro
    carbs: Macro
    fat: Macro

class DietItem(BaseModel):
    meal: str
    cals: int
    time: str

class Hydration(BaseModel):
    current: int
    target: int

class Progress(BaseModel):
    photos: List[str]
    hydration: Hydration
    weekly_history: List[int]
    macros: Macros
    diet_log: Dict[str, List[DietItem]]

# --- CALENDAR ---
class CalendarEvent(BaseModel):
    date: str  # YYYY-MM-DD
    title: str
    type: str  # 'workout', 'rest', 'milestone'
    completed: bool
    details: str

class CalendarData(BaseModel):
    events: List[CalendarEvent]

# --- CLIENT ---
class ClientData(BaseModel):
    name: str
    streak: int
    gems: int
    health_score: int
    todays_workout: Workout
    daily_quests: List[DailyQuest]
    progress: Progress
    calendar: CalendarData

# --- TRAINER ---
class ClientSummary(BaseModel):
    name: str
    status: str
    last_seen: str
    plan: str

class Video(BaseModel):
    id: str
    title: str
    type: str
    thumb: str

class TrainerData(BaseModel):
    clients: List[ClientSummary]
    video_library: List[Video]

# --- OWNER ---
class Activity(BaseModel):
    time: str
    text: str
    type: str

class OwnerData(BaseModel):
    revenue_today: str
    active_members: int
    staff_active: int
    recent_activity: List[Activity]

# --- LEADERBOARD ---
class LeaderboardUser(BaseModel):
    name: str
    streak: int
    gems: int
    health_score: int
    rank: int
    isCurrentUser: Optional[bool] = False

class WeeklyChallenge(BaseModel):
    title: str
    description: str
    progress: int
    target: int
class WorkoutAssignment(BaseModel):
    client_name: str
    workout_type: str

class LeaderboardData(BaseModel):
    users: List[LeaderboardUser]
    weekly_challenge: WeeklyChallenge
