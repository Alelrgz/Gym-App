from sqlalchemy import Column, Integer, String, Boolean, Float, ForeignKey, Text
from database import Base
from datetime import datetime

# --- CORE MODELS ---

class UserORM(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True, nullable=True)
    hashed_password = Column(String)
    role = Column(String, index=True) # client, trainer, owner
    sub_role = Column(String, nullable=True) # trainer: trainer/nutritionist/both, owner: owner/staff
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    settings = Column(String, nullable=True) # JSON string
    profile_picture = Column(String, nullable=True)  # Path to profile image
    bio = Column(String, nullable=True)  # User bio/description (mainly for trainers)
    specialties = Column(String, nullable=True)  # Comma-separated trainer specialties (e.g., "Yoga,Calisthenics,Bodybuilding")

    # Gym code system
    gym_code = Column(String(6), unique=True, nullable=True, index=True)  # 6-char code for owners
    gym_owner_id = Column(String, ForeignKey("users.id"), nullable=True, index=True)  # For trainers: which gym they belong to
    is_approved = Column(Boolean, default=True, index=True)  # For trainers: needs owner approval (False = pending)

    # Stripe Connect (for gym owners to receive payments)
    stripe_account_id = Column(String, nullable=True)  # Connected Stripe account ID (acct_xxx)
    stripe_account_status = Column(String, nullable=True)  # pending, active, restricted

    # Trainer pricing
    session_rate = Column(Float, nullable=True)  # Hourly rate for 1-on-1 sessions

    # Gym branding (for owners)
    gym_name = Column(String, nullable=True)  # Custom gym name
    gym_logo = Column(String, nullable=True)  # Path to gym logo image

    # Onboarding fields
    phone = Column(String, nullable=True)  # Phone number
    must_change_password = Column(Boolean, default=False)  # Force password change on first login

    # Legal compliance
    terms_agreed_at = Column(String, nullable=True)  # ISO datetime when user agreed to Terms/Privacy

    # Spotify Integration (for music playback control)
    spotify_access_token = Column(String, nullable=True)  # OAuth access token
    spotify_refresh_token = Column(String, nullable=True)  # OAuth refresh token
    spotify_token_expires_at = Column(String, nullable=True)  # ISO datetime when token expires

    # Shower/NFC system settings (for owners)
    shower_timer_minutes = Column(Integer, nullable=True)  # Default shower duration in minutes
    shower_daily_limit = Column(Integer, nullable=True)  # Max showers per member per day
    device_api_key = Column(String, nullable=True, unique=True, index=True)  # UUID for ESP32 device auth

# --- EXERCISE & WORKOUT LIBRARY (Global + Personal) ---

class ExerciseORM(Base):
    __tablename__ = "exercises"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, index=True)
    muscle = Column(String)  # Also used as category for course exercises (warmup, cardio, etc.)
    type = Column(String)
    video_id = Column(String)
    # If owner_id is NULL, it's a global exercise. If set, it belongs to that trainer.
    owner_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)

    # Extended fields for course exercises
    description = Column(String, nullable=True)
    default_duration = Column(Integer, nullable=True)  # Duration in seconds
    difficulty = Column(String, nullable=True)  # beginner, intermediate, advanced
    thumbnail_url = Column(String, nullable=True)  # Image URL
    video_url = Column(String, nullable=True)  # Full video URL (YouTube, etc.)
    steps_json = Column(String, nullable=True)  # JSON array of step strings

class WorkoutORM(Base):
    __tablename__ = "workouts"

    id = Column(String, primary_key=True, index=True)
    title = Column(String, index=True)
    duration = Column(String)
    difficulty = Column(String)
    
    # Store exercises as JSON string for flexibility (Schema: list of dicts)
    # Long term: normalized WorkoutExercise table
    exercises_json = Column(String) 
    
    owner_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)

class WeeklySplitORM(Base):
    __tablename__ = "weekly_splits"
    
    id = Column(String, primary_key=True, index=True)
    name = Column(String)
    description = Column(String)
    days_per_week = Column(Integer)
    schedule_json = Column(String) # Store schedule as JSON
    owner_id = Column(String, ForeignKey("users.id"), index=True)

# --- CLIENT DATA (Formerly in per-client DBs) ---

class ClientProfileORM(Base):
    __tablename__ = "client_profile"

    # One-to-One with User, so PK is the same as User ID
    id = Column(String, ForeignKey("users.id"), primary_key=True, index=True)
    name = Column(String)
    email = Column(String, nullable=True) 
    streak = Column(Integer, default=0)
    gems = Column(Integer, default=0)
    health_score = Column(Integer, default=0)
    plan = Column(String, nullable=True)
    status = Column(String, nullable=True)
    last_seen = Column(String, nullable=True)

    # Gym and trainer/nutritionist assignment
    gym_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)  # Owner's ID representing the gym
    trainer_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)
    nutritionist_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)

    is_premium = Column(Boolean, default=False)

    # Personal info
    date_of_birth = Column(String, nullable=True)  # Format: YYYY-MM-DD
    emergency_contact_name = Column(String, nullable=True)
    emergency_contact_phone = Column(String, nullable=True)

    # Privacy setting for client-to-client chat
    privacy_mode = Column(String, default="public")  # "public" or "private"

    # Physical stats
    weight = Column(Float, nullable=True)  # Weight in kg
    body_fat_pct = Column(Float, nullable=True)  # Body fat percentage
    fat_mass = Column(Float, nullable=True)  # Fat mass in kg
    lean_mass = Column(Float, nullable=True)  # Lean mass in kg

    # Strength goals set by trainer (target % increase)
    strength_goal_upper = Column(Integer, nullable=True)  # Upper body target %
    strength_goal_lower = Column(Integer, nullable=True)  # Lower body target %
    strength_goal_cardio = Column(Integer, nullable=True)  # Cardio target %

    # Weight goal set by nutritionist
    weight_goal = Column(Float, nullable=True)  # Target weight in kg

    # Nutritionist-only health data
    height_cm = Column(Float, nullable=True)
    gender = Column(String, nullable=True)  # male / female / other
    activity_level = Column(String, nullable=True)  # sedentary / light / moderate / active / very_active
    allergies = Column(String, nullable=True)
    medical_conditions = Column(String, nullable=True)
    supplements = Column(String, nullable=True)
    sleep_hours = Column(Float, nullable=True)
    meal_frequency = Column(String, nullable=True)  # 3_meals / 5_small / intermittent_fasting / custom
    food_preferences = Column(String, nullable=True)  # none / vegan / vegetarian / halal / kosher / other
    occupation_type = Column(String, nullable=True)  # sedentary / light_physical / heavy_physical

    # Current assigned split tracking
    current_split_id = Column(String, nullable=True)  # WeeklySplitORM.id
    split_expiry_date = Column(String, nullable=True)  # YYYY-MM-DD when the 4-week split ends


class ClientDocumentORM(Base):
    """Stores client documents like medical certificates and signed waivers"""
    __tablename__ = "client_documents"

    id = Column(String, primary_key=True, index=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)
    gym_id = Column(String, ForeignKey("users.id"), index=True)

    document_type = Column(String)  # "medical_certificate", "waiver"
    file_path = Column(String, nullable=True)  # For uploaded files
    signature_data = Column(Text, nullable=True)  # Base64 signature for waivers

    uploaded_by = Column(String, ForeignKey("users.id"))  # Staff who uploaded
    created_at = Column(String)

    # Waiver-specific fields
    waiver_text = Column(Text, nullable=True)  # The waiver content they signed
    signed_at = Column(String, nullable=True)


class WeightHistoryORM(Base):
    __tablename__ = "weight_history"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)
    weight = Column(Float)
    body_fat_pct = Column(Float, nullable=True)  # Body fat percentage
    fat_mass = Column(Float, nullable=True)  # Fat mass in kg
    lean_mass = Column(Float, nullable=True)  # Lean mass in kg
    recorded_at = Column(String)  # ISO format datetime

class ClientScheduleORM(Base):
    __tablename__ = "client_schedule"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    # Vital for shared DB:
    client_id = Column(String, ForeignKey("users.id"), index=True)

    date = Column(String, index=True) # ISO format YYYY-MM-DD
    title = Column(String)
    type = Column(String) # workout, rest, course, etc.
    completed = Column(Boolean, default=False)
    workout_id = Column(String, nullable=True)
    details = Column(String, nullable=True)
    # For group courses
    course_id = Column(String, ForeignKey("courses.id"), nullable=True, index=True)

class ClientDietSettingsORM(Base):
    __tablename__ = "client_diet_settings"

    id = Column(String, ForeignKey("users.id"), primary_key=True, index=True) # client_id

    # Fitness goal: cut, maintain, bulk
    fitness_goal = Column(String, default="maintain")
    # Base maintenance calories (used to calculate cut/bulk targets)
    base_calories = Column(Integer, default=2000)

    calories_target = Column(Integer, default=2000)
    protein_target = Column(Integer, default=150)
    carbs_target = Column(Integer, default=200)
    fat_target = Column(Integer, default=70)
    hydration_target = Column(Integer, default=2500)
    consistency_target = Column(Integer, default=80)

    # Current day values (resets daily)
    calories_current = Column(Integer, default=0)
    protein_current = Column(Integer, default=0)
    carbs_current = Column(Integer, default=0)
    fat_current = Column(Integer, default=0)
    hydration_current = Column(Integer, default=0)

    # Track when we last reset (YYYY-MM-DD)
    last_reset_date = Column(String, nullable=True)

class ClientDietLogORM(Base):
    __tablename__ = "client_diet_log"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)

    date = Column(String, index=True)
    meal_type = Column(String)
    meal_name = Column(String)
    calories = Column(Integer)
    time = Column(String)

class ClientDailyDietSummaryORM(Base):
    """Daily diet summaries - stores end-of-day totals for metrics/history"""
    __tablename__ = "client_daily_diet_summary"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)

    date = Column(String, index=True)  # YYYY-MM-DD

    # Daily totals
    total_calories = Column(Integer, default=0)
    total_protein = Column(Integer, default=0)
    total_carbs = Column(Integer, default=0)
    total_fat = Column(Integer, default=0)
    total_hydration = Column(Integer, default=0)

    # Targets for that day (for historical comparison)
    target_calories = Column(Integer, nullable=True)
    target_protein = Column(Integer, nullable=True)
    target_carbs = Column(Integer, nullable=True)
    target_fat = Column(Integer, nullable=True)

    # Meal count
    meal_count = Column(Integer, default=0)

    # Daily health score (calculated from diet adherence)
    health_score = Column(Integer, default=0)

class ClientExerciseLogORM(Base):
    __tablename__ = "client_exercise_log"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)

    date = Column(String, index=True)
    workout_id = Column(String, nullable=True)
    exercise_name = Column(String, index=True)
    set_number = Column(Integer)
    reps = Column(Integer)
    weight = Column(Float)
    duration = Column(Float, nullable=True)  # Duration in minutes for cardio
    distance = Column(Float, nullable=True)  # Distance in km for cardio
    metric_type = Column(String, default="weight_reps")  # weight_reps, duration, distance, duration_distance 

class TrainerScheduleORM(Base):
    __tablename__ = "trainer_schedule"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    trainer_id = Column(String, ForeignKey("users.id"), index=True)

    date = Column(String, index=True) # YYYY-MM-DD
    time = Column(String) # HH:MM AM/PM
    title = Column(String)
    subtitle = Column(String, nullable=True)
    type = Column(String) # consultation, class, 1on1_appointment, etc
    duration = Column(Integer, default=60)  # Duration in minutes
    completed = Column(Boolean, default=False)
    workout_id = Column(String, nullable=True)
    details = Column(String, nullable=True)  # Store workout snapshot JSON on completion

    # For 1-on-1 appointments
    client_id = Column(String, ForeignKey("users.id"), nullable=True, index=True)
    appointment_id = Column(String, nullable=True, index=True)  # Links to AppointmentORM

    # For course-based schedule entries (recurring group classes)
    course_id = Column(String, ForeignKey("courses.id"), nullable=True, index=True)


class TrainerNoteORM(Base):
    __tablename__ = "trainer_notes"

    id = Column(String, primary_key=True, index=True)
    trainer_id = Column(String, ForeignKey("users.id"), index=True)
    title = Column(String)
    content = Column(String)  # Note body
    created_at = Column(String)
    updated_at = Column(String)


# --- SUBSCRIPTION & BILLING MODELS ---

class SubscriptionPlanORM(Base):
    """Subscription plans created by gym owners/trainers"""
    __tablename__ = "subscription_plans"

    id = Column(String, primary_key=True, index=True)
    gym_id = Column(String, ForeignKey("users.id"), index=True)  # Owner/trainer who created this plan

    name = Column(String)  # e.g., "Basic", "Premium", "VIP"
    description = Column(String, nullable=True)
    price = Column(Float)  # Monthly price in dollars
    currency = Column(String, default="usd")

    # Stripe integration
    stripe_price_id = Column(String, nullable=True)  # Stripe Price ID
    stripe_product_id = Column(String, nullable=True)  # Stripe Product ID

    # Plan features (JSON string)
    features_json = Column(String, nullable=True)  # e.g., '["Unlimited workouts", "Meal plans", "1-on-1 coaching"]'

    # Plan settings
    is_active = Column(Boolean, default=True)
    trial_period_days = Column(Integer, default=0)  # Free trial days
    billing_interval = Column(String, default="month")  # month, year

    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class ClientSubscriptionORM(Base):
    """Tracks client subscriptions to gym plans"""
    __tablename__ = "client_subscriptions"

    id = Column(String, primary_key=True, index=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)
    plan_id = Column(String, ForeignKey("subscription_plans.id"), index=True)
    gym_id = Column(String, ForeignKey("users.id"), index=True)  # Which gym they're subscribed to

    # Stripe integration
    stripe_subscription_id = Column(String, nullable=True, unique=True)
    stripe_customer_id = Column(String, nullable=True)
    stripe_payment_intent_id = Column(String, nullable=True)  # For one-time payments (onboarding)

    # Subscription status
    status = Column(String, default="active", index=True)  # active, canceled, past_due, trialing, incomplete

    # Dates
    start_date = Column(String)  # ISO format
    current_period_start = Column(String, nullable=True)
    current_period_end = Column(String, nullable=True)
    cancel_at_period_end = Column(Boolean, default=False)
    canceled_at = Column(String, nullable=True)
    ended_at = Column(String, nullable=True)
    trial_end = Column(String, nullable=True)

    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class PaymentORM(Base):
    """Payment history for subscriptions"""
    __tablename__ = "payments"

    id = Column(String, primary_key=True, index=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)
    subscription_id = Column(String, ForeignKey("client_subscriptions.id"), index=True, nullable=True)
    gym_id = Column(String, ForeignKey("users.id"), index=True)

    # Payment details
    amount = Column(Float)
    currency = Column(String, default="usd")
    status = Column(String, index=True)  # succeeded, pending, failed, refunded

    # Stripe integration
    stripe_payment_intent_id = Column(String, nullable=True, unique=True)
    stripe_invoice_id = Column(String, nullable=True)

    # Payment metadata
    description = Column(String, nullable=True)
    payment_method = Column(String, nullable=True)  # card, bank_transfer, etc.

    # Dates
    paid_at = Column(String, nullable=True)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class PlanOfferORM(Base):
    """Promotional offers for subscription plans"""
    __tablename__ = "plan_offers"

    id = Column(String, primary_key=True, index=True)
    gym_id = Column(String, ForeignKey("users.id"), index=True)
    plan_id = Column(String, ForeignKey("subscription_plans.id"), index=True, nullable=True)  # Specific plan or all plans if null

    # Offer details
    title = Column(String)  # e.g. "New Year Special"
    description = Column(String, nullable=True)  # e.g. "Get 50% off your first 3 months!"

    # Discount configuration
    discount_type = Column(String)  # "percent" or "fixed"
    discount_value = Column(Float)  # e.g. 50 for 50% or 10.00 for $10 off
    discount_duration_months = Column(Integer, default=1)  # How many months discount applies

    # Coupon code (optional)
    coupon_code = Column(String, nullable=True, index=True)  # e.g. "NEWYEAR50"

    # Stripe coupon integration
    stripe_coupon_id = Column(String, nullable=True)  # Stripe coupon ID for applying discounts

    # Validity
    is_active = Column(Boolean, default=True)
    starts_at = Column(String)  # ISO date
    expires_at = Column(String, nullable=True)  # ISO date, null = no expiry
    max_redemptions = Column(Integer, nullable=True)  # null = unlimited
    current_redemptions = Column(Integer, default=0)

    # Metadata
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, default=lambda: datetime.utcnow().isoformat())


# --- APPOINTMENT BOOKING MODELS ---

class TrainerAvailabilityORM(Base):
    """Trainer's weekly availability schedule for 1-on-1 appointments"""
    __tablename__ = "trainer_availability"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    trainer_id = Column(String, ForeignKey("users.id"), index=True)

    # Day of week (0 = Monday, 6 = Sunday)
    day_of_week = Column(Integer, index=True)

    # Time slots in HH:MM format (24-hour)
    start_time = Column(String)  # e.g., "09:00"
    end_time = Column(String)    # e.g., "17:00"

    # If false, this slot is temporarily blocked
    is_available = Column(Boolean, default=True)

    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class AppointmentORM(Base):
    """1-on-1 appointments between clients and trainers"""
    __tablename__ = "appointments"

    id = Column(String, primary_key=True, index=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)
    trainer_id = Column(String, ForeignKey("users.id"), index=True)

    # Appointment date and time
    date = Column(String, index=True)  # ISO format YYYY-MM-DD
    start_time = Column(String)  # HH:MM format
    end_time = Column(String)    # HH:MM format
    duration = Column(Integer, default=60)  # Duration in minutes

    # Appointment details
    title = Column(String, default="1-on-1 Training Session")
    session_type = Column(String, nullable=True)  # bodybuilding, crossfit, calisthenics, or custom
    notes = Column(String, nullable=True)  # Client's notes/goals for the session
    trainer_notes = Column(String, nullable=True)  # Trainer's notes after session

    # Payment
    price = Column(Float, nullable=True)  # Session price at time of booking
    payment_method = Column(String, nullable=True)  # card, cash, or null (free)
    payment_status = Column(String, default="pending")  # pending, paid, refunded, free
    stripe_payment_intent_id = Column(String, nullable=True)

    # Status
    status = Column(String, default="scheduled", index=True)  # scheduled, completed, canceled, no_show

    # Cancellation
    canceled_by = Column(String, nullable=True)  # user_id of who canceled
    canceled_at = Column(String, nullable=True)
    cancellation_reason = Column(String, nullable=True)

    # Timestamps
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, default=lambda: datetime.utcnow().isoformat())


# --- MESSAGING MODELS ---

class ConversationORM(Base):
    """Conversation thread between two users"""
    __tablename__ = "conversations"

    id = Column(String, primary_key=True, index=True)

    # Legacy fields for trainer <-> client (kept for backwards compatibility)
    trainer_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)
    client_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)

    # Generic participant fields for any conversation type
    user1_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)
    user2_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)

    # Conversation type: "trainer_client" or "client_client"
    conversation_type = Column(String, default="trainer_client")

    # Last activity for sorting
    last_message_at = Column(String, nullable=True)
    last_message_preview = Column(String, nullable=True)  # First 50 chars of last message

    # Unread counts (user1 and user2 for generic, trainer/client for legacy)
    trainer_unread_count = Column(Integer, default=0)
    client_unread_count = Column(Integer, default=0)
    user1_unread_count = Column(Integer, default=0)
    user2_unread_count = Column(Integer, default=0)

    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class MessageORM(Base):
    """Individual message in a conversation"""
    __tablename__ = "messages"

    id = Column(String, primary_key=True, index=True)
    conversation_id = Column(String, ForeignKey("conversations.id"), index=True)

    # Sender info
    sender_id = Column(String, ForeignKey("users.id"), index=True)
    sender_role = Column(String)  # 'trainer' or 'client'

    # Message content
    content = Column(String)

    # Read status
    is_read = Column(Boolean, default=False)
    read_at = Column(String, nullable=True)

    # Timestamps
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class PhysiquePhotoORM(Base):
    """Physique progress photos - visible to client and their trainer/nutritionist."""
    __tablename__ = "physique_photos"

    id = Column(Integer, primary_key=True, autoincrement=True)
    client_id = Column(String, nullable=False, index=True)  # Owner of the photo
    trainer_id = Column(String, nullable=True, index=True)  # Trainer who can view (if assigned)

    # Photo metadata
    title = Column(String, nullable=True)  # e.g., "Front pose", "Back pose"
    photo_date = Column(String, nullable=False)  # Date the photo was taken
    notes = Column(Text, nullable=True)  # Optional notes

    # File info
    filename = Column(String, nullable=False)
    file_path = Column(String, nullable=False)  # Relative path to the file

    # Timestamps
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, nullable=True)


class MedicalCertificateORM(Base):
    """Medical certificates uploaded by clients (certificato medico sportivo)."""
    __tablename__ = "medical_certificates"

    id = Column(Integer, primary_key=True, autoincrement=True)
    client_id = Column(String, nullable=False, index=True)

    # File info
    filename = Column(String, nullable=False)  # Original filename
    file_path = Column(String, nullable=False)  # Relative path to the file

    # Expiration tracking
    expiration_date = Column(String, nullable=True)  # YYYY-MM-DD

    # Timestamps
    uploaded_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class CheckInORM(Base):
    """Member check-in records for gym reception/staff."""
    __tablename__ = "checkins"

    id = Column(Integer, primary_key=True, autoincrement=True)
    member_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    staff_id = Column(String, ForeignKey("users.id"), nullable=True)  # Staff who checked them in
    gym_owner_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)

    checked_in_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    notes = Column(String, nullable=True)


class DailyQuestCompletionORM(Base):
    """Tracks manual quest completions for a client on a specific date."""
    __tablename__ = "daily_quest_completions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)
    date = Column(String, index=True)  # YYYY-MM-DD
    quest_index = Column(Integer)  # Index of the quest (0, 1, 2, 3...)
    completed = Column(Boolean, default=False)
    completed_at = Column(String, nullable=True)


class NotificationORM(Base):
    """Notifications for users (trainers, clients, owners)."""
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String, ForeignKey("users.id"), index=True)  # Who receives the notification
    type = Column(String, index=True)  # appointment_booked, appointment_canceled, message, etc.
    title = Column(String)
    message = Column(String)
    data = Column(Text, nullable=True)  # JSON data for additional context
    read = Column(Boolean, default=False, index=True)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class ChatRequestORM(Base):
    """Chat requests for private users - must be accepted before messaging."""
    __tablename__ = "chat_requests"

    id = Column(Integer, primary_key=True, autoincrement=True)
    from_user_id = Column(String, ForeignKey("users.id"), index=True)  # Who sent the request
    to_user_id = Column(String, ForeignKey("users.id"), index=True)  # Who receives the request

    status = Column(String, default="pending")  # pending, accepted, rejected
    message = Column(String, nullable=True)  # Optional intro message

    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    responded_at = Column(String, nullable=True)  # When accepted/rejected


class FriendshipORM(Base):
    """Friendships between gym members."""
    __tablename__ = "friendships"

    id = Column(Integer, primary_key=True, autoincrement=True)
    # Normalized: user1_id < user2_id to prevent duplicate entries
    user1_id = Column(String, ForeignKey("users.id"), index=True)
    user2_id = Column(String, ForeignKey("users.id"), index=True)

    status = Column(String, default="pending")  # pending, accepted, declined
    initiated_by = Column(String, ForeignKey("users.id"))  # Who sent the request
    message = Column(String, nullable=True)  # Optional message with request

    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    accepted_at = Column(String, nullable=True)


# --- AUTOMATED MESSAGING ---

class AutomatedMessageTemplateORM(Base):
    """Automated message templates configured by gym owners."""
    __tablename__ = "automated_message_templates"

    id = Column(String, primary_key=True, index=True)  # UUID
    gym_id = Column(String, ForeignKey("users.id"), index=True)  # Owner's user ID
    name = Column(String)  # e.g., "Inactive Client Reminder"
    trigger_type = Column(String, index=True)  # missed_workout, days_inactive, no_show_appointment
    trigger_config = Column(Text, nullable=True)  # JSON: {"days_threshold": 5}
    subject = Column(String, nullable=True)  # For email
    message_template = Column(Text)  # Supports {client_name}, {days_inactive}, etc.
    delivery_methods = Column(Text)  # JSON: ["in_app", "email", "whatsapp"]
    is_enabled = Column(Boolean, default=True)
    send_delay_hours = Column(Integer, default=0)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, nullable=True)


class AutomatedMessageLogORM(Base):
    """Log of sent automated messages to prevent duplicates."""
    __tablename__ = "automated_message_log"

    id = Column(Integer, primary_key=True, autoincrement=True)
    template_id = Column(String, ForeignKey("automated_message_templates.id"), index=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)
    gym_id = Column(String, index=True)
    trigger_type = Column(String)
    trigger_reference = Column(String, nullable=True)  # schedule_id or appointment_id
    delivery_method = Column(String)  # in_app, email, whatsapp
    status = Column(String, default="sent")  # sent, failed
    error_message = Column(Text, nullable=True)
    triggered_at = Column(String)
    sent_at = Column(String, nullable=True)


# --- GROUP COURSES & LESSONS ---

class CourseORM(Base):
    """Group fitness courses/classes that trainers can create and schedule."""
    __tablename__ = "courses"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String, nullable=True)

    # Exercises planned for this course (reuse existing Exercise structure)
    exercises_json = Column(String, nullable=True)  # JSON: List of exercise dicts

    # Music integration - store array of links
    music_links_json = Column(String, nullable=True)  # JSON: [{"title": "...", "url": "...", "type": "spotify|youtube"}]

    # Recurring schedule (e.g., "Monday 9:00 AM")
    day_of_week = Column(Integer, nullable=True)  # 0=Monday, 6=Sunday (legacy, single day)
    days_of_week_json = Column(String, nullable=True)  # JSON array of days [0,2,4] for Mon/Wed/Fri
    time_slot = Column(String, nullable=True)  # "9:00 AM"
    duration = Column(Integer, default=60)  # Duration in minutes

    # Ownership and visibility
    owner_id = Column(String, ForeignKey("users.id"), index=True)  # Trainer who created it
    gym_id = Column(String, ForeignKey("users.id"), index=True, nullable=True)  # Gym owner ID
    is_shared = Column(Boolean, default=False)  # If True, visible to all trainers in gym

    # Client preview / visual intro
    course_type = Column(String, nullable=True)  # yoga, pilates, hiit, dance, spin, strength, stretch, cardio
    cover_image_url = Column(String, nullable=True)  # Cover image for client view
    trailer_url = Column(String, nullable=True)  # YouTube/Vimeo trailer URL

    # Capacity management
    max_capacity = Column(Integer, nullable=True)  # Max participants (None = unlimited)
    waitlist_enabled = Column(Boolean, default=True)  # Allow waitlist when full

    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, nullable=True)


class CourseLessonORM(Base):
    """Individual lesson/session of a course with engagement tracking."""
    __tablename__ = "course_lessons"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    course_id = Column(String, ForeignKey("courses.id"), index=True)

    # Scheduling
    date = Column(String, index=True)  # YYYY-MM-DD
    time = Column(String)  # "9:00 AM"
    duration = Column(Integer, default=60)

    trainer_id = Column(String, ForeignKey("users.id"), index=True)

    # Capacity (overrides course default if set)
    max_capacity = Column(Integer, nullable=True)  # None = use course default

    # Lesson content (can override course defaults)
    exercises_json = Column(String, nullable=True)  # Optional override
    music_links_json = Column(String, nullable=True)  # Optional override

    # Completion tracking
    completed = Column(Boolean, default=False)
    completed_at = Column(String, nullable=True)

    # Engagement tracking (1-5 scale)
    engagement_level = Column(Integer, nullable=True)  # 1=Low, 5=Excellent
    notes = Column(String, nullable=True)  # Trainer notes after lesson
    attendee_count = Column(Integer, nullable=True)

    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())


# --- LESSON ENROLLMENT & WAITLIST ---

class LessonEnrollmentORM(Base):
    """Tracks client enrollments in course lessons."""
    __tablename__ = "lesson_enrollments"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    lesson_id = Column(Integer, ForeignKey("course_lessons.id"), index=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)

    status = Column(String, default="confirmed")  # confirmed, cancelled, attended, no_show
    enrolled_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    cancelled_at = Column(String, nullable=True)

    # For calendar integration
    added_to_calendar = Column(Boolean, default=False)
    calendar_event_id = Column(String, nullable=True)  # External calendar event ID


class LessonWaitlistORM(Base):
    """Tracks clients on waitlist for full lessons."""
    __tablename__ = "lesson_waitlist"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    lesson_id = Column(Integer, ForeignKey("course_lessons.id"), index=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)

    position = Column(Integer)  # 1 = first in line
    added_at = Column(String, default=lambda: datetime.utcnow().isoformat())

    # Notification tracking
    notified_at = Column(String, nullable=True)  # When spot became available
    notification_expires_at = Column(String, nullable=True)  # Deadline to accept

    status = Column(String, default="waiting")  # waiting, notified, accepted, declined, expired


# --- NFC SHOWER SYSTEM ---

class NfcTagORM(Base):
    """NFC tags (wristbands/cards) registered to gym members."""
    __tablename__ = "nfc_tags"

    id = Column(Integer, primary_key=True, autoincrement=True)
    nfc_uid = Column(String, unique=True, nullable=False, index=True)  # Hardware UID (e.g., "04:A3:2B:1C:5D:80:00")
    member_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    gym_owner_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    registered_by = Column(String, ForeignKey("users.id"), nullable=True)  # Staff who registered
    label = Column(String, nullable=True)  # e.g., "Wristband #42"
    is_active = Column(Boolean, default=True)
    registered_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class ShowerUsageORM(Base):
    """Shower session usage logs."""
    __tablename__ = "shower_usage"

    id = Column(Integer, primary_key=True, autoincrement=True)
    nfc_tag_id = Column(Integer, ForeignKey("nfc_tags.id"), nullable=True, index=True)
    member_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    gym_owner_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    shower_id = Column(String, nullable=True)  # Which shower/device (e.g., "shower-1")
    started_at = Column(String, nullable=False)  # ISO datetime
    duration_seconds = Column(Integer, nullable=True)  # Actual duration (from ESP32 report)
    timer_seconds = Column(Integer, nullable=False)  # Granted timer duration
    completed = Column(Boolean, default=False)
    ended_at = Column(String, nullable=True)  # ISO datetime when session ended


# --- FACILITY / FIELD / ROOM BOOKING MODELS ---

class ActivityTypeORM(Base):
    """Owner-defined activity types (tennis, paddle, yoga, etc.)"""
    __tablename__ = "activity_types"

    id = Column(String, primary_key=True, index=True)
    gym_id = Column(String, ForeignKey("users.id"), index=True)
    name = Column(String)
    emoji = Column(String, nullable=True)
    description = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, nullable=True)


class FacilityORM(Base):
    """Individual facility (court, room, field) under an activity type"""
    __tablename__ = "facilities"

    id = Column(String, primary_key=True, index=True)
    activity_type_id = Column(String, ForeignKey("activity_types.id"), index=True)
    gym_id = Column(String, ForeignKey("users.id"), index=True)
    name = Column(String)
    description = Column(String, nullable=True)
    slot_duration = Column(Integer, default=60)  # Minutes per booking slot
    price_per_slot = Column(Float, nullable=True)
    max_participants = Column(Integer, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, nullable=True)


class FacilityAvailabilityORM(Base):
    """Facility weekly availability schedule (mirrors trainer_availability)"""
    __tablename__ = "facility_availability"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    facility_id = Column(String, ForeignKey("facilities.id"), index=True)
    day_of_week = Column(Integer, index=True)  # 0=Monday, 6=Sunday
    start_time = Column(String)  # HH:MM (24h)
    end_time = Column(String)    # HH:MM (24h)
    is_available = Column(Boolean, default=True)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())


class FacilityBookingORM(Base):
    """Facility booking by a client"""
    __tablename__ = "facility_bookings"

    id = Column(String, primary_key=True, index=True)
    facility_id = Column(String, ForeignKey("facilities.id"), index=True)
    activity_type_id = Column(String, ForeignKey("activity_types.id"), index=True)
    gym_id = Column(String, ForeignKey("users.id"), index=True)
    client_id = Column(String, ForeignKey("users.id"), index=True)

    date = Column(String, index=True)  # YYYY-MM-DD
    start_time = Column(String)        # HH:MM
    end_time = Column(String)          # HH:MM
    duration = Column(Integer, default=60)

    title = Column(String, nullable=True)
    notes = Column(String, nullable=True)

    price = Column(Float, nullable=True)
    payment_method = Column(String, nullable=True)
    payment_status = Column(String, default="pending")

    status = Column(String, default="confirmed", index=True)  # confirmed, completed, canceled

    canceled_by = Column(String, nullable=True)
    canceled_at = Column(String, nullable=True)
    cancellation_reason = Column(String, nullable=True)

    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, nullable=True)
