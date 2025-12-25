
import * as API from './api.js';
import * as UI from './ui.js';
import * as Utils from './utils.js';

// Expose Utils to window for inline event handlers (legacy support if any remain)
Object.assign(window, Utils);

// Workout State Management
let workoutState = null;

// Event Delegation
document.addEventListener('click', (e) => {
    const target = e.target.closest('[data-action]');
    if (!target) return;

    const action = target.dataset.action;

    // Modal Actions
    if (action === 'showModal') {
        Utils.showModal(target.dataset.target);
    } else if (action === 'hideModal') {
        // Only hide if clicking the backdrop or the close button
        if (e.target === target || target.tagName === 'BUTTON') {
            Utils.hideModal(target.dataset.target);
        }
    } else if (action === 'showToast') {
        Utils.showToast(target.dataset.message);
    }

    // Workout Actions
    else if (action === 'adjustReps') {
        adjustReps(parseInt(target.dataset.delta));
    } else if (action === 'completeSet') {
        completeSet();
    } else if (action === 'jumpToExercise') {
        jumpToExercise(parseInt(target.dataset.idx));
    }

    // Client Actions
    else if (action === 'quickAction') {
        Utils.quickAction(target.dataset.type);
    } else if (action === 'addWater') {
        Utils.addWater();
    } else if (action === 'addPhoto') {
        Utils.addPhoto();
    }

    // Trainer Actions
    else if (action === 'uploadVideo') {
        uploadVideo();
    } else if (action === 'assignWorkout') {
        handleAssignWorkout(target.dataset.client);
    }
});

// Internal Functions
function uploadVideo() {
    const title = prompt("Video Title:");
    if (title) {
        const vidLib = document.getElementById('video-library');
        const div = document.createElement('div');
        div.className = "glass-card p-0 overflow-hidden relative group tap-effect slide-up";
        div.innerHTML = `<img src="https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=150&h=150&fit=crop" class="w-full h-24 object-cover opacity-60 group-hover:opacity-100 transition"><div class="absolute bottom-0 w-full p-2 bg-gradient-to-t from-black to-transparent"><p class="text-[10px] font-bold text-white truncate">${title}</p><p class="text-[8px] text-gray-400 uppercase">Custom</p></div>`;
        vidLib.prepend(div);
        Utils.showToast('Video uploaded successfully! 🎥');
    }
}

function adjustReps(delta) {
    if (!workoutState) return;
    workoutState.currentReps = Math.max(0, workoutState.currentReps + delta);
    document.getElementById('rep-counter').innerText = workoutState.currentReps;
}

function completeSet() {
    if (!workoutState) return;

    const ex = workoutState.exercises[workoutState.currentExerciseIdx];

    // Show Rest Timer
    UI.showRestTimer(ex.rest || 60, () => {
        // Move to next set
        if (workoutState.currentSet < ex.sets) {
            workoutState.currentSet++;
            // Parse reps if it's a range like "8-10"
            let targetReps = ex.reps;
            if (typeof ex.reps === 'string' && ex.reps.includes('-')) {
                targetReps = ex.reps.split('-')[1]; // Take upper bound
            }
            workoutState.currentReps = parseInt(targetReps);
            UI.updateWorkoutUI(workoutState);
        } else {
            // Move to next exercise
            if (workoutState.currentExerciseIdx < workoutState.exercises.length - 1) {
                workoutState.currentExerciseIdx++;
                workoutState.currentSet = 1;
                const nextEx = workoutState.exercises[workoutState.currentExerciseIdx];
                let nextReps = nextEx.reps;
                if (typeof nextEx.reps === 'string' && nextEx.reps.includes('-')) {
                    nextReps = nextEx.reps.split('-')[1];
                }
                workoutState.currentReps = parseInt(nextReps);
                UI.updateWorkoutUI(workoutState);
            } else {
                // Workout complete!
                document.getElementById('celebration-overlay').classList.remove('hidden');
                Utils.startConfetti();
            }
        }
    });
}

function jumpToExercise(idx) {
    if (!workoutState) return;
    if (idx < 0 || idx >= workoutState.exercises.length) return;

    workoutState.currentExerciseIdx = idx;
    workoutState.currentSet = 1;

    const ex = workoutState.exercises[idx];
    let targetReps = ex.reps;
    if (typeof ex.reps === 'string' && ex.reps.includes('-')) {
        targetReps = ex.reps.split('-')[1];
    }
    workoutState.currentReps = parseInt(targetReps);

    UI.updateWorkoutUI(workoutState);
}

async function handleAssignWorkout(clientName) {
    const select = document.getElementById('workout-select');
    if (!select) return;

    const type = select.value;
    Utils.showToast(`Assigning ${type}... ⏳`);
    try {
        await API.assignWorkout(clientName, type);
        Utils.showToast(`Assigned ${type} to ${clientName}! ✅`);
        setTimeout(() => Utils.hideModal('client-modal'), 1000);
    } catch (e) {
        Utils.showToast('Error assigning workout ❌');
        console.error(e);
    }
}

async function init() {
    const { gymId, role } = window.APP_CONFIG;

    const gymConfig = await API.fetchGymConfig(gymId);
    document.documentElement.style.setProperty('--primary', gymConfig.primary_color);
    const nameEls = document.querySelectorAll('#gym-name, #gym-name-owner');
    nameEls.forEach(el => el.innerText = gymConfig.logo_text);

    if (role === 'client') {
        const user = await API.fetchClientData();
        UI.renderClientDashboard(user);

        // Progress Mode Logic
        if (user.progress) {
            // Hydration
            if (document.getElementById('hydro-val')) {
                const cur = user.progress.hydration.current;
                const max = user.progress.hydration.target;
                document.getElementById('hydro-val').innerText = `${cur}ml`;
                const pct = 100 - ((cur / max) * 100);
                document.getElementById('hydro-wave').style.top = `${pct}%`;
            }

            // Macros
            if (document.getElementById('val-protein')) {
                const macros = user.progress.macros;
                const setMacro = (type, val, max, color) => {
                    document.getElementById(`val-${type}`).innerText = `${val}g`;
                    const pct = (val / max) * 100;
                    document.getElementById(`ring-${type}`).style.background = `conic-gradient(${color} ${pct}%, #333 ${pct}%)`;
                };
                setMacro('protein', macros.protein.current, macros.protein.target, '#4ADE80');
                setMacro('carbs', macros.carbs.current, macros.carbs.target, '#60A5FA');
                setMacro('fat', macros.fat.current, macros.fat.target, '#F472B6');
                document.getElementById('cals-remaining').innerText = `${macros.calories.target - macros.calories.current} kcal left`;
            }

            // Weekly Chart
            const chart = document.getElementById('weekly-chart');
            if (chart && user.progress.weekly_consistency) {
                chart.innerHTML = '';
                user.progress.weekly_consistency.forEach(day => {
                    const h = Math.max(10, (day.score / 100) * 100);
                    const bar = document.createElement('div');
                    bar.className = "flex-1 bg-white/10 rounded-t-sm mx-0.5 relative group";
                    bar.style.height = `${h}%`;
                    if (day.active) bar.className += " bg-primary";
                    bar.innerHTML = `<div class="absolute -top-6 left-1/2 transform -translate-x-1/2 text-[8px] text-white opacity-0 group-hover:opacity-100 transition">${day.day}</div>`;
                    chart.appendChild(bar);
                });
            }

            // Diet Log (Mock)
            const dietLog = document.getElementById('diet-log-container');
            if (dietLog) {
                dietLog.innerHTML = `
                    <div class="glass-card p-3 flex justify-between items-center">
                        <div><p class="text-xs text-gray-400 uppercase">Breakfast</p><p class="text-sm font-bold text-white">Oatmeal & Berries</p></div>
                        <span class="text-xs font-bold text-green-400">350 kcal</span>
                    </div>
                    <div class="glass-card p-3 flex justify-between items-center">
                        <div><p class="text-xs text-gray-400 uppercase">Lunch</p><p class="text-sm font-bold text-white">Chicken Salad</p></div>
                        <span class="text-xs font-bold text-green-400">450 kcal</span>
                    </div>
                 `;
            }
        }
    }

    if (role === 'trainer') {
        const data = await API.fetchTrainerData();
        UI.renderTrainerDashboard(data);
    }

    if (role === 'owner') {
        const data = await API.fetchOwnerData();
        const setTxt = (id, val) => { if (document.getElementById(id)) document.getElementById(id).innerText = val; };
        setTxt('revenue-display', data.revenue_today);
        setTxt('active-members', data.active_members);
        setTxt('staff-active', data.staff_active);

        const feed = document.getElementById('activity-feed');
        if (feed) {
            data.recent_activity.forEach(item => {
                const div = document.createElement('div');
                div.className = "p-4 flex items-start";
                let icon = '🔹';
                if (item.type === 'money') icon = '💰';
                if (item.type === 'staff') icon = '👔';
                div.innerHTML = `<span class="mr-3 text-lg">${icon}</span><div><p class="text-sm font-medium text-gray-200">${item.text}</p><p class="text-[10px] text-gray-500">${item.time}</p></div>`;
                feed.appendChild(div);
            });
        }
    }

    // Leaderboard
    const leaderboard = await API.fetchLeaderboardData();
    if (document.getElementById('leaderboard-list')) {
        const setTxt = (id, val) => { if (document.getElementById(id)) document.getElementById(id).innerText = val; };
        setTxt('challenge-title', leaderboard.weekly_challenge.title);
        setTxt('challenge-desc', leaderboard.weekly_challenge.description);
        setTxt('challenge-progress', leaderboard.weekly_challenge.progress);
        setTxt('challenge-target', leaderboard.weekly_challenge.target);
        setTxt('challenge-reward', leaderboard.weekly_challenge.reward_gems);
        const challengePct = (leaderboard.weekly_challenge.progress / leaderboard.weekly_challenge.target) * 100;
        if (document.getElementById('challenge-bar')) {
            document.getElementById('challenge-bar').style.width = `${challengePct}%`;
        }

        const leaderList = document.getElementById('leaderboard-list');
        leaderboard.users.forEach((u, idx) => {
            const div = document.createElement('div');
            const isUser = u.isCurrentUser || false;
            div.className = `glass-card p-4 flex items-center justify-between tap-effect ${isUser ? 'border-2 border-primary bg-primary/10' : ''}`;
            div.innerHTML = `
                <div class="flex items-center space-x-3">
                    <span class="text-2xl font-black w-10">#${u.rank}</span>
                    <div class="w-10 h-10 rounded-full bg-white/10 overflow-hidden">
                        <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=${u.name}" />
                    </div>
                    <div>
                        <p class="font-bold text-sm text-white">${u.name}${isUser ? ' (You)' : ''}</p>
                        <p class="text-[10px] text-gray-400">${u.streak} day streak • ${u.health_score} health</p>
                    </div>
                </div>
                <div class="text-right">
                    <p class="text-yellow-400 font-bold">💎 ${u.gems}</p>
                </div>
            `;
            leaderList.appendChild(div);
        });
    }

    // Workout Mode Initialization
    if (document.getElementById('workout-screen')) {
        const user = await API.fetchClientData();
        const workout = user.todays_workout;
        workoutState = {
            exercises: workout.exercises,
            currentExerciseIdx: 0,
            currentSet: 1,
            currentReps: parseInt(workout.exercises[0].reps.split('-')[1] || workout.exercises[0].reps)
        };
        UI.updateWorkoutUI(workoutState);
    }
}

init();
