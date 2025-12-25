import * as Services from './services.js';

export async function fetchGymConfig(gymId) {
    return Services.getGymConfig(gymId);
}

export async function fetchClientData() {
    return Services.getClientData();
}

export async function fetchTrainerData() {
    return Services.getTrainerData();
}

export async function fetchOwnerData() {
    return Services.getOwnerData();
}

export async function fetchLeaderboardData() {
    return Services.getLeaderboardData();
}

export async function assignWorkout(clientName, workoutType) {
    return Services.assignWorkout(clientName, workoutType);
}
