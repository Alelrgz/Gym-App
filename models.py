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
    current: float
    target: float

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
    weekly_health_scores: List[int]  # Daily health scores Mon-Sun for consistency chart
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
    username: str
    name: str
    email: Optional[str] = None # Added
    streak: int
    gems: int
    health_score: int
    weight: Optional[float] = None  # Weight in kg
    todays_workout: Optional[Workout] = None
    daily_quests: List[DailyQuest]
    progress: Optional[Progress] = None
    calendar: CalendarData

class ClientProfileUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    password: Optional[str] = None
    weight: Optional[float] = None  # Weight in kg

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
    duration: int = 60 # Default to 60
    completed: bool = False

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
    streak: int = 0

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
    user_id: Optional[str] = None
    profile_picture: Optional[str] = None
    privacy_mode: Optional[str] = "public"

class WeeklyChallenge(BaseModel):
    title: str
    description: str
    progress: int
    target: int
    reward_gems: Optional[int] = 200

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

# --- SUBSCRIPTION & BILLING ---

class SubscriptionPlan(BaseModel):
    id: Optional[str] = None
    gym_id: str
    name: str
    description: Optional[str] = None
    price: float
    currency: str = "usd"
    features: Optional[List[str]] = []
    is_active: bool = True
    trial_period_days: int = 0
    billing_interval: str = "month"
    stripe_price_id: Optional[str] = None
    stripe_product_id: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class CreateSubscriptionPlanRequest(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    features: Optional[List[str]] = []
    trial_period_days: int = 0
    billing_interval: str = "month"  # month or year

class UpdateSubscriptionPlanRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    features: Optional[List[str]] = None
    is_active: Optional[bool] = None
    trial_period_days: Optional[int] = None

class ClientSubscription(BaseModel):
    id: Optional[str] = None
    client_id: str
    plan_id: str
    gym_id: str
    status: str  # active, canceled, past_due, trialing
    start_date: str
    current_period_start: Optional[str] = None
    current_period_end: Optional[str] = None
    cancel_at_period_end: bool = False
    canceled_at: Optional[str] = None
    trial_end: Optional[str] = None
    stripe_subscription_id: Optional[str] = None
    stripe_customer_id: Optional[str] = None

class CreateSubscriptionRequest(BaseModel):
    plan_id: str
    payment_method_id: Optional[str] = None  # Stripe payment method ID

class CancelSubscriptionRequest(BaseModel):
    subscription_id: str
    cancel_immediately: bool = False  # If False, cancels at period end

class Payment(BaseModel):
    id: str
    client_id: str
    subscription_id: Optional[str] = None
    gym_id: str
    amount: float
    currency: str
    status: str  # succeeded, pending, failed, refunded
    description: Optional[str] = None
    paid_at: Optional[str] = None
    created_at: str

class SubscriptionPlanWithDetails(SubscriptionPlan):
    """Subscription plan with additional computed fields"""
    active_subscriptions_count: int = 0
    monthly_revenue: float = 0.0


# --- APPOINTMENT BOOKING MODELS ---

class TrainerAvailability(BaseModel):
    id: Optional[int] = None
    trainer_id: str
    day_of_week: int  # 0 = Monday, 6 = Sunday
    start_time: str  # HH:MM format
    end_time: str    # HH:MM format
    is_available: bool = True
    created_at: Optional[str] = None

class SetAvailabilityRequest(BaseModel):
    day_of_week: int
    start_time: str
    end_time: str

class UpdateAvailabilityRequest(BaseModel):
    availability: List[SetAvailabilityRequest]

class Appointment(BaseModel):
    id: Optional[str] = None
    client_id: str
    trainer_id: str
    date: str  # YYYY-MM-DD
    start_time: str  # HH:MM
    end_time: str    # HH:MM
    duration: int = 60
    title: str = "1-on-1 Training Session"
    notes: Optional[str] = None
    trainer_notes: Optional[str] = None
    status: str = "scheduled"  # scheduled, completed, canceled, no_show
    canceled_by: Optional[str] = None
    canceled_at: Optional[str] = None
    cancellation_reason: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class BookAppointmentRequest(BaseModel):
    trainer_id: str
    date: str  # YYYY-MM-DD
    start_time: str  # HH:MM
    duration: int = 60
    session_type: Optional[str] = None  # e.g., "bodybuilding", "crossfit", "calisthenics", or custom
    notes: Optional[str] = None

class CancelAppointmentRequest(BaseModel):
    cancellation_reason: Optional[str] = None

class AvailableSlot(BaseModel):
    start_time: str  # HH:MM
    end_time: str    # HH:MM
    available: bool = True

# --- GYM/TRAINER ASSIGNMENT ---

class JoinGymRequest(BaseModel):
    gym_code: str

class SelectTrainerRequest(BaseModel):
    trainer_id: str

class TrainerInfo(BaseModel):
    id: str
    username: str
    email: Optional[str] = None
    client_count: int = 0


# --- GROUP COURSES ---

class MusicLink(BaseModel):
    title: str
    url: str
    type: str  # "spotify" or "youtube"

class Course(BaseModel):
    id: Optional[str] = None
    name: str
    description: Optional[str] = None
    exercises: Optional[List[Exercise]] = []
    music_links: Optional[List[MusicLink]] = []
    day_of_week: Optional[int] = None  # 0=Monday, 6=Sunday
    time_slot: Optional[str] = None
    duration: int = 60
    owner_id: Optional[str] = None
    gym_id: Optional[str] = None
    is_shared: bool = False
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class CreateCourseRequest(BaseModel):
    name: str
    description: Optional[str] = None
    exercises: Optional[List[Exercise]] = []
    music_links: Optional[List[MusicLink]] = []
    day_of_week: Optional[int] = None
    time_slot: Optional[str] = None
    duration: int = 60
    is_shared: bool = False

class UpdateCourseRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    exercises: Optional[List[Exercise]] = None
    music_links: Optional[List[MusicLink]] = None
    day_of_week: Optional[int] = None
    time_slot: Optional[str] = None
    duration: Optional[int] = None
    is_shared: Optional[bool] = None

class CourseLesson(BaseModel):
    id: Optional[int] = None
    course_id: str
    course_name: Optional[str] = None
    date: str  # YYYY-MM-DD
    time: str
    duration: int = 60
    trainer_id: Optional[str] = None
    exercises: Optional[List[Exercise]] = []
    music_links: Optional[List[MusicLink]] = []
    completed: bool = False
    completed_at: Optional[str] = None
    engagement_level: Optional[int] = None  # 1-5
    notes: Optional[str] = None
    attendee_count: Optional[int] = None
    created_at: Optional[str] = None

class ScheduleLessonRequest(BaseModel):
    date: str  # YYYY-MM-DD
    time: Optional[str] = None  # Override course default
    duration: Optional[int] = None  # Override course default
    exercises: Optional[List[Exercise]] = None  # Optional override
    music_links: Optional[List[MusicLink]] = None  # Optional override

class CompleteLessonRequest(BaseModel):
    engagement_level: int  # 1-5 required
    notes: Optional[str] = None
    attendee_count: Optional[int] = None
