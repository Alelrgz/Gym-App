
import { showToast, startConfetti, showClientModal, toggleQuest } from './utils.js';

export function updateWorkoutUI(workoutState) {
    if (!workoutState) return;

    const ex = workoutState.exercises[workoutState.currentExerciseIdx];

    // Update Header & Counters
    document.getElementById('exercise-name').innerText = ex.name;
    document.getElementById('exercise-target').innerText = `Set ${workoutState.currentSet} of ${ex.sets} • Target: ${ex.reps} Reps`;
    document.getElementById('rep-counter').innerText = workoutState.currentReps;

    // Update Video
    const videoEl = document.getElementById('exercise-video');
    const repVideoEl = document.getElementById('rep-counter-video');
    let src = ex.video_id;
    if (!src.startsWith('http') && !src.startsWith('/')) {
        src = `/static/videos/${src}.mp4`;
    }
    const newSrc = `${src}?v=3`;

    if (!videoEl.src.includes(newSrc)) {
        // Update Main Video
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

        // Update Rep Counter Video (if exists)
        if (repVideoEl) {
            repVideoEl.src = newSrc;
            repVideoEl.load();
            repVideoEl.play().catch(e => console.log("Rep video autoplay prevented", e));
        }
    }

    // Render Routine List - Modern clean style
    const list = document.getElementById('workout-routine-list');
    if (list) {
        list.innerHTML = '';
        workoutState.exercises.forEach((item, idx) => {
            const div = document.createElement('div');
            const isCurrent = idx === workoutState.currentExerciseIdx;

            // Event Delegation Attributes
            div.dataset.action = 'jumpToExercise';
            div.dataset.idx = idx;

            div.className = `p-3 rounded-xl flex items-center mb-2 cursor-pointer transition-all ${isCurrent ? 'bg-white/5 border border-orange-500/30' : 'bg-white/[0.02] hover:bg-white/5 border border-white/5'} ${idx < workoutState.currentExerciseIdx ? 'opacity-60' : ''}`;

            let icon = `<div class="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-xs text-white/50 font-medium">${idx + 1}</div>`;
            if (isCurrent) icon = `<div class="w-8 h-8 rounded-lg bg-orange-500 flex items-center justify-center text-white">
                <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
            </div>`;
            if (idx < workoutState.currentExerciseIdx) icon = `<div class="w-8 h-8 rounded-lg bg-green-500/20 flex items-center justify-center text-green-500">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
            </div>`;

            div.innerHTML = `
                <div class="flex items-center gap-3 pointer-events-none w-full">
                    ${icon}
                    <div class="flex-1">
                        <h4 class="font-medium text-white ${isCurrent ? 'text-base' : 'text-sm'}">${item.name}</h4>
                        <p class="text-xs text-white/40">${item.sets} Sets &bull; ${item.reps} Reps</p>
                    </div>
                    ${isCurrent ? '<span class="text-[10px] font-medium text-orange-500 bg-orange-500/10 px-2 py-1 rounded-md border border-orange-500/20 uppercase tracking-wider">Attivo</span>' : ''}
                    ${idx < workoutState.currentExerciseIdx ? '<span class="text-[10px] text-green-500 font-medium uppercase tracking-wider">Fatto</span>' : ''}
                </div>
            `;

            // Scroll to active item
            if (isCurrent) {
                setTimeout(() => {
                    div.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }, 100);
            }

            list.appendChild(div);
        });
    }

    // Update Progress Text
    const totalExercises = workoutState.exercises.length;
    const completedExercises = workoutState.currentExerciseIdx;
    const progressPct = Math.round((completedExercises / totalExercises) * 100);
    const progressEl = document.getElementById('routine-progress');
    if (progressEl) progressEl.innerText = `${progressPct}% Completato`;
}

export function showRestTimer(seconds, callback) {
    const overlay = document.createElement('div');
    overlay.className = "absolute inset-0 bg-black/95 z-50 flex flex-col items-center justify-center";
    overlay.innerHTML = `
        <div class="text-center slide-up">
            <p class="text-sm text-gray-400 uppercase tracking-wider mb-2">Periodo di Riposo</p>
            <h1 class="text-8xl font-black text-white mb-8" id="rest-countdown">${seconds}</h1>
            <button id="skip-rest" class="px-8 py-3 bg-white/10 rounded-full font-bold text-white hover:bg-white/20 transition">SALTA</button>
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

export function renderClientDashboard(user) {
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
}

export function renderTrainerDashboard(data) {
    const list = document.getElementById('client-list');
    if (list) {
        data.clients.forEach(c => {
            const div = document.createElement('div');
            div.className = "glass-card p-4 flex justify-between items-center tap-effect";
            // Using data attributes for event delegation in main.js/utils.js would be better, 
            // but keeping onclick here for now as it calls a specific utility function.
            // Ideally, this should also be refactored to data-action="showClientModal"
            div.dataset.action = "showClientModal";
            div.dataset.name = c.name;
            div.dataset.plan = c.plan;
            div.dataset.status = c.status;

            // For now, we'll keep the onclick as a fallback or if event delegation isn't fully covering this dynamic list yet.
            // But wait, the plan was to remove global functions. showClientModal is imported from utils.js.
            // So we can attach it directly or use event delegation.
            // Let's use the event delegation pattern we set up in main.js if possible.
            // In main.js: if (action === 'showModal') ...
            // We need a specific handler for client modal which takes args.
            // Let's stick to the onclick for now but make it use the imported function, 
            // OR better, use the data attributes and let a delegate handle it.
            // However, main.js delegate for 'showModal' only takes target ID.
            // Let's use a direct click listener here to avoid global scope issues.
            div.onclick = () => showClientModal(c.name, c.plan, c.status);

            const statusColor = c.status === 'At Risk' ? 'text-red-400' : 'text-green-400';
            const avatarUrl = c.profile_picture || `https://api.dicebear.com/7.x/avataaars/svg?seed=${c.name}`;
            div.innerHTML = `<div class="flex items-center pointer-events-none"><div class="w-10 h-10 rounded-full bg-white/10 mr-3 overflow-hidden"><img src="${avatarUrl}" class="w-full h-full object-cover" /></div><div><p class="font-bold text-sm text-white">${c.name}</p><p class="text-[10px] text-gray-400">${c.plan} • Seen ${c.last_seen}</p></div></div><span class="text-xs font-bold ${statusColor} pointer-events-none">${c.status}</span>`;
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
