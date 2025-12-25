const { gymId, role } = window.APP_CONFIG;
let workoutState = null;

async function init() {
    const gymRes = await fetch(`/api/config/${gymId}`);
    const gymConfig = await gymRes.json();
    document.documentElement.style.setProperty('--primary', gymConfig.primary_color);
    const nameEls = document.querySelectorAll('#gym-name, #gym-name-owner');
    nameEls.forEach(el => el.innerText = gymConfig.logo_text);

    if (role === 'client') {
        const userRes = await fetch('/api/client/data');
        const user = await userRes.json();

        const setTxt = (id, val) => { if (document.getElementById(id)) document.getElementById(id).innerText = val; };
        setTxt('streak-count', user.streak);
        setTxt('gem-count', user.gems);
        setTxt('workout-title', user.todays_workout.title);
        setTxt('workout-duration', user.todays_workout.duration);
        setTxt('workout-difficulty', user.todays_workout.difficulty);
        setTxt('health-score', user.health_score);

        const questList = document.getElementById('quest-list');
        if (questList) {
            user.daily_quests.forEach(quest => {
                const div = document.createElement('div');
                div.className = "glass-card p-4 flex justify-between items-center tap-effect";
                div.onclick = function () { toggleQuest(this); };
                if (quest.completed) div.style.borderColor = "rgba(255, 255, 0, 0.3)";
                div.innerHTML = `<div class="flex items-center"><div class="w-5 h-5 rounded-full border border-white/20 mr-3 flex items-center justify-center ${quest.completed ? 'bg-yellow-400 text-black border-none' : ''}">${quest.completed ? '✓' : ''}</div><span class="text-sm font-medium text-gray-200">${quest.text}</span></div><span class="text-xs font-bold text-yellow-500">+${quest.xp}</span>`;
                questList.appendChild(div);
            });
        }

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

            // Weekly History
            const chart = document.getElementById('weekly-chart');
            if (chart && user.progress.weekly_history) {
                user.progress.weekly_history.forEach(val => {
                    const h = Math.min((val / 2500) * 100, 100);
                    const bar = document.createElement('div');
                    bar.className = "w-full bg-white/20 rounded-t-sm hover:bg-white/40 transition";
                    bar.style.height = `${h}%`;
                    chart.appendChild(bar);
                });
            }

            // Macros
            const m = user.progress.macros;
            if (m && document.getElementById('cals-remaining')) {
                document.getElementById('cals-remaining').innerText = `${m.calories.target - m.calories.current} kcal left`;

                const updateRing = (id, cur, max, color) => {
                    const pct = (cur / max) * 100;
                    const el = document.getElementById(id);
                    if (el) {
                        el.style.background = `conic-gradient(${color} ${pct}%, #333 0%)`;
                        document.getElementById('val-' + id.split('-')[1]).innerText = `${cur}g`;
                    }
                };
                updateRing('ring-protein', m.protein.current, m.protein.target, '#4ADE80');
                updateRing('ring-carbs', m.carbs.current, m.carbs.target, '#60A5FA');
                updateRing('ring-fat', m.fat.current, m.fat.target, '#F472B6');
            }

            // Grouped Diet Log
            const dietContainer = document.getElementById('diet-log-container');
            if (dietContainer && user.progress.diet_log) {
                for (const [group, items] of Object.entries(user.progress.diet_log)) {
                    const groupDiv = document.createElement('div');
                    groupDiv.innerHTML = `<h3 class="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2 ml-1">${group}</h3>`;
                    const listDiv = document.createElement('div');
                    listDiv.className = "space-y-2";
                    items.forEach(item => {
                        const div = document.createElement('div');
                        div.className = "glass-card p-3 flex justify-between items-center";
                        div.innerHTML = `<div><p class="text-sm font-bold text-white">${item.meal}</p><p class="text-[10px] text-gray-400">${item.time}</p></div><span class="text-xs font-mono text-green-400">${item.cals}</span>`;
                        listDiv.appendChild(div);
                    });
                    groupDiv.appendChild(listDiv);
                    dietContainer.appendChild(groupDiv);
                }
            }

            // Photos
            const photoGallery = document.getElementById('photo-gallery');
            if (photoGallery) {
                user.progress.photos.forEach(url => {
                    const img = document.createElement('img');
                    img.src = url;
                    img.className = "w-24 h-32 object-cover rounded-xl border border-white/10 flex-shrink-0";
                    photoGallery.appendChild(img);
                });
            }
        }
    }

    if (role === 'trainer') {
        const trainerRes = await fetch('/api/trainer/data');
        const data = await trainerRes.json();

        const list = document.getElementById('client-list');
        if (list) {
            data.clients.forEach(c => {
                const div = document.createElement('div');
                div.className = "glass-card p-4 flex justify-between items-center tap-effect";
                div.onclick = function () { showClientModal(c.name, c.plan, c.status); };
                const statusColor = c.status === 'At Risk' ? 'text-red-400' : 'text-green-400';
                div.innerHTML = `<div class="flex items-center"><div class="w-10 h-10 rounded-full bg-white/10 mr-3 overflow-hidden"><img src="https://api.dicebear.com/7.x/avataaars/svg?seed=${c.name}" /></div><div><p class="font-bold text-sm text-white">${c.name}</p><p class="text-[10px] text-gray-400">${c.plan} • Seen ${c.last_seen}</p></div></div><span class="text-xs font-bold ${statusColor}">${c.status}</span>`;
                list.appendChild(div);
            });
        }

        const vidLib = document.getElementById('video-library');
        if (vidLib && data.video_library) {
            data.video_library.forEach(v => {
                const div = document.createElement('div');
                div.className = "glass-card p-0 overflow-hidden relative group tap-effect";
                div.innerHTML = `<img src="${v.thumb}" class="w-full h-24 object-cover opacity-60 group-hover:opacity-100 transition"><div class="absolute bottom-0 w-full p-2 bg-gradient-to-t from-black to-transparent"><p class="text-[10px] font-bold text-white truncate">${v.title}</p><p class="text-[8px] text-gray-400 uppercase">${v.type}</p></div>`;
                vidLib.appendChild(div);
            });
        }
    }

    if (role === 'owner') {
        const ownerRes = await fetch('/api/owner/data');
        const data = await ownerRes.json();
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

    // Leaderboard Mode
    const leaderboardRes = await fetch('/api/leaderboard/data');
    const leaderboard = await leaderboardRes.json();

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

            const getRankEmoji = (rank) => {
                if (rank === 1) return '🥇';
                if (rank === 2) return '🥈';
                if (rank === 3) return '🥉';
                return `#${rank}`;
            };

            div.innerHTML = `
                <div class="flex items-center space-x-3">
                    <span class="text-2xl font-black w-10">${getRankEmoji(u.rank)}</span>
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
}

// MODAL SYSTEM
function showModal(id) {
    document.getElementById(id).classList.remove('hidden');
}

function hideModal(id) {
    document.getElementById(id).classList.add('hidden');
}

function toggleQuest(el) {
    const check = el.querySelector('.rounded-full');
    const isComplete = check.classList.contains('bg-yellow-400');

    if (!isComplete) {
        check.classList.add('bg-yellow-400', 'text-black', 'border-none');
        check.innerText = '✓';
        el.style.borderColor = "rgba(255, 255, 0, 0.3)";

        // Celebration
        const reward = el.querySelector('.text-yellow-500').innerText;
        showToast(`Quest Complete! ${reward} 💎`);

        // Update gems (mock)
        const gemEl = document.getElementById('gem-count');
        if (gemEl) {
            let gems = parseInt(gemEl.innerText);
            gemEl.innerText = gems + parseInt(reward.replace('+', ''));
        }
    }
}

function addWater() {
    const el = document.getElementById('hydro-val');
    const wave = document.getElementById('hydro-wave');
    if (el && wave) {
        let cur = parseInt(el.innerText);
        cur += 250;
        el.innerText = cur + 'ml';
        // Mock target 2500
        const pct = 100 - ((cur / 2500) * 100);
        wave.style.top = Math.max(0, pct) + '%';
        showToast('Hydration recorded! 💧');
    }
}

function showClientModal(name, plan, status) {
    document.getElementById('modal-client-name').innerText = name;
    document.getElementById('modal-client-plan').innerText = plan;
    document.getElementById('modal-client-status').innerText = status;
    document.getElementById('modal-client-status').className = `text-lg font-bold ${status === 'At Risk' ? 'text-red-400' : 'text-green-400'}`;
    showModal('client-modal');
}

// Quick Actions
function quickAction(action) {
    if (action === 'scan') {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.onchange = e => {
            showToast('Analyzing meal... 🍎');
            setTimeout(() => showToast('Logged: Avocado Toast (350 kcal)'), 1500);
        };
        input.click();
    } else if (action === 'search') {
        const food = prompt("Search for food:");
        if (food) showToast(`Found: ${food} (Loading details...)`);
    } else if (action === 'copy') {
        showToast('Copied yesterday\'s meals 📋');
    }
}

// Physique Photos
function addPhoto() {
    const url = prompt("Enter photo URL:");
    if (url) {
        const gallery = document.getElementById('photo-gallery');
        const img = document.createElement('img');
        img.src = url;
        img.className = "w-24 h-32 object-cover rounded-xl border border-white/10 flex-shrink-0 slide-up";
        gallery.prepend(img);
        showToast('Physique update saved! 📸');
    }
}

// Toast Notification System
function showToast(msg) {
    let toast = document.getElementById('toast');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'toast';
        toast.className = "fixed bottom-24 left-1/2 transform -translate-x-1/2 bg-white text-black px-6 py-3 rounded-full font-bold shadow-2xl z-50 transition-all duration-300 opacity-0 translate-y-10";
        document.body.appendChild(toast);
    }
    toast.innerText = msg;
    toast.classList.remove('opacity-0', 'translate-y-10');
    setTimeout(() => {
        toast.classList.add('opacity-0', 'translate-y-10');
    }, 3000);
}


// --- TRAINER INTERACTIVITY ---
function uploadVideo() {
    const title = prompt("Video Title:");
    if (title) {
        const vidLib = document.getElementById('video-library');
        const div = document.createElement('div');
        div.className = "glass-card p-0 overflow-hidden relative group tap-effect slide-up";
        div.innerHTML = `<img src="https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=150&h=150&fit=crop" class="w-full h-24 object-cover opacity-60 group-hover:opacity-100 transition"><div class="absolute bottom-0 w-full p-2 bg-gradient-to-t from-black to-transparent"><p class="text-[10px] font-bold text-white truncate">${title}</p><p class="text-[8px] text-gray-400 uppercase">Custom</p></div>`;
        vidLib.prepend(div);
        showToast('Video uploaded successfully! 🎥');
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
    showRestTimer(ex.rest || 60, () => {
        // Move to next set
        if (workoutState.currentSet < ex.sets) {
            workoutState.currentSet++;
            // Parse reps if it's a range like "8-10"
            let targetReps = ex.reps;
            if (typeof ex.reps === 'string' && ex.reps.includes('-')) {
                targetReps = ex.reps.split('-')[1]; // Take upper bound
            }
            workoutState.currentReps = targetReps;
            updateWorkoutUI();
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
                workoutState.currentReps = nextReps;
                updateWorkoutUI();
            } else {
                // Workout complete!
                document.getElementById('celebration-overlay').classList.remove('hidden');
                startConfetti();
            }
        }
    });
}

function showRestTimer(seconds, callback) {
    const overlay = document.createElement('div');
    overlay.className = "absolute inset-0 bg-black/95 z-50 flex flex-col items-center justify-center";
    overlay.innerHTML = `
        <div class="text-center slide-up">
            <p class="text-sm text-gray-400 uppercase tracking-wider mb-2">Rest Period</p>
            <h1 class="text-8xl font-black text-white mb-8" id="rest-countdown">${seconds}</h1>
            <button id="skip-rest" class="px-8 py-3 bg-white/10 rounded-full font-bold text-white hover:bg-white/20 transition">SKIP</button>
        </div>
    `;
    document.body.appendChild(overlay);

    let remaining = seconds;
    const interval = setInterval(() => {
        remaining--;
        const el = document.getElementById('rest-countdown');
        if (el) el.innerText = remaining;

        if (remaining <= 0) {
            clearInterval(interval);
            if (overlay.parentNode) overlay.remove();
            if (callback) callback();
        }
    }, 1000);

    document.getElementById('skip-rest').onclick = () => {
        clearInterval(interval);
        if (overlay.parentNode) overlay.remove();
        if (callback) callback();
    };
}

// Initialize workout state when in workout mode
if (document.getElementById('workout-screen')) {
    fetch('/api/client/data')
        .then(res => res.json())
        .then(user => {
            const workout = user.todays_workout;
            workoutState = {
                exercises: workout.exercises,
                currentExerciseIdx: 0,
                currentSet: 1,
                currentReps: parseInt(workout.exercises[0].reps.split('-')[1] || workout.exercises[0].reps)
            };
            updateWorkoutUI();
        });
}

init();

// Missing Functions (updateWorkoutUI, startConfetti)
// I need to make sure these are included.
// Wait, I missed copying updateWorkoutUI and startConfetti from the original templates.py!
// I should check templates.py again to make sure I have ALL functions.

function updateWorkoutUI() {
    if (!workoutState) return;

    const ex = workoutState.exercises[workoutState.currentExerciseIdx];

    // Update Text
    document.getElementById('exercise-name').innerText = ex.name;
    document.getElementById('exercise-target').innerText = `Set ${workoutState.currentSet} of ${ex.sets} • Target: ${ex.reps} Reps`;
    document.getElementById('rep-counter').innerText = workoutState.currentReps;

    // Update Progress Bar
    const totalSets = workoutState.exercises.reduce((acc, curr) => acc + curr.sets, 0);
    let completedSets = 0;
    for (let i = 0; i < workoutState.currentExerciseIdx; i++) {
        completedSets += workoutState.exercises[i].sets;
    }
    completedSets += (workoutState.currentSet - 1);
    const progressPct = (completedSets / totalSets) * 100;
    document.getElementById('workout-progress-bar').style.width = `${progressPct}%`;
    document.getElementById('workout-progress-text').innerText = `Exercise ${workoutState.currentExerciseIdx + 1} of ${workoutState.exercises.length}`;
    document.getElementById('set-progress-text').innerText = `Set ${workoutState.currentSet} of ${ex.sets}`;

    // Update Video
    const videoEl = document.getElementById('exercise-video');
    const newSrc = `/static/videos/${ex.video_id}.mp4?v=1`;

    if (!videoEl.src.includes(newSrc)) {
        videoEl.src = newSrc;
        videoEl.load();
        const playPromise = videoEl.play();
        if (playPromise !== undefined) {
            playPromise.catch(error => {
                console.log("Autoplay prevented:", error);
                videoEl.muted = true;
                videoEl.play();
            });
        }
    }
}

function startConfetti() {
    const container = document.getElementById('confetti-container');
    const colors = ['#f00', '#0f0', '#00f', '#ff0', '#0ff', '#f0f'];

    for (let i = 0; i < 100; i++) {
        const conf = document.createElement('div');
        conf.className = 'confetti';
        conf.style.left = Math.random() * 100 + '%';
        conf.style.animationDuration = (Math.random() * 3 + 2) + 's';
        conf.style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];
        container.appendChild(conf);
    }
}
