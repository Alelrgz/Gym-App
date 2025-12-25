
# --- MOCK DATABASE ---
GYMS_DB = {
    "iron_gym": {
        "name": "Iron Paradise Gym",
        "primary_color": "#D32F2F", # Red
        "secondary_color": "#212121", 
        "logo_text": "IRON PARADISE",
    },
    "zen_yoga": {
        "name": "Zen Soul Yoga",
        "primary_color": "#009688", # Teal
        "secondary_color": "#E0F2F1",
        "logo_text": "ZEN SOUL",
    }
}

CLIENT_DATA = {
    "user_123": {
        "name": "Alex",
        "streak": 12,
        "gems": 69,
        "health_score": 88, # New Metric
        "todays_workout": {
            "title": "Cbum's Push Day",
            "duration": "75 min",
            "difficulty": "Elite",
            "exercises": [
                {"name": "Incline DB Press", "sets": 4, "reps": "8-10", "rest": 90, "video_id": "InclineDBPress"},
                {"name": "Seated Shoulder Press", "sets": 4, "reps": "8-10", "rest": 90, "video_id": "SeatedShoulderPress"},
                {"name": "Machine Chest Fly", "sets": 3, "reps": "10-12", "rest": 60, "video_id": "MachineFly"},
                {"name": "DB Lateral Raise", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "LateralRaise"},
                {"name": "Tricep Rope Pushdown", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown"}
            ]
        },
        "daily_quests": [
            {"text": "Complete 'Leg Day Destruction'", "xp": 100, "completed": False},
            {"text": "Drink 2L Water", "xp": 20, "completed": True},
        ],
        "progress": {
            "photos": [
                "https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?w=150&h=200&fit=crop",
                "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=150&h=200&fit=crop"
            ],
            "hydration": {"current": 1250, "target": 2500}, # ml
            "weekly_history": [1800, 2100, 1950, 2200, 2000, 1850, 1450], # Last 7 days cals
            "macros": {
                "calories": {"current": 1450, "target": 2200},
                "protein": {"current": 110, "target": 180},
                "carbs": {"current": 150, "target": 250},
                "fat": {"current": 45, "target": 70}
            },
            "diet_log": {
                "Breakfast": [
                    {"meal": "Oatmeal & Berries", "cals": 350, "time": "08:00 AM"},
                    {"meal": "Black Coffee", "cals": 5, "time": "08:15 AM"},
                ],
                "Lunch": [
                    {"meal": "Grilled Chicken Salad", "cals": 450, "time": "12:30 PM"},
                ],
                "Snacks": [
                    {"meal": "Protein Shake", "cals": 180, "time": "03:00 PM"},
                ],
                "Dinner": [
                    {"meal": "Steak & Asparagus", "cals": 470, "time": "07:00 PM"},
                ]
            }
        }
    }
}

TRAINER_DATA = {
    "clients": [
        {"name": "Alex", "status": "On Track", "last_seen": "Today", "plan": "Hypertrophy"},
        {"name": "Sarah", "status": "At Risk", "last_seen": "5 days ago", "plan": "Weight Loss"},
    ],
    "video_library": [
        {"id": "v1", "title": "Squat Form 101", "type": "Stock", "thumb": "https://images.unsplash.com/photo-1574680096141-1cddd32e04ca?w=150&h=150&fit=crop"},
        {"id": "v2", "title": "Coach Mike's Lunge Tips", "type": "Custom", "thumb": "https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=150&h=150&fit=crop"},
        {"id": "v3", "title": "HIIT Cardio Intro", "type": "Stock", "thumb": "https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?w=150&h=150&fit=crop"},
    ]
}

OWNER_DATA = {
    "revenue_today": "$1,250",
    "active_members": 142,
    "staff_active": 4,
    "recent_activity": [
        {"time": "10:02 AM", "text": "New Signup: John D.", "type": "money"},
        {"time": "09:45 AM", "text": "Coach Mike started shift", "type": "staff"},
    ]
}

LEADERBOARD_DATA = {
    "users": [
        {"name": "Sarah Chen", "streak": 28, "gems": 1240, "health_score": 95, "rank": 1},
        {"name": "Mike Johnson", "streak": 21, "gems": 980, "health_score": 92, "rank": 2},
        {"name": "Alex", "streak": 12, "gems": 450, "health_score": 88, "rank": 3, "isCurrentUser": True},
        {"name": "Emma Wilson", "streak": 8, "gems": 380, "health_score": 85, "rank": 4},
        {"name": "Chris Lee", "streak": 5, "gems": 220, "health_score": 82, "rank": 5},
        {"name": "Lisa Taylor", "streak": 4, "gems": 180, "health_score": 78, "rank": 6},
    ],
    "weekly_challenge": {
        "title": "Winter Warrior Challenge",
        "description": "Complete 5 workouts this week",
        "progress": 3,
        "target": 5,
        "reward_gems": 200
    }
}
