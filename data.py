
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

SPLITS_DB = {
    "split_1": {
        "id": "split_1",
        "name": "PPL (Push Pull Legs)",
        "description": "Classic 6-day split for hypertrophy",
        "days_per_week": 7,
        "schedule": {
            "Monday": "cbum_push",
            "Tuesday": "w1", # Placeholder for Pull
            "Wednesday": "w1", # Placeholder for Legs
            "Thursday": "cbum_push",
            "Friday": "w1",
            "Saturday": "w1",
            "Sunday": None # Rest
        }
    }
}

WORKOUTS_DB = {
    "w1": {
        "id": "w1",
        "title": "Full Body Blast",
        "duration": "45 min",
        "difficulty": "Intermediate",
        "exercises": [
            {"name": "Barbell Squat", "sets": 3, "reps": "10", "rest": 60, "video_id": "Squats"},
            {"name": "Push-Ups", "sets": 3, "reps": "15", "rest": 45, "video_id": "PushUps"},
            {"name": "Pull-Up", "sets": 3, "reps": "8", "rest": 60, "video_id": "PullUp"}
        ]
    },
    "cbum_push": {
        "id": "cbum_push",
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
        },
        "calendar": {
            "events": [
                # 12-Day Streak (Dec 15 - Dec 26)
                {"date": "2025-12-15", "title": "Streak Day 1", "type": "workout", "completed": True, "details": "Start of streak"},
                {"date": "2025-12-16", "title": "Streak Day 2", "type": "workout", "completed": True, "details": "Cardio"},
                {"date": "2025-12-17", "title": "Streak Day 3", "type": "workout", "completed": True, "details": "Upper Body"},
                {"date": "2025-12-18", "title": "Streak Day 4", "type": "workout", "completed": True, "details": "Legs"},
                {"date": "2025-12-19", "title": "Streak Day 5", "type": "workout", "completed": True, "details": "Abs"},
                {"date": "2025-12-20", "title": "Streak Day 6", "type": "workout", "completed": True, "details": "Yoga"},
                {"date": "2025-12-21", "title": "Streak Day 7", "type": "workout", "completed": True, "details": "HIIT"},
                {"date": "2025-12-22", "title": "Streak Day 8", "type": "workout", "completed": True, "details": "Push Day"},
                {"date": "2025-12-23", "title": "Streak Day 9", "type": "workout", "completed": True, "details": "Pull Day"},
                {"date": "2025-12-24", "title": "Christmas Eve Pump", "type": "workout", "completed": True, "details": "Full Body"},
                {"date": "2025-12-25", "title": "Christmas Cardio", "type": "workout", "completed": True, "details": "Morning Run"},
                {"date": "2025-12-26", "title": "Cbum's Push Day", "type": "workout", "completed": True, "details": "Chest & Shoulders"},
                
                # Future
                {"date": "2025-12-28", "title": "Leg Day", "type": "workout", "completed": False, "details": "Squats & Lunges"},
                {"date": "2025-12-31", "title": "New Year's Eve Pump", "type": "workout", "completed": False, "details": "Arms & Abs"},
                {"date": "2026-01-01", "title": "Recovery", "type": "rest", "completed": False, "details": "Stretching"},
                {"date": "2026-01-11", "title": "Cbum's Push Day", "type": "workout", "completed": False, "details": "Chest & Shoulders", "workout_id": "cbum_push"}
            ]
        }
    },
    "user_123_v2": {
        "name": "Alex V2",
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
        },
        "calendar": {
            "events": [
                # 12-Day Streak (Dec 15 - Dec 26)
                {"date": "2025-12-15", "title": "Streak Day 1", "type": "workout", "completed": True, "details": "Start of streak"},
                {"date": "2025-12-16", "title": "Streak Day 2", "type": "workout", "completed": True, "details": "Cardio"},
                {"date": "2025-12-17", "title": "Streak Day 3", "type": "workout", "completed": True, "details": "Upper Body"},
                {"date": "2025-12-18", "title": "Streak Day 4", "type": "workout", "completed": True, "details": "Legs"},
                {"date": "2025-12-19", "title": "Streak Day 5", "type": "workout", "completed": True, "details": "Abs"},
                {"date": "2025-12-20", "title": "Streak Day 6", "type": "workout", "completed": True, "details": "Yoga"},
                {"date": "2025-12-21", "title": "Streak Day 7", "type": "workout", "completed": True, "details": "HIIT"},
                {"date": "2025-12-22", "title": "Streak Day 8", "type": "workout", "completed": True, "details": "Push Day"},
                {"date": "2025-12-23", "title": "Streak Day 9", "type": "workout", "completed": True, "details": "Pull Day"},
                {"date": "2025-12-24", "title": "Christmas Eve Pump", "type": "workout", "completed": True, "details": "Full Body"},
                {"date": "2025-12-25", "title": "Christmas Cardio", "type": "workout", "completed": True, "details": "Morning Run"},
                {"date": "2025-12-26", "title": "Cbum's Push Day", "type": "workout", "completed": True, "details": "Chest & Shoulders"},
                
                # Future
                {"date": "2025-12-28", "title": "Leg Day", "type": "workout", "completed": False, "details": "Squats & Lunges"},
                {"date": "2025-12-31", "title": "New Year's Eve Pump", "type": "workout", "completed": False, "details": "Arms & Abs"},
                {"date": "2026-01-01", "title": "Recovery", "type": "rest", "completed": False, "details": "Stretching"},
                {"date": "2026-01-11", "title": "Verification Workout", "type": "workout", "completed": False, "details": "Testing Completion", "workout_id": "w1"}
            ]
        }
    },
    "user_456": {
        "name": "Sarah",
        "streak": 3,
        "gems": 20,
        "health_score": 72,
        "todays_workout": None,
        "daily_quests": [],
        "progress": {
            "photos": [],
            "hydration": {"current": 500, "target": 2000},
            "weekly_history": [1200, 1400, 1100, 1300, 1250, 1400, 1350],
            "macros": {
                "calories": {"current": 1200, "target": 1800},
                "protein": {"current": 80, "target": 140},
                "carbs": {"current": 120, "target": 180},
                "fat": {"current": 40, "target": 60}
            },
            "diet_log": {}
        },
        "calendar": {
            "events": []
        }
    }
}

TRAINER_DATA = {
    "clients": [
        {"id": "user_123", "name": "Alex", "status": "On Track", "last_seen": "Today", "plan": "Hypertrophy"},
        {"id": "user_456", "name": "Sarah", "status": "At Risk", "last_seen": "5 days ago", "plan": "Weight Loss"},
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

EXERCISE_LIBRARY = [
    # --- CHEST ---
    {"id": "ex_1", "name": "Barbell Bench Press", "muscle": "Chest", "type": "Compound", "video_id": "BenchPress"},
    {"id": "ex_2", "name": "Incline Dumbbell Press", "muscle": "Chest", "type": "Compound", "video_id": "InclineDBPress"},
    {"id": "ex_3", "name": "Cable Crossover", "muscle": "Chest", "type": "Isolation", "video_id": "CableCrossover"},
    {"id": "ex_4", "name": "Machine Chest Fly", "muscle": "Chest", "type": "Isolation", "video_id": "MachineFly"},
    {"id": "ex_5", "name": "Dips", "muscle": "Chest", "type": "Compound", "video_id": "Dips"},
    {"id": "ex_6", "name": "Decline Bench Press", "muscle": "Chest", "type": "Compound", "video_id": "DeclineBench"},
    {"id": "ex_7", "name": "Push-Ups", "muscle": "Chest", "type": "Bodyweight", "video_id": "PushUps"},
    {"id": "ex_8", "name": "Dumbbell Pullover", "muscle": "Chest", "type": "Isolation", "video_id": "DBPullover"},
    {"id": "ex_9", "name": "Smith Machine Bench Press", "muscle": "Chest", "type": "Compound", "video_id": "SmithBench"},
    {"id": "ex_10", "name": "Pec Deck Fly", "muscle": "Chest", "type": "Isolation", "video_id": "PecDeck"},

    # --- BACK ---
    {"id": "ex_11", "name": "Deadlift", "muscle": "Back", "type": "Compound", "video_id": "Deadlift"},
    {"id": "ex_12", "name": "Pull-Up", "muscle": "Back", "type": "Bodyweight", "video_id": "PullUp"},
    {"id": "ex_13", "name": "Barbell Row", "muscle": "Back", "type": "Compound", "video_id": "BarbellRow"},
    {"id": "ex_14", "name": "Lat Pulldown", "muscle": "Back", "type": "Compound", "video_id": "LatPulldown"},
    {"id": "ex_15", "name": "Seated Cable Row", "muscle": "Back", "type": "Compound", "video_id": "SeatedRow"},
    {"id": "ex_16", "name": "Single-Arm Dumbbell Row", "muscle": "Back", "type": "Isolation", "video_id": "DBRow"},
    {"id": "ex_17", "name": "T-Bar Row", "muscle": "Back", "type": "Compound", "video_id": "TBarRow"},
    {"id": "ex_18", "name": "Face Pull", "muscle": "Back", "type": "Isolation", "video_id": "FacePull"},
    {"id": "ex_19", "name": "Hyperextension", "muscle": "Back", "type": "Isolation", "video_id": "Hyperextension"},
    {"id": "ex_20", "name": "Straight-Arm Pulldown", "muscle": "Back", "type": "Isolation", "video_id": "StraightArmPulldown"},

    # --- SHOULDERS ---
    {"id": "ex_21", "name": "Overhead Press", "muscle": "Shoulders", "type": "Compound", "video_id": "OHP"},
    {"id": "ex_22", "name": "Seated Dumbbell Press", "muscle": "Shoulders", "type": "Compound", "video_id": "SeatedDBPress"},
    {"id": "ex_23", "name": "Dumbbell Lateral Raise", "muscle": "Shoulders", "type": "Isolation", "video_id": "LateralRaise"},
    {"id": "ex_24", "name": "Front Raise", "muscle": "Shoulders", "type": "Isolation", "video_id": "FrontRaise"},
    {"id": "ex_25", "name": "Reverse Pec Deck", "muscle": "Shoulders", "type": "Isolation", "video_id": "ReversePecDeck"},
    {"id": "ex_26", "name": "Arnold Press", "muscle": "Shoulders", "type": "Compound", "video_id": "ArnoldPress"},
    {"id": "ex_27", "name": "Upright Row", "muscle": "Shoulders", "type": "Compound", "video_id": "UprightRow"},
    {"id": "ex_28", "name": "Cable Lateral Raise", "muscle": "Shoulders", "type": "Isolation", "video_id": "CableLateral"},

    # --- LEGS ---
    {"id": "ex_29", "name": "Barbell Squat", "muscle": "Legs", "type": "Compound", "video_id": "Squats"},
    {"id": "ex_30", "name": "Leg Press", "muscle": "Legs", "type": "Compound", "video_id": "LegPress"},
    {"id": "ex_31", "name": "Romanian Deadlift", "muscle": "Legs", "type": "Compound", "video_id": "RDL"},
    {"id": "ex_32", "name": "Leg Extension", "muscle": "Legs", "type": "Isolation", "video_id": "LegExtension"},
    {"id": "ex_33", "name": "Seated Leg Curl", "muscle": "Legs", "type": "Isolation", "video_id": "LegCurls"},
    {"id": "ex_34", "name": "Walking Lunge", "muscle": "Legs", "type": "Compound", "video_id": "Lunges"},
    {"id": "ex_35", "name": "Bulgarian Split Squat", "muscle": "Legs", "type": "Compound", "video_id": "SplitSquat"},
    {"id": "ex_36", "name": "Calf Raise", "muscle": "Legs", "type": "Isolation", "video_id": "CalfRaise"},
    {"id": "ex_37", "name": "Hack Squat", "muscle": "Legs", "type": "Compound", "video_id": "HackSquat"},
    {"id": "ex_38", "name": "Goblet Squat", "muscle": "Legs", "type": "Compound", "video_id": "GobletSquat"},

    # --- ARMS ---
    {"id": "ex_39", "name": "Barbell Curl", "muscle": "Biceps", "type": "Isolation", "video_id": "BarbellCurl"},
    {"id": "ex_40", "name": "Dumbbell Hammer Curl", "muscle": "Biceps", "type": "Isolation", "video_id": "HammerCurl"},
    {"id": "ex_41", "name": "Preacher Curl", "muscle": "Biceps", "type": "Isolation", "video_id": "PreacherCurl"},
    {"id": "ex_42", "name": "Tricep Rope Pushdown", "muscle": "Triceps", "type": "Isolation", "video_id": "TricepPushdown"},
    {"id": "ex_43", "name": "Skullcrusher", "muscle": "Triceps", "type": "Isolation", "video_id": "Skullcrusher"},
    {"id": "ex_44", "name": "Overhead Tricep Extension", "muscle": "Triceps", "type": "Isolation", "video_id": "OverheadExt"},
    {"id": "ex_45", "name": "Concentration Curl", "muscle": "Biceps", "type": "Isolation", "video_id": "ConcentrationCurl"},

    # --- ABS & CARDIO ---
    {"id": "ex_46", "name": "Plank", "muscle": "Abs", "type": "Isometric", "video_id": "Plank"},
    {"id": "ex_47", "name": "Hanging Leg Raise", "muscle": "Abs", "type": "Isolation", "video_id": "LegRaise"},
    {"id": "ex_48", "name": "Cable Crunch", "muscle": "Abs", "type": "Isolation", "video_id": "CableCrunch"},
    {"id": "ex_49", "name": "Russian Twist", "muscle": "Abs", "type": "Isolation", "video_id": "RussianTwist"},
    {"id": "ex_50", "name": "HIIT Sprint", "muscle": "Cardio", "type": "Cardio", "video_id": "Sprint"},
]
