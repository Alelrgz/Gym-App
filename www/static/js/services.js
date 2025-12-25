// Mock Data Ported from data.py/services.py

const GYM_CONFIG = {
    "iron_gym": {
        "id": "iron_gym",
        "name": "Iron Gym",
        "logo_text": "IRON GYM",
        "primary_color": "#ef4444", // red-500
        "secondary_color": "#1f2937"
    },
    "zen_yoga": {
        "id": "zen_yoga",
        "name": "Zen Yoga Studio",
        "logo_text": "ZEN YOGA",
        "primary_color": "#8b5cf6", // violet-500
        "secondary_color": "#f3f4f6"
    }
};

const CLIENT_DATA = {
    "user_123": {
        "id": "user_123",
        "name": "Alex",
        "role": "client",
        "gems": 1250,
        "streak": 12,
        "health_score": 92,
        "todays_workout": {
            "title": "Push Day: Chest & Tris",
            "duration": "45 min",
            "difficulty": "Intermediate",
            "exercises": [
                { "name": "Incline DB Press", "sets": 4, "reps": "8-10", "rest": 90, "video_id": "InclineDBPress" },
                { "name": "Lateral Raises", "sets": 3, "reps": "12-15", "rest": 60, "video_id": "LateralRaises" },
                { "name": "Tricep Pushdowns", "sets": 3, "reps": "10-12", "rest": 60, "video_id": "TricepPushdowns" }
            ]
        },
        "progress": {
            "hydration": { "current": 1250, "target": 2500 },
            "macros": {
                "calories": { "current": 1800, "target": 2500 },
                "protein": { "current": 140, "target": 180 },
                "carbs": { "current": 200, "target": 250 },
                "fat": { "current": 60, "target": 80 }
            },
            "weekly_consistency": [
                { "day": "M", "score": 100, "active": true },
                { "day": "T", "score": 80, "active": true },
                { "day": "W", "score": 0, "active": false },
                { "day": "T", "score": 90, "active": true },
                { "day": "F", "score": 100, "active": true },
                { "day": "S", "score": 40, "active": false },
                { "day": "S", "score": 0, "active": false }
            ]
        }
    }
};

const TRAINER_DATA = {
    "id": "trainer_456",
    "name": "Coach Mike",
    "clients": [
        { "id": "c1", "name": "Sarah Connor", "plan": "Fat Loss", "status": "On Track", "last_active": "2h ago" },
        { "id": "c2", "name": "John Wick", "plan": "Strength", "status": "At Risk", "last_active": "3d ago" },
        { "id": "c3", "name": "Bruce Wayne", "plan": "Hypertrophy", "status": "On Track", "last_active": "5m ago" }
    ]
};

const OWNER_DATA = {
    "id": "owner_789",
    "gym_name": "Iron Gym HQ",
    "revenue_today": "$1,250",
    "active_members": 42,
    "staff_active": 4,
    "recent_activity": [
        { "time": "10:00 AM", "text": "New membership signup", "type": "money" },
        { "time": "09:45 AM", "text": "Mike clocked in", "type": "staff" },
        { "time": "09:30 AM", "text": "Pro Shop sale: Protein", "type": "money" }
    ]
};

const LEADERBOARD_DATA = {
    "weekly_challenge": {
        "title": "1000 Pushup Challenge",
        "description": "Complete 1000 pushups this week",
        "target": 1000,
        "progress": 750,
        "reward_gems": 500
    },
    "users": [
        { "rank": 1, "name": "TheRock", "gems": 5000, "streak": 45, "health_score": 98 },
        { "rank": 2, "name": "Alex", "gems": 1250, "streak": 12, "health_score": 92, "isCurrentUser": true },
        { "rank": 3, "name": "Arnold", "gems": 1200, "streak": 10, "health_score": 90 }
    ]
};

// Service Functions
export function getGymConfig(gymId) {
    return GYMS_DB[gymId] || GYMS_DB["iron_gym"];
}

export function getClientData() {
    return CLIENT_DATA["user_123"];
}

export function getTrainerData() {
    return TRAINER_DATA;
}

export function getOwnerData() {
    return OWNER_DATA;
}

export function getLeaderboardData() {
    return LEADERBOARD_DATA;
}

export function assignWorkout(clientName, workoutType) {
    const client = CLIENT_DATA["user_123"];

    let newWorkout = {
        "title": `Coach Assigned: ${workoutType}`,
        "duration": "60 min",
        "difficulty": "Hard",
        "exercises": []
    };

    if (workoutType === "Push") {
        newWorkout.exercises = [
            { "name": "Incline DB Press", "sets": 4, "reps": "8-10", "rest": 90, "video_id": "InclineDBPress" },
            { "name": "Seated Shoulder Press", "sets": 4, "reps": "8-10", "rest": 90, "video_id": "SeatedShoulderPress" },
            { "name": "Machine Chest Fly", "sets": 3, "reps": "10-12", "rest": 60, "video_id": "MachineFly" },
            { "name": "Tricep Rope Pushdown", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown" }
        ];
    } else if (workoutType === "Pull") {
        newWorkout.exercises = [
            { "name": "Lat Pulldown", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown" },
            { "name": "Cable Row", "sets": 4, "reps": "10-12", "rest": 60, "video_id": "TricepPushdown" }
        ];
    } else if (workoutType === "Legs") {
        newWorkout.exercises = [
            { "name": "Squat", "sets": 4, "reps": "5-8", "rest": 120, "video_id": "InclineDBPress" },
            { "name": "Leg Extension", "sets": 3, "reps": "12-15", "rest": 60, "video_id": "InclineDBPress" }
        ];
    } else if (workoutType === "Cardio") {
        newWorkout.exercises = [
            { "name": "Treadmill Run", "sets": 1, "reps": "30 min", "rest": 0, "video_id": "InclineDBPress" }
        ];
    }

    client.todays_workout = newWorkout;
    return { "status": "success", "message": `Assigned ${workoutType} to ${clientName}` };
}
