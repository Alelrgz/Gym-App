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
    sets: Optional[int] = 0
    reps: Optional[Union[str, int]] = 0
    rest: Optional[int] = 0
    video_id: Optional[str] = None
    performance: Optional[List[Dict]] = None

class ExerciseTemplate(BaseModel):
    id: Optional[str] = None
    name: str
    muscle: Optional[str] = None
    muscle_group: Optional[str] = None  # Alias for muscle (used in course exercises)
    type: Optional[str] = None
    video_id: Optional[str] = None
    video_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    description: Optional[str] = None
    default_duration: Optional[int] = None  # Duration in seconds
    difficulty: Optional[str] = None  # beginner, intermediate, advanced
    steps: Optional[List[str]] = None  # Exercise steps/cues

class Workout(BaseModel):
    id: Optional[str] = None
    title: str
    duration: Optional[str] = ""
    difficulty: Optional[str] = ""
    exercises: List[Exercise] = []
    completed: Optional[bool] = False
    details: Optional[str] = None  # JSON string containing CO-OP info for completed workouts

class WorkoutTemplate(BaseModel):
    id: Optional[str] = None
    title: str
    duration: Optional[str] = ""
    difficulty: Optional[str] = ""
    exercises: List[Exercise] = []

class WeeklySplit(BaseModel):
    id: str
    name: str
    description: Optional[str] = ""
    days_per_week: int
    schedule: Union[Dict[str, Optional[Union[str, Dict]]], List[Dict]] = {}  # Dict or List format

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
    body_fat_pct: Optional[float] = None  # Body fat percentage

# --- TRAINER ---

class ClientSummary(BaseModel):
    id: str
    name: str
    status: str
    last_seen: str
    plan: str
    is_premium: Optional[bool] = False
    profile_picture: Optional[str] = None
    assigned_split: Optional[str] = None
    plan_expiry: Optional[str] = None
    upcoming_workouts: Optional[int] = 0

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
    type: str # 'consultation', 'class', 'personal', 'other', 'course'
    duration: int = 60 # Default to 60
    completed: bool = False
    course_id: Optional[str] = None  # Links to CourseORM for recurring group classes

class TrainerData(BaseModel):
    id: str # Self ID
    name: Optional[str] = None  # Trainer's display name (username)
    profile_picture: Optional[str] = None  # Profile picture URL
    specialties: Optional[str] = None  # Comma-separated specialties
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

class LeagueTier(BaseModel):
    name: str
    level: int
    min_gems: int
    color: str

class LeagueInfo(BaseModel):
    current_tier: LeagueTier
    all_tiers: List[LeagueTier]
    advance_count: int
    weekly_reset_iso: str

class LeaderboardData(BaseModel):
    users: List[LeaderboardUser]
    weekly_challenge: WeeklyChallenge
    league: LeagueInfo

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
    coupon_code: Optional[str] = None  # Coupon code for discount

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
    payment_method: Optional[str] = None  # "card", "cash", or None (free)
    stripe_payment_intent_id: Optional[str] = None  # From frontend card payment

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

class SelectNutritionistRequest(BaseModel):
    nutritionist_id: str

class AddBodyCompositionRequest(BaseModel):
    client_id: str
    weight: float
    body_fat_pct: Optional[float] = None
    fat_mass: Optional[float] = None
    lean_mass: Optional[float] = None

class SetWeightGoalRequest(BaseModel):
    client_id: str
    weight_goal: float

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
    max_capacity: Optional[int] = None  # None = unlimited
    waitlist_enabled: bool = True

class UpdateCourseRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    exercises: Optional[List[Exercise]] = None
    music_links: Optional[List[MusicLink]] = None
    day_of_week: Optional[int] = None
    time_slot: Optional[str] = None
    duration: Optional[int] = None
    is_shared: Optional[bool] = None
    max_capacity: Optional[int] = None
    waitlist_enabled: Optional[bool] = None

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


# --- LESSON ENROLLMENT & WAITLIST ---

class LessonEnrollment(BaseModel):
    id: Optional[int] = None
    lesson_id: int
    client_id: str
    client_name: Optional[str] = None
    status: str = "confirmed"  # confirmed, cancelled, attended, no_show
    enrolled_at: Optional[str] = None
    cancelled_at: Optional[str] = None
    added_to_calendar: bool = False

class LessonWaitlistEntry(BaseModel):
    id: Optional[int] = None
    lesson_id: int
    client_id: str
    client_name: Optional[str] = None
    position: int
    added_at: Optional[str] = None
    notified_at: Optional[str] = None
    notification_expires_at: Optional[str] = None
    status: str = "waiting"  # waiting, notified, accepted, declined, expired

class EnrollLessonRequest(BaseModel):
    lesson_id: int

class WaitlistAcceptRequest(BaseModel):
    waitlist_id: int
    add_to_calendar: bool = True

class LessonAvailability(BaseModel):
    lesson_id: int
    course_name: str
    date: str
    time: str
    max_capacity: Optional[int] = None
    enrolled_count: int = 0
    waitlist_count: int = 0
    spots_available: Optional[int] = None  # None if unlimited
    user_status: Optional[str] = None  # enrolled, waitlisted, or None

class Notification(BaseModel):
    id: Optional[int] = None
    user_id: str
    type: str  # waitlist_spot, class_reminder, payment_due, etc.
    title: str
    message: str
    action_data: Optional[dict] = None
    action_url: Optional[str] = None
    read: bool = False
    read_at: Optional[str] = None
    acted_on: bool = False
    created_at: Optional[str] = None
    expires_at: Optional[str] = None
