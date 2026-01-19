from pydantic import BaseModel
from typing import List, Optional, Dict, Union

# --- GYM CONFIG ---
class GymConfig(BaseModel):
    name: str
    primary_color: str
    secondary_color: str
    logo_text: str

# --- WORKOUT ---
# --- WORKOUT ---
class Exercise(BaseModel):
    name: str
    sets: int
    reps: Union[str, int]
    rest: int
    video_id: str
    performance: Optional[List[Dict]] = None

class ExerciseTemplate(BaseModel):
    id: Optional[str] = None
    name: str
    muscle: str
    type: str
    video_id: Optional[str] = None

class Workout(BaseModel):
    id: Optional[str] = None
    title: str
    duration: str
    difficulty: str
    exercises: List[Exercise]
    completed: Optional[bool] = False

class WorkoutTemplate(BaseModel):
    id: Optional[str] = None
    title: str
    duration: str
    difficulty: str
    exercises: List[Exercise]

class WeeklySplit(BaseModel):
    id: str
    name: str
    description: Optional[str] = ""
    days_per_week: int
    schedule: Dict[str, Optional[Union[str, Dict]]] # Key: "Monday", "Tuesday", etc. Value: workout_id or {id, title} or None (Rest)

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
    consistency_target: Optional[int] = 80

# --- CALENDAR ---
class CalendarEvent(BaseModel):
    id: Optional[int] = None
    date: str  # YYYY-MM-DD
    title: str
    type: str  # 'workout', 'rest', 'milestone'
    completed: bool
    details: str

class CalendarData(BaseModel):
    events: List[CalendarEvent]

# --- CLIENT ---
class ClientData(BaseModel):
    id: str
    name: str
    email: Optional[str] = None # Added
    streak: int
    gems: int
    health_score: int
    todays_workout: Optional[Workout] = None
    daily_quests: List[DailyQuest]
    progress: Optional[Progress] = None
    calendar: CalendarData

class ClientProfileUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = None

# --- TRAINER ---

class ClientSummary(BaseModel):
    id: str
    name: str
    status: str
    last_seen: str
    plan: str
    is_premium: Optional[bool] = False

class Video(BaseModel):
    id: str
    title: str
    type: str
    thumb: str

class TrainerEvent(BaseModel):
    id: str
    date: str # YYYY-MM-DD
    time: str # HH:MM AM/PM
    title: str
    subtitle: str
    type: str # 'consultation', 'class', 'personal', 'other'

class TrainerData(BaseModel):
    id: str # Self ID
    clients: List[ClientSummary]
    video_library: List[Video]
    active_clients: int
    at_risk_clients: int
    schedule: Optional[List[TrainerEvent]] = []
    todays_workout: Optional[Workout] = None
    workouts: Optional[List[WorkoutTemplate]] = []
    splits: Optional[List[WeeklySplit]] = []

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

class AssignDietRequest(BaseModel):
    client_id: str
    calories: int
    protein: int
    carbs: int
    fat: int
    hydration_target: int
    consistency_target: int
