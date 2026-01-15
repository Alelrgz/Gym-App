const { gymId, role, apiBase } = window.APP_CONFIG;
alert("App.js loaded! apiBase: " + apiBase);
console.log("App.js loaded (Restored Monolithic) v" + Math.random());

// --- AUTHENTICATION ---
if (!localStorage.getItem('token') && window.location.pathname !== '/login') {
    window.location.href = '/login';
}

const originalFetch = window.fetch;
window.fetch = async function (url, options = {}) {
    const token = localStorage.getItem('token');
    if (token) {
        options.headers = options.headers || {};
        if (!options.headers['Authorization']) {
            options.headers['Authorization'] = `Bearer ${token}`;
        }
    }

    try {
        const response = await originalFetch(url, options);
        if (response.status === 401 && window.location.pathname !== '/login') {
            localStorage.removeItem('token');
            window.location.href = '/login';
        }
        return response;
    } catch (e) {
        throw e;
    }
};

function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('role');
    window.location.href = '/login';
}
window.logout = logout;

document.addEventListener('DOMContentLoaded', () => {
    if (window.location.pathname !== '/login') {
        const logoutBtn = document.createElement('button');
        logoutBtn.innerText = 'Logout';
        logoutBtn.style.position = 'fixed';
        logoutBtn.style.top = '10px';
        logoutBtn.style.right = '10px';
        logoutBtn.style.zIndex = '9999';
        logoutBtn.style.padding = '5px 10px';
        logoutBtn.style.background = '#e94560';
        logoutBtn.style.color = 'white';
        logoutBtn.style.border = 'none';
        logoutBtn.style.borderRadius = '5px';
        logoutBtn.style.cursor = 'pointer';
        logoutBtn.onclick = logout;
        document.body.appendChild(logoutBtn);
    }
});

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
                hideModal('calendar-modal'); // Close schedule to show assignment
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
                    <p class="text-[10px] text-gray-400">
                        ${(e.details && (e.details.startsWith('[') || e.details.startsWith('{'))) ? 'Workout Data Saved' : e.details}
                    </p>
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

        div.onclick = () => {
            if (window.datePickerMode && window.onDatePicked) {
                window.onDatePicked(dateStr);
            } else {
                window.showDayDetails(dateStr, dayEvents, detailTitleId, detailListId, isTrainer);
            }
        };
        calendarGrid.appendChild(div);
    }
};

window.openTrainerCalendar = async (explicitClientId) => {
    const clientId = explicitClientId || document.getElementById('client-modal').dataset.clientId;
    if (!clientId) {
        console.error("No client ID found for calendar");
        return;
    }

    try {
        console.log("Fetching client data for calendar:", clientId);
        const res = await fetch(`${apiBase}/api/trainer/client/${clientId}`);
        if (!res.ok) throw new Error("Failed to fetch client data: " + res.status);
        const user = await res.json();
        console.log("Client data received:", user);

        if (user.calendar) {
            console.log("Opening calendar modal...");
            showModal('calendar-modal');
            let currentMonth = new Date().getMonth();
            let currentYear = new Date().getFullYear();
            const events = user.calendar.events;
            console.log("Rendering calendar with events:", events);

            if (!document.getElementById('trainer-calendar-grid')) console.error("CRITICAL: trainer-calendar-grid missing!");

            window.renderCalendar(currentMonth, currentYear, events, 'trainer-calendar-grid', 'trainer-month-year', 'trainer-date-title', 'trainer-events-list', true);

            const prevBtn = document.getElementById('trainer-prev-month');
            const nextBtn = document.getElementById('trainer-next-month');

            if (prevBtn) {
                prevBtn.onclick = () => {
                    currentMonth--;
                    if (currentMonth < 0) { currentMonth = 11; currentYear--; }
                    window.renderCalendar(currentMonth, currentYear, events, 'trainer-calendar-grid', 'trainer-month-year', 'trainer-date-title', 'trainer-events-list', true);
                };
            } else {
                console.error("CRITICAL: trainer-prev-month missing!");
            }

            if (nextBtn) {
                nextBtn.onclick = () => {
                    currentMonth++;
                    if (currentMonth > 11) { currentMonth = 0; currentYear++; }
                    window.renderCalendar(currentMonth, currentYear, events, 'trainer-calendar-grid', 'trainer-month-year', 'trainer-date-title', 'trainer-events-list', true);
                };
            } else {
                console.error("CRITICAL: trainer-next-month missing!");
            }
        } else {
            console.warn("User has no calendar data");
        }
    } catch (e) {
        console.error("Error opening trainer calendar:", e);
        showToast("Error loading schedule: " + e.message);
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
            // Display client username from localStorage
            const username = localStorage.getItem('username') || 'Guest';
            const displayNameEl = document.getElementById('client-display-name');
            const welcomeNameEl = document.getElementById('client-welcome-name');
            if (displayNameEl) displayNameEl.textContent = username;
            if (welcomeNameEl) welcomeNameEl.textContent = username;

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

                    if (user.todays_workout.completed) {
                        const startBtn = document.querySelector('a[href*="mode=workout"]');
                        if (startBtn) {
                            startBtn.innerText = "COMPLETED ✓";
                            startBtn.className = "block w-full py-3 bg-green-500 text-white text-center font-bold rounded-xl hover:bg-green-600 transition";
                            // Append view=completed to existing href
                            if (startBtn.href.includes('?')) {
                                startBtn.href += "&view=completed";
                            } else {
                                startBtn.href += "?view=completed";
                            }
                        }
                    }
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

            // Pre-fill Profile Data (if on settings page)
            if (user) {
                const pName = document.getElementById('profile-name');
                const pEmail = document.getElementById('profile-email');
                if (pName) pName.value = user.name;
                if (pEmail) pEmail.value = user.email || "";
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
            // Display trainer username from localStorage
            const username = localStorage.getItem('username') || 'Trainer';
            const usernameEl = document.getElementById('trainer-username');
            if (usernameEl) usernameEl.textContent = username;

            const trainerRes = await fetch(`${apiBase}/api/trainer/data`);
            const data = await trainerRes.json();

            const list = document.getElementById('client-list');
            if (list) {
                data.clients.forEach(c => {
                    console.log("Rendering client:", c.name, "ID:", c.id);
                    const div = document.createElement('div');
                    div.className = "glass-card p-4 flex justify-between items-center tap-effect";
                    div.onclick = function () {
                        console.log("Clicked client:", c.name, "ID:", c.id);
                        showClientModal(c.name, c.plan, c.status, c.id);
                    };
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
                        // Refresh Workouts
                        if (document.getElementById('workout-library')) {
                            fetchAndRenderWorkouts();
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
    console.log("showClientModal called with ID:", clientId);
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


window.saveProfile = async () => {
    const name = document.getElementById('profile-name').value;
    const email = document.getElementById('profile-email').value;
    const password = document.getElementById('profile-password').value;

    if (!name || !email) {
        showToast("Name and Email are required! ⚠️");
        return;
    }

    try {
        const res = await fetch(`${apiBase}/api/client/profile`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name,
                email,
                password: password ? password : undefined
            })
        });

        if (!res.ok) throw new Error("Failed to update");

        showToast("Profile updated successfully! ✅");

        // Clear password field
        document.getElementById('profile-password').value = '';

    } catch (e) {
        console.error(e);
        showToast("Error updating profile ❌");
    }
};


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
    console.log(`[DEBUG] Fetched ${exercises.length} exercises for ${trainerId}`);
    if (exercises.length > 0) {
        console.log("[DEBUG] First ex:", exercises[0].name, "Video:", exercises[0].video_id);
    }

    // Store exercises globally for other components (like Metrics) 
    if (!window.APP_STATE) window.APP_STATE = {};
    window.APP_STATE.exercises = exercises;

    // Store exercises globally for other components (like Metrics)
    if (!window.APP_STATE) window.APP_STATE = {};
    window.APP_STATE.exercises = exercises;

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

            // CLICK TO ADD TO WORKOUT
            if (onClick === 'addToWorkout') {
                div.style.cursor = 'pointer';
                div.addEventListener('click', () => {
                    if (typeof window.addExerciseToWorkout === 'function') {
                        window.addExerciseToWorkout(ex);
                    }
                });
            }

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
            // div.appendChild(editBtn); // REMOVED: This breaks the layout by moving the button out of the header

            // If no specific onClick action (Main List), do nothing (only edit button works)
            if (!onClick) {
                div.style.cursor = 'default';
            }

            container.appendChild(div);
        });
    };

    render();

    // Attach listeners to filters
    document.getElementById(searchId)?.addEventListener('input', render);
    document.getElementById(muscleId)?.addEventListener('change', render);
    document.getElementById(typeId)?.addEventListener('change', render);

    populateVideoSuggestions(exercises);
}


// --- DIET ASSIGNMENT ---
window.openAssignDietModal = async () => {
    const clientId = document.getElementById('client-modal').dataset.clientId;
    if (!clientId) {
        showToast("Error: No client selected");
        return;
    }

    document.getElementById('diet-client-id').value = clientId;

    // Ideally fetch current diet data to pre-fill
    // For now, we'll just show the modal empty or with placeholders
    // If we had an endpoint to get specific client details including diet, we'd call it here.
    // The client-modal is populated from `showClientModal` which gets data from `TRAINER_DATA` (summary).
    // We might need to fetch full client data.

    showModal('assign-diet-modal');
};

window.saveDietPlan = async () => {
    const clientId = document.getElementById('diet-client-id').value;
    const calories = parseInt(document.getElementById('diet-calories').value) || 0;
    const protein = parseInt(document.getElementById('diet-protein').value) || 0;
    const carbs = parseInt(document.getElementById('diet-carbs').value) || 0;
    const fat = parseInt(document.getElementById('diet-fat').value) || 0;
    const hydration = parseInt(document.getElementById('diet-hydration').value) || 2500;
    const consistency = parseInt(document.getElementById('diet-consistency').value) || 80;

    const payload = {
        client_id: clientId,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        hydration_target: hydration,
        consistency_target: consistency
    };

    try {
        const res = await fetch(`${apiBase}/api/trainer/assign_diet`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast("Diet plan assigned successfully! 🥗");
            hideModal('assign-diet-modal');
        } else {
            const err = await res.json();
            showToast(`Error: ${err.detail || 'Failed to assign diet'}`);
        }
    } catch (e) {
        console.error(e);
        showToast("Network error");
    }
};

// Click card action

function populateVideoSuggestions(exercises) {
    const dataList = document.getElementById('video-suggestions');
    if (!dataList) return;

    dataList.innerHTML = ''; // Clear existing
    const uniqueVideos = new Set();

    exercises.forEach(ex => {
        if (ex.video_id) {
            uniqueVideos.add(ex.video_id);
        }
    });

    uniqueVideos.forEach(vid => {
        const option = document.createElement('option');
        option.value = vid;
        dataList.appendChild(option);
    });
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

    // Initialize Exercise List for Modal
    initializeExerciseList({
        containerId: 'modal-exercise-library',
        searchId: 'modal-ex-search',
        muscleId: 'modal-ex-filter-muscle',
        typeId: 'modal-ex-filter-type',
        onClick: 'addToWorkout'
    });
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
        // Refresh calendar to show new assignment
        if (window.openTrainerCalendar) {
            window.openTrainerCalendar();
        }
    } else {
        showToast('Failed to assign workout');
    }
}

function adjustReps(delta) {
    if (!workoutState) return;
    workoutState.currentReps = Math.max(0, parseInt(workoutState.currentReps) + delta);
    document.getElementById('rep-counter').innerText = workoutState.currentReps;
}

// function completeSet() removed (duplicate)

async function finishWorkout() {
    // Call API to mark as complete
    try {
        const todayStr = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD local time

        // Disable button specific logic if needed, or show loading state

        const res = await fetch(`${apiBase}/api/client/schedule/complete`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                date: todayStr,
                exercises: workoutState.exercises // Send performance data
            })
        });

        if (res.ok) {
            console.log("Workout marked as complete on server");

            // Clear Cache to prevent stale data on reload
            localStorage.removeItem(getCacheKey());

            // Show Success UI ONLY after server confirms
            document.getElementById('celebration-overlay').classList.remove('hidden');
            startConfetti();

            // Update UI to show completed state
            const startBtn = document.querySelector('a[href*="mode=workout"]');
            if (startBtn) {
                startBtn.innerText = "COMPLETED ✓";
                startBtn.className = "block w-full py-3 bg-green-500 text-white text-center font-bold rounded-xl hover:bg-green-600 transition";
                // Append view=completed to existing href
                if (!startBtn.href.includes('view=completed')) {
                    if (startBtn.href.includes('?')) {
                        startBtn.href += "&view=completed";
                    } else {
                        startBtn.href += "?view=completed";
                    }
                }
            }
        } else {
            console.error("Failed to mark workout complete");
            const errText = await res.text();
            showToast("Failed to save workout: " + errText); // Show error to user
        }
    } catch (e) {
        console.error("Error finishing workout:", e);
        showToast("Error finishing workout. Please try again.");
    }
}

window.updateSetData = async function (exIdx, setIdx, reps, weight) {
    if (!workoutState) return;

    const ex = workoutState.exercises[exIdx];
    const setNum = setIdx + 1;
    const dateStr = new Date().toLocaleDateString('en-CA');

    const payload = {
        date: dateStr,
        workout_id: workoutState.workoutId,
        exercise_name: ex.name,
        set_number: setNum,
        reps: reps,
        weight: weight
    };

    try {
        const res = await fetch(`${apiBase}/api/client/schedule/update_set`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast("Set updated! 💾");
            // Update local state to reflect changes
            workoutState.exercises[exIdx].performance[setIdx].reps = reps;
            workoutState.exercises[exIdx].performance[setIdx].weight = weight;
        } else {
            const err = await res.text();
            showToast("Failed to update: " + err);
        }
    } catch (e) {
        console.error(e);
        showToast("Error updating set");
    }
};

// --- METRICS MODAL LOGIC ---

let metricsChartInstance = null;

function openMetricsModal(clientId = null) {
    if (!clientId) {
        // Try to get from client details modal dataset (most reliable source when opened from client card)
        const clientModal = document.getElementById('client-modal');
        if (clientModal && clientModal.dataset.clientId) {
            clientId = clientModal.dataset.clientId;
        } else {
            // Fallback to checking other potential sources if client modal isn't the source
            clientId = document.getElementById('diet-client-id')?.value ||
                document.getElementById('assign-client-id')?.value;
        }
    }

    if (!clientId) {
        showToast("Error: No client selected.");
        return;
    }

    document.getElementById('metrics-client-id').value = clientId;

    // Set Client Name if available
    const clientName = document.getElementById('modal-client-name').innerText;
    document.getElementById('metrics-client-name').innerText = `Performance Analytics for ${clientName}`;

    showModal('metrics-modal');

    // Reset Chart
    if (metricsChartInstance) {
        metricsChartInstance.destroy();
        metricsChartInstance = null;
    }

    // Clear search and show empty state
    document.getElementById('metrics-exercise-search').value = "";
    document.getElementById('metrics-search-suggestions').classList.add('hidden');

    // Maybe render empty chart or auto-fetch a common exercise?
    // Let's try to fetch "Bench Press" as a default to show something cool immediately
    // fetchExerciseMetrics(clientId, "Bench Press (Barbell)"); 
}

const metricsSearchInput = document.getElementById('metrics-exercise-search');
const metricsSuggestions = document.getElementById('metrics-search-suggestions');
let metricsDebounceTimer;

if (metricsSearchInput) {
    metricsSearchInput.addEventListener('input', (e) => {
        const query = e.target.value;
        clearTimeout(metricsDebounceTimer);

        if (query.length < 2) {
            metricsSuggestions.classList.add('hidden');
            return;
        }

        metricsDebounceTimer = setTimeout(() => {
            // Use global exercises list if available
            let options = [];
            if (window.APP_STATE && window.APP_STATE.exercises) {
                options = window.APP_STATE.exercises.map(ex => ex.name);
            } else {
                // Fallback to video suggestions if APP_STATE not ready (unlikely in trainer mode)
                const datalist = document.getElementById('video-suggestions');
                if (datalist) {
                    options = Array.from(datalist.options).map(o => o.value);
                }
            }

            // Deduplicate and Filter
            const uniqueOptions = [...new Set(options)];
            const matches = uniqueOptions.filter(name => name.toLowerCase().includes(query.toLowerCase())).slice(0, 10);

            renderMetricsSuggestions(matches);
        }, 300);
    });
}

function renderMetricsSuggestions(matches) {
    metricsSuggestions.innerHTML = '';
    if (matches.length === 0) {
        metricsSuggestions.classList.add('hidden');
        return;
    }

    matches.forEach(name => {
        const li = document.createElement('li');
        li.className = "px-4 py-2 hover:bg-white/10 cursor-pointer text-sm text-gray-300";
        li.innerText = name;
        li.onclick = () => {
            document.getElementById('metrics-exercise-search').value = name;
            metricsSuggestions.classList.add('hidden');
            const clientId = document.getElementById('metrics-client-id').value;
            fetchExerciseMetrics(clientId, name);
        };
        metricsSuggestions.appendChild(li);
    });
    metricsSuggestions.classList.remove('hidden');
}

async function fetchExerciseMetrics(clientId, exerciseName) {
    if (!exerciseName) return;

    try {
        const response = await fetch(`${APP_CONFIG.apiBase}/api/client/${clientId}/history?exercise_name=${encodeURIComponent(exerciseName)}`);
        if (!response.ok) throw new Error("Failed to fetch history");

        const history = await response.json();
        renderExerciseChart(history, exerciseName);

    } catch (e) {
        console.error(e);
        showToast("Error loading metrics.");
    }
}

function renderExerciseChart(history, exerciseName) {
    const ctx = document.getElementById('exerciseProgressChart');
    if (!ctx) return;

    if (metricsChartInstance) {
        metricsChartInstance.destroy();
    }

    if (!history || history.length === 0) {
        // Show "No Data" message on canvas?
        // Or just an empty chart
        showToast(`No history found for ${exerciseName}`);
        return;
    }

    // Format Data
    const labels = history.map(h => new Date(h.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }));
    const weights = history.map(h => h.max_weight);
    // const reps = history.map(h => h.total_reps);

    metricsChartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Max Weight (kg)',
                data: weights,
                borderColor: '#4CAF50', // Green
                backgroundColor: 'rgba(76, 175, 80, 0.2)',
                borderWidth: 2,
                tension: 0.4, // Smooth curves
                pointBackgroundColor: '#fff',
                pointRadius: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    labels: { color: '#fff' }
                },
                title: {
                    display: true,
                    text: `${exerciseName} Progress`,
                    color: '#fff',
                    font: { size: 16 }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(255,255,255,0.1)' },
                    ticks: { color: '#aaa' }
                },
                x: {
                    grid: { color: 'rgba(255,255,255,0.1)' },
                    ticks: { color: '#aaa' }
                }
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
        const urlParams = new URLSearchParams(window.location.search);
        const isCompletedView = urlParams.get('view') === 'completed';

        if (isCompletedView) {
            // Hide controls
            const completeBtn = document.getElementById('complete-btn');
            if (completeBtn) completeBtn.style.display = 'none';

            const repBtns = document.querySelectorAll('[data-action="adjustReps"]');
            repBtns.forEach(btn => btn.style.display = 'none');

            // Show banner
            const header = document.querySelector('#workout-screen .absolute.top-0.left-0');
            if (header) {
                const banner = document.createElement('div');
                banner.className = "absolute top-20 left-1/2 transform -translate-x-1/2 bg-green-500/90 text-white px-4 py-1 rounded-full text-xs font-bold backdrop-blur-md z-50";
                banner.innerText = "COMPLETED VIEW";
                header.appendChild(banner);
            }
        }

        fetch(`${apiBase}/api/client/data`)
            .then(res => res.json())
            .then(user => {
                const workout = user.todays_workout;

                if (!workout) {
                    // Rest Day Logic
                    document.getElementById('exercise-name').innerText = "Rest Day";
                    document.getElementById('exercise-target').innerText = "Take it easy and recover! 🧘";
                    document.getElementById('workout-screen').innerHTML = `
                        <div class="flex flex-col items-center justify-center h-screen bg-gray-900 text-white p-8 text-center">
                            <div class="text-6xl mb-4">🧘</div>
                            <h1 class="text-4xl font-black mb-2">Rest Day</h1>
                            <p class="text-gray-400 mb-8">No workout scheduled for today. Enjoy your recovery!</p>
                            <a href="/?gym_id=${gymId}&role=client" class="px-8 py-3 bg-white/10 rounded-xl font-bold hover:bg-white/20 transition">Back to Dashboard</a>
                        </div>
                    `;
                    return;
                }

                // Store global user ID for cache keys
                window.currentUserId = user.id;

                workoutState = {
                    workoutId: workout.id, // Needed for cache key
                    exercises: workout.exercises.map(ex => ({
                        ...ex,
                        collapsed: false, // Init collapsed state
                        performance: ex.performance || Array(ex.sets).fill().map(() => ({ reps: '', weight: '', completed: false }))
                    })),
                    currentExerciseIdx: 0,
                    currentSet: 1,
                    currentReps: parseInt(String(workout.exercises[0].reps).split('-')[1] || workout.exercises[0].reps),
                    isCompletedView: isCompletedView // Store in state
                };

                // Restore from cache if available, but only if NOT completed
                if (!workout.completed) {
                    loadProgress();
                } else {
                    console.log("Workout already completed. Using DB snapshot.");
                }

                // Populate Routine List
                // Initial empty populate, real render happens in updateWorkoutUI
                updateWorkoutUI();
            });
    }
});

// Helper to update performance data
window.updatePerformance = function (exIdx, setIdx, field, val) {
    if (workoutState && workoutState.exercises[exIdx]) {
        workoutState.exercises[exIdx].performance[setIdx][field] = val;
        saveProgress(); // Auto-save
    }
}

window.toggleSetComplete = function (exIdx, setIdx, event) {
    if (event) event.stopPropagation();
    if (!workoutState || !workoutState.exercises[exIdx]) return;

    // Toggle state
    const currentState = workoutState.exercises[exIdx].performance[setIdx].completed;
    workoutState.exercises[exIdx].performance[setIdx].completed = !currentState;

    saveProgress(); // Auto-save
    updateWorkoutUI();
};

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

window.toggleCollapse = function (idx, event) {
    if (event) event.stopPropagation();
    if (!workoutState || !workoutState.exercises[idx]) return;

    workoutState.exercises[idx].collapsed = !workoutState.exercises[idx].collapsed;
    saveProgress(); // Auto-save
    updateWorkoutUI();
}

// --- PERSISTENCE HELPERS ---

function getCacheKey() {
    // Include DATE in key to separate workouts across days
    if (!window.currentUserId || !workoutState || !workoutState.workoutId) return null;
    const dateStr = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD local
    return `gym_cache_${window.currentUserId}_workout_${workoutState.workoutId}_${dateStr}`;
}

function saveProgress() {
    const key = getCacheKey();
    if (!key) return;

    const dataToSave = {
        exercises: workoutState.exercises.map(ex => ({
            id: ex.id,
            performance: ex.performance,
            collapsed: ex.collapsed
        })),
        timestamp: Date.now()
    };

    localStorage.setItem(key, JSON.stringify(dataToSave));
}

function loadProgress() {
    const key = getCacheKey();
    if (!key) return;

    const cached = localStorage.getItem(key);
    if (!cached) return;

    try {
        const data = JSON.parse(cached);

        // Merge data
        data.exercises.forEach((savedEx, idx) => {
            if (workoutState.exercises[idx] && workoutState.exercises[idx].id === savedEx.id) {
                // RESTORE ALL FIELDS (Weight, Reps, Completed)
                if (savedEx.performance) {
                    savedEx.performance.forEach((p, setIdx) => {
                        if (workoutState.exercises[idx].performance[setIdx]) {
                            workoutState.exercises[idx].performance[setIdx].weight = p.weight;
                            workoutState.exercises[idx].performance[setIdx].reps = p.reps;
                            workoutState.exercises[idx].performance[setIdx].completed = p.completed;
                        }
                    });
                }
                workoutState.exercises[idx].collapsed = savedEx.collapsed || false;
            }
        });
        console.log("Progress fully restored from daily cache");
    } catch (e) {
        console.error("Failed to load progress", e);
    }
}

function completeSet() {
    if (!workoutState) return;

    const exId = workoutState.currentExerciseIdx;
    const setId = workoutState.currentSet - 1; // 0-indexed

    // VALIDATION: Check if weight is entered
    if (workoutState.exercises[exId] && workoutState.exercises[exId].performance[setId]) {
        const currentPerf = workoutState.exercises[exId].performance[setId];

        if (!currentPerf.weight && currentPerf.weight !== 0) {
            showToast("Please enter weight for this set! ⚖️");
            return;
        }

        // AUTO-FILL REPS from Main Counter
        currentPerf.reps = workoutState.currentReps;
        currentPerf.completed = true; // Mark as done

        // AUTO-FILL NEXT SET WEIGHT
        const nextSetPerf = workoutState.exercises[exId].performance[setId + 1];
        if (nextSetPerf) {
            // Only auto-fill if next set has no weight yet
            if (!nextSetPerf.weight && nextSetPerf.weight !== 0) {
                nextSetPerf.weight = currentPerf.weight;
            }
        }

        saveProgress(); // Save the new data
    }

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
                finishWorkout();
            }
        }
    });
}

function updateWorkoutUI() {
    if (!workoutState) return;

    const ex = workoutState.exercises[workoutState.currentExerciseIdx];

    // Update Header & Counters
    document.getElementById('exercise-name').innerText = ex.name;
    document.getElementById('exercise-target').innerText = `Set ${workoutState.currentSet}/${ex.sets} • Target: ${ex.reps} Reps`;
    document.getElementById('rep-counter').innerText = workoutState.currentReps;

    // Update Video
    const videoEl = document.getElementById('exercise-video');
    const repVideoEl = document.getElementById('rep-counter-video');

    let src = ex.video_id ? ex.video_id.trim() : '';

    if (src && !src.startsWith('http') && !src.startsWith('/')) {
        src = `/static/videos/${src}.mp4`;
    }

    const newSrc = src ? `${src}?v=${Date.now()}` : '';

    // Force update to ensure we aren't stuck on old video
    if (newSrc) {
        // Reset error state
        videoEl.style.border = "none";

        // Add error listener to catch broken paths
        videoEl.onerror = (e) => {
            console.error("Video failed to load:", newSrc, e);
            videoEl.style.border = "5px solid red"; // Visual indicator
            showToast("Video failed to load: " + newSrc.split('/').pop());
        };

        // Update Main Video
        videoEl.src = newSrc;
        videoEl.load();
        videoEl.muted = true; // Force muted for autoplay policy

        const playPromise = videoEl.play();
        if (playPromise !== undefined) {
            playPromise.catch(error => {
                console.log("Autoplay prevented:", error);
                // Try again muted (already muted but just in case)
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

            if (isCurrent) {
                // EXPANDED ACTIVE CARD
                // Use glass-card class + glow for distinct active state
                div.className = `glass-card p-5 mb-6 relative overflow-visible transition-all duration-500 transform scale-[1.02] border-2 border-primary/50 shadow-2xl shadow-primary/20`;
                div.onclick = null; // Disable collapse on click

                // Active Indicator (Background Glow)
                const glow = document.createElement('div');
                glow.className = "absolute top-0 right-0 w-32 h-32 bg-primary/20 blur-[50px] rounded-full pointer-events-none -mr-10 -mt-10";
                div.appendChild(glow);

                // Generate Sets Rows
                // Add disable logic
                const isDisabled = workoutState.isCompletedView ? 'disabled' : '';
                // Adjusted input styling
                const baseInputClass = "w-full bg-transparent border-none text-white text-right font-black outline-none text-xl font-mono placeholder-white/20";
                const inputClass = isDisabled ? `${baseInputClass} opacity-50 cursor-not-allowed` : baseInputClass;

                let setsHtml = '';
                for (let i = 0; i < item.sets; i++) {
                    const perf = item.performance[i];

                    const isSetCompleted = perf.completed;
                    const isSetActive = (i === (workoutState.currentSet - 1));

                    // Dynamic styles
                    let rowClass = "grid grid-cols-[1.5fr,1fr,1fr] gap-4 mb-3 items-center relative z-10 transition-all duration-300 rounded-xl p-2";
                    let currentInputClass = inputClass; // Create a copy of const inputClass
                    let statusIcon = "";

                    if (isSetCompleted) {
                        rowClass += " bg-green-500/10 border border-green-500/20"; // Removed opacity-60
                        statusIcon = `<div class="absolute left-2 top-1/2 transform -translate-y-1/2 w-6 h-6 bg-green-500 rounded-full flex items-center justify-center text-black font-bold text-xs shadow-lg shadow-green-500/50 z-20">✓</div>`;
                        currentInputClass += " cursor-not-allowed text-white opacity-80"; // Changed to text-white for visibility
                    } else if (isSetActive) {
                        rowClass += " bg-primary/10 border border-primary/40 ring-1 ring-primary/20"; // Active look
                        statusIcon = `<div class="absolute left-2 top-1/2 transform -translate-y-1/2 w-6 h-6 bg-primary rounded-full flex items-center justify-center text-black font-bold text-xs shadow-lg shadow-primary/50 z-20 animate-pulse">▶</div>`;
                    } else {
                        rowClass += " border border-transparent"; // Pending
                    }

                    // Disable inputs if completed
                    const isInputDisabled = isDisabled || isSetCompleted ? 'disabled' : '';

                    // EDIT MODE LOGIC
                    let editBtnHtml = '';
                    if (workoutState.isCompletedView) {
                        // Check if this specific set is in edit mode
                        const isEditing = perf.isEditing || false;

                        if (isEditing) {
                            // Enable inputs
                            currentInputClass = baseInputClass + " border-b border-primary";
                            // Save Button
                            editBtnHtml = `
                                <button onclick="event.stopPropagation(); window.updateSetData(${idx}, ${i}, this.closest('.grid').querySelector('input[placeholder=\\'${item.reps}\\']').value, this.closest('.grid').querySelector('input[placeholder=\\'-\\' ]').value); workoutState.exercises[${idx}].performance[${i}].isEditing = false; updateWorkoutUI();" 
                                    class="absolute -right-2 top-1/2 transform -translate-y-1/2 w-8 h-8 bg-green-500 rounded-full flex items-center justify-center text-black shadow-lg z-30 hover:scale-110 transition">
                                    💾
                                </button>
                            `;
                        } else {
                            // Edit Button
                            editBtnHtml = `
                                <button onclick="event.stopPropagation(); workoutState.exercises[${idx}].performance[${i}].isEditing = true; updateWorkoutUI();" 
                                    class="absolute -right-2 top-1/2 transform -translate-y-1/2 w-8 h-8 bg-white/10 rounded-full flex items-center justify-center text-gray-300 shadow-lg z-30 hover:bg-white/20 hover:text-white transition">
                                    ✏️
                                </button>
                            `;
                        }
                    }

                    setsHtml += `
                        <div class="${rowClass}">
                            ${statusIcon}
                            <span class="text-sm font-bold text-gray-400 tracking-widest pl-10 font-mono uppercase ${isSetActive ? 'text-primary' : ''}">Set ${i + 1}</span>
                            <div class="flex items-center bg-black/40 border border-white/10 rounded-xl px-3 py-3 focus-within:border-primary/80 focus-within:bg-black/60 transition duration-300 shadow-inner">
                                <input type="number" value="${perf.reps}" 
                                    oninput="window.updatePerformance(${idx}, ${i}, 'reps', this.value)"
                                    onclick="event.stopPropagation()"
                                    ${workoutState.isCompletedView && !perf.isEditing ? 'disabled' : (isInputDisabled && !perf.isEditing ? 'disabled' : '')}
                                    class="${currentInputClass}" placeholder="${item.reps}">
                                <span class="text-[10px] text-gray-500 font-bold ml-2 mt-1 tracking-wider">REPS</span>
                            </div>
                            <div class="flex items-center bg-black/40 border border-white/10 rounded-xl px-3 py-3 focus-within:border-primary/80 focus-within:bg-black/60 transition duration-300 shadow-inner">
                                <input type="number" value="${perf.weight}" 
                                    oninput="window.updatePerformance(${idx}, ${i}, 'weight', this.value)"
                                    onclick="event.stopPropagation()"
                                    ${workoutState.isCompletedView && !perf.isEditing ? 'disabled' : (isInputDisabled && !perf.isEditing ? 'disabled' : '')}
                                    class="${currentInputClass}" placeholder="-">
                                <span class="text-[10px] text-gray-500 font-bold ml-2 mt-1 tracking-wider text-white">KG</span>
                            </div>
                            ${editBtnHtml}
                        </div>
                     `;
                }

                const isCollapsed = item.collapsed || false;
                const chevronRotate = isCollapsed ? '-rotate-90' : 'rotate-0';

                // Badge Logic
                const isAllDetailedCompleted = item.performance.every(p => p.completed);
                let badgeHtml = '';
                if (isAllDetailedCompleted) {
                    badgeHtml = `
                    <span class="text-[10px] font-black text-white bg-green-500 px-3 py-1 rounded-full shadow-lg shadow-green-500/40 tracking-widest uppercase items-center flex gap-1">
                        <span class="w-2 h-2 bg-white rounded-full"></span> Done
                    </span>`;
                } else {
                    badgeHtml = `
                    <span class="text-[10px] font-black text-white bg-red-500 px-3 py-1 rounded-full shadow-lg shadow-red-500/40 tracking-widest uppercase items-center flex gap-1">
                        <span class="w-2 h-2 bg-white rounded-full animate-ping"></span> Active
                    </span>`;
                }

                div.innerHTML += `
                    <div class="flex items-center justify-between mb-6 pb-4 border-b border-white/10 relative z-10 cursor-pointer group"
                        onclick="window.toggleCollapse(${idx}, event)">
                        <div class="flex items-center space-x-4">
                            <div class="w-12 h-12 rounded-full bg-primary text-black flex items-center justify-center font-black animate-pulse text-xl shadow-lg shadow-primary/50">▶</div>
                            <div>
                                <h4 class="font-black text-white text-2xl tracking-tight leading-none mb-1 drop-shadow-md">${item.name}</h4>
                                <p class="text-xs text-primary font-bold tracking-widest uppercase opacity-90">${item.sets} Sets • ${item.reps} Target</p>
                            </div>
                        </div>
                        <div class="flex items-center gap-3">
                             ${badgeHtml}
                            <div class="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center transition-transform duration-300 ${chevronRotate} group-hover:bg-white/20">
                                ▼
                            </div>
                        </div>
                    </div>
                    
                    <div class="space-y-2 relative z-10 transition-all duration-300 overflow-hidden ${isCollapsed ? 'max-h-0 opacity-0' : 'max-h-[1000px] opacity-100'}">
                        ${setsHtml}
                    </div>
                `;

            } else {
                // COMPACT CARD (Inactive)
                div.className = `p-3 rounded-xl flex items-center mb-2 cursor-pointer transition-all hover:bg-white/5 border border-transparent opacity-60 hover:opacity-100`;
                div.onclick = () => window.switchExercise(idx);

                let icon = `<div class="w-8 h-8 rounded-full bg-white/10 flex items-center justify-center mr-3 text-xs text-gray-400 font-bold">${idx + 1}</div>`;
                if (idx < workoutState.currentExerciseIdx || workoutState.isCompletedView) {
                    icon = '<div class="w-8 h-8 rounded-full bg-green-500 text-black flex items-center justify-center mr-3 font-bold">✓</div>';
                }

                div.innerHTML = `
                    <div class="flex items-center space-x-4 pointer-events-none w-full">
                        ${icon}
                        <div class="flex-1">
                            <h4 class="font-bold text-white text-sm">${item.name}</h4>
                            <p class="text-xs text-gray-400">${item.sets} Sets • ${item.reps} Reps</p>
                        </div>
                        ${idx < workoutState.currentExerciseIdx ? '<span class="text-xs text-green-400 font-bold">Done</span>' : ''}
                    </div>
                `;
            }

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
    let completedExercises = workoutState.currentExerciseIdx;

    if (workoutState.isCompletedView) {
        completedExercises = totalExercises;
    }

    const progressPct = Math.round((completedExercises / totalExercises) * 100);
    const progressEl = document.getElementById('routine-progress');
    if (progressEl) progressEl.innerText = `${progressPct}% Complete`;

    // Update Progress Bar
    const totalSets = workoutState.exercises.reduce((acc, curr) => acc + curr.sets, 0);
    let completedSets = 0;

    if (workoutState.isCompletedView) {
        completedSets = totalSets;
    } else {
        for (let i = 0; i < workoutState.currentExerciseIdx; i++) {
            completedSets += workoutState.exercises[i].sets;
        }
        completedSets += (workoutState.currentSet - 1);
    }

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

// --- SPLIT ASSIGNMENT LOGIC ---

window.openAssignSplitModal = async function () {
    const clientId = document.getElementById('client-modal').dataset.clientId;
    if (!clientId) {
        showToast('Error: No client selected');
        return;
    }

    document.getElementById('assign-split-client-id').value = clientId;

    // Fetch splits
    try {
        const trainerId = getCurrentTrainerId();
        const res = await fetch(`${apiBase}/api/trainer/splits`, {
            headers: { 'x-trainer-id': trainerId }
        });
        const splits = await res.json();

        const select = document.getElementById('assign-split-select');
        select.innerHTML = '';

        if (splits.length === 0) {
            const option = document.createElement('option');
            option.text = "No splits available";
            select.appendChild(option);
        } else {
            splits.forEach(s => {
                const option = document.createElement('option');
                option.value = s.id;
                option.text = s.name;
                select.appendChild(option);
            });
        }

        // Set default date to next Monday
        const today = new Date();
        const nextMonday = new Date(today);
        nextMonday.setDate(today.getDate() + (1 + 7 - today.getDay()) % 7 || 7);
        document.getElementById('assign-split-date').value = nextMonday.toISOString().split('T')[0];

        showModal('assign-split-modal');
    } catch (e) {
        console.error("Error fetching splits:", e);
        showToast('Failed to load splits');
    }
}

window.assignSplit = async function () {
    const clientId = document.getElementById('assign-split-client-id').value;
    const splitId = document.getElementById('assign-split-select').value;
    const startDate = document.getElementById('assign-split-date').value;

    if (!clientId || !splitId || !startDate) {
        showToast('Please fill in all fields');
        return;
    }

    try {
        const trainerId = getCurrentTrainerId();
        const res = await fetch(`${apiBase}/api/trainer/assign_split`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify({
                client_id: clientId,
                split_id: splitId,
                start_date: startDate
            })
        });

        if (res.ok) {
            showToast('Split assigned successfully! 📅');
            hideModal('assign-split-modal');
        } else {
            const err = await res.text();
            showToast('Failed: ' + err);
        }
    } catch (e) {
        console.error(e);
        showToast('Error assigning split');
    }
}

window.openSchedulePicker = function () {
    const clientId = document.getElementById('assign-split-client-id').value;
    if (clientId) {
        // Enable Date Picker Mode
        window.datePickerMode = true;
        window.onDatePicked = (dateStr) => {
            document.getElementById('assign-split-date').value = dateStr;
            hideModal('calendar-modal');
            window.datePickerMode = false; // Reset
            window.onDatePicked = null;
        };

        openTrainerCalendar(clientId);

        // Add a listener to reset mode if modal is closed without picking
        const modal = document.getElementById('calendar-modal');
        const resetMode = () => {
            window.datePickerMode = false;
            window.onDatePicked = null;
            modal.removeEventListener('click', checkClose);
        };

        const checkClose = (e) => {
            if (e.target === modal || e.target.dataset.action === 'hideModal') {
                resetMode();
            }
        };

        // We need to attach this safely, maybe just relying on the hideModal global function is enough if we hook into it,
        // but for now, let's just ensure if they click X it resets.
        // Actually, renderCalendar is called every time, so the mode state is what matters.
        // If we close the modal, the next time we open it for normal viewing, we want mode to be false.
        // So we should ensure it's false by default or reset it when opening normally.
    } else {
        showToast('No client selected');
    }
}

// Ensure normal calendar open resets the mode
const originalOpenTrainerCalendar = window.openTrainerCalendar;
window.openTrainerCalendar = async (explicitClientId) => {
    if (!window.datePickerMode) {
        window.datePickerMode = false;
        window.onDatePicked = null;
    }
    await originalOpenTrainerCalendar(explicitClientId);
};

// --- SPLIT CREATION LOGIC ---

let splitScheduleState = {
    Monday: null,
    Tuesday: null,
    Wednesday: null,
    Thursday: null,
    Friday: null,
    Saturday: null,
    Sunday: null
};

window.openCreateSplitModal = function () {
    document.getElementById('new-split-name').value = '';
    document.getElementById('new-split-desc').value = '';

    // Reset State
    splitScheduleState = {
        Monday: null,
        Tuesday: null,
        Wednesday: null,
        Thursday: null,
        Friday: null,
        Saturday: null,
        Sunday: null
    };

    renderSplitScheduleBuilder();
    showModal('create-split-modal');
}

function renderSplitScheduleBuilder() {
    const container = document.getElementById('split-schedule-builder');
    if (!container) return;

    container.innerHTML = '';
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    days.forEach(day => {
        const div = document.createElement('div');
        div.className = "flex items-center justify-between bg-white/5 p-3 rounded-xl";

        const workoutId = splitScheduleState[day];
        let content = `<span class="text-gray-500 italic text-xs">Rest Day</span>`;

        if (workoutId) {
            content = `<span class="text-primary font-bold text-xs">Workout Assigned</span>`;
        }

        div.innerHTML = `
            <span class="text-sm font-bold text-white w-24">${day}</span>
            <div class="flex-1 mx-4 text-center">${content}</div>
            <button onclick="openSplitWorkoutSelector('${day}')" class="text-xs bg-white/10 px-2 py-1 rounded hover:bg-white/20 transition">
                ${workoutId ? 'Change' : '+ Add Workout'}
            </button>
        `;
        container.appendChild(div);
    });
}

window.openSplitWorkoutSelector = async function (day) {
    const trainerId = getCurrentTrainerId();
    const res = await fetch(`${apiBase}/api/trainer/workouts`, {
        headers: { 'x-trainer-id': trainerId }
    });
    const workouts = await res.json();

    const overlay = document.createElement('div');
    overlay.className = "fixed inset-0 bg-black/90 z-[70] flex items-center justify-center p-4 backdrop-blur-sm";

    let options = `<option value="">Rest Day</option>`;
    workouts.forEach(w => {
        options += `<option value="${w.id}">${w.title}</option>`;
    });

    overlay.innerHTML = `
        <div class="bg-[#1a1a1a] w-full max-w-sm rounded-3xl p-6 border border-white/10 relative slide-up">
            <h2 class="text-xl font-bold mb-4 text-white">Select Workout for ${day}</h2>
            <select id="temp-split-selector" class="w-full bg-white/5 border border-white/10 rounded-xl p-3 text-white focus:border-primary outline-none transition mb-4">
                ${options}
            </select>
            <div class="flex gap-2">
                <button id="btn-cancel-split-sel" class="flex-1 py-3 bg-white/10 text-white font-bold rounded-xl">Cancel</button>
                <button id="btn-confirm-split-sel" class="flex-1 py-3 bg-primary text-black font-bold rounded-xl">Confirm</button>
            </div>
        </div>
    `;

    document.body.appendChild(overlay);

    document.getElementById('btn-cancel-split-sel').onclick = () => overlay.remove();
    document.getElementById('btn-confirm-split-sel').onclick = () => {
        const val = document.getElementById('temp-split-selector').value;
        splitScheduleState[day] = val || null;
        renderSplitScheduleBuilder();
        overlay.remove();
    };
}

window.createSplit = async function () {
    const name = document.getElementById('new-split-name').value;
    const desc = document.getElementById('new-split-desc').value;

    if (!name) {
        showToast('Please enter a split name');
        return;
    }

    const payload = {
        name: name,
        description: desc,
        schedule: splitScheduleState
    };

    try {
        const trainerId = getCurrentTrainerId();
        const res = await fetch(`${apiBase}/api/trainer/splits`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast('Split created successfully! 🎉');
            hideModal('create-split-modal');
        } else {
            showToast('Failed to create split');
        }
    } catch (e) {
        console.error(e);
        showToast('Error creating split');
    }
}
