// Services - Now fetching from Backend API

export async function getGymConfig(gymId) {
    const res = await fetch(`/api/config/${gymId}`);
    if (!res.ok) throw new Error('Failed to fetch gym config');
    return await res.json();
}

export async function getClientData() {
    const res = await fetch('/api/client/data');
    if (!res.ok) throw new Error('Failed to fetch client data');
    return await res.json();
}

export async function getTrainerData() {
    const res = await fetch('/api/trainer/data');
    if (!res.ok) throw new Error('Failed to fetch trainer data');
    return await res.json();
}

export async function getOwnerData() {
    const res = await fetch('/api/owner/data');
    if (!res.ok) throw new Error('Failed to fetch owner data');
    return await res.json();
}

export async function getLeaderboardData() {
    const res = await fetch('/api/leaderboard/data');
    if (!res.ok) throw new Error('Failed to fetch leaderboard data');
    return await res.json();
}

export async function assignWorkout(clientName, workoutType) {
    const res = await fetch('/api/trainer/assign_workout', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            client_name: clientName,
            workout_type: workoutType
        })
    });
    if (!res.ok) throw new Error('Failed to assign workout');
    return await res.json();
}
