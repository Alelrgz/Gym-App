const { gymId, role, apiBase } = window.APP_CONFIG;
alert("App.js loaded! apiBase: " + apiBase);
console.log("App.js loaded (Restored Monolithic) v" + Math.random());

// --- ACCESS CONTROL ---
if (role === 'client') {
    const isDesktop = window.innerWidth > 1024; // Simple check for now
    const isCapacitor = !!window.Capacitor; // Check if running in native app

    if (isDesktop && !isCapacitor) {
        document.body.innerHTML = `
            <div class="flex flex-col items-center justify-center min-h-screen bg-black text-white p-8 text-center">
                <div class="text-6xl mb-4">📱</div>
                <h1 class="text-2xl font-bold mb-2">Mobile App Only</h1>
                <p class="text-gray-400 max-w-md">
                    The Client experience is designed for your phone.
                    Please download the app or log in from a mobile device.
                </p>
            </div>
        `;
        throw new Error("Desktop access blocked for client"); // Stop execution
    }
}

let workoutState = null;
let selectedExercisesList = []; // Global state for workout creation

// --- WEBSOCKET CONNECTION ---
const clientId = Date.now().toString();
const protocol = window.location.protocol === 'https:' ? 'wss' : 'ws';
const wsHost = apiBase ? apiBase.replace('http', 'ws') : `${protocol}://${window.location.host}`;
const wsUrl = `${wsHost}/ws/${clientId}`;
const socket = new WebSocket(wsUrl);

socket.onmessage = function (event) {
    const data = JSON.parse(event.data);
    if (data.type === 'reload') {
        console.log("Reloading due to code change...");
        window.location.reload();
    } else if (data.type === 'refresh') {
        console.log("Refreshing data...", data.target);
        // Re-run init to fetch fresh data
        init();
    }
};

socket.onopen = () => console.log("Connected to Real-Time Engine");
socket.onclose = () => console.log("Disconnected from Real-Time Engine");

// --- SHARED FUNCTIONS (Defined first to avoid hoisting issues) ---

window.showDayDetails = (dateStr, dayEvents, titleId, listId, isTrainer) => {
    const titleEl = document.getElementById(titleId);
    const listEl = document.getElementById(listId);

    const dateObj = new Date(dateStr);
    titleEl.innerText = dateObj.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
    listEl.innerHTML = '';

    if (isTrainer) {
        const addBtn = document.getElementById('add-workout-btn');
        if (addBtn) {
            addBtn.classList.remove('hidden');
            addBtn.onclick = () => {
                // Open Assign Modal
                document.getElementById('assign-date').value = dateStr;
                document.getElementById('assign-modal-date').innerText = `Assigning for ${new Date(dateStr).toLocaleDateString()}`;
                // We need client ID. Currently showDayDetails doesn't receive it directly but we can assume it's the currently viewed client.
                // Let's store client ID in a global var or data attribute when opening client modal.
                // For now, let's assume we can get it from the client modal's data or similar.
                // Actually, openTrainerCalendar is called when viewing a client.
                // We should store the current client ID when opening the calendar.
                const clientId = document.getElementById('client-modal').dataset.clientId;
                document.getElementById('assign-client-id').value = clientId;

                populateWorkoutSelector();
                showModal('assign-workout-modal');
            };
        }
    }

    if (dayEvents.length === 0) {
        listEl.innerHTML = '<p class="text-sm text-gray-500 italic">No events scheduled.</p>';
        return;
    }

    dayEvents.forEach(e => {
        const div = document.createElement('div');
        div.className = "glass-card p-3 flex justify-between items-center slide-up";
        const icon = e.type === 'workout' ? '💪' : '🧘';
        const statusColor = e.completed ? 'text-green-400' : 'text-orange-400';

        div.innerHTML = `
            <div class="flex items-center">
                <span class="text-xl mr-3">${icon}</span>
                <div>
                    <p class="text-sm font-bold text-white">${e.title}</p>
                    <p class="text-[10px] text-gray-400">${e.details}</p>
                </div>
            </div>
            <span class="text-xs font-bold ${statusColor}">${e.completed ? 'COMPLETED' : 'SCHEDULED'}</span>
        `;
        listEl.appendChild(div);
    });
};

window.renderCalendar = (month, year, events, gridId, titleId, detailTitleId, detailListId, isTrainer = false) => {
    const calendarGrid = document.getElementById(gridId);
    if (!calendarGrid) return;

    const firstDay = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

    document.getElementById(titleId).innerText = `${monthNames[month]} ${year}`;
    calendarGrid.innerHTML = '';

    // Empty slots for previous month
    for (let i = 0; i < firstDay; i++) {
        const div = document.createElement('div');
        calendarGrid.appendChild(div);
    }

    // Days
    for (let i = 1; i <= daysInMonth; i++) {
        const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(i).padStart(2, '0')}`;
        const dayEvents = events.filter(e => e.date === dateStr);
        const isCompleted = dayEvents.some(e => e.completed);

        // Check neighbors for streak connection
        const prevDate = new Date(year, month, i - 1);
        const prevDateStr = `${prevDate.getFullYear()}-${String(prevDate.getMonth() + 1).padStart(2, '0')}-${String(prevDate.getDate()).padStart(2, '0')}`;
        const prevCompleted = events.some(e => e.date === prevDateStr && e.completed);

        const nextDate = new Date(year, month, i + 1);
        const nextDateStr = `${nextDate.getFullYear()}-${String(nextDate.getMonth() + 1).padStart(2, '0')}-${String(nextDate.getDate()).padStart(2, '0')}`;
        const nextCompleted = events.some(e => e.date === nextDateStr && e.completed);

        const div = document.createElement('div');

        // Base classes
        let classes = "aspect-square flex flex-col items-center justify-center relative cursor-pointer transition mx-[1px] ";

        if (isCompleted) {
            classes += "bg-green-500/20 "; // Streak color
            if (!prevCompleted) classes += "rounded-l-lg ";
            if (!nextCompleted) classes += "rounded-r-lg ";
        } else {
            classes += "rounded-lg hover:bg-white/10 ";
        }

        div.className = classes;

        // Highlight today
        const today = new Date();
        if (i === today.getDate() && month === today.getMonth() && year === today.getFullYear()) {
            div.classList.add('border', 'border-primary');
        }

        div.innerHTML = `<span class="text-sm font-bold ${dayEvents.length > 0 ? 'text-white' : 'text-gray-500'}">${i}</span>`;

        // Event dots (only for non-streak days or incomplete events)
        if (dayEvents.length > 0 && !isCompleted) {
            const dots = document.createElement('div');
            dots.className = "flex space-x-1 mt-1";
            dayEvents.forEach(e => {
                const dot = document.createElement('div');
                dot.className = `w-1 h-1 rounded-full ${e.completed ? 'bg-green-400' : 'bg-orange-400'}`;
                dots.appendChild(dot);
            });
            div.appendChild(dots);
        } else if (isCompleted) {
            // Add checkmark for streak days
            const check = document.createElement('div');
            check.className = "text-[10px] text-green-400 mt-1";
            check.innerText = "✓";
            div.appendChild(check);
        }

        div.onclick = () => window.showDayDetails(dateStr, dayEvents, detailTitleId, detailListId, isTrainer);
        calendarGrid.appendChild(div);
    }
};

window.openTrainerCalendar = async () => {
    // Mock fetching client data for the calendar
    // In a real app, we'd pass the client ID
    const res = await fetch(`${apiBase}/api/client/data`);
    const user = await res.json();

    if (user.calendar) {
        showModal('calendar-modal');
        let currentMonth = new Date().getMonth();
        let currentYear = new Date().getFullYear();
        const events = user.calendar.events;

        window.renderCalendar(currentMonth, currentYear, events, 'trainer-calendar-grid', 'trainer-month-year', 'trainer-date-title', 'trainer-events-list', true);

        document.getElementById('trainer-prev-month').onclick = () => {
            currentMonth--;
            if (currentMonth < 0) { currentMonth = 11; currentYear--; }
            window.renderCalendar(currentMonth, currentYear, events, 'trainer-calendar-grid', 'trainer-month-year', 'trainer-date-title', 'trainer-events-list', true);
        };

        document.getElementById('trainer-next-month').onclick = () => {
            currentMonth++;
            if (currentMonth > 11) { currentMonth = 0; currentYear++; }
            window.renderCalendar(currentMonth, currentYear, events, 'trainer-calendar-grid', 'trainer-month-year', 'trainer-date-title', 'trainer-events-list', true);
        };
    }
};

// --- INITIALIZATION ---

async function init() {
    try {
        const gymRes = await fetch(`${apiBase}/api/config/${gymId}`);
        const gymConfig = await gymRes.json();
        document.documentElement.style.setProperty('--primary', gymConfig.primary_color);
        const nameEls = document.querySelectorAll('#gym-name, #gym-name-owner');
        nameEls.forEach(el => el.innerText = gymConfig.logo_text);

        if (role === 'client') {
            let user = null;
            try {
                console.log("Fetching client data from:", `${apiBase}/api/client/data`);
                const userRes = await fetch(`${apiBase}/api/client/data`);
                if (!userRes.ok) throw new Error(`API Error: ${userRes.status}`);

                user = await userRes.json();
                console.log("Client Data Received:", user);

                const setTxt = (id, val) => {
                    const el = document.getElementById(id);
                    if (el) {
                        el.innerText = val;
                    } else {
                        console.warn(`Element #${id} not found`);
                    }
                };

                setTxt('streak-count', user.streak);
                setTxt('gem-count', user.gems);
                setTxt('health-score', user.health_score);

                if (user.todays_workout) {
                    console.log("Rendering workout:", user.todays_workout);
                    setTxt('workout-title', user.todays_workout.title);
                    setTxt('workout-duration', user.todays_workout.duration);
                    setTxt('workout-difficulty', user.todays_workout.difficulty);
                } else {
                    console.warn("No todays_workout found in user data");
                    setTxt('workout-title', "Rest Day");
                    setTxt('workout-duration', "0 min");
                    setTxt('workout-difficulty', "Relax");
                }
            } catch (e) {
                console.error("Error fetching client data:", e);
                alert("Client Data Error: " + e.message);
            }

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

            // Calendar Mode Logic
            const calendarGrid = document.getElementById('calendar-grid');

            if (calendarGrid && user.calendar) {
                let currentMonth = new Date().getMonth();
                let currentYear = new Date().getFullYear();
                const events = user.calendar.events;

                // Initial render
                try {
                    window.renderCalendar(currentMonth, currentYear, events, 'calendar-grid', 'current-month-year', 'selected-date-title', 'day-events-list');
                } catch (e) {
                    console.error("Error rendering calendar:", e);
                }

                document.getElementById('prev-month').onclick = () => {
                    currentMonth--;
                    if (currentMonth < 0) { currentMonth = 11; currentYear--; }
                    window.renderCalendar(currentMonth, currentYear, events, 'calendar-grid', 'current-month-year', 'selected-date-title', 'day-events-list');
                };

                document.getElementById('next-month').onclick = () => {
                    currentMonth++;
                    if (currentMonth > 11) { currentMonth = 0; currentYear++; }
                    window.renderCalendar(currentMonth, currentYear, events, 'calendar-grid', 'current-month-year', 'selected-date-title', 'day-events-list');
                };

                // Show today's details by default
                const todayStr = new Date().toISOString().split('T')[0];
                const todayEvents = events.filter(e => e.date === todayStr);
                window.showDayDetails(todayStr, todayEvents, 'selected-date-title', 'day-events-list');
            } else {
                console.warn("Skipping calendar init. Grid:", !!calendarGrid, "Data:", !!user.calendar);
                if (calendarGrid && !user.calendar) alert("Calendar data missing!");
            }
        }

        if (role === 'trainer') {
            const trainerRes = await fetch(`${apiBase}/api/trainer/data`);
            const data = await trainerRes.json();

            const list = document.getElementById('client-list');
            if (list) {
                data.clients.forEach(c => {
                    const div = document.createElement('div');
                    div.className = "glass-card p-4 flex justify-between items-center tap-effect";
                    div.onclick = function () { showClientModal(c.name, c.plan, c.status, c.id); };
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

            // Fetch and Render Exercise Library (Main View)
            if (document.getElementById('main-exercise-library')) {
                initializeExerciseList({
                    containerId: 'main-exercise-library',
                    searchId: 'main-ex-search',
                    muscleId: 'main-ex-filter-muscle',
                    typeId: 'main-ex-filter-type',
                    onClick: null // Default behavior (just view/edit)
                });

                // Add trainer selector change listener
                const trainerSelector = document.getElementById('trainer-selector');
                if (trainerSelector) {
                    trainerSelector.addEventListener('change', () => {
                        // Re-initialize/Render both lists if they exist
                        if (document.getElementById('main-exercise-library')) {
                            initializeExerciseList({
                                containerId: 'main-exercise-library',
                                searchId: 'main-ex-search',
                                muscleId: 'main-ex-filter-muscle',
                                typeId: 'main-ex-filter-type',
                                onClick: null
                            });
                        }
                        showToast(`Switched to ${trainerSelector.options[trainerSelector.selectedIndex].text}`);
                    });
                }
            }

            // Setup Global Exercise Modals (Create/Edit)
            setupExerciseModals();

            // Toggle Exercise List Visibility
            const toggleBtn = document.getElementById('toggle-exercises-btn');
            const exercisesSection = document.getElementById('exercises-section');
            if (toggleBtn && exercisesSection) {
                toggleBtn.addEventListener('click', () => {
                    exercisesSection.classList.toggle('hidden');
                    const isHidden = exercisesSection.classList.contains('hidden');
                    toggleBtn.textContent = isHidden ? 'Edit Exercises' : 'Hide Exercises';
                });
            }

            // Fetch and Render Workouts
            if (document.getElementById('workout-library')) {
                fetchAndRenderWorkouts();

            }
        }

        if (role === 'owner') {
            const ownerRes = await fetch(`${apiBase}/api/owner/data`);
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
        if (document.getElementById('leaderboard-list')) {
            const leaderboardRes = await fetch(`${apiBase}/api/leaderboard/data`);
            const leaderboard = await leaderboardRes.json();

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
    } catch (e) {
        console.error("Init Error:", e);
    }
}

// Call init
init();


// --- GLOBAL EVENT LISTENER ---
document.body.addEventListener('click', e => {
    const target = e.target.closest('[data-action]');
    if (!target) return;

    const action = target.dataset.action;

    if (action === 'adjustReps') {
        adjustReps(parseInt(target.dataset.delta));
    } else if (action === 'completeSet') {
        completeSet();
    } else if (action === 'showModal') {
        showModal(target.dataset.target);
    } else if (action === 'hideModal') {
        hideModal(target.dataset.target);
    } else if (action === 'quickAction') {
        quickAction(target.dataset.type);
    } else if (action === 'addPhoto') {
        addPhoto();
    } else if (action === 'uploadVideo') {
        uploadVideo();
    } else if (action === 'addWater') {
        addWater();
    } else if (action === 'openCreateWorkout') {
        openCreateWorkoutModal();
    }
});


// --- MODAL SYSTEM & HELPERS ---

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
        if (cur + 250 > 10000) {
            showToast('Daily limit reached! (10000ml) 🚫');
            return;
        }
        cur += 250;
        el.innerText = cur + 'ml';
        // Mock target 2500
        const pct = 100 - ((cur / 2500) * 100);
        wave.style.top = Math.max(0, pct) + '%';
        showToast('Hydration recorded! 💧');
    }
}

function showClientModal(name, plan, status, clientId) {
    document.getElementById('modal-client-name').innerText = name;
    document.getElementById('modal-client-plan').innerText = plan;
    document.getElementById('modal-client-status').innerText = status;
    document.getElementById('modal-client-status').className = `text-lg font-bold ${status === 'At Risk' ? 'text-red-400' : 'text-green-400'}`;
    document.getElementById('client-modal').dataset.clientId = clientId;
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

// Helper function to get current trainer ID
function getCurrentTrainerId() {
    const selector = document.getElementById('trainer-selector');
    return selector ? selector.value : 'trainer_default';
}

async function initializeExerciseList(config) {
    const { containerId, searchId, muscleId, typeId, onClick } = config;
    const container = document.getElementById(containerId);
    if (!container) return;

    const trainerId = getCurrentTrainerId();
    const res = await fetch(`${apiBase}/api/trainer/exercises`, {
        headers: { 'x-trainer-id': trainerId }
    });
    const exercises = await res.json();

    // Render Function
    const render = () => {
        const searchVal = document.getElementById(searchId)?.value.toLowerCase() || '';
        const muscleVal = document.getElementById(muscleId)?.value || '';
        const typeVal = document.getElementById(typeId)?.value || '';

        const filtered = exercises.filter(ex => {
            const matchesSearch = ex.name.toLowerCase().includes(searchVal);
            const matchesMuscle = muscleVal ? ex.muscle === muscleVal : true;
            const matchesType = typeVal ? ex.type === typeVal : true;
            return matchesSearch && matchesMuscle && matchesType;
        });

        container.innerHTML = '';

        const muscleIcons = {
            'Chest': '🛡️', 'Back': '🦅', 'Legs': '🦵',
            'Shoulders': '💪', 'Arms': '🦾', 'Abs': '🍫', 'Cardio': '🏃'
        };

        const typeColors = {
            'Compound': 'bg-yellow-500/20 text-yellow-400',
            'Isolation': 'bg-blue-500/20 text-blue-400',
            'Bodyweight': 'bg-green-500/20 text-green-400',
            'Cardio': 'bg-red-500/20 text-red-400'
        };

        filtered.forEach(ex => {
            const div = document.createElement('div');
            div.className = "glass-card p-4 flex flex-col justify-between relative overflow-hidden group tap-effect slide-up min-h-[120px]";

            const icon = muscleIcons[ex.muscle] || '🏋️';
            const badgeClass = typeColors[ex.type] || 'bg-gray-500/20 text-gray-400';

            let videoBackground = '';
            if (ex.video_id) {
                let src = ex.video_id;
                if (!src.startsWith('http') && !src.startsWith('/')) {
                    src = `/static/videos/${src}.mp4`;
                }
                if (!src.includes('youtube') && !src.includes('youtu.be')) {
                    videoBackground = `
                        <div class="absolute inset-0 z-0 opacity-0 group-hover:opacity-40 transition duration-500">
                            <video src="${src}" muted loop playsinline class="w-full h-full object-cover"></video>
                        </div>
                     `;
                }
            }

            div.innerHTML = `
                ${videoBackground}
                
                <div class="absolute -right-2 -top-2 opacity-10 group-hover:opacity-0 transition transform group-hover:scale-110 pointer-events-none">
                    <span class="text-8xl">${icon}</span>
                </div>
                <div class="relative z-10 w-full h-full flex flex-col justify-between pointer-events-none">
                    <div class="flex justify-between items-start mb-2 pointer-events-auto pl-1">
                        <span class="text-[10px] font-bold px-2 py-1 rounded-full ${badgeClass} uppercase tracking-wider">${ex.type}</span>
                        <button class="edit-btn w-8 h-8 flex items-center justify-center bg-white/10 rounded-full text-gray-300 hover:bg-white/20 hover:text-white transition tap-effect">
                            ⚙️
                        </button>
                    </div>
                    <div>
                        <h4 class="font-bold text-lg text-white mb-1 leading-tight drop-shadow-md">${ex.name}</h4>
                        <div class="flex items-center text-xs text-gray-400 mt-1">
                            <span class="mr-2">${icon}</span>
                            <span>${ex.muscle}</span>
                        </div>
                    </div>
                </div>
            `;

            // Video Hover Logic
            if (videoBackground) {
                const video = div.querySelector('video');
                div.addEventListener('mouseenter', () => {
                    try { video.play(); } catch (e) { }
                });
                div.addEventListener('mouseleave', () => {
                    try { video.pause(); video.currentTime = 0; } catch (e) { }
                });
            }

            // Attach click listener to the edit button
            const editBtn = div.querySelector('.edit-btn');
            editBtn.addEventListener('click', (e) => {
                e.stopPropagation(); // Prevent card click
                openEditExerciseModal(ex);
            });

            // Click card action
            div.addEventListener('click', (e) => {
                if (onClick === 'addToWorkout') {
                    addExerciseToWorkout(ex);
                }
            });

            container.appendChild(div);
        });
    };

    // Attach listeners if not already attached
    if (!container.dataset.listenersAttached) {
        document.getElementById(searchId)?.addEventListener('input', render);
        document.getElementById(muscleId)?.addEventListener('change', render);
        document.getElementById(typeId)?.addEventListener('change', render);
        container.dataset.listenersAttached = "true";
    }

    // Initial Render
    render();
}

function setupExerciseModals() {
    // File input listeners for preview and upload
    ['new', 'edit'].forEach(prefix => {
        const fileInput = document.getElementById(`${prefix}-ex-file`);
        const videoInput = document.getElementById(`${prefix}-ex-video`);
        const filenameDisplay = document.getElementById(`${prefix}-ex-filename`);

        if (fileInput && !fileInput.dataset.listenerAttached) {
            fileInput.addEventListener('change', async (e) => {
                const file = e.target.files[0];
                if (file) {
                    filenameDisplay.innerText = `Uploading: ${file.name}...`;

                    const formData = new FormData();
                    formData.append('file', file);

                    try {
                        const res = await fetch(`${apiBase}/api/upload`, {
                            method: 'POST',
                            body: formData
                        });

                        if (res.ok) {
                            const data = await res.json();
                            videoInput.value = data.url; // Use real server URL
                            filenameDisplay.innerText = `Uploaded: ${file.name}`;
                            showToast('Video uploaded! 🎥');

                            // Update Preview
                            const previewContainer = document.getElementById(`${prefix}-ex-preview-container`);
                            const previewVideo = document.getElementById(`${prefix}-ex-preview`);
                            if (previewContainer && previewVideo) {
                                previewVideo.src = data.url;
                                previewContainer.classList.remove('hidden');
                                previewVideo.load();
                            }
                        } else {
                            filenameDisplay.innerText = `Upload failed`;
                            showToast('Upload failed ❌');
                        }
                    } catch (err) {
                        console.error(err);
                        filenameDisplay.innerText = `Upload error`;
                        showToast('Upload error ❌');
                    }
                }
            });
            fileInput.dataset.listenerAttached = "true";
        }

        // URL Input Listener for Preview
        if (videoInput && !videoInput.dataset.listenerAttached) {
            videoInput.addEventListener('input', (e) => {
                const url = e.target.value;
                const previewContainer = document.getElementById(`${prefix}-ex-preview-container`);
                const previewVideo = document.getElementById(`${prefix}-ex-preview`);

                if (previewContainer && previewVideo) {
                    if (url) {
                        previewVideo.src = url;
                        previewContainer.classList.remove('hidden');
                        previewVideo.load();
                    } else {
                        previewContainer.classList.add('hidden');
                        previewVideo.pause();
                        previewVideo.src = "";
                    }
                }
            });
            videoInput.dataset.listenerAttached = "true";
        }
    });
}

function openEditExerciseModal(ex) {
    document.getElementById('edit-ex-id').value = ex.id;
    document.getElementById('edit-ex-name').value = ex.name;
    document.getElementById('edit-ex-muscle').value = ex.muscle;
    document.getElementById('edit-ex-type').value = ex.type;
    document.getElementById('edit-ex-video').value = ex.video_id || '';
    document.getElementById('edit-ex-filename').innerText = ''; // Reset file label

    // Set Preview
    const previewContainer = document.getElementById('edit-ex-preview-container');
    const previewVideo = document.getElementById('edit-ex-preview');
    if (previewContainer && previewVideo) {
        if (ex.video_id) {
            // Check if it's a full URL or a local ID (assuming local IDs don't have http)
            let src = ex.video_id;
            if (!src.startsWith('http') && !src.startsWith('/')) {
                src = `/static/videos/${src}.mp4`;
            }
            previewVideo.src = src;
            previewContainer.classList.remove('hidden');
            previewVideo.load();
        } else {
            previewContainer.classList.add('hidden');
            previewVideo.pause();
            previewVideo.src = "";
        }
    }

    showModal('edit-exercise-modal');
}

async function updateExercise() {
    const id = document.getElementById('edit-ex-id').value;
    const name = document.getElementById('edit-ex-name').value;
    const muscle = document.getElementById('edit-ex-muscle').value;
    const type = document.getElementById('edit-ex-type').value;
    const video = document.getElementById('edit-ex-video').value;

    if (!name) {
        showToast('Please enter an exercise name ⚠️');
        return;
    }

    const trainerId = getCurrentTrainerId();
    const payload = { name, muscle, type, video_id: video };

    try {
        const res = await fetch(`${apiBase}/api/trainer/exercises/${id}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast('Exercise updated! ✅');
            hideModal('edit-exercise-modal');
            hideModal('edit-exercise-modal');
            // Refresh main list if it exists
            if (document.getElementById('main-exercise-library')) {
                initializeExerciseList({
                    containerId: 'main-exercise-library',
                    searchId: 'main-ex-search',
                    muscleId: 'main-ex-filter-muscle',
                    typeId: 'main-ex-filter-type',
                    onClick: null
                });
            }
            // Refresh modal list if open
            if (document.getElementById('modal-exercise-library')) {
                initializeExerciseList({
                    containerId: 'modal-exercise-library',
                    searchId: 'modal-ex-search',
                    muscleId: 'modal-ex-filter-muscle',
                    typeId: 'modal-ex-filter-type',
                    onClick: 'addToWorkout'
                });
            }
        } else {
            showToast('Failed to update exercise ❌');
        }
    } catch (e) {
        console.error(e);
        showToast('Error updating exercise ❌');
    }
}

window.createExercise = async function () {
    const name = document.getElementById('new-ex-name').value;
    const muscle = document.getElementById('new-ex-muscle').value;
    const type = document.getElementById('new-ex-type').value;
    const video = document.getElementById('new-ex-video').value;

    if (!name) {
        showToast('Please enter an exercise name ⚠️');
        return;
    }

    const trainerId = getCurrentTrainerId();
    const payload = { name, muscle, type, video_id: video };

    try {
        const res = await fetch(`${apiBase}/api/trainer/exercises`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast('Exercise created! 💪');
            hideModal('create-exercise-modal');
            // Clear inputs
            document.getElementById('new-ex-name').value = '';
            document.getElementById('new-ex-video').value = '';
            document.getElementById('new-ex-filename').innerText = '';
            document.getElementById('new-ex-filename').innerText = '';

            // Refresh main list if it exists
            if (document.getElementById('main-exercise-library')) {
                initializeExerciseList({
                    containerId: 'main-exercise-library',
                    searchId: 'main-ex-search',
                    muscleId: 'main-ex-filter-muscle',
                    typeId: 'main-ex-filter-type',
                    onClick: null
                });
            }
            // Refresh modal list if open
            if (document.getElementById('modal-exercise-library')) {
                initializeExerciseList({
                    containerId: 'modal-exercise-library',
                    searchId: 'modal-ex-search',
                    muscleId: 'modal-ex-filter-muscle',
                    typeId: 'modal-ex-filter-type',
                    onClick: 'addToWorkout'
                });
            }
        } else {
            showToast('Failed to create exercise ❌');
        }
    } catch (e) {
        console.error(e);
        showToast('Error creating exercise ❌');
    }
};

async function fetchAndRenderWorkouts() {
    const trainerId = getCurrentTrainerId();
    const res = await fetch(`${apiBase}/api/trainer/workouts`, {
        headers: { 'x-trainer-id': trainerId }
    });
    const workouts = await res.json();
    const container = document.getElementById('workout-library');
    if (!container) return;

    container.innerHTML = '';
    workouts.forEach(w => {
        const div = document.createElement('div');
        div.className = "glass-card p-3 flex justify-between items-center";
        div.innerHTML = `
            <div>
                <p class="font-bold text-sm text-white">${w.title}</p>
                <p class="text-[10px] text-gray-400">${w.exercises.length} Exercises • ${w.duration} • ${w.difficulty}</p>
            </div>
            <button class="edit-workout-btn text-xs bg-white/5 hover:bg-white/10 px-2 py-1 rounded text-gray-300 transition">Edit</button>
        `;

        div.querySelector('.edit-workout-btn').onclick = () => openEditWorkout(w);

        container.appendChild(div);
    });
}



// --- SELECTED EXERCISES LOGIC ---

window.renderSelectedExercises = function () {
    const container = document.getElementById('selected-exercises-list');
    if (!container) return;

    container.innerHTML = '';

    if (selectedExercisesList.length === 0) {
        container.innerHTML = '<p class="text-xs text-gray-500 text-center py-4 italic">No exercises selected.</p>';
        return;
    }

    selectedExercisesList.forEach((ex, idx) => {
        const div = document.createElement('div');
        div.className = "bg-white/5 rounded-xl p-3 relative animate-fade-in border border-white/5";

        div.innerHTML = `
            <button onclick="removeExerciseFromWorkout(${idx})" class="absolute top-2 right-2 text-gray-500 hover:text-red-500 transition p-1">✕</button>
            
            <div class="pr-8 mb-3">
                <p class="text-sm font-bold text-white truncate">${ex.name}</p>
                <p class="text-[10px] text-gray-400 uppercase tracking-wider">${ex.muscle} • ${ex.type}</p>
            </div>

            <div class="grid grid-cols-3 gap-3">
                <div>
                    <label class="text-[9px] text-gray-500 uppercase font-bold block mb-1 text-center">Sets</label>
                    <input type="number" value="${ex.sets}" onchange="updateExerciseDetails(${idx}, 'sets', this.value)" 
                        class="w-full bg-black/30 border border-white/10 rounded-lg text-center text-sm text-white py-2 focus:border-primary outline-none transition">
                </div>
                <div>
                    <label class="text-[9px] text-gray-500 uppercase font-bold block mb-1 text-center">Reps</label>
                    <input type="text" value="${ex.reps}" onchange="updateExerciseDetails(${idx}, 'reps', this.value)" 
                        class="w-full bg-black/30 border border-white/10 rounded-lg text-center text-sm text-white py-2 focus:border-primary outline-none transition">
                </div>
                <div>
                    <label class="text-[9px] text-gray-500 uppercase font-bold block mb-1 text-center">Rest (s)</label>
                    <input type="number" value="${ex.rest}" onchange="updateExerciseDetails(${idx}, 'rest', this.value)" 
                        class="w-full bg-black/30 border border-white/10 rounded-lg text-center text-sm text-white py-2 focus:border-primary outline-none transition">
                </div>
            </div>
        `;
        container.appendChild(div);
    });
}

window.addExerciseToWorkout = function (exercise) {
    // Add new instance allowing duplicates (e.g. for supersets or multiple sets of same exercise)
    selectedExercisesList.push({
        id: exercise.id,
        name: exercise.name,
        muscle: exercise.muscle,
        video_id: exercise.video_id,
        sets: 3,
        reps: "10",
        rest: 60
    });

    renderSelectedExercises();
    showToast(`Added ${exercise.name}`);
}

window.removeExerciseFromWorkout = function (idx) {
    selectedExercisesList.splice(idx, 1);
    renderSelectedExercises();
}

window.updateExerciseDetails = function (idx, field, value) {
    if (selectedExercisesList[idx]) {
        if (field === 'reps') selectedExercisesList[idx][field] = value; // Keep as string for ranges
        else selectedExercisesList[idx][field] = parseInt(value);
    }
}

// --- WORKOUT CREATION & EDITING ---

window.openCreateWorkoutModal = function () {
    document.getElementById('new-workout-id').value = '';
    document.getElementById('modal-workout-title').innerText = 'New Workout';
    document.getElementById('btn-save-workout').innerText = 'Create Workout';

    document.getElementById('new-workout-title').value = '';
    document.getElementById('new-workout-duration').value = '';
    document.getElementById('new-workout-difficulty').value = 'Intermediate';

    selectedExercisesList = [];
    renderSelectedExercises();

    showModal('create-workout-modal');

    // Initialize Exercise List for Modal
    initializeExerciseList({
        containerId: 'modal-exercise-library',
        searchId: 'modal-ex-search',
        muscleId: 'modal-ex-filter-muscle',
        typeId: 'modal-ex-filter-type',
        onClick: 'addToWorkout'
    });
}

window.openEditWorkout = function (workout) {
    document.getElementById('new-workout-id').value = workout.id;
    document.getElementById('modal-workout-title').innerText = 'Edit Workout';
    document.getElementById('btn-save-workout').innerText = 'Update Workout';

    document.getElementById('new-workout-title').value = workout.title;
    document.getElementById('new-workout-duration').value = workout.duration;
    document.getElementById('new-workout-difficulty').value = workout.difficulty;

    selectedExercisesList = JSON.parse(JSON.stringify(workout.exercises)); // Deep copy
    renderSelectedExercises();

    showModal('create-workout-modal');
}

window.createWorkout = async function () {
    const id = document.getElementById('new-workout-id').value;
    const title = document.getElementById('new-workout-title').value;
    const duration = document.getElementById('new-workout-duration').value;
    const difficulty = document.getElementById('new-workout-difficulty').value;

    if (!title) {
        showToast('Please enter a workout title');
        return;
    }

    if (selectedExercisesList.length === 0) {
        showToast('Please select at least one exercise');
        return;
    }

    const trainerId = getCurrentTrainerId();
    const payload = { title, duration, difficulty, exercises: selectedExercisesList };

    let url = `${apiBase}/api/trainer/workouts`;
    let method = 'POST';

    if (id) {
        url = `${apiBase}/api/trainer/workouts/${id}`;
        method = 'PUT';
    }

    try {
        const res = await fetch(url, {
            method: method,
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast(id ? 'Workout updated! 💪' : 'Workout created! 💪');
            hideModal('create-workout-modal');

            // Reset form
            document.getElementById('new-workout-title').value = '';
            document.getElementById('new-workout-id').value = '';
            selectedExercisesList = [];
            renderSelectedExercises();

            fetchAndRenderWorkouts();
        } else {
            const errText = await res.text();
            console.error(errText);
            showToast('Failed: ' + errText); // Show actual error
        }
    } catch (e) {
        console.error(e);
        showToast('Error saving workout ❌');
        // alert(e.message); // Debug
    }
}

async function populateWorkoutSelector() {
    const res = await fetch(`${apiBase}/api/trainer/workouts`);
    const workouts = await res.json();
    const select = document.getElementById('assign-workout-select');
    if (!select) return;

    select.innerHTML = '';
    workouts.forEach(w => {
        const option = document.createElement('option');
        option.value = w.id;
        option.innerText = w.title;
        select.appendChild(option);
    });
}

window.assignWorkout = async function () {
    const clientId = document.getElementById('assign-client-id').value;
    const date = document.getElementById('assign-date').value;
    const workoutId = document.getElementById('assign-workout-select').value;

    if (!clientId || !date || !workoutId) {
        showToast('Missing information');
        return;
    }

    const res = await fetch('/api/trainer/assign_workout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ client_id: clientId, date: date, workout_id: workoutId })
    });

    if (res.ok) {
        showToast('Workout assigned successfully! 📅');
        hideModal('assign-workout-modal');
        // Refresh calendar
        // We need to re-fetch client data or just reload the calendar.
        // Simple way: close calendar and let user re-open, or trigger a refresh.
        // Let's try to refresh the calendar view if possible.
        // window.openTrainerCalendar() fetches data again.
        // But we are inside the calendar.
        // Let's just hide the assign modal and maybe update the UI manually or close/open calendar.
        // For better UX, let's close the calendar modal too so they can re-open to see changes, or just show toast.
        // Ideally we re-render the calendar.
        // We can call openTrainerCalendar() again?
        // But we need the client ID.
        // Let's just show toast for now.
    } else {
        showToast('Failed to assign workout');
    }
}

function adjustReps(delta) {
    if (!workoutState) return;
    workoutState.currentReps = Math.max(0, parseInt(workoutState.currentReps) + delta);
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
            workoutState.currentReps = parseInt(targetReps);
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
                workoutState.currentReps = parseInt(nextReps);
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
document.addEventListener('DOMContentLoaded', () => {
    if (document.getElementById('workout-screen')) {
        fetch(`${apiBase}/api/client/data`)
            .then(res => res.json())
            .then(user => {
                const workout = user.todays_workout;
                workoutState = {
                    exercises: workout.exercises,
                    currentExerciseIdx: 0,
                    currentSet: 1,
                    currentReps: parseInt(String(workout.exercises[0].reps).split('-')[1] || workout.exercises[0].reps)
                };

                // Populate Routine List
                const list = document.getElementById('workout-routine-list');
                if (list) {
                    list.innerHTML = '';
                    workout.exercises.forEach((ex, idx) => {
                        const div = document.createElement('div');
                        div.id = `exercise-${idx}`;
                        div.className = "glass-card p-4 flex justify-between items-center transition duration-300 tap-effect cursor-pointer";
                        div.onclick = () => window.switchExercise(idx);
                        div.innerHTML = `
                            <div class="flex items-center space-x-4">
                                <div class="w-12 h-12 rounded-xl bg-white/10 flex items-center justify-center text-xl font-bold text-gray-400 status-icon">
                                    ${idx + 1}
                                </div>
                                <div>
                                    <h4 class="font-bold text-white text-sm">${ex.name}</h4>
                                    <p class="text-[10px] text-gray-400">${ex.sets} Sets • ${ex.reps} Reps</p>
                                </div>
                            </div>
                            <div class="w-6 h-6 rounded-full border border-white/20 flex items-center justify-center">
                                <div class="w-3 h-3 bg-green-400 rounded-full opacity-0 status-dot"></div>
                            </div>
                        `;
                        list.appendChild(div);
                    });
                }

                updateWorkoutUI();
            });
    }
});

window.switchExercise = function (idx) {
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

    updateWorkoutUI();
}

function updateWorkoutUI() {
    if (!workoutState) return;

    const ex = workoutState.exercises[workoutState.currentExerciseIdx];

    // Update Header & Counters
    document.getElementById('exercise-name').innerText = ex.name;
    document.getElementById('exercise-target').innerText = `Set ${workoutState.currentSet} of ${ex.sets} • Target: ${ex.reps} Reps`;
    document.getElementById('rep-counter').innerText = workoutState.currentReps;

    // Update Video
    const videoEl = document.getElementById('exercise-video');
    const repVideoEl = document.getElementById('rep-counter-video');
    const newSrc = `/static/videos/${ex.video_id}.mp4?v=3`;

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

    // Render Routine List
    const list = document.getElementById('workout-routine-list');
    if (list) {
        list.innerHTML = '';
        workoutState.exercises.forEach((item, idx) => {
            const div = document.createElement('div');
            const isCurrent = idx === workoutState.currentExerciseIdx;

            // Event Delegation Attributes
            div.dataset.action = 'switchExercise';
            div.dataset.idx = idx;

            div.className = `p-3 rounded-xl flex items-center mb-2 cursor-pointer transition-all ${isCurrent ? 'bg-white/10 border border-primary/50' : 'hover:bg-white/5 border border-transparent'}`;
            // Add onclick for direct interaction if delegation fails or for legacy support
            div.onclick = () => window.switchExercise(idx);

            let icon = `<div class="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center mr-3 text-xs text-gray-400">${idx + 1}</div>`;
            if (isCurrent) icon = '<div class="w-8 h-8 rounded-full bg-primary text-black flex items-center justify-center mr-3 font-bold animate-pulse">▶</div>';
            if (idx < workoutState.currentExerciseIdx) icon = '<div class="w-8 h-8 rounded-full bg-red-500 text-white flex items-center justify-center mr-3 font-bold animate-pulse">✓</div>';

            div.innerHTML = `
                <div class="flex items-center space-x-4 pointer-events-none">
                    ${icon}
                    <div class="flex-1">
                        <h4 class="font-bold text-white ${isCurrent ? 'text-lg' : 'text-sm'}">${item.name}</h4>
                        <p class="text-xs text-gray-400">${item.sets} Sets • ${item.reps} Reps</p>
                    </div>
                    ${isCurrent ? '<span class="text-xs font-bold text-primary uppercase tracking-wider">Active</span>' : ''}
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
    if (progressEl) progressEl.innerText = `${progressPct}% Complete`;

    // Update Progress Bar
    const totalSets = workoutState.exercises.reduce((acc, curr) => acc + curr.sets, 0);
    let completedSets = 0;
    for (let i = 0; i < workoutState.currentExerciseIdx; i++) {
        completedSets += workoutState.exercises[i].sets;
    }
    completedSets += (workoutState.currentSet - 1);
    const barPct = (completedSets / totalSets) * 100;
    const barEl = document.getElementById('workout-progress-bar');
    if (barEl) barEl.style.width = `${barPct}%`;
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
