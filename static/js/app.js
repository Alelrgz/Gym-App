const { gymId, role, apiBase } = window.APP_CONFIG;
console.log("App.js loaded! apiBase: " + apiBase);
console.log("App.js loaded (Restored Monolithic) v" + Math.random());

// --- AUTHENTICATION ---
// Bootstrap from Server if valid token present in config
if (window.APP_CONFIG.token && window.APP_CONFIG.token !== "None") {
    console.log("Bootstrapping auth from server...");
    localStorage.setItem('token', window.APP_CONFIG.token);
    localStorage.setItem('role', window.APP_CONFIG.role);
}

if (!localStorage.getItem('token') && window.location.pathname !== '/auth/login' && window.location.pathname !== '/auth/register') {
    // Check if we are on a public page or not
    // Simple check: if not login/register page specific
    window.location.href = '/auth/login';
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
    console.log("FETCH Request:", url, "Headers:", options.headers);

    try {
        const response = await originalFetch(url, options);
        if (response.status === 401 && window.location.pathname !== '/auth/login') {
            localStorage.removeItem('token');
            window.location.href = '/auth/login';
        }
        return response;
    } catch (e) {
        throw e;
    }
};

function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('role');
    window.location.href = '/auth/logout';
}
window.logout = logout;

// --- BIO FUNCTIONS ---
async function loadTrainerBio() {
    try {
        const response = await fetch('/api/profile/bio', {
            credentials: 'include'
        });
        if (response.ok) {
            const data = await response.json();
            const bioInput = document.getElementById('trainer-bio-input');
            const charCount = document.getElementById('bio-char-count');
            if (bioInput && data.bio) {
                bioInput.value = data.bio;
                if (charCount) {
                    charCount.textContent = `${data.bio.length}/300`;
                }
            }
        }
    } catch (error) {
        console.error('Error loading bio:', error);
    }
}
window.loadTrainerBio = loadTrainerBio;

async function saveTrainerBio() {
    const bioInput = document.getElementById('trainer-bio-input');
    if (!bioInput) return;

    const bio = bioInput.value.trim();

    try {
        const formData = new FormData();
        formData.append('bio', bio);

        const response = await fetch('/api/profile/bio', {
            method: 'POST',
            credentials: 'include',
            body: formData
        });

        if (response.ok) {
            showToast('Bio saved successfully!', 'success');
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to save bio', 'error');
        }
    } catch (error) {
        console.error('Error saving bio:', error);
        showToast('Failed to save bio', 'error');
    }
}
window.saveTrainerBio = saveTrainerBio;

// Bio character counter
document.addEventListener('DOMContentLoaded', function() {
    const bioInput = document.getElementById('trainer-bio-input');
    const charCount = document.getElementById('bio-char-count');

    if (bioInput && charCount) {
        bioInput.addEventListener('input', function() {
            charCount.textContent = `${this.value.length}/300`;
        });
    }
});

// --- TRAINER SPECIALTIES (Checkbox-based) ---
let currentSpecialties = [];

// Map checkbox IDs to specialty values
const specialtyMapping = {
    'spec-bodybuilding': 'Bodybuilding',
    'spec-crossfit': 'Crossfit',
    'spec-calisthenics': 'Calisthenics',
    'spec-cardio': 'Cardio',
    'spec-hiit': 'HIIT',
    'spec-yoga': 'Yoga',
    'spec-boxing': 'Boxing',
    'spec-rehab': 'Rehabilitation'
};

async function loadTrainerSpecialties() {
    try {
        const response = await fetch('/api/profile/specialties', {
            credentials: 'include'
        });
        if (response.ok) {
            const data = await response.json();
            currentSpecialties = data.specialties || [];

            // Update checkboxes based on saved specialties
            Object.entries(specialtyMapping).forEach(([checkboxId, value]) => {
                const checkbox = document.getElementById(checkboxId);
                if (checkbox) {
                    checkbox.checked = currentSpecialties.includes(value);
                }
            });
        }
    } catch (error) {
        console.error('Error loading specialties:', error);
    }
}
window.loadTrainerSpecialties = loadTrainerSpecialties;

function updateSpecialties() {
    // Collect all checked specialties
    currentSpecialties = [];
    Object.entries(specialtyMapping).forEach(([checkboxId, value]) => {
        const checkbox = document.getElementById(checkboxId);
        if (checkbox && checkbox.checked) {
            currentSpecialties.push(value);
        }
    });

    // Auto-save when specialties change
    saveSpecialties();
}
window.updateSpecialties = updateSpecialties;

async function saveSpecialties() {
    try {
        const formData = new FormData();
        formData.append('specialties', currentSpecialties.join(','));

        const response = await fetch('/api/profile/specialties', {
            method: 'POST',
            credentials: 'include',
            body: formData
        });

        if (response.ok) {
            showToast('Specialties updated!', 'success');
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to save specialties', 'error');
        }
    } catch (error) {
        console.error('Error saving specialties:', error);
        showToast('Failed to save specialties', 'error');
    }
}

// --- MODAL UTILS ---
window.showModal = function (id) {
    const el = document.getElementById(id);
    if (el) {
        el.classList.remove('hidden');

        // Load bio and specialties when profile-modal opens (for trainers)
        if (id === 'profile-modal') {
            if (typeof loadTrainerBio === 'function') {
                loadTrainerBio();
            }
            if (typeof loadTrainerSpecialties === 'function') {
                loadTrainerSpecialties();
            }
        }
    } else {
        console.error("Modal not found:", id);
    }
};

window.hideModal = function (id) {
    const el = document.getElementById(id);
    if (el) {
        el.classList.add('hidden');
    }
};

window.showToast = function (message, duration = 3000) {
    let container = document.getElementById('toast-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toast-container';
        container.className = 'fixed top-4 left-1/2 transform -translate-x-1/2 z-[100] flex flex-col items-center space-y-2 pointer-events-none';
        document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = 'bg-white/10 backdrop-blur-md border border-white/20 text-white px-4 py-2 rounded-full shadow-lg text-sm font-bold slide-down pointer-events-auto';
    toast.innerText = message;

    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
    }, duration);
};

// Global Action Listener
document.addEventListener('click', (e) => {
    const trigger = e.target.closest('[data-action]');
    if (trigger) {
        const action = trigger.dataset.action;
        const target = trigger.dataset.target;

        if (action === 'showModal' && target) {
            window.showModal(target);
        } else if (action === 'hideModal' && target) {
            window.hideModal(target);
        } else if (action === 'showToast') {
            const msg = trigger.dataset.message;
            if (window.showToast && msg) window.showToast(msg);
        }
    }
});

// Debug logout button removed (moved to Settings modal)
/*
document.addEventListener('DOMContentLoaded', () => {
   // ... removed ...
});
*/

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
let allClients = []; // Global state for client roster

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

        // Determine icon and color based on event type
        let icon, statusColor;
        if (e.type === 'course') {
            icon = '📚';
            statusColor = e.completed ? 'text-green-400' : 'text-purple-400';
        } else if (e.type === 'workout') {
            icon = '💪';
            statusColor = e.completed ? 'text-green-400' : 'text-orange-400';
        } else if (e.type === 'appointment') {
            icon = '📅';
            statusColor = e.completed ? 'text-green-400' : 'text-blue-400';
        } else {
            icon = '🧘';
            statusColor = e.completed ? 'text-green-400' : 'text-orange-400';
        }

        // Add edit/delete buttons for course events if trainer
        const isCourseEvent = e.type === 'course' && e.course_id;
        const courseActions = isCourseEvent && isTrainer ? `
            <div class="flex items-center gap-2 ml-2">
                <button onclick="event.stopPropagation(); window.editScheduleEvent('${e.id}', '${e.date}', '${e.time}', '${e.title}')"
                    class="text-white/50 hover:text-white text-xs px-2 py-1 rounded bg-white/10 hover:bg-white/20 transition">✏️</button>
                <button onclick="event.stopPropagation(); window.deleteScheduleEvent('${e.id}', '${e.title}')"
                    class="text-white/50 hover:text-red-400 text-xs px-2 py-1 rounded bg-white/10 hover:bg-red-500/20 transition">🗑️</button>
            </div>
        ` : '';

        div.innerHTML = `
            <div class="flex items-center flex-1">
                <span class="text-xl mr-3">${icon}</span>
                <div>
                    <p class="text-sm font-bold text-white">${e.title}</p>
                    <p class="text-[10px] text-gray-400">
                        ${isCourseEvent ? `Group Course • ${e.time || ''}` : ((e.details && (e.details.startsWith('[') || e.details.startsWith('{'))) ? 'Workout Data Saved' : (e.details || e.subtitle || ''))}
                    </p>
                </div>
            </div>
            <div class="flex items-center">
                <span class="text-xs font-bold ${statusColor}">${e.completed ? 'COMPLETED' : 'SCHEDULED'}</span>
                ${courseActions}
            </div>
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
                let dotColor;
                if (e.type === 'course') {
                    dotColor = e.completed ? 'bg-green-400' : 'bg-purple-400';
                } else if (e.type === 'appointment') {
                    dotColor = e.completed ? 'bg-green-400' : 'bg-blue-400';
                } else {
                    dotColor = e.completed ? 'bg-green-400' : 'bg-orange-400';
                }
                dot.className = `w-1 h-1 rounded-full ${dotColor}`;
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

// --- SCHEDULE EVENT EDIT/DELETE ---
window.editScheduleEvent = async (eventId, currentDate, currentTime, title) => {
    // Show a simple prompt to edit date/time
    const newDate = prompt(`Edit date for "${title}":`, currentDate);
    if (!newDate) return;

    const newTime = prompt(`Edit time for "${title}":`, currentTime || '9:00 AM');
    if (!newTime) return;

    try {
        const res = await fetch(`${apiBase}/api/trainer/events/${eventId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({ date: newDate, time: newTime })
        });

        if (res.ok) {
            showToast('Schedule updated! 📅');
            // Refresh the page or re-fetch trainer data
            init();
        } else {
            const err = await res.json();
            showToast(err.detail || 'Failed to update schedule');
        }
    } catch (e) {
        console.error('Error updating schedule:', e);
        showToast('Failed to update schedule');
    }
};

window.deleteScheduleEvent = async (eventId, title) => {
    if (!confirm(`Remove "${title}" from your schedule?`)) return;

    try {
        const res = await fetch(`${apiBase}/api/trainer/events/${eventId}`, {
            method: 'DELETE',
            credentials: 'include'
        });

        if (res.ok) {
            showToast('Removed from schedule 🗑️');
            // Refresh
            init();
        } else {
            showToast('Failed to remove from schedule');
        }
    } catch (e) {
        console.error('Error deleting schedule:', e);
        showToast('Failed to remove from schedule');
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
        const res = await fetch(`${apiBase}/api/trainer/client/${clientId}`, {
            credentials: 'include'
        });
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



window.togglePremium = async (clientId, currentState, event) => {
    event.stopPropagation(); // Prevent opening client modal

    // Optimistic UI Update (find button and toggle immediately?)
    // Or just reload list. Let's do API call then reload list.

    try {
        const res = await fetch(`${apiBase}/api/trainer/client/${clientId}/toggle_premium`, {
            method: 'POST',
            credentials: 'include'
        });

        if (!res.ok) throw new Error("Failed to toggle premium");

        const data = await res.json();
        showToast(data.message);

        // Update local state and re-render
        const clientIndex = allClients.findIndex(c => c.id === clientId);
        if (clientIndex > -1) {
            allClients[clientIndex].is_premium = data.is_premium;
            renderClientList(allClients);
        }
    } catch (e) {
        console.error("Toggle Premium Error:", e);
        showToast("Error updating status");
    }
};

function renderClientList(clients) {
    const list = document.getElementById('client-list');
    if (!list) return;

    list.innerHTML = ''; // Clear current list

    if (clients.length === 0) {
        list.innerHTML = '<p class="text-gray-500 text-xs text-center py-4">No clients found.</p>';
        return;
    }

    clients.forEach(c => {
        const div = document.createElement('div');
        div.className = "glass-card p-4 flex justify-between items-center tap-effect cursor-pointer hover:bg-white/5 transition";
        div.onclick = function () {
            showClientModal(c.name, c.plan, c.status, c.id, c.is_premium);
        };
        const statusColor = c.status === 'At Risk' ? 'text-red-400' : 'text-green-400';

        // Premium Tag Logic - PRO means this client selected this trainer as their personal trainer
        let premiumBtn = '';
        if (c.is_premium) {
            // Show PRO badge (non-clickable) for clients who selected this trainer
            premiumBtn = `<span class="ml-2 bg-yellow-500/20 text-yellow-500 border border-yellow-500 px-2 py-0.5 rounded text-[10px] font-bold">PRO</span>`;
        }
        // COMMENTED OUT: Manual "Make PRO" button - now handled automatically when client selects trainer
        // else {
        //     premiumBtn = `<button onclick="window.togglePremium('${c.id}', false, event)" class="ml-2 bg-white/5 text-gray-500 border border-white/10 px-2 py-0.5 rounded text-[10px] font-bold hover:bg-white/20 hover:text-white transition">Make PRO</button>`;
        // }

        div.innerHTML = `<div class="flex items-center"><div class="w-10 h-10 rounded-full bg-white/10 mr-3 overflow-hidden"><img src="https://api.dicebear.com/7.x/avataaars/svg?seed=${c.name}" /></div><div><p class="font-bold text-sm text-white flex items-center">${c.name} ${premiumBtn}</p><p class="text-[10px] text-gray-400">${c.plan} • Seen ${c.last_seen}</p></div></div><span class="text-xs font-bold ${statusColor}">${c.status}</span>`;
        list.appendChild(div);
    });

    // Scroll Shadow Logic
    list.removeEventListener('scroll', handleClientListScroll); // Avoid duplicates
    list.addEventListener('scroll', handleClientListScroll);
}

function handleClientListScroll(e) {
    const shadow = document.getElementById('client-list-top-shadow');
    if (shadow) {
        if (e.target.scrollTop > 10) {
            shadow.classList.remove('opacity-0');
        } else {
            shadow.classList.add('opacity-0');
        }
    }
}

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

                // Update display name with actual username from API
                if (user.username) {
                    if (displayNameEl) displayNameEl.textContent = user.username;
                    if (welcomeNameEl) welcomeNameEl.textContent = user.username;
                }

                // Update streak display (week streak)
                setTxt('client-streak', user.streak);
                setTxt('streak-count', user.streak); // Legacy fallback

                // Calculate next goal for week streak (milestones: 4, 8, 12, 16, 24, 52 weeks)
                const weekMilestones = [4, 8, 12, 16, 24, 36, 52];
                const nextWeekGoal = weekMilestones.find(m => m > user.streak) || (user.streak + 12);
                setTxt('client-next-goal', `${nextWeekGoal} Weeks`);

                setTxt('gem-count', user.gems);
                setTxt('health-score', user.health_score);

                // Update weight display
                currentClientWeight = user.weight;
                updateWeightDisplay(user.weight);

                // Load weight chart
                if (document.getElementById('weight-chart')) {
                    loadWeightChart('month');
                }

                // Animate Diet Score Ring
                const dietRing = document.getElementById('diet-progress-ring') || document.querySelector('circle[stroke="#4ADE80"]');
                if (dietRing) {
                    // Circumference is ~213.6 (r=34)
                    const offset = 213.6 - (213.6 * (user.health_score / 100));
                    dietRing.style.strokeDashoffset = offset;
                }

                // Update diet status text based on score
                const dietStatus = document.getElementById('diet-status');
                if (dietStatus) {
                    const score = user.health_score || 0;
                    if (score >= 90) {
                        dietStatus.textContent = 'Excellent! Top 5%';
                        dietStatus.className = 'text-xs text-green-400 font-bold mt-1';
                    } else if (score >= 75) {
                        dietStatus.textContent = 'Great progress!';
                        dietStatus.className = 'text-xs text-green-400 font-bold mt-1';
                    } else if (score >= 50) {
                        dietStatus.textContent = 'Keep going!';
                        dietStatus.className = 'text-xs text-yellow-400 font-bold mt-1';
                    } else if (score >= 25) {
                        dietStatus.textContent = 'Room to improve';
                        dietStatus.className = 'text-xs text-orange-400 font-bold mt-1';
                    } else {
                        dietStatus.textContent = 'Let\'s get started!';
                        dietStatus.className = 'text-xs text-red-400 font-bold mt-1';
                    }
                }

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
                user.daily_quests.forEach((quest, index) => {
                    const div = document.createElement('div');
                    div.className = "glass-card p-4 flex justify-between items-center tap-effect";
                    div.setAttribute('data-quest-index', index);
                    div.onclick = function () { toggleQuest(this); };
                    if (quest.completed) div.style.borderColor = "rgba(249, 115, 22, 0.3)";
                    div.innerHTML = `<div class="flex items-center"><div class="w-5 h-5 rounded-full border border-white/20 mr-3 flex items-center justify-center ${quest.completed ? 'bg-orange-500 text-white border-none' : ''}">${quest.completed ? '✓' : ''}</div><span class="text-sm font-medium text-gray-200">${quest.text}</span></div><span class="text-xs font-bold text-orange-500">+${quest.xp}</span>`;
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

                // Weekly Health Scores Chart
                const chart = document.getElementById('weekly-chart');
                if (chart && user.progress.weekly_health_scores) {
                    chart.innerHTML = ''; // Clear existing bars
                    const today = new Date().getDay(); // 0=Sun, 1=Mon, etc
                    const todayIdx = today === 0 ? 6 : today - 1; // Convert to Mon=0, Sun=6

                    user.progress.weekly_health_scores.forEach((score, idx) => {
                        const bar = document.createElement('div');
                        bar.className = 'w-full flex items-end justify-center';
                        bar.style.height = '100%';

                        const innerBar = document.createElement('div');
                        innerBar.className = 'w-full rounded-t-sm transition-all';

                        if (score > 0) {
                            // Has data - show colored bar
                            let colorClass = 'bg-red-500';
                            if (score >= 80) colorClass = 'bg-green-500';
                            else if (score >= 60) colorClass = 'bg-yellow-500';
                            else if (score >= 40) colorClass = 'bg-orange-500';

                            innerBar.classList.add(colorClass);
                            innerBar.style.height = `${Math.max(score, 10)}%`;
                            innerBar.title = `${score}%`;
                        } else {
                            // No data - show subtle dot
                            innerBar.classList.add('bg-white/20');
                            innerBar.style.height = '3px';
                            innerBar.style.borderRadius = '2px';
                            innerBar.title = 'No data';
                        }

                        bar.appendChild(innerBar);
                        chart.appendChild(bar);
                    });
                }

                // Macros
                const m = user.progress.macros;
                if (m && document.getElementById('cals-remaining')) {
                    const calsLeft = Math.round(m.calories.target - m.calories.current);
                    document.getElementById('cals-remaining').innerText = `${calsLeft} kcal left`;
                    // Also update hero carousel calories tag
                    const heroCurrent = document.getElementById('hero-cals-current');
                    const heroTarget = document.getElementById('hero-cals-target');
                    if (heroCurrent) heroCurrent.innerText = Math.round(m.calories.current);
                    if (heroTarget) heroTarget.innerText = Math.round(m.calories.target);

                    const updateRing = (id, cur, max, color) => {
                        const pct = Math.min((cur / max) * 100, 100);
                        // Round to integer for display
                        const displayVal = Math.round(cur);
                        const el = document.getElementById(id);
                        if (el) {
                            el.style.background = `conic-gradient(${color} ${pct}%, #333 0%)`;
                            document.getElementById('val-' + id.split('-')[1]).innerText = `${displayVal}g`;
                        }
                        // Also update hero carousel rings
                        const heroEl = document.getElementById('hero-' + id);
                        if (heroEl) {
                            heroEl.style.background = `conic-gradient(${color} ${pct}%, #333 0%)`;
                            const heroValEl = document.getElementById('hero-val-' + id.split('-')[1]);
                            if (heroValEl) heroValEl.innerText = `${displayVal}g`;
                        }
                    };
                    updateRing('ring-protein', m.protein.current, m.protein.target, '#4ADE80');
                    updateRing('ring-carbs', m.carbs.current, m.carbs.target, '#60A5FA');
                    updateRing('ring-fat', m.fat.current, m.fat.target, '#F472B6');
                }

                // Grouped Diet Log
                const dietContainer = document.getElementById('diet-log-container');
                if (dietContainer && user.progress.diet_log) {
                    dietContainer.innerHTML = ''; // Clear existing content
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

                // Photos - load from physique API
                const photoGallery = document.getElementById('photo-gallery');
                if (photoGallery) {
                    loadPhysiquePhotos(photoGallery);
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

            const trainerRes = await fetch(`${apiBase}/api/trainer/data?limit_cache=${Date.now()}`, {
                credentials: 'include'
            });
            const data = await trainerRes.json();

            // Store trainer data globally for course modal and other features
            window.trainerData = data;

            if (document.getElementById('active-clients-count')) {
                document.getElementById('active-clients-count').innerText = data.active_clients;
            }
            if (document.getElementById('at-risk-clients-count')) {
                document.getElementById('at-risk-clients-count').innerText = data.at_risk_clients;
            }

            // --- TODAY'S PLAN SECTION ---
            const planContainer = document.getElementById('todays-plan-container');
            if (planContainer && data.todays_workout) {
                const workout = data.todays_workout;
                const completedClass = workout.completed ? 'bg-green-500' : 'bg-white';
                const completedText = workout.completed ? 'COMPLETED ✓' : 'START SESSION';
                const completedTextColor = workout.completed ? 'text-white' : 'text-black';

                planContainer.innerHTML = `
                    <div class="glass-card p-5 relative overflow-hidden group tap-effect cursor-pointer" onclick="window.location.href='/?gym_id=${gymId}&role=trainer&mode=workout&workout_id=${workout.id}${workout.completed ? '&view=completed' : ''}'">
                        <div class="absolute inset-0 bg-primary opacity-20 group-hover:opacity-30 transition"></div>
                        <div class="relative z-10">
                            <div class="flex justify-between items-start mb-4">
                                <span class="bg-white/10 px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider">Today's Plan</span>
                                <span class="text-xl">💪</span>
                            </div>
                            <h3 class="text-2xl font-black italic uppercase mb-1">${workout.title}</h3>
                            <p class="text-sm text-gray-300 mb-4">${workout.duration} min • ${workout.difficulty}</p>
                            <button class="block w-full py-3 ${completedClass} hover:bg-gray-200 ${completedTextColor} text-center font-bold rounded-xl transition">${completedText}</button>
                        </div>
                    </div>
                `;
            }

            // --- TRAINER STATS ---
            // Update streak on personal page
            const streakEl = document.getElementById('personal-streak');
            if (streakEl && data.streak !== undefined) {
                streakEl.innerText = data.streak;
            }

            // --- TRAINER PROFILE & NOTES ---
            // Populate Profile Modal
            const tProfileName = document.getElementById('profile-name');
            const tProfileEmail = document.getElementById('profile-email');
            const tProfileClientCount = document.getElementById('profile-client-count');

            if (tProfileName) tProfileName.innerText = username;
            if (tProfileEmail) tProfileEmail.innerText = `${username.toLowerCase().replace(/\s+/g, '')}@irongym.com`; // Mock email if not available
            if (tProfileClientCount) tProfileClientCount.innerText = data.active_clients;

            // Simple Quick Notes Logic (LocalStorage)
            const notesArea = document.getElementById('trainer-notes');
            if (notesArea) {
                // Load saved notes
                const savedNotes = localStorage.getItem(`trainer_notes_${username}`);
                if (savedNotes) notesArea.value = savedNotes;

                // Auto-save logic
                let saveTimeout;
                notesArea.addEventListener('input', () => {
                    const indicator = document.getElementById('notes-saved-indicator');
                    if (indicator) indicator.style.opacity = '0';

                    clearTimeout(saveTimeout);
                    saveTimeout = setTimeout(() => {
                        localStorage.setItem(`trainer_notes_${username}`, notesArea.value);
                        if (indicator) {
                            indicator.style.opacity = '1';
                        }
                    }, 1000); // Save after 1 second of inactivity
                });
            }

            // Store and render clients
            if (data.clients) {
                allClients = data.clients;
                renderClientList(allClients);

                // Setup Search Listener
                const searchInput = document.getElementById('client-search');
                if (searchInput) {
                    searchInput.addEventListener('input', (e) => {
                        const term = e.target.value.toLowerCase();
                        const filtered = allClients.filter(c =>
                            c.name.toLowerCase().includes(term) ||
                            c.plan.toLowerCase().includes(term)
                        );
                        renderClientList(filtered);
                    });
                }
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

            // Toggle Exercise List Visibility with slide animation
            const toggleBtn = document.getElementById('toggle-exercises-btn');
            const exercisesSection = document.getElementById('exercises-section');
            const exercisesChevron = document.getElementById('exercises-chevron');
            let exercisesOpen = false;

            if (toggleBtn && exercisesSection) {
                toggleBtn.addEventListener('click', () => {
                    exercisesOpen = !exercisesOpen;

                    if (exercisesOpen) {
                        // Opening
                        exercisesSection.style.maxHeight = exercisesSection.scrollHeight + 500 + 'px';
                        exercisesSection.style.opacity = '1';
                        if (exercisesChevron) exercisesChevron.style.transform = 'rotate(180deg)';
                    } else {
                        // Closing
                        exercisesSection.style.maxHeight = '0';
                        exercisesSection.style.opacity = '0';
                        if (exercisesChevron) exercisesChevron.style.transform = 'rotate(0deg)';
                    }
                });
            }

            // Fetch and Render Workouts (Library)
            if (document.getElementById('workout-library')) {
                fetchAndRenderWorkouts();
            }

            // --- MY WORKOUTS SECTION ---
            // Skip on trainer_personal page (has its own handlers)
            const isTrainerPersonalPage = window.location.pathname.includes('/trainer/personal');
            const toggleMyWorkout = document.getElementById('toggle-my-workout-btn');
            const myWorkoutSection = document.getElementById('my-workout-section');
            if (toggleMyWorkout && myWorkoutSection && !isTrainerPersonalPage) {
                toggleMyWorkout.onclick = () => {
                    myWorkoutSection.classList.toggle('hidden');
                };
            }

            if (data.workouts) {
                const container = document.getElementById('my-workout-card-container');
                if (container) {
                    container.innerHTML = '';

                    // Create Button (Centered)
                    // Create Button (Centered)
                    const createBtn = document.createElement('div');
                    createBtn.className = "flex justify-center mb-4";
                    createBtn.innerHTML = `<button data-action="openCreateWorkout" class="w-auto px-8 py-3 bg-white/10 rounded-xl hover:bg-white/20 transition flex items-center justify-center gap-2 font-bold text-sm border border-white/5 shadow-lg"><span>+</span> Create Personal Workout</button>`;
                    container.appendChild(createBtn);

                    if (data.workouts.length === 0) {
                        const emptyDiv = document.createElement('div');
                        emptyDiv.className = "glass-card p-4 text-center text-gray-500 italic";
                        emptyDiv.innerText = "No personal workouts created yet.";
                        container.appendChild(emptyDiv);
                    } else {
                        data.workouts.forEach(w => {
                            // Client Structure Card
                            const card = document.createElement('div');
                            card.className = "glass-card p-5 relative overflow-hidden group tap-effect mb-4";
                            card.innerHTML = `
                                <div class="absolute inset-0 bg-primary opacity-5 group-hover:opacity-10 transition"></div>
                                <div class="relative z-10">
                                    <div class="flex justify-between items-start mb-4">
                                        <span class="bg-white/10 px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider">Workout</span>
                                        <span class="text-xl">💪</span>
                                    </div>
                                    <h3 class="text-2xl font-black italic uppercase mb-1 text-white">${w.title}</h3>
                                    <p class="text-sm text-gray-300 mb-4">${w.duration} • ${w.difficulty}</p>
                                    <div class="flex gap-2 mb-2">
                                         <button onclick='openEditWorkout(JSON.parse(decodeURIComponent("${encodeURIComponent(JSON.stringify(w))}")))' class="flex-1 py-3 bg-white/10 text-white text-center font-bold rounded-xl hover:bg-white/20 transition">EDIT</button>
                                         <a href="/?gym_id=${gymId}&role=client&mode=workout&view=preview&workout_id=${w.id}" class="flex-1 py-3 bg-white text-black text-center font-bold rounded-xl hover:bg-gray-200 transition">PREVIEW</a>
                                    </div>
                                    <button onclick='window.assignWorkoutToSelf("${w.id}", "${w.title.replace(/'/g, "\\'")}")' 
                                        class="w-full py-2 bg-green-600/20 hover:bg-green-600 text-green-400 hover:text-white text-sm font-bold rounded-lg transition border border-green-500/30">
                                        📅 Assign to Me (Today)
                                    </button>
                                </div>
                            `;
                            container.appendChild(card);
                        });
                    }
                }
            }

            // --- MY SPLITS SECTION ---
            // Skip on trainer_personal page (has its own handlers)
            const toggleMySplit = document.getElementById('toggle-my-split-btn');
            const mySplitSection = document.getElementById('my-split-section');
            if (toggleMySplit && mySplitSection && !isTrainerPersonalPage) {
                toggleMySplit.onclick = () => {
                    console.log('TOGGLE DEBUG [app.js]: My Splits onclick triggered!');
                    mySplitSection.classList.toggle('hidden');
                    console.log('TOGGLE DEBUG [app.js]: NOW hidden:', mySplitSection.classList.contains('hidden'));
                };
            }

            if (data.splits) {
                const container = document.getElementById('my-split-card-container');
                if (container) {
                    container.innerHTML = '';

                    // Create Button (Centered)
                    // Create Button (Centered)
                    const createBtn = document.createElement('div');
                    createBtn.className = "flex justify-center mb-4";
                    createBtn.innerHTML = `<button data-action="openCreateSplit" class="w-auto px-8 py-3 bg-white/10 rounded-xl hover:bg-white/20 transition flex items-center justify-center gap-2 font-bold text-sm border border-white/5 shadow-lg"><span>+</span> Create Personal Split</button>`;
                    container.appendChild(createBtn);

                    if (data.splits.length === 0) {
                        const emptyDiv = document.createElement('div');
                        emptyDiv.className = "glass-card p-4 text-center text-gray-500 italic";
                        emptyDiv.innerText = "No personal splits created yet.";
                        container.appendChild(emptyDiv);
                    } else {
                        data.splits.forEach(s => {
                            const card = document.createElement('div');
                            card.className = "glass-card p-5 relative overflow-hidden group tap-effect mb-4";
                            card.innerHTML = `
                                <div class="flex justify-between items-start mb-2">
                                     <div class="flex items-center gap-3">
                                         <div class="p-2 bg-purple-500/20 rounded-lg text-purple-400">
                                             📅
                                         </div>
                                         <div>
                                             <h3 class="font-bold text-white text-lg leading-tight">${s.name}</h3>
                                             <p class="text-xs text-gray-500">${s.description || 'No description'}</p>
                                         </div>
                                     </div>
                                     
                                     <div class="flex gap-2">
                                         <button onclick='window.openEditSplit(JSON.parse(decodeURIComponent("${encodeURIComponent(JSON.stringify(s))}")))' 
                                            class="text-gray-500 hover:text-white transition p-1" title="Edit">
                                            ✏️
                                         </button>
                                         <button onclick='window.deleteSplit("${s.id}")' 
                                            class="text-gray-500 hover:text-red-400 transition p-1" title="Delete">
                                            🗑️
                                         </button>
                                     </div>
                                </div>

                                <button onclick='window.assignSplitToSelf("${s.id}", "${s.name.replace(/'/g, "\\'")}")'
                                    class="w-full mt-3 py-2 bg-white/5 hover:bg-purple-600 hover:text-white text-gray-400 text-sm font-bold rounded-lg transition border border-white/10 group-hover:border-purple-500/50">
                                    📅 Assign to Me (This Week)
                                </button>
                            `;
                            container.appendChild(card);
                        });
                    }
                }
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
                // Add cursor-pointer for clickable entries (not yourself)
                div.className = `glass-card p-4 flex items-center justify-between tap-effect ${isUser ? 'border-2 border-primary bg-primary/10' : 'cursor-pointer hover:bg-white/5'}`;

                const getRankEmoji = (rank) => {
                    if (rank === 1) return '🥇';
                    if (rank === 2) return '🥈';
                    if (rank === 3) return '🥉';
                    return `#${rank}`;
                };

                // Use actual profile picture if available, otherwise use DiceBear
                const avatarUrl = u.profile_picture
                    ? u.profile_picture
                    : `https://api.dicebear.com/7.x/avataaars/svg?seed=${u.name}`;

                // Determine privacy indicator
                const privacyMode = u.privacy_mode || 'public';
                let chatIcon = '💬';
                let privacyIndicator = '';
                if (privacyMode === 'private') {
                    chatIcon = '🔒';
                    privacyIndicator = ' <span class="text-xs text-gray-500">🔒</span>';
                } else if (privacyMode === 'staff_only') {
                    chatIcon = '🛡️';
                    privacyIndicator = ' <span class="text-xs text-gray-500">🛡️</span>';
                }

                div.innerHTML = `
                    <div class="flex items-center space-x-3">
                        <span class="text-2xl font-black w-10">${getRankEmoji(u.rank)}</span>
                        <div class="w-10 h-10 rounded-full bg-white/10 overflow-hidden">
                            <img src="${avatarUrl}" class="w-full h-full object-cover" />
                        </div>
                        <div>
                            <p class="font-bold text-sm text-white">${u.name}${isUser ? ' (You)' : ''}${!isUser ? privacyIndicator : ''}</p>
                            <p class="text-[10px] text-gray-400">${u.streak} day streak • ${u.health_score} health</p>
                        </div>
                    </div>
                    <div class="text-right flex items-center space-x-2">
                        ${!isUser ? `<span class="text-xs text-gray-400">${chatIcon}</span>` : ''}
                        <p class="text-yellow-400 font-bold">🔶 ${u.gems}</p>
                    </div>
                `;

                // Add click handler to open chat (if not yourself)
                if (!isUser && u.user_id) {
                    div.addEventListener('click', () => {
                        window.openChatWithUser(u.user_id, u.name, avatarUrl);
                    });
                }

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
    } else if (action === 'openCreateSplit') {
        openCreateSplitModal();
    } else if (action === 'openCreateCourse') {
        openCreateCourseModal();
    }
});


// --- MODAL SYSTEM & HELPERS ---

function showModal(id) {
    document.getElementById(id).classList.remove('hidden');
}

function hideModal(id) {
    document.getElementById(id).classList.add('hidden');
}

// Flying gems animation
function animateFlyingGems(fromEl, toEl, gemCount, onComplete) {
    const fromRect = fromEl.getBoundingClientRect();
    const toRect = toEl.getBoundingClientRect();

    // Start position (center of quest)
    const startX = fromRect.left + fromRect.width / 2;
    const startY = fromRect.top + fromRect.height / 2;

    // End position (gem counter)
    const endX = toRect.left + toRect.width / 2;
    const endY = toRect.top + toRect.height / 2;

    // Create multiple gem particles
    const numGems = Math.min(Math.ceil(gemCount / 10), 5); // 1-5 gems based on reward
    let completedGems = 0;

    for (let i = 0; i < numGems; i++) {
        setTimeout(() => {
            const gem = document.createElement('div');
            gem.innerHTML = '🔶';
            gem.style.cssText = `
                position: fixed;
                left: ${startX}px;
                top: ${startY}px;
                font-size: 24px;
                z-index: 9999;
                pointer-events: none;
                transform: translate(-50%, -50%) scale(0);
                filter: drop-shadow(0 0 10px rgba(249, 115, 22, 0.8));
            `;
            document.body.appendChild(gem);

            // Pop in animation
            requestAnimationFrame(() => {
                gem.style.transition = 'transform 0.15s ease-out';
                gem.style.transform = 'translate(-50%, -50%) scale(1.2)';

                setTimeout(() => {
                    // Calculate curved path with random offset
                    const offsetX = (Math.random() - 0.5) * 100;
                    const controlY = Math.min(startY, endY) - 100 - Math.random() * 50;

                    // Animate along bezier-like curve
                    gem.style.transition = 'all 0.6s cubic-bezier(0.2, 0, 0.3, 1)';
                    gem.style.left = `${endX}px`;
                    gem.style.top = `${endY}px`;
                    gem.style.transform = 'translate(-50%, -50%) scale(0.5)';
                    gem.style.opacity = '0.8';

                    setTimeout(() => {
                        gem.remove();
                        completedGems++;

                        // When all gems arrive, pulse the counter
                        if (completedGems === numGems && onComplete) {
                            onComplete();
                        }
                    }, 600);
                }, 150);
            });
        }, i * 80); // Stagger gem spawns
    }
}

// Pulse animation for gem counter
function pulseGemCounter() {
    const gemContainer = document.querySelector('[data-target="shop-modal"]');
    if (gemContainer) {
        gemContainer.style.transition = 'transform 0.15s ease-out';
        gemContainer.style.transform = 'scale(1.3)';
        gemContainer.style.background = 'rgba(249, 115, 22, 0.3)';

        setTimeout(() => {
            gemContainer.style.transform = 'scale(1)';
            setTimeout(() => {
                gemContainer.style.background = '';
            }, 150);
        }, 150);
    }
}

async function toggleQuest(el) {
    const check = el.querySelector('.rounded-full');
    const isComplete = check.classList.contains('bg-orange-500');
    const questIndex = parseInt(el.getAttribute('data-quest-index'));

    if (isNaN(questIndex)) {
        console.error('Quest index not found');
        return;
    }

    // Prevent double-clicking during animation
    if (el.classList.contains('animating')) return;

    try {
        const response = await fetch('/api/client/quest/toggle', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ quest_index: questIndex })
        });

        if (!response.ok) {
            throw new Error('Failed to toggle quest');
        }

        const result = await response.json();

        if (result.completed) {
            el.classList.add('animating');

            // Mark as complete with orange styling
            check.classList.add('bg-orange-500', 'text-white', 'border-none');
            check.innerText = '✓';
            el.style.borderColor = "rgba(249, 115, 22, 0.5)";
            el.style.boxShadow = "0 0 20px rgba(249, 115, 22, 0.3)";

            // Get reward amount
            const rewardText = el.querySelector('.text-orange-500').innerText;
            const rewardAmount = parseInt(rewardText.replace('+', ''));
            const gemEl = document.getElementById('gem-count');
            const gemContainer = document.querySelector('[data-target="shop-modal"]');

            // Celebration toast
            showToast(`Quest Complete! ${rewardText} 🔶`);

            // Animate flying gems to counter
            if (gemContainer && gemEl) {
                animateFlyingGems(el, gemContainer, rewardAmount, () => {
                    // Update gem count when gems arrive
                    let currentGems = parseInt(gemEl.innerText);
                    gemEl.innerText = currentGems + rewardAmount;
                    pulseGemCounter();
                });
            } else if (gemEl) {
                // Fallback if container not found
                let currentGems = parseInt(gemEl.innerText);
                gemEl.innerText = currentGems + rewardAmount;
            }

            // Zoom in animation then remove
            el.style.transition = 'transform 0.3s ease-out, opacity 0.3s ease-out, box-shadow 0.3s ease-out';
            el.style.transform = 'scale(1.05)';

            setTimeout(() => {
                // Zoom out and fade
                el.style.transform = 'scale(0.8)';
                el.style.opacity = '0';
                el.style.boxShadow = 'none';

                setTimeout(() => {
                    // Collapse height smoothly
                    el.style.transition = 'all 0.3s ease-out';
                    el.style.height = el.offsetHeight + 'px';
                    el.offsetHeight; // Force reflow
                    el.style.height = '0';
                    el.style.padding = '0';
                    el.style.marginBottom = '0';
                    el.style.overflow = 'hidden';

                    setTimeout(() => {
                        el.remove();
                    }, 300);
                }, 250);
            }, 400); // Increased delay to let gems fly
        } else {
            // Unmark as complete (restore quest)
            check.classList.remove('bg-orange-500', 'text-white', 'border-none');
            check.innerText = '';
            el.style.borderColor = "";
        }
    } catch (error) {
        console.error('Error toggling quest:', error);
        showToast('Failed to update quest');
        el.classList.remove('animating');
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

function showClientModal(name, plan, status, clientId, isPremium = false) {
    console.log("showClientModal called with ID:", clientId, "isPremium:", isPremium);
    document.getElementById('modal-client-name').innerText = name;
    document.getElementById('modal-client-plan').innerText = plan;
    document.getElementById('modal-client-status').innerText = status;
    document.getElementById('modal-client-status').className = `text-lg font-bold ${status === 'At Risk' ? 'text-red-400' : 'text-green-400'}`;
    document.getElementById('client-modal').dataset.clientId = clientId;
    document.getElementById('client-modal').dataset.clientName = name;

    // Show/hide PRO-only buttons based on whether this client selected this trainer
    const btnManageDiet = document.getElementById('btn-manage-diet');
    const btnViewMetrics = document.getElementById('btn-view-metrics');
    if (btnManageDiet) {
        btnManageDiet.classList.toggle('hidden', !isPremium);
    }
    if (btnViewMetrics) {
        btnViewMetrics.classList.toggle('hidden', !isPremium);
    }

    showModal('client-modal');
}

// Quick Actions
function quickAction(action) {
    if (action === 'scan') {
        // Open live camera scanner
        openCameraScanner();
    } else if (action === 'search') {
        const food = prompt("Search for food:");
        if (food) showToast(`Found: ${food} (Loading details...)`);
    } else if (action === 'copy') {
        showToast('Copied yesterday\'s meals 📋');
    }
}

// ============ CAMERA MEAL SCANNER ============

let cameraStream = null;
let currentFacingMode = 'environment'; // 'environment' = back camera, 'user' = front camera
let capturedImageBlob = null; // Store captured photo for analysis
let currentScanMode = 'photo'; // 'photo' or 'barcode'
let scannedFoodData = null; // Store scanned result for editing
let barcodeScanning = false; // Track if barcode scanner is active
let per100gData = null; // Store per-100g values for recalculation

async function openCameraScanner() {
    const modal = document.getElementById('camera-scanner-modal');
    if (!modal) {
        // Fallback to old behavior if modal doesn't exist
        quickActionFallback();
        return;
    }

    // Reset to photo capture mode
    currentScanMode = 'photo';
    scannedFoodData = null;
    showCaptureMode();
    updateScanModeTabs();
    modal.classList.remove('hidden');
    await startCamera();
}

function closeCameraScanner() {
    const modal = document.getElementById('camera-scanner-modal');
    if (modal) {
        modal.classList.add('hidden');
    }
    stopCamera();
    stopBarcodeScanner();
    capturedImageBlob = null;
    scannedFoodData = null;
}

function setScanMode(mode) {
    if (currentScanMode === mode) return;
    currentScanMode = mode;
    updateScanModeTabs();

    // Reset to appropriate view
    if (mode === 'photo') {
        stopBarcodeScanner();
        showCaptureMode();
        startCamera();
    } else if (mode === 'barcode') {
        showBarcodeMode();
        startBarcodeScanner();
    }
}

function updateScanModeTabs() {
    const photoBtn = document.getElementById('photo-mode-btn');
    const barcodeBtn = document.getElementById('barcode-mode-btn');
    const photoOverlay = document.getElementById('photo-overlay');
    const barcodeOverlay = document.getElementById('barcode-overlay');

    if (currentScanMode === 'photo') {
        if (photoBtn) {
            photoBtn.classList.add('bg-primary', 'text-white');
            photoBtn.classList.remove('text-white/60');
        }
        if (barcodeBtn) {
            barcodeBtn.classList.remove('bg-primary', 'text-white');
            barcodeBtn.classList.add('text-white/60');
        }
        if (photoOverlay) photoOverlay.classList.remove('hidden');
        if (barcodeOverlay) barcodeOverlay.classList.add('hidden');
    } else {
        if (photoBtn) {
            photoBtn.classList.remove('bg-primary', 'text-white');
            photoBtn.classList.add('text-white/60');
        }
        if (barcodeBtn) {
            barcodeBtn.classList.add('bg-primary', 'text-white');
            barcodeBtn.classList.remove('text-white/60');
        }
        if (photoOverlay) photoOverlay.classList.add('hidden');
        if (barcodeOverlay) barcodeOverlay.classList.remove('hidden');
    }
}

function showCaptureMode() {
    // Show live camera view, hide other views
    const liveView = document.getElementById('camera-live-view');
    const barcodeView = document.getElementById('barcode-scanner-view');
    const previewView = document.getElementById('camera-preview-view');
    const resultsView = document.getElementById('results-edit-view');
    const captureControls = document.getElementById('capture-controls');
    const barcodeControls = document.getElementById('barcode-controls');
    const reviewControls = document.getElementById('review-controls');
    const resultsControls = document.getElementById('results-controls');
    const flipBtn = document.getElementById('flip-btn');
    const modeTabs = document.getElementById('scan-mode-tabs');

    if (liveView) liveView.classList.remove('hidden');
    if (barcodeView) barcodeView.classList.add('hidden');
    if (previewView) previewView.classList.add('hidden');
    if (resultsView) resultsView.classList.add('hidden');
    if (captureControls) captureControls.classList.remove('hidden');
    if (barcodeControls) barcodeControls.classList.add('hidden');
    if (reviewControls) reviewControls.classList.add('hidden');
    if (resultsControls) resultsControls.classList.add('hidden');
    if (flipBtn) flipBtn.classList.remove('hidden');
    if (modeTabs) modeTabs.classList.remove('hidden');
}

function showBarcodeMode() {
    const liveView = document.getElementById('camera-live-view');
    const barcodeView = document.getElementById('barcode-scanner-view');
    const previewView = document.getElementById('camera-preview-view');
    const resultsView = document.getElementById('results-edit-view');
    const captureControls = document.getElementById('capture-controls');
    const barcodeControls = document.getElementById('barcode-controls');
    const reviewControls = document.getElementById('review-controls');
    const resultsControls = document.getElementById('results-controls');
    const flipBtn = document.getElementById('flip-btn');
    const modeTabs = document.getElementById('scan-mode-tabs');

    if (liveView) liveView.classList.add('hidden');
    if (barcodeView) barcodeView.classList.remove('hidden');
    if (previewView) previewView.classList.add('hidden');
    if (resultsView) resultsView.classList.add('hidden');
    if (captureControls) captureControls.classList.add('hidden');
    if (barcodeControls) barcodeControls.classList.remove('hidden');
    if (reviewControls) reviewControls.classList.add('hidden');
    if (resultsControls) resultsControls.classList.add('hidden');
    if (flipBtn) flipBtn.classList.add('hidden');
    if (modeTabs) modeTabs.classList.remove('hidden');

    // Stop regular camera when switching to barcode mode
    stopCamera();
}

function showReviewMode(imageDataUrl) {
    // Show captured photo preview, hide live camera
    const liveView = document.getElementById('camera-live-view');
    const previewView = document.getElementById('camera-preview-view');
    const resultsView = document.getElementById('results-edit-view');
    const captureControls = document.getElementById('capture-controls');
    const barcodeControls = document.getElementById('barcode-controls');
    const reviewControls = document.getElementById('review-controls');
    const resultsControls = document.getElementById('results-controls');
    const capturedPhoto = document.getElementById('captured-photo');
    const flipBtn = document.getElementById('flip-btn');
    const modeTabs = document.getElementById('scan-mode-tabs');

    if (liveView) liveView.classList.add('hidden');
    if (previewView) previewView.classList.remove('hidden');
    if (resultsView) resultsView.classList.add('hidden');
    if (captureControls) captureControls.classList.add('hidden');
    if (barcodeControls) barcodeControls.classList.add('hidden');
    if (reviewControls) reviewControls.classList.remove('hidden');
    if (resultsControls) resultsControls.classList.add('hidden');
    if (capturedPhoto) capturedPhoto.src = imageDataUrl;
    if (flipBtn) flipBtn.classList.add('hidden');
    if (modeTabs) modeTabs.classList.add('hidden');

    // Stop the camera since we have the photo
    stopCamera();
}

function showResultsEditView(food, source = 'AI Vision') {
    scannedFoodData = { ...food };

    // Store per-100g values for recalculation (if available from barcode scan)
    if (food.per_100g) {
        per100gData = { ...food.per_100g };
    } else {
        // Calculate per-100g from current values if not provided
        const currentGrams = parsePortionGrams(food.portion_size) || 100;
        per100gData = {
            cals: Math.round((food.cals || 0) / currentGrams * 100),
            protein: Math.round(((food.protein || 0) / currentGrams * 100) * 10) / 10,
            carbs: Math.round(((food.carbs || 0) / currentGrams * 100) * 10) / 10,
            fat: Math.round(((food.fat || 0) / currentGrams * 100) * 10) / 10
        };
    }

    const liveView = document.getElementById('camera-live-view');
    const barcodeView = document.getElementById('barcode-scanner-view');
    const previewView = document.getElementById('camera-preview-view');
    const resultsView = document.getElementById('results-edit-view');
    const captureControls = document.getElementById('capture-controls');
    const barcodeControls = document.getElementById('barcode-controls');
    const reviewControls = document.getElementById('review-controls');
    const resultsControls = document.getElementById('results-controls');
    const flipBtn = document.getElementById('flip-btn');
    const modeTabs = document.getElementById('scan-mode-tabs');

    if (liveView) liveView.classList.add('hidden');
    if (barcodeView) barcodeView.classList.add('hidden');
    if (previewView) previewView.classList.add('hidden');
    if (resultsView) resultsView.classList.remove('hidden');
    if (captureControls) captureControls.classList.add('hidden');
    if (barcodeControls) barcodeControls.classList.add('hidden');
    if (reviewControls) reviewControls.classList.add('hidden');
    if (resultsControls) resultsControls.classList.remove('hidden');
    if (flipBtn) flipBtn.classList.add('hidden');
    if (modeTabs) modeTabs.classList.add('hidden');

    // Populate edit fields
    document.getElementById('result-food-name').textContent = food.name || 'Scanned Food';
    document.getElementById('edit-food-name').value = food.name || '';
    document.getElementById('edit-calories').value = food.cals || 0;
    document.getElementById('edit-protein').value = food.protein || 0;
    document.getElementById('edit-carbs').value = food.carbs || 0;
    document.getElementById('edit-fat').value = food.fat || 0;
    document.getElementById('edit-portion').value = food.portion_size || '';
    document.getElementById('result-source').textContent = `Source: ${source}`;

    // Set up portion change listener for auto-recalculation
    const portionInput = document.getElementById('edit-portion');
    portionInput.removeEventListener('input', recalculateMacrosFromPortion);
    portionInput.addEventListener('input', recalculateMacrosFromPortion);

    stopCamera();
    stopBarcodeScanner();
}

// Parse portion size string to get grams (e.g., "480g" -> 480, "100" -> 100)
function parsePortionGrams(portionStr) {
    if (!portionStr) return null;
    const match = String(portionStr).match(/(\d+\.?\d*)/);
    return match ? parseFloat(match[1]) : null;
}

// Recalculate macros when portion size changes
function recalculateMacrosFromPortion() {
    if (!per100gData) return;

    const portionInput = document.getElementById('edit-portion');
    const grams = parsePortionGrams(portionInput.value);

    if (!grams || grams <= 0) return;

    const scale = grams / 100;

    document.getElementById('edit-calories').value = Math.round(per100gData.cals * scale);
    document.getElementById('edit-protein').value = Math.round(per100gData.protein * scale * 10) / 10;
    document.getElementById('edit-carbs').value = Math.round(per100gData.carbs * scale * 10) / 10;
    document.getElementById('edit-fat').value = Math.round(per100gData.fat * scale * 10) / 10;
}

// ============ BARCODE SCANNER (QuaggaJS) ============

function startBarcodeScanner() {
    if (barcodeScanning) return;
    if (typeof Quagga === 'undefined') {
        showToast('Barcode scanner not available');
        setScanMode('photo');
        return;
    }

    barcodeScanning = true;
    stopCamera(); // Stop regular camera

    const container = document.getElementById('barcode-scanner-container');
    if (container) {
        container.innerHTML = ''; // Clear any previous content
    }

    Quagga.init({
        inputStream: {
            name: "Live",
            type: "LiveStream",
            target: container,
            constraints: {
                facingMode: "environment",
                width: { ideal: 1280 },
                height: { ideal: 720 }
            }
        },
        decoder: {
            readers: [
                "ean_reader",
                "ean_8_reader",
                "upc_reader",
                "upc_e_reader"
            ]
        },
        locate: true,
        frequency: 10
    }, function(err) {
        if (err) {
            console.error('Quagga init error:', err);
            showToast('Could not start barcode scanner');
            barcodeScanning = false;
            setScanMode('photo');
            return;
        }
        Quagga.start();

        // Style the Quagga video element to fill container
        const video = container.querySelector('video');
        if (video) {
            video.style.width = '100%';
            video.style.height = '100%';
            video.style.objectFit = 'cover';
        }
    });

    Quagga.onDetected(onBarcodeDetected);
}

function stopBarcodeScanner() {
    if (!barcodeScanning) return;
    barcodeScanning = false;

    if (typeof Quagga !== 'undefined') {
        Quagga.offDetected(onBarcodeDetected);
        Quagga.stop();
    }
}

async function onBarcodeDetected(result) {
    const code = result.codeResult.code;
    console.log('Barcode detected:', code);

    // Stop scanning immediately to prevent multiple detections
    stopBarcodeScanner();

    // Show loading
    const loadingText = document.getElementById('loading-text');
    const loading = document.getElementById('camera-loading');
    const previewView = document.getElementById('camera-preview-view');
    const barcodeView = document.getElementById('barcode-scanner-view');
    const barcodeControls = document.getElementById('barcode-controls');

    if (loadingText) loadingText.textContent = 'Looking up product...';
    if (loading) loading.classList.remove('hidden');
    if (previewView) previewView.classList.remove('hidden');
    if (barcodeView) barcodeView.classList.add('hidden');
    if (barcodeControls) barcodeControls.classList.add('hidden');

    showToast(`Barcode: ${code}`);

    try {
        const res = await fetch(`${apiBase}/api/client/diet/barcode/${code}`, {
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            }
        });

        const data = await res.json();

        if (loading) loading.classList.add('hidden');
        if (previewView) previewView.classList.add('hidden');

        if (data.status === 'success') {
            showToast(`Found: ${data.data.name}`);
            showResultsEditView(data.data, 'Open Food Facts (Barcode)');
        } else {
            showToast('Product not found. Try photo mode.');
            currentScanMode = 'photo';
            updateScanModeTabs();
            showCaptureMode();
            startCamera();
        }
    } catch (err) {
        console.error('Barcode lookup error:', err);
        if (loading) loading.classList.add('hidden');
        if (previewView) previewView.classList.add('hidden');
        showToast('Error looking up barcode');
        currentScanMode = 'photo';
        updateScanModeTabs();
        showCaptureMode();
        startCamera();
    }
}

async function startCamera() {
    const video = document.getElementById('camera-preview');
    if (!video) return;

    try {
        // Stop any existing stream
        stopCamera();

        // Request camera access
        cameraStream = await navigator.mediaDevices.getUserMedia({
            video: {
                facingMode: currentFacingMode,
                width: { ideal: 1920 },
                height: { ideal: 1080 }
            },
            audio: false
        });

        video.srcObject = cameraStream;
        await video.play();
    } catch (err) {
        console.error('Camera access error:', err);
        showToast('Could not access camera. Please check permissions.');
        closeCameraScanner();
        // Fallback to file picker
        quickActionFallback();
    }
}

function stopCamera() {
    if (cameraStream) {
        cameraStream.getTracks().forEach(track => track.stop());
        cameraStream = null;
    }
    const video = document.getElementById('camera-preview');
    if (video) {
        video.srcObject = null;
    }
}

async function flipCamera() {
    currentFacingMode = currentFacingMode === 'environment' ? 'user' : 'environment';
    await startCamera();
}

// Step 1: Take photo (just capture, don't analyze yet)
async function takePhoto() {
    const video = document.getElementById('camera-preview');
    const canvas = document.getElementById('camera-canvas');

    if (!video || !canvas) return;

    // Set canvas size to video dimensions
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    // Draw current frame to canvas
    const ctx = canvas.getContext('2d');
    ctx.drawImage(video, 0, 0);

    // Get data URL for preview
    const imageDataUrl = canvas.toDataURL('image/jpeg', 0.9);

    // Store blob for later analysis
    capturedImageBlob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', 0.9));

    // Show the review mode with captured photo
    showReviewMode(imageDataUrl);
}

// Step 2: User wants to retake photo
async function retakePhoto() {
    capturedImageBlob = null;
    showCaptureMode();
    await startCamera();
}

// Step 3: User confirms and wants to analyze
async function analyzePhoto() {
    if (!capturedImageBlob) {
        showToast('No photo captured');
        return;
    }

    const loading = document.getElementById('camera-loading');
    const analyzeBtn = document.getElementById('analyze-btn');

    // Show loading state
    if (loading) loading.classList.remove('hidden');
    if (analyzeBtn) analyzeBtn.disabled = true;

    try {
        await analyzeMealImage(capturedImageBlob);
    } catch (err) {
        console.error('Analysis error:', err);
        showToast('Failed to analyze photo');
    } finally {
        if (loading) loading.classList.add('hidden');
        if (analyzeBtn) analyzeBtn.disabled = false;
    }
}

function openGalleryForScan() {
    const input = document.getElementById('gallery-input');
    if (input) {
        input.click();
    }
}

async function handleGallerySelect(event) {
    const file = event.target.files[0];
    if (!file) return;

    const loading = document.getElementById('camera-loading');
    if (loading) loading.classList.remove('hidden');

    try {
        await analyzeMealImage(file);
    } finally {
        if (loading) loading.classList.add('hidden');
        // Reset input so same file can be selected again
        event.target.value = '';
    }
}

async function analyzeMealImage(imageBlob) {
    const formData = new FormData();
    formData.append('file', imageBlob, 'meal.jpg');

    const loadingText = document.getElementById('loading-text');
    if (loadingText) loadingText.textContent = 'Analyzing meal...';

    showToast('Analyzing meal... 🍎');

    try {
        const res = await fetch(`${apiBase}/api/client/diet/scan`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            },
            credentials: 'include',
            body: formData
        });

        if (!res.ok) throw new Error("Scan failed");
        const result = await res.json();

        if (result.status === 'success') {
            if (result.message) {
                showToast(result.message);
            }
            const food = result.data;

            // Show results in edit view (instead of closing modal)
            showResultsEditView(food, 'AI Vision');
        } else {
            throw new Error(result.message || "Unknown error");
        }
    } catch (err) {
        console.error(err);
        showToast('Error analyzing meal ⚠️');
        // Go back to capture mode on error
        showCaptureMode();
        startCamera();
    }
}

function cancelScanResult() {
    scannedFoodData = null;
    currentScanMode = 'photo';
    updateScanModeTabs();
    showCaptureMode();
    startCamera();
}

async function logScannedMeal() {
    // Get values from edit fields
    const food = {
        name: document.getElementById('edit-food-name').value || 'Scanned Meal',
        cals: parseFloat(document.getElementById('edit-calories').value) || 0,
        protein: parseFloat(document.getElementById('edit-protein').value) || 0,
        carbs: parseFloat(document.getElementById('edit-carbs').value) || 0,
        fat: parseFloat(document.getElementById('edit-fat').value) || 0,
        portion_size: document.getElementById('edit-portion').value || ''
    };

    try {
        const logRes = await fetch(`${apiBase}/api/client/diet/log`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${localStorage.getItem('token')}`,
                'Content-Type': 'application/json'
            },
            credentials: 'include',
            body: JSON.stringify(food)
        });

        if (logRes.ok) {
            showToast('Meal logged successfully! ✅');
            // Close modal and refresh data
            closeCameraScanner();
            init();
        } else {
            showToast('Failed to log meal ❌');
        }
    } catch (err) {
        console.error(err);
        showToast('Failed to log meal ❌');
    }
}

// Fallback for when camera isn't available
function quickActionFallback() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.capture = 'environment';
    input.onchange = async e => {
        if (!e.target.files[0]) return;
        const loading = document.getElementById('camera-loading');
        if (loading) loading.classList.remove('hidden');
        try {
            await analyzeMealImage(e.target.files[0]);
        } finally {
            if (loading) loading.classList.add('hidden');
        }
    };
    input.click();
}

// ============ PHYSIQUE PHOTOS ============

// Selected file for upload
let selectedPhysiqueFile = null;
let selectedPhysiqueTag = null;
let currentClientWeight = null;

// --- WEIGHT FUNCTIONS ---
function openWeightModal() {
    const modal = document.getElementById('weight-modal');
    if (modal) {
        modal.classList.remove('hidden');
        const input = document.getElementById('weight-input');
        if (input && currentClientWeight) {
            input.value = currentClientWeight;
        }
        input?.focus();
    }
}

function closeWeightModal() {
    const modal = document.getElementById('weight-modal');
    if (modal) {
        modal.classList.add('hidden');
    }
}

async function saveWeight() {
    const input = document.getElementById('weight-input');
    const weight = parseFloat(input?.value);

    if (!weight || weight < 20 || weight > 300) {
        showToast('Please enter a valid weight (20-300 kg)', 'error');
        return;
    }

    try {
        const response = await fetch('/api/client/profile', {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('token') || ''}`
            },
            credentials: 'include',
            body: JSON.stringify({ weight: weight })
        });

        if (response.ok) {
            currentClientWeight = weight;
            updateWeightDisplay(weight);
            closeWeightModal();
            showToast('Weight updated!', 'success');
            // Reload the weight chart
            loadWeightChart(currentWeightPeriod);
        } else {
            showToast('Failed to update weight', 'error');
        }
    } catch (error) {
        console.error('Error updating weight:', error);
        showToast('Failed to update weight', 'error');
    }
}

function updateWeightDisplay(weight) {
    const el = document.getElementById('client-weight');
    if (el) {
        el.textContent = weight ? weight.toFixed(1) : '--';
    }
    // Also update hero weight
    const heroWeight = document.getElementById('hero-weight');
    if (heroWeight) {
        heroWeight.textContent = weight ? weight.toFixed(1) : '--';
    }
}

// --- STATS CAROUSEL ---
let currentCarouselSlide = 0;

function scrollToSlide(index) {
    const carousel = document.getElementById('stats-carousel');
    if (!carousel) return;

    const slides = carousel.children;
    if (index < 0 || index >= slides.length) return;

    currentCarouselSlide = index;
    const slideWidth = slides[0].offsetWidth + 12; // width + gap
    carousel.scrollTo({ left: slideWidth * index, behavior: 'smooth' });

    updateCarouselDots(index);
}

function updateCarouselDots(activeIndex) {
    for (let i = 0; i < 2; i++) {
        const dot = document.getElementById(`carousel-dot-${i}`);
        if (dot) {
            dot.className = `w-2 h-2 rounded-full transition ${i === activeIndex ? 'bg-white/60' : 'bg-white/20'}`;
        }
    }
}

// Initialize carousel scroll listener
function initCarousel() {
    const carousel = document.getElementById('stats-carousel');
    if (!carousel) return;

    carousel.addEventListener('scroll', () => {
        const slideWidth = carousel.children[0]?.offsetWidth + 12 || 1;
        const newIndex = Math.round(carousel.scrollLeft / slideWidth);
        if (newIndex !== currentCarouselSlide) {
            currentCarouselSlide = newIndex;
            updateCarouselDots(newIndex);
        }
    });
}

// Call on page load
document.addEventListener('DOMContentLoaded', initCarousel);

let weightChartInstance = null;
let currentWeightPeriod = 'month';
let currentTrendView = 'weight'; // 'weight' or 'strength'
let cachedWeightData = null;
let cachedStrengthData = null;

// Switch between weight and strength views
function switchTrendView(view) {
    currentTrendView = view;

    // Update toggle buttons
    const weightBtn = document.getElementById('trend-toggle-weight');
    const strengthBtn = document.getElementById('trend-toggle-strength');
    const title = document.getElementById('trend-section-title');
    const weightUpdateBtn = document.getElementById('weight-update-btn');
    const trendBadge = document.getElementById('weight-trend-badge');
    const weightStatsRow = document.getElementById('weight-stats-row');
    const strengthStatsRow = document.getElementById('strength-stats-row');

    if (view === 'weight') {
        weightBtn.className = 'text-[10px] px-3 py-1 rounded-md bg-blue-500/20 text-blue-400 font-bold transition';
        strengthBtn.className = 'text-[10px] px-3 py-1 rounded-md text-gray-400 hover:text-white transition';
        title.textContent = 'Weight Trend';
        if (weightUpdateBtn) weightUpdateBtn.classList.remove('hidden');
        if (weightStatsRow) weightStatsRow.classList.remove('hidden');
        if (strengthStatsRow) strengthStatsRow.classList.add('hidden');
        // Render weight chart
        if (cachedWeightData) {
            renderWeightChart(cachedWeightData.data, cachedWeightData.stats);
        }
    } else {
        weightBtn.className = 'text-[10px] px-3 py-1 rounded-md text-gray-400 hover:text-white transition';
        strengthBtn.className = 'text-[10px] px-3 py-1 rounded-md bg-green-500/20 text-green-400 font-bold transition';
        title.textContent = 'Strength Progress';
        if (weightUpdateBtn) weightUpdateBtn.classList.add('hidden');
        if (weightStatsRow) weightStatsRow.classList.add('hidden');
        if (strengthStatsRow) strengthStatsRow.classList.remove('hidden');
        // Render strength chart
        if (cachedStrengthData) {
            renderStrengthChart(cachedStrengthData);
        }
    }

    // Update trend badge based on current view
    updateTrendBadge(view);
}

function updateTrendBadge(view) {
    const trendBadge = document.getElementById('weight-trend-badge');
    if (!trendBadge) return;

    if (view === 'weight' && cachedWeightData && cachedWeightData.stats) {
        const stats = cachedWeightData.stats;
        if (stats.trend === 'down') {
            trendBadge.textContent = `↓ ${Math.abs(stats.change)} kg`;
            trendBadge.className = 'text-[10px] px-2 py-0.5 rounded-full bg-green-500/20 text-green-400 font-bold';
        } else if (stats.trend === 'up') {
            trendBadge.textContent = `↑ ${stats.change} kg`;
            trendBadge.className = 'text-[10px] px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 font-bold';
        } else {
            trendBadge.textContent = '→ Stable';
            trendBadge.className = 'text-[10px] px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400 font-bold';
        }
    } else if (view === 'strength' && cachedStrengthData) {
        const progress = cachedStrengthData.progress || 0;
        if (progress > 0) {
            trendBadge.textContent = `↑ +${progress}%`;
            trendBadge.className = 'text-[10px] px-2 py-0.5 rounded-full bg-green-500/20 text-green-400 font-bold';
        } else if (progress < 0) {
            trendBadge.textContent = `↓ ${progress}%`;
            trendBadge.className = 'text-[10px] px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 font-bold';
        } else {
            trendBadge.textContent = '→ Stable';
            trendBadge.className = 'text-[10px] px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400 font-bold';
        }
    }
}

// Load chart based on current view
function loadTrendChart(period = 'month') {
    loadWeightChart(period);
}

async function loadWeightChart(period = 'month') {
    currentWeightPeriod = period;

    // Update period buttons
    ['week', 'month', 'year'].forEach(p => {
        const btn = document.getElementById(`weight-period-${p}`);
        if (btn) {
            if (p === period) {
                btn.className = 'text-[10px] px-2 py-1 rounded-lg bg-blue-500/20 text-blue-400 font-bold';
            } else {
                btn.className = 'text-[10px] px-2 py-1 rounded-lg bg-white/5 text-gray-400 hover:bg-white/10 transition';
            }
        }
    });

    const loadingEl = document.getElementById('weight-chart-loading');
    if (loadingEl) loadingEl.style.display = 'flex';

    try {
        // Fetch both weight history and strength progress in parallel
        const [weightResponse, strengthResponse] = await Promise.all([
            fetch(`/api/client/weight-history?period=${period}`, {
                headers: { 'Authorization': `Bearer ${localStorage.getItem('token') || ''}` },
                credentials: 'include'
            }),
            fetch(`/api/client/strength-progress?period=${period}`, {
                headers: { 'Authorization': `Bearer ${localStorage.getItem('token') || ''}` },
                credentials: 'include'
            })
        ]);

        if (!weightResponse.ok) throw new Error('Failed to load weight history');

        const result = await weightResponse.json();
        cachedWeightData = result;

        // Get strength data
        if (strengthResponse.ok) {
            cachedStrengthData = await strengthResponse.json();
            updateStrengthStats(cachedStrengthData);
        }

        // Render based on current view
        if (currentTrendView === 'weight') {
            renderWeightChart(result.data, result.stats);
        } else {
            renderStrengthChart(cachedStrengthData);
        }

        // Also render mini hero chart (weight only)
        renderHeroWeightChart(result.data, result.stats);

        // Update trend badge
        updateTrendBadge(currentTrendView);
    } catch (error) {
        console.error('Error loading chart:', error);
    } finally {
        if (loadingEl) loadingEl.style.display = 'none';
    }
}

function updateStrengthStats(strengthData) {
    if (!strengthData) return;

    const progress = strengthData.progress || 0;
    const trend = strengthData.trend || 'stable';

    // Update strength stats row
    const startEl = document.getElementById('strength-stat-start');
    const currentEl = document.getElementById('strength-stat-current');
    const progressEl = document.getElementById('strength-stat-progress');
    const trendEl = document.getElementById('strength-stat-trend');

    if (startEl) startEl.textContent = '0%';
    if (currentEl) {
        const prefix = progress > 0 ? '+' : '';
        currentEl.textContent = `${prefix}${progress}%`;
        currentEl.className = `text-sm font-bold ${progress > 0 ? 'text-green-400' : progress < 0 ? 'text-red-400' : 'text-gray-400'}`;
    }
    if (progressEl) {
        const prefix = progress > 0 ? '+' : '';
        progressEl.textContent = `${prefix}${progress}%`;
        progressEl.className = `text-sm font-bold ${progress > 0 ? 'text-green-400' : progress < 0 ? 'text-red-400' : 'text-purple-400'}`;
    }
    if (trendEl) {
        trendEl.textContent = trend === 'up' ? '↑ Gaining' : trend === 'down' ? '↓ Losing' : '→ Stable';
        trendEl.className = `text-sm font-bold ${trend === 'up' ? 'text-green-400' : trend === 'down' ? 'text-red-400' : 'text-blue-400'}`;
    }
}

function renderStrengthChart(strengthData) {
    const canvas = document.getElementById('weight-chart');
    if (!canvas || !strengthData || !strengthData.data || strengthData.data.length === 0) {
        // Show empty state
        const ctx = canvas?.getContext('2d');
        if (ctx) {
            const rect = canvas.getBoundingClientRect();
            canvas.width = rect.width * 2;
            canvas.height = rect.height * 2;
            ctx.scale(2, 2);
            ctx.clearRect(0, 0, rect.width, rect.height);
            ctx.fillStyle = 'rgba(255,255,255,0.3)';
            ctx.font = '12px system-ui';
            ctx.textAlign = 'center';
            ctx.fillText('No strength data yet', rect.width / 2, rect.height / 2);
            ctx.fillText('Complete workouts to track progress', rect.width / 2, rect.height / 2 + 16);
        }
        return;
    }

    const data = strengthData.data;
    const ctx = canvas.getContext('2d');
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * 2;
    canvas.height = rect.height * 2;
    ctx.scale(2, 2);

    const width = rect.width;
    const height = rect.height;
    const padding = { top: 10, right: 10, bottom: 20, left: 35 };
    const chartWidth = width - padding.left - padding.right;
    const chartHeight = height - padding.top - padding.bottom;

    ctx.clearRect(0, 0, width, height);

    // Get min/max for strength scaling
    const values = data.map(d => d.strength);
    const minStrength = Math.min(...values, 0) - 5;
    const maxStrength = Math.max(...values, 0) + 5;
    const strengthRange = maxStrength - minStrength || 1;

    // Draw grid lines
    ctx.strokeStyle = 'rgba(255,255,255,0.05)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
        const y = padding.top + (chartHeight * i / 4);
        ctx.beginPath();
        ctx.moveTo(padding.left, y);
        ctx.lineTo(width - padding.right, y);
        ctx.stroke();
    }

    // Draw zero line if visible
    if (minStrength < 0 && maxStrength > 0) {
        const zeroY = padding.top + chartHeight - ((0 - minStrength) / strengthRange * chartHeight);
        ctx.strokeStyle = 'rgba(255,255,255,0.2)';
        ctx.setLineDash([5, 5]);
        ctx.beginPath();
        ctx.moveTo(padding.left, zeroY);
        ctx.lineTo(width - padding.right, zeroY);
        ctx.stroke();
        ctx.setLineDash([]);
    }

    // Draw Y-axis labels (percentage)
    ctx.fillStyle = 'rgba(34, 197, 94, 0.7)';
    ctx.font = '9px system-ui';
    ctx.textAlign = 'right';
    for (let i = 0; i <= 4; i++) {
        const strength = maxStrength - (strengthRange * i / 4);
        const y = padding.top + (chartHeight * i / 4);
        ctx.fillText(`${strength.toFixed(0)}%`, padding.left - 5, y + 3);
    }

    // Calculate points
    const points = data.map((d, i) => ({
        x: padding.left + (chartWidth * i / (data.length - 1 || 1)),
        y: padding.top + chartHeight - ((d.strength - minStrength) / strengthRange * chartHeight),
        label: d.label,
        strength: d.strength
    }));

    // Draw gradient fill
    const gradient = ctx.createLinearGradient(0, padding.top, 0, height - padding.bottom);
    gradient.addColorStop(0, 'rgba(34, 197, 94, 0.3)');
    gradient.addColorStop(1, 'rgba(34, 197, 94, 0.0)');

    ctx.beginPath();
    ctx.moveTo(points[0].x, height - padding.bottom);
    points.forEach(p => ctx.lineTo(p.x, p.y));
    ctx.lineTo(points[points.length - 1].x, height - padding.bottom);
    ctx.closePath();
    ctx.fillStyle = gradient;
    ctx.fill();

    // Draw line
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    points.forEach(p => ctx.lineTo(p.x, p.y));
    ctx.strokeStyle = '#22C55E';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Draw points
    points.forEach(p => {
        ctx.beginPath();
        ctx.arc(p.x, p.y, 3, 0, Math.PI * 2);
        ctx.fillStyle = '#22C55E';
        ctx.fill();
    });

    // Draw X-axis labels
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    ctx.font = '8px system-ui';
    ctx.textAlign = 'center';
    const labelStep = Math.ceil(data.length / 5);
    data.forEach((d, i) => {
        if (i % labelStep === 0 || i === data.length - 1) {
            const x = padding.left + (chartWidth * i / (data.length - 1 || 1));
            ctx.fillText(d.label, x, height - 5);
        }
    });
}

function renderHeroWeightChart(data, stats) {
    const canvas = document.getElementById('hero-weight-chart');
    if (!canvas || !data || data.length === 0) return;

    const ctx = canvas.getContext('2d');
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * 2;
    canvas.height = rect.height * 2;
    ctx.scale(2, 2);

    const width = rect.width;
    const height = rect.height;
    const padding = { top: 5, right: 5, bottom: 5, left: 5 };
    const chartWidth = width - padding.left - padding.right;
    const chartHeight = height - padding.top - padding.bottom;

    ctx.clearRect(0, 0, width, height);

    const weights = data.map(d => d.weight);
    const minWeight = Math.min(...weights) - 0.5;
    const maxWeight = Math.max(...weights) + 0.5;
    const weightRange = maxWeight - minWeight;

    const points = data.map((d, i) => ({
        x: padding.left + (chartWidth * i / (data.length - 1 || 1)),
        y: padding.top + chartHeight - ((d.weight - minWeight) / weightRange * chartHeight)
    }));

    // Draw gradient fill
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, 'rgba(59, 130, 246, 0.4)');
    gradient.addColorStop(1, 'rgba(59, 130, 246, 0.0)');

    ctx.beginPath();
    ctx.moveTo(points[0].x, height - padding.bottom);
    points.forEach(p => ctx.lineTo(p.x, p.y));
    ctx.lineTo(points[points.length - 1].x, height - padding.bottom);
    ctx.closePath();
    ctx.fillStyle = gradient;
    ctx.fill();

    // Draw line
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    points.forEach(p => ctx.lineTo(p.x, p.y));
    ctx.strokeStyle = '#3B82F6';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Update hero trend badge
    const trendBadge = document.getElementById('hero-weight-trend');
    if (trendBadge && stats) {
        if (stats.trend === 'down') {
            trendBadge.textContent = `↓ ${Math.abs(stats.change)}`;
            trendBadge.className = 'text-xs px-2 py-0.5 rounded-full bg-green-500/20 text-green-400 font-bold ml-2';
        } else if (stats.trend === 'up') {
            trendBadge.textContent = `↑ ${stats.change}`;
            trendBadge.className = 'text-xs px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 font-bold ml-2';
        } else {
            trendBadge.textContent = '→ Stable';
            trendBadge.className = 'text-xs px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400 font-bold ml-2';
        }
    }
}

function renderWeightChart(data, stats) {
    const canvas = document.getElementById('weight-chart');
    if (!canvas || !data || data.length === 0) return;

    const ctx = canvas.getContext('2d');
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * 2;
    canvas.height = rect.height * 2;
    ctx.scale(2, 2);

    const width = rect.width;
    const height = rect.height;
    const padding = { top: 10, right: 10, bottom: 20, left: 35 };
    const chartWidth = width - padding.left - padding.right;
    const chartHeight = height - padding.top - padding.bottom;

    // Clear canvas
    ctx.clearRect(0, 0, width, height);

    // Get min/max for weight scaling
    const weights = data.map(d => d.weight);
    const minWeight = Math.min(...weights) - 1;
    const maxWeight = Math.max(...weights) + 1;
    const weightRange = maxWeight - minWeight;

    // Draw grid lines
    ctx.strokeStyle = 'rgba(255,255,255,0.05)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
        const y = padding.top + (chartHeight * i / 4);
        ctx.beginPath();
        ctx.moveTo(padding.left, y);
        ctx.lineTo(width - padding.right, y);
        ctx.stroke();
    }

    // Draw Y-axis labels (Weight in kg)
    ctx.fillStyle = 'rgba(59, 130, 246, 0.7)';
    ctx.font = '9px system-ui';
    ctx.textAlign = 'right';
    for (let i = 0; i <= 4; i++) {
        const weight = maxWeight - (weightRange * i / 4);
        const y = padding.top + (chartHeight * i / 4);
        ctx.fillText(weight.toFixed(1), padding.left - 5, y + 3);
    }

    // Calculate weight points
    const points = data.map((d, i) => ({
        x: padding.left + (chartWidth * i / (data.length - 1 || 1)),
        y: padding.top + chartHeight - ((d.weight - minWeight) / weightRange * chartHeight),
        label: d.label,
        weight: d.weight
    }));

    // Draw gradient fill
    const gradient = ctx.createLinearGradient(0, padding.top, 0, height - padding.bottom);
    gradient.addColorStop(0, 'rgba(59, 130, 246, 0.3)');
    gradient.addColorStop(1, 'rgba(59, 130, 246, 0.0)');

    ctx.beginPath();
    ctx.moveTo(points[0].x, height - padding.bottom);
    points.forEach(p => ctx.lineTo(p.x, p.y));
    ctx.lineTo(points[points.length - 1].x, height - padding.bottom);
    ctx.closePath();
    ctx.fillStyle = gradient;
    ctx.fill();

    // Draw line
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    points.forEach(p => ctx.lineTo(p.x, p.y));
    ctx.strokeStyle = '#3B82F6';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Draw points
    points.forEach(p => {
        ctx.beginPath();
        ctx.arc(p.x, p.y, 3, 0, Math.PI * 2);
        ctx.fillStyle = '#3B82F6';
        ctx.fill();
    });

    // Draw X-axis labels (only a few)
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    ctx.font = '8px system-ui';
    ctx.textAlign = 'center';
    const labelStep = Math.ceil(data.length / 5);
    data.forEach((d, i) => {
        if (i % labelStep === 0 || i === data.length - 1) {
            const x = padding.left + (chartWidth * i / (data.length - 1 || 1));
            ctx.fillText(d.label, x, height - 5);
        }
    });

    // Update stats
    const startEl = document.getElementById('weight-stat-start');
    const minEl = document.getElementById('weight-stat-min');
    const maxEl = document.getElementById('weight-stat-max');
    const changeEl = document.getElementById('weight-stat-change');

    if (startEl) startEl.textContent = stats.start ? `${stats.start} kg` : '--';
    if (minEl) minEl.textContent = stats.min ? `${stats.min} kg` : '--';
    if (maxEl) maxEl.textContent = stats.max ? `${stats.max} kg` : '--';

    if (changeEl && stats.change !== undefined) {
        const sign = stats.change > 0 ? '+' : '';
        changeEl.textContent = `${sign}${stats.change} kg`;
        changeEl.className = `text-sm font-bold ${stats.change < 0 ? 'text-green-400' : stats.change > 0 ? 'text-red-400' : 'text-gray-400'}`;
    }
}

function openPhysiqueModal() {
    const modal = document.getElementById('physique-modal');
    if (modal) {
        modal.classList.remove('hidden');
        // Set default date to today
        document.getElementById('physique-date').value = new Date().toISOString().split('T')[0];
        // Clear previous state
        clearPhysiquePhoto();
        clearPhysiqueTags();
        document.getElementById('physique-title').value = '';
        document.getElementById('physique-notes').value = '';
    }
}

function selectPhysiqueTag(btn, tag) {
    // Clear all selected tags
    document.querySelectorAll('.physique-tag').forEach(t => {
        t.classList.remove('bg-primary', 'border-primary', 'text-white');
        t.classList.add('bg-white/10', 'border-white/20');
    });

    // If clicking the same tag, deselect
    if (selectedPhysiqueTag === tag) {
        selectedPhysiqueTag = null;
        return;
    }

    // Select this tag
    selectedPhysiqueTag = tag;
    btn.classList.remove('bg-white/10', 'border-white/20');
    btn.classList.add('bg-primary', 'border-primary', 'text-white');
}

function clearPhysiqueTags() {
    selectedPhysiqueTag = null;
    document.querySelectorAll('.physique-tag').forEach(t => {
        t.classList.remove('bg-primary', 'border-primary', 'text-white');
        t.classList.add('bg-white/10', 'border-white/20');
    });
}

function closePhysiqueModal() {
    const modal = document.getElementById('physique-modal');
    if (modal) {
        modal.classList.add('hidden');
        clearPhysiquePhoto();
    }
}

function previewPhysiquePhoto(input) {
    const file = input.files?.[0];
    if (!file) return;

    // Validate file type
    const validTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
    if (!validTypes.includes(file.type)) {
        showToast('Please select a valid image (JPG, PNG, WEBP, GIF)', 'error');
        input.value = '';
        return;
    }

    // Validate file size (10MB max)
    if (file.size > 10 * 1024 * 1024) {
        showToast('Image too large. Maximum 10MB', 'error');
        input.value = '';
        return;
    }

    selectedPhysiqueFile = file;

    // Show preview
    const reader = new FileReader();
    reader.onload = (e) => {
        document.getElementById('physique-preview').src = e.target.result;
        document.getElementById('physique-preview-container').classList.remove('hidden');
        document.getElementById('physique-upload-area').classList.add('hidden');
    };
    reader.readAsDataURL(file);
}

function clearPhysiquePhoto() {
    selectedPhysiqueFile = null;
    document.getElementById('physique-file-input').value = '';
    document.getElementById('physique-preview-container').classList.add('hidden');
    document.getElementById('physique-upload-area').classList.remove('hidden');
}

// Form submission handler
document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('physique-form');
    if (form) {
        form.addEventListener('submit', async (e) => {
            e.preventDefault();

            if (!selectedPhysiqueFile) {
                showToast('Please select a photo', 'error');
                return;
            }

            const submitBtn = document.getElementById('physique-submit-btn');
            submitBtn.disabled = true;
            submitBtn.textContent = 'Uploading...';

            try {
                const formData = new FormData();
                formData.append('file', selectedPhysiqueFile);

                // Build title with tag and custom title
                let title = '';
                if (selectedPhysiqueTag) {
                    title = selectedPhysiqueTag;
                    const customTitle = document.getElementById('physique-title').value.trim();
                    if (customTitle) {
                        title += ' - ' + customTitle;
                    }
                } else {
                    title = document.getElementById('physique-title').value || 'Progress Photo';
                }
                formData.append('title', title);
                formData.append('photo_date', document.getElementById('physique-date').value);
                formData.append('notes', document.getElementById('physique-notes').value);

                const res = await fetch('/api/physique/photo', {
                    method: 'POST',
                    body: formData
                });

                const data = await res.json();

                if (res.ok) {
                    showToast('Progress photo saved! 📸', 'success');
                    closePhysiqueModal();

                    // Reload gallery
                    const gallery = document.getElementById('photo-gallery');
                    if (gallery) {
                        loadPhysiquePhotos(gallery);
                    }
                } else {
                    showToast(data.detail || 'Failed to upload photo', 'error');
                }
            } catch (e) {
                console.error('Error uploading physique photo:', e);
                showToast('Failed to upload photo', 'error');
            } finally {
                submitBtn.disabled = false;
                submitBtn.textContent = 'Upload Photo';
            }
        });
    }
});

async function deletePhysiquePhoto(photoId, element) {
    if (!confirm('Delete this photo?')) return;

    try {
        const res = await fetch(`/api/physique/photo/${photoId}`, {
            method: 'DELETE'
        });

        if (res.ok) {
            element.remove();
            showToast('Photo deleted', 'success');

            // Check if gallery is empty
            const gallery = document.getElementById('photo-gallery');
            if (gallery && gallery.children.length === 0) {
                gallery.innerHTML = '<p class="text-gray-500 text-xs py-4">No photos yet. Tap + Add to track your progress!</p>';
            }
        } else {
            showToast('Failed to delete photo', 'error');
        }
    } catch (e) {
        console.error('Error deleting photo:', e);
        showToast('Failed to delete photo', 'error');
    }
}

async function loadPhysiquePhotos(gallery) {
    try {
        const res = await fetch('/api/physique/photos');
        if (res.ok) {
            const data = await res.json();
            gallery.innerHTML = ''; // Clear existing

            if (data.photos && data.photos.length > 0) {
                data.photos.forEach(photo => {
                    const wrapper = document.createElement('div');
                    wrapper.className = 'relative flex-shrink-0';
                    wrapper.innerHTML = `
                        <div class="relative cursor-pointer" onclick="openPhotoViewer('${photo.photo_url}', '${photo.title || ''}', '${photo.photo_date || ''}', '${(photo.notes || '').replace(/'/g, "\\'")}')">
                            <img src="${photo.photo_url}" class="w-24 h-32 object-cover rounded-xl border border-white/10">
                            ${photo.title ? `<div class="absolute bottom-0 left-0 right-0 bg-black/60 px-1 py-0.5 rounded-b-xl">
                                <p class="text-[8px] text-white truncate">${photo.title}</p>
                            </div>` : ''}
                        </div>
                        <button onclick="event.stopPropagation(); deletePhysiquePhoto(${photo.photo_id}, this.parentElement)"
                            class="absolute -top-1 -right-1 w-5 h-5 bg-red-500/80 rounded-full text-white text-[10px] flex items-center justify-center hover:bg-red-500 transition">×</button>
                    `;
                    gallery.appendChild(wrapper);
                });
            } else {
                gallery.innerHTML = '<p class="text-gray-500 text-xs py-4">No photos yet. Tap + Add to track your progress!</p>';
            }
        }
    } catch (e) {
        console.error('Error loading physique photos:', e);
        gallery.innerHTML = '<p class="text-red-400 text-xs py-4">Failed to load photos</p>';
    }
}

function openPhotoViewer(url, title, date, notes) {
    const viewer = document.createElement('div');
    viewer.className = 'fixed inset-0 bg-black/70 backdrop-blur-xl z-50 flex flex-col items-center justify-center p-4';
    viewer.onclick = (e) => { if (e.target === viewer) viewer.remove(); };
    viewer.innerHTML = `
        <button onclick="this.parentElement.remove()" class="absolute top-4 right-4 w-10 h-10 bg-white/10 backdrop-blur-sm border border-white/20 rounded-full text-white text-xl flex items-center justify-center hover:bg-white/20 transition z-10">×</button>
        <div class="bg-white/10 backdrop-blur-sm p-3 rounded-2xl border border-white/20">
            <img src="${url}" class="max-w-full max-h-[60vh] object-contain rounded-xl">
        </div>
        ${title || date || notes ? `
        <div class="mt-4 text-center max-w-md bg-white/5 backdrop-blur-sm px-6 py-3 rounded-xl border border-white/10">
            ${title ? `<h3 class="text-lg font-bold text-white">${title}</h3>` : ''}
            ${date ? `<p class="text-sm text-gray-400">${new Date(date).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</p>` : ''}
            ${notes ? `<p class="text-sm text-gray-300 mt-2">${notes}</p>` : ''}
        </div>
        ` : ''}
    `;
    document.body.appendChild(viewer);
}

// Legacy function for backward compatibility
function addPhoto() {
    openPhysiqueModal();
}

// ============ PHYSIQUE COMPARISON (CAROUSEL) ============
let comparePhotos = [];
let allPhysiquePhotos = [];
let compareScrollY = 0;
let carouselIndex = 0;

async function openCompareModal() {
    const modal = document.getElementById('compare-modal');
    if (!modal) return;

    // Prevent background scroll (mobile-friendly)
    compareScrollY = window.scrollY;
    document.body.style.position = 'fixed';
    document.body.style.top = `-${compareScrollY}px`;
    document.body.style.left = '0';
    document.body.style.right = '0';
    document.body.style.overflow = 'hidden';

    // Reset state
    comparePhotos = [];
    carouselIndex = 0;
    updateCarouselDisplay();
    resetSelectorPanel();

    // Reset filters
    const searchInput = document.getElementById('compare-search');
    const dateFilter = document.getElementById('compare-date-filter');
    const poseFilter = document.getElementById('compare-pose-filter');
    if (searchInput) searchInput.value = '';
    if (dateFilter) dateFilter.value = 'all';
    if (poseFilter) poseFilter.value = 'all';

    // Load photos for selection
    try {
        const res = await fetch('/api/physique/photos');
        if (res.ok) {
            const data = await res.json();
            allPhysiquePhotos = data.photos || [];
            renderComparePhotoList();
        }
    } catch (e) {
        console.error('Error loading photos for comparison:', e);
    }

    modal.classList.remove('hidden');
}

function closeCompareModal() {
    const modal = document.getElementById('compare-modal');
    if (modal) {
        modal.classList.add('hidden');
        // Restore background scroll
        document.body.style.position = '';
        document.body.style.top = '';
        document.body.style.left = '';
        document.body.style.right = '';
        document.body.style.overflow = '';
        window.scrollTo(0, compareScrollY);
    }
}

function getFilteredPhotos() {
    const searchTerm = (document.getElementById('compare-search')?.value || '').toLowerCase();
    const dateFilter = document.getElementById('compare-date-filter')?.value || 'all';
    const poseFilter = document.getElementById('compare-pose-filter')?.value || 'all';

    const now = new Date();
    const weekAgo = new Date(now - 7 * 24 * 60 * 60 * 1000);
    const monthAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);
    const threeMonthsAgo = new Date(now - 90 * 24 * 60 * 60 * 1000);
    const yearStart = new Date(now.getFullYear(), 0, 1);

    return allPhysiquePhotos.map((photo, idx) => ({ photo, idx })).filter(({ photo }) => {
        // Search filter
        if (searchTerm && !(photo.title || '').toLowerCase().includes(searchTerm)) {
            return false;
        }

        // Pose filter
        if (poseFilter !== 'all') {
            const title = (photo.title || '').toLowerCase();
            if (!title.includes(poseFilter.toLowerCase())) {
                return false;
            }
        }

        // Date filter
        if (dateFilter !== 'all' && photo.photo_date) {
            const photoDate = new Date(photo.photo_date);
            switch (dateFilter) {
                case 'week':
                    if (photoDate < weekAgo) return false;
                    break;
                case 'month':
                    if (photoDate < monthAgo) return false;
                    break;
                case '3months':
                    if (photoDate < threeMonthsAgo) return false;
                    break;
                case 'year':
                    if (photoDate < yearStart) return false;
                    break;
            }
        }

        return true;
    });
}

function filterComparePhotos() {
    renderComparePhotoList();
}

function renderComparePhotoList() {
    const list = document.getElementById('compare-photo-list');
    const countEl = document.getElementById('compare-photo-count');
    if (!list) return;

    if (allPhysiquePhotos.length < 2) {
        list.innerHTML = '<p class="text-gray-500 text-sm py-2">Upload at least 2 photos to compare progress</p>';
        if (countEl) countEl.textContent = '';
        return;
    }

    const filtered = getFilteredPhotos();

    if (countEl) {
        countEl.textContent = `(${comparePhotos.length} selected, ${filtered.length} shown)`;
    }

    if (filtered.length === 0) {
        list.innerHTML = '<p class="text-gray-500 text-sm py-2">No photos match your filters</p>';
        return;
    }

    list.innerHTML = filtered.map(({ photo, idx }) => `
        <div class="flex-shrink-0 cursor-pointer compare-thumb ${comparePhotos.includes(idx) ? 'ring-2 ring-primary' : ''}"
             onclick="toggleComparePhoto(${idx})">
            <img src="${photo.photo_url}" class="w-16 h-20 object-cover rounded-lg border border-white/10">
            <p class="text-[8px] text-gray-400 text-center mt-1 truncate w-16">${photo.title || photo.photo_date || ''}</p>
        </div>
    `).join('');
}

function toggleComparePhoto(idx) {
    const photoIdx = comparePhotos.indexOf(idx);

    if (photoIdx > -1) {
        // Remove from selection
        comparePhotos.splice(photoIdx, 1);
        // Adjust carousel index if needed
        if (carouselIndex >= comparePhotos.length && carouselIndex > 0) {
            carouselIndex = comparePhotos.length - 1;
        }
    } else {
        // Add to selection (no limit now - can add multiple photos)
        comparePhotos.push(idx);
        // Jump to newly added photo
        carouselIndex = comparePhotos.length - 1;
    }

    renderComparePhotoList();
    updateCarouselDisplay();
}

function carouselPrev() {
    if (comparePhotos.length === 0) return;
    carouselIndex = (carouselIndex - 1 + comparePhotos.length) % comparePhotos.length;
    updateCarouselDisplay();
}

function carouselNext() {
    if (comparePhotos.length === 0) return;
    carouselIndex = (carouselIndex + 1) % comparePhotos.length;
    updateCarouselDisplay();
}

function goToCarouselSlide(index) {
    if (index >= 0 && index < comparePhotos.length) {
        carouselIndex = index;
        updateCarouselDisplay();
    }
}

function updateCarouselDisplay() {
    const img = document.getElementById('carousel-img');
    const placeholder = document.getElementById('carousel-placeholder');
    const label = document.getElementById('carousel-label');
    const dateEl = document.getElementById('carousel-date');
    const dotsContainer = document.getElementById('carousel-dots');
    const prevBtn = document.getElementById('carousel-prev');
    const nextBtn = document.getElementById('carousel-next');

    // Update navigation button states
    if (prevBtn) prevBtn.disabled = comparePhotos.length <= 1;
    if (nextBtn) nextBtn.disabled = comparePhotos.length <= 1;

    // Show current photo
    if (comparePhotos.length > 0 && allPhysiquePhotos[comparePhotos[carouselIndex]]) {
        const photo = allPhysiquePhotos[comparePhotos[carouselIndex]];
        if (img) {
            img.src = photo.photo_url;
            img.classList.remove('hidden');
        }
        if (placeholder) placeholder.classList.add('hidden');
        if (label) label.textContent = photo.title || 'Progress Photo';
        if (dateEl) dateEl.textContent = formatCompareDate(photo.photo_date);
    } else {
        if (img) img.classList.add('hidden');
        if (placeholder) placeholder.classList.remove('hidden');
        if (label) label.textContent = '';
        if (dateEl) dateEl.textContent = '';
    }

    // Render pagination dots
    if (dotsContainer) {
        if (comparePhotos.length <= 1) {
            dotsContainer.innerHTML = '';
        } else {
            dotsContainer.innerHTML = comparePhotos.map((_, i) => `
                <button onclick="goToCarouselSlide(${i})"
                    class="w-2.5 h-2.5 rounded-full transition-all ${i === carouselIndex
                        ? 'bg-primary scale-125'
                        : 'bg-white/30 hover:bg-white/50'}">
                </button>
            `).join('');
        }
    }
}

function formatCompareDate(dateStr) {
    if (!dateStr) return '';
    try {
        return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    } catch {
        return dateStr;
    }
}

// Photo selector panel toggle
let selectorPanelOpen = true;

function togglePhotoSelector() {
    const panel = document.getElementById('photo-selector-panel');
    const handle = document.getElementById('selector-toggle-icon');
    const photoContainer = document.getElementById('carousel-photo-container');
    const prevBtn = document.getElementById('carousel-prev');
    const nextBtn = document.getElementById('carousel-next');

    if (!panel) return;

    selectorPanelOpen = !selectorPanelOpen;

    if (selectorPanelOpen) {
        // Open panel
        panel.style.maxHeight = '260px';
        if (handle) {
            handle.style.width = '2.5rem';  // 40px - normal
            handle.style.opacity = '0.3';
        }
        // Reset photo container margin
        if (photoContainer) {
            photoContainer.style.marginLeft = '3.5rem';
            photoContainer.style.marginRight = '3.5rem';
        }
        // Reset nav buttons
        if (prevBtn) {
            prevBtn.style.background = 'rgba(255,255,255,0.1)';
            prevBtn.style.borderColor = 'rgba(255,255,255,0.2)';
            prevBtn.style.left = '0.5rem';
        }
        if (nextBtn) {
            nextBtn.style.background = 'rgba(255,255,255,0.1)';
            nextBtn.style.borderColor = 'rgba(255,255,255,0.2)';
            nextBtn.style.right = '0.5rem';
        }
    } else {
        // Close panel - show only the handle
        panel.style.maxHeight = '28px';
        if (handle) {
            handle.style.width = '4rem';  // 64px - wider to indicate expandable
            handle.style.opacity = '0.5';
        }
        // Expand photo container horizontally
        if (photoContainer) {
            photoContainer.style.marginLeft = '0.5rem';
            photoContainer.style.marginRight = '0.5rem';
        }
        // Make nav buttons transparent and move inward
        if (prevBtn) {
            prevBtn.style.background = 'transparent';
            prevBtn.style.borderColor = 'transparent';
            prevBtn.style.left = '1.5rem';
        }
        if (nextBtn) {
            nextBtn.style.background = 'transparent';
            nextBtn.style.borderColor = 'transparent';
            nextBtn.style.right = '1.5rem';
        }
    }
}

// Reset selector panel state when opening modal
function resetSelectorPanel() {
    const panel = document.getElementById('photo-selector-panel');
    const handle = document.getElementById('selector-toggle-icon');
    const photoContainer = document.getElementById('carousel-photo-container');
    const prevBtn = document.getElementById('carousel-prev');
    const nextBtn = document.getElementById('carousel-next');

    selectorPanelOpen = true;
    if (panel) panel.style.maxHeight = '260px';
    if (handle) {
        handle.style.width = '2.5rem';
        handle.style.opacity = '0.3';
    }
    // Reset photo container margin
    if (photoContainer) {
        photoContainer.style.marginLeft = '3.5rem';
        photoContainer.style.marginRight = '3.5rem';
    }
    // Reset nav buttons
    if (prevBtn) {
        prevBtn.style.background = 'rgba(255,255,255,0.1)';
        prevBtn.style.borderColor = 'rgba(255,255,255,0.2)';
        prevBtn.style.left = '0.5rem';
    }
    if (nextBtn) {
        nextBtn.style.background = 'rgba(255,255,255,0.1)';
        nextBtn.style.borderColor = 'rgba(255,255,255,0.2)';
        nextBtn.style.right = '0.5rem';
    }
}

// Carousel animation settings
let carouselAnimationsEnabled = true;

function toggleCarouselAnimations() {
    carouselAnimationsEnabled = !carouselAnimationsEnabled;
    const btn = document.getElementById('animation-toggle-btn');
    if (btn) {
        btn.innerHTML = carouselAnimationsEnabled
            ? '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'
            : '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>';
        btn.title = carouselAnimationsEnabled ? 'Animations On' : 'Animations Off';
    }
    showToast(carouselAnimationsEnabled ? 'Swipe animations enabled' : 'Swipe animations disabled');
}

// Animated carousel navigation (for swipe only)
function carouselPrevAnimated() {
    if (comparePhotos.length === 0) return;
    if (carouselAnimationsEnabled) {
        animateCarouselSlide('right', () => {
            carouselIndex = (carouselIndex - 1 + comparePhotos.length) % comparePhotos.length;
            updateCarouselDisplay();
        });
    } else {
        carouselPrev();
    }
}

function carouselNextAnimated() {
    if (comparePhotos.length === 0) return;
    if (carouselAnimationsEnabled) {
        animateCarouselSlide('left', () => {
            carouselIndex = (carouselIndex + 1) % comparePhotos.length;
            updateCarouselDisplay();
        });
    } else {
        carouselNext();
    }
}

function animateCarouselSlide(direction, callback) {
    const img = document.getElementById('carousel-img');
    if (!img) {
        callback();
        return;
    }

    const slideDistance = direction === 'left' ? '-100%' : '100%';

    // Slide out current image
    img.style.transition = 'transform 0.12s ease-out, opacity 0.12s ease-out';
    img.style.transform = `translateX(${slideDistance})`;
    img.style.opacity = '0';

    setTimeout(() => {
        // Update to new image (happens in callback)
        callback();

        // Position new image on opposite side
        img.style.transition = 'none';
        img.style.transform = `translateX(${direction === 'left' ? '100%' : '-100%'})`;
        img.style.opacity = '0';

        // Force reflow
        img.offsetHeight;

        // Slide in new image
        img.style.transition = 'transform 0.12s ease-out, opacity 0.12s ease-out';
        img.style.transform = 'translateX(0)';
        img.style.opacity = '1';

        // Clean up after animation
        setTimeout(() => {
            img.style.transition = '';
            img.style.transform = '';
        }, 130);
    }, 120);
}

// Initialize carousel swipe support with drag animation
(function initCarouselSwipe() {
    let touchStartX = 0;
    let touchCurrentX = 0;
    let isDragging = false;
    const minSwipeDistance = 50;
    const maxDragDistance = 150;

    document.addEventListener('touchstart', (e) => {
        const container = document.getElementById('carousel-photo-container');
        if (container && container.contains(e.target)) {
            touchStartX = e.changedTouches[0].screenX;
            touchCurrentX = touchStartX;
            isDragging = true;
        }
    }, { passive: true });

    document.addEventListener('touchmove', (e) => {
        if (!isDragging || !carouselAnimationsEnabled) return;

        const container = document.getElementById('carousel-photo-container');
        const img = document.getElementById('carousel-img');
        if (!container || !container.contains(e.target) || !img) return;

        touchCurrentX = e.changedTouches[0].screenX;
        const dragDistance = touchCurrentX - touchStartX;

        // Limit drag distance and add resistance
        const limitedDrag = Math.sign(dragDistance) * Math.min(Math.abs(dragDistance), maxDragDistance);
        const resistance = 1 - (Math.abs(limitedDrag) / maxDragDistance) * 0.3;

        // Apply transform during drag
        img.style.transition = 'none';
        img.style.transform = `translateX(${limitedDrag * resistance}px)`;
        img.style.opacity = `${1 - Math.abs(limitedDrag) / maxDragDistance * 0.3}`;
    }, { passive: true });

    document.addEventListener('touchend', (e) => {
        if (!isDragging) return;
        isDragging = false;

        const container = document.getElementById('carousel-photo-container');
        const img = document.getElementById('carousel-img');
        if (!container || !container.contains(e.target)) return;

        const swipeDistance = touchCurrentX - touchStartX;

        if (Math.abs(swipeDistance) >= minSwipeDistance) {
            if (swipeDistance > 0) {
                carouselPrevAnimated(); // Swipe right = previous
            } else {
                carouselNextAnimated(); // Swipe left = next
            }
        } else if (img) {
            // Snap back if swipe wasn't far enough
            img.style.transition = 'transform 0.1s ease-out, opacity 0.1s ease-out';
            img.style.transform = 'translateX(0)';
            img.style.opacity = '1';
            setTimeout(() => {
                img.style.transition = '';
                img.style.transform = '';
            }, 110);
        }
    }, { passive: true });
})();

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

    if (workouts.length === 0) {
        container.innerHTML = `
            <button data-action="openCreateWorkout"
                class="w-full py-6 border-2 border-dashed border-white/10 rounded-xl text-white/40 hover:text-white/70 hover:border-white/20 transition flex flex-col items-center justify-center gap-2 group">
                <span class="text-2xl group-hover:scale-110 transition-transform">💪</span>
                <span class="text-xs uppercase tracking-wider font-medium">Create Your First Workout</span>
            </button>
        `;
        return;
    }

    workouts.forEach(w => {
        const div = document.createElement('div');
        div.className = "glass-card p-3 flex justify-between items-center";
        div.innerHTML = `
            <div>
                <p class="font-bold text-sm text-white">${w.title}</p>
                <p class="text-[10px] text-gray-400">${w.exercises.length} Exercises • ${w.duration} • ${w.difficulty}</p>
            </div>
            <div class="flex gap-2">
                <button class="edit-workout-btn text-xs bg-white/5 hover:bg-white/10 px-2 py-1 rounded text-gray-300 transition">Edit</button>
                <button class="delete-workout-btn text-xs bg-red-500/20 hover:bg-red-500/40 px-2 py-1 rounded text-red-400 transition">🗑️</button>
            </div>
        `;

        div.querySelector('.edit-workout-btn').onclick = () => openEditWorkout(w);
        div.querySelector('.delete-workout-btn').onclick = () => deleteWorkout(w.id, w.title);

        container.appendChild(div);
    });
}

window.deleteWorkout = async function (workoutId, workoutTitle) {
    if (!confirm(`Are you sure you want to delete "${workoutTitle}"? This cannot be undone.`)) {
        return;
    }

    const { apiBase } = window.APP_CONFIG || {};

    try {
        const res = await fetch(`${apiBase}/api/trainer/workouts/${workoutId}`, {
            method: 'DELETE'
        });

        if (!res.ok) {
            const error = await res.json();
            throw new Error(error.detail || 'Failed to delete workout');
        }

        showToast(`"${workoutTitle}" deleted successfully`);
        fetchAndRenderWorkouts(); // Refresh the list
    } catch (error) {
        console.error('Error deleting workout:', error);
        showToast(`Error: ${error.message}`);
    }
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

// Toggle workout panel between expanded and compact mode (full screen video)
let workoutPanelCompact = false;
function toggleWorkoutPanel() {
    const panel = document.getElementById('workout-panel');
    const dragHandle = document.getElementById('drag-handle');
    const videoSection = document.querySelector('#workout-screen > div:first-child');

    if (!panel) return;

    // Ensure smooth transitions are set
    panel.style.transition = 'height 0.4s cubic-bezier(0.4, 0, 0.2, 1), flex 0.4s cubic-bezier(0.4, 0, 0.2, 1)';
    if (videoSection) {
        videoSection.style.transition = 'height 0.4s cubic-bezier(0.4, 0, 0.2, 1), flex 0.4s cubic-bezier(0.4, 0, 0.2, 1)';
    }
    if (dragHandle) {
        dragHandle.style.transition = 'all 0.3s ease';
    }

    workoutPanelCompact = !workoutPanelCompact;

    if (workoutPanelCompact) {
        // Compact mode - collapse panel to just the drag handle, video expands
        panel.style.flex = '0 0 56px';
        panel.style.height = '56px';
        panel.style.minHeight = '56px';
        panel.style.overflow = 'hidden';
        if (videoSection) {
            videoSection.style.flex = '1';
            videoSection.style.height = 'auto';
        }
        if (dragHandle) {
            dragHandle.style.width = '5rem';
            dragHandle.style.height = '5px';
            dragHandle.style.backgroundColor = 'rgba(249, 115, 22, 0.7)';
        }
    } else {
        // Expanded mode - restore normal layout
        panel.style.flex = '1';
        panel.style.height = 'auto';
        panel.style.minHeight = 'unset';
        panel.style.overflow = 'auto';
        if (videoSection) {
            videoSection.style.flex = '0 0 35vh';
            videoSection.style.height = '35vh';
        }
        if (dragHandle) {
            dragHandle.style.width = '2.5rem';
            dragHandle.style.height = '4px';
            dragHandle.style.backgroundColor = 'rgba(255, 255, 255, 0.2)';
        }
    }
}
window.toggleWorkoutPanel = toggleWorkoutPanel;

// function completeSet() removed (duplicate)

async function finishWorkout() {
    // Call API to mark as complete
    try {
        const todayStr = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD local time

        // Disable button specific logic if needed, or show loading state

        // Use different endpoint for trainers vs clients
        const endpoint = APP_CONFIG.role === 'trainer'
            ? `${apiBase}/api/trainer/schedule/complete`
            : `${apiBase}/api/client/schedule/complete`;

        const res = await fetch(endpoint, {
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

            // Refresh streak and quest data after workout completion
            if (APP_CONFIG.role === 'client') {
                try {
                    const clientDataRes = await fetch(`${apiBase}/api/client/data`);
                    if (clientDataRes.ok) {
                        const clientData = await clientDataRes.json();
                        console.log("Refreshed client data after workout:", clientData);

                        // Update username display
                        if (clientData.username) {
                            const displayNameEl = document.getElementById('client-display-name');
                            const welcomeNameEl = document.getElementById('client-welcome-name');
                            if (displayNameEl) displayNameEl.textContent = clientData.username;
                            if (welcomeNameEl) welcomeNameEl.textContent = clientData.username;
                        }

                        // Update streak display (week streak)
                        const streakEl = document.getElementById('client-streak');
                        if (streakEl) {
                            streakEl.innerText = clientData.streak;
                        }
                        // Legacy fallback
                        const legacyStreakEl = document.getElementById('streak-count');
                        if (legacyStreakEl) {
                            legacyStreakEl.innerText = clientData.streak;
                        }

                        // Update next goal for week streak
                        const weekMilestones = [4, 8, 12, 16, 24, 36, 52];
                        const nextMilestone = weekMilestones.find(m => m > clientData.streak) || (clientData.streak + 12);
                        const nextGoalEl = document.getElementById('client-next-goal');
                        if (nextGoalEl) {
                            nextGoalEl.innerText = `${nextMilestone} Weeks`;
                        }
                        const legacyNextGoalEl = document.getElementById('next-goal');
                        if (legacyNextGoalEl) {
                            legacyNextGoalEl.innerText = `${nextMilestone} Weeks`;
                        }
                    }
                } catch (e) {
                    console.error("Error refreshing client data:", e);
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

// --- WEEKLY SPLIT LOGIC ---

window.openCreateSplit = function () {
    document.getElementById('new-split-name').value = '';
    document.getElementById('new-split-desc').value = '';
    renderSplitScheduleBuilder('split-schedule-builder', []);
    showModal('create-split-modal');
};

window.openEditSplit = function (split) {
    document.getElementById('edit-split-id').value = split.id;
    document.getElementById('edit-split-name').value = split.name;
    document.getElementById('edit-split-desc').value = split.description || '';
    renderSplitScheduleBuilder('edit-split-schedule-builder', split.schedule || []);
    showModal('edit-split-modal');
};

window.createSplit = async function () {
    const name = document.getElementById('new-split-name').value;
    const desc = document.getElementById('new-split-desc').value;
    const schedule = getSplitScheduleFromBuilder('split-schedule-builder');

    if (!name) {
        showToast('Please enter a split name');
        return;
    }

    const trainerId = getCurrentTrainerId();
    const payload = { name, description: desc, schedule };

    try {
        const res = await fetch(`${apiBase}/api/trainer/splits`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast('Split created successfully! 📅');
            hideModal('create-split-modal');
            // Refresh data based on context
            if (location.pathname.includes('personal')) {
                if (typeof fetchTrainerData === 'function') fetchTrainerData();
            } else {
                if (typeof init === 'function') init(); // Reload dashboard data
                else window.location.reload();
            }
        } else {
            showToast('Failed to create split');
        }
    } catch (e) {
        console.error(e);
        showToast('Error creating split');
    }
};

window.updateSplit = async function () {
    const id = document.getElementById('edit-split-id').value;
    const name = document.getElementById('edit-split-name').value;
    const desc = document.getElementById('edit-split-desc').value;
    const schedule = getSplitScheduleFromBuilder('edit-split-schedule-builder');

    if (!id || !name) {
        showToast('Missing information');
        return;
    }

    const trainerId = getCurrentTrainerId();
    const payload = { name, description: desc, schedule };

    try {
        const res = await fetch(`${apiBase}/api/trainer/splits/${id}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast('Split updated! 💾');
            hideModal('edit-split-modal');
            if (location.pathname.includes('personal')) {
                if (typeof fetchTrainerData === 'function') fetchTrainerData();
            } else {
                if (typeof init === 'function') init();
                else window.location.reload();
            }
        } else {
            showToast('Failed to update split');
        }
    } catch (e) {
        console.error(e);
        showToast('Error updating split');
    }
};

window.deleteSplit = async function (id) {
    if (!id) id = document.getElementById('edit-split-id').value; // fallback for modal usage
    if (!confirm("Are you sure you want to delete this split?")) return;

    const trainerId = getCurrentTrainerId();

    try {
        const res = await fetch(`${apiBase}/api/trainer/splits/${id}`, {
            method: 'DELETE',
            headers: { 'x-trainer-id': trainerId }
        });

        if (res.ok) {
            showToast('Split deleted 🗑️');
            hideModal('edit-split-modal');
            if (location.pathname.includes('personal')) {
                if (typeof fetchTrainerData === 'function') fetchTrainerData();
            } else {
                if (typeof init === 'function') init();
                else window.location.reload();
            }
        } else {
            showToast('Failed to delete split');
        }
    } catch (e) {
        console.error(e);
        showToast('Error deleting split');
    }
};

// Helper to build the 7-day schedule UI
function renderSplitScheduleBuilder(containerId, scheduleData) {
    const container = document.getElementById(containerId);
    if (!container) return;
    container.innerHTML = '<p class="text-xs text-center text-gray-500">Loading workouts...</p>';

    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    // Convert scheduleData to map for easy lookup { 'Monday': workoutId, ... }
    const scheduleMap = {};
    if (scheduleData) {
        scheduleData.forEach(item => {
            scheduleMap[item.day] = item.workout_id;
        });
    }

    // Fetch Workouts
    fetch(`${apiBase}/api/trainer/workouts`).then(res => res.json()).then(workouts => {
        container.innerHTML = ''; // Clear loading
        days.forEach(day => {
            const row = document.createElement('div');
            row.className = "flex items-center space-x-3 bg-white/5 p-2 rounded-lg";

            let optionsHtml = `<option value="">Rest Day</option>`;
            workouts.forEach(w => {
                const selected = scheduleMap[day] === w.id ? 'selected' : '';
                optionsHtml += `<option value="${w.id}" ${selected}>${w.title}</option>`;
            });

            row.innerHTML = `
                <span class="w-24 text-sm text-gray-400 font-bold">${day}</span>
                <select class="flex-1 bg-black/30 border border-white/10 rounded-lg p-2 text-sm text-white focus:border-primary outline-none transition"
                    data-day="${day}">
                    ${optionsHtml}
                </select>
            `;
            container.appendChild(row);
        });
    }).catch(err => {
        console.error("Failed to load workouts for split builder", err);
        container.innerHTML = '<p class="text-xs text-red-500">Failed to load workouts.</p>';
    });
}

function getSplitScheduleFromBuilder(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return [];

    const schedule = [];
    const selects = container.querySelectorAll('select');
    selects.forEach(select => {
        const day = select.dataset.day;
        const workoutId = select.value;
        if (workoutId) {
            schedule.push({ day, workout_id: workoutId });
        }
    });
    return schedule;
}

window.assignSplitToSelf = async function (splitId, splitName) {
    const planContainer = document.getElementById('todays-plan-container');
    if (!planContainer) {
        showToast("Could not find Today's Plan section");
        return;
    }

    const { gymId: localGymId, apiBase } = window.APP_CONFIG || {};

    // Current date (Monday of this week)
    let d = new Date();
    const day = d.getDay() || 7;
    if (day !== 1) d.setHours(-24 * (day - 1));
    d.setHours(0, 0, 0, 0);
    const startDate = d.toLocaleDateString('en-CA'); // YYYY-MM-DD

    let myId = window.currentTrainerId;

    if (!myId) {
        // Fallback: Fetch trainer data to get ID
        try {
            const res = await fetch(`${apiBase}/api/trainer/data`, {
                credentials: 'include'
            });
            if (res.ok) {
                const data = await res.json();
                myId = data.id;
                window.currentTrainerId = myId; // Cache it
            }
        } catch (e) {
            console.error("Failed to fetch trainer ID from trainer/data", e);
        }
    }

    // Double fallback to client/data if trainer data doesn't return ID
    if (!myId) {
        try {
            const meRes = await fetch(`${apiBase}/api/client/data`, {
                credentials: 'include'
            });
            if (meRes.ok) {
                const me = await meRes.json();
                myId = me.id;
            }
        } catch (e) {
            console.error("Failed to fetch ID from client/data", e);
        }
    }

    if (!myId) {
        showToast("Error: Could not identify your user account.");
        return;
    }

    try {
        const res = await fetch(`${apiBase}/api/trainer/assign_split`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
                client_id: myId,
                split_id: splitId,
                start_date: startDate
            })
        });

        if (!res.ok) {
            const errText = await res.text();
            throw new Error(errText || 'Failed to assign split');
        }

        // Fetch updated trainer data to get today's workout
        const trainerRes = await fetch(`${apiBase}/api/trainer/data?limit_cache=${Date.now()}`, {
            credentials: 'include'
        });
        const trainerData = await trainerRes.json();

        if (trainerData.todays_workout) {
            const workout = trainerData.todays_workout;
            const completedClass = workout.completed ? 'bg-green-500' : 'bg-white';
            const completedText = workout.completed ? 'COMPLETED ✓' : 'START SESSION';
            const completedTextColor = workout.completed ? 'text-white' : 'text-black';

            planContainer.innerHTML = `
                <div class="glass-card p-5 relative overflow-hidden group tap-effect cursor-pointer" onclick="window.location.href='/?gym_id=${localGymId}&role=trainer&mode=workout&workout_id=${workout.id}${workout.completed ? '&view=completed' : ''}'">
                    <div class="absolute inset-0 bg-primary opacity-20 group-hover:opacity-30 transition"></div>
                    <div class="relative z-10">
                        <div class="flex justify-between items-start mb-4">
                            <span class="bg-white/10 px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider">Today's Plan</span>
                            <span class="text-xl">💪</span>
                        </div>
                        <h3 class="text-2xl font-black italic uppercase mb-1">${workout.title}</h3>
                        <p class="text-sm text-gray-300 mb-4">${workout.duration} min • ${workout.difficulty}</p>
                        <p class="text-xs text-gray-400 mb-3">📅 From: ${splitName}</p>
                        <button class="block w-full py-3 ${completedClass} hover:bg-gray-200 ${completedTextColor} text-center font-bold rounded-xl transition">${completedText}</button>
                    </div>
                </div>
            `;
        } else {
            // If no workout for today, just show success message
            planContainer.innerHTML = `
                <div class="glass-card p-5 relative overflow-hidden">
                    <div class="flex justify-between items-start mb-4">
                        <span class="bg-white/10 px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider">Today's Plan</span>
                        <span class="text-xl">📋</span>
                    </div>
                    <h3 class="text-xl font-bold text-white/50 mb-2">Rest Day</h3>
                    <p class="text-sm text-gray-400">Split "${splitName}" assigned! No workout scheduled for today.</p>
                </div>
            `;
        }

        showToast(`${splitName} assigned to you! 🚀`);
    } catch (error) {
        console.error('Error assigning split:', error);
        showToast(`Error: ${error.message}`);
    }
};

// Assign workout to trainer's own schedule for Today
window.assignWorkoutToSelf = async function (workoutId, workoutTitle) {
    const planContainer = document.getElementById('todays-plan-container');
    if (!planContainer) {
        showToast("Could not find Today's Plan section");
        return;
    }

    const { gymId: localGymId, apiBase } = window.APP_CONFIG || {};

    try {
        // Get today's date in YYYY-MM-DD format
        const today = new Date();
        const dateStr = today.toISOString().split('T')[0];

        // Create event data for the API
        const eventData = {
            date: dateStr,
            time: "08:00", // Default morning time
            title: workoutTitle,
            subtitle: "Personal Workout",
            type: "workout",
            duration: 60,
            workout_id: workoutId
        };

        // Save to database via API
        const response = await fetch(`${apiBase}/api/trainer/events`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(eventData)
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Failed to assign workout');
        }

        // Update UI after successful save
        planContainer.innerHTML = `
            <div class="glass-card p-5 relative overflow-hidden group tap-effect cursor-pointer" onclick="window.location.href='/?gym_id=${localGymId}&role=trainer&mode=workout&workout_id=${workoutId}'">
                <div class="absolute inset-0 bg-primary opacity-20 group-hover:opacity-30 transition"></div>
                <div class="relative z-10">
                    <div class="flex justify-between items-start mb-4">
                        <span class="bg-white/10 px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider">Today's Plan</span>
                        <span class="text-xl">💪</span>
                    </div>
                    <h3 class="text-2xl font-black italic uppercase mb-1">${workoutTitle}</h3>
                    <p class="text-sm text-gray-300 mb-4">60 min • Intermediate</p>
                    <button class="block w-full py-3 bg-white text-black hover:bg-gray-200 text-center font-bold rounded-xl transition">START SESSION</button>
                </div>
            </div>
        `;

        showToast(`${workoutTitle} set as today's plan! 💪`);
    } catch (error) {
        console.error('Error assigning workout:', error);
        showToast(`Error: ${error.message}`);
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

// Helper function to initialize workout with given data
function initWorkoutWithData(workout, isPreview = false) {
    console.log('initWorkoutWithData called:', workout.title, 'preview:', isPreview);

    workoutState = {
        workoutId: workout.id,
        exercises: workout.exercises.map(ex => ({
            ...ex,
            collapsed: false,
            performance: ex.performance || Array(ex.sets || 3).fill().map(() => ({ reps: '', weight: '', completed: false }))
        })),
        currentExerciseIdx: 0,
        currentSet: 1,
        currentReps: parseInt(String(workout.exercises[0]?.reps || '10').split('-')[1] || workout.exercises[0]?.reps || '10'),
        isCompletedView: isPreview, // Treat preview like completed view (no edits)
        isPreview: isPreview
    };

    // Show preview banner if in preview mode
    if (isPreview) {
        const header = document.querySelector('#workout-screen .absolute.top-0.left-0');
        if (header) {
            const banner = document.createElement('div');
            banner.className = "absolute top-20 left-1/2 transform -translate-x-1/2 bg-blue-500/90 text-white px-4 py-1 rounded-full text-xs font-bold backdrop-blur-md z-50";
            banner.innerText = "PREVIEW MODE";
            header.appendChild(banner);
        }

        // Hide complete button in preview
        const completeBtn = document.getElementById('complete-btn');
        if (completeBtn) completeBtn.style.display = 'none';
    }

    updateWorkoutUI();
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

        const role = APP_CONFIG.role;
        const previewWorkoutId = urlParams.get('workout_id');
        const isPreviewMode = urlParams.get('view') === 'preview';

        // If previewing a specific workout (not today's workout), fetch it directly
        if (previewWorkoutId && isPreviewMode) {
            console.log('PREVIEW MODE: Loading workout ID:', previewWorkoutId);
            fetch(`${apiBase}/api/trainer/workouts`)
                .then(res => res.json())
                .then(workouts => {
                    const workout = workouts.find(w => w.id === previewWorkoutId || w.id === parseInt(previewWorkoutId));
                    if (!workout) {
                        console.error('Workout not found:', previewWorkoutId);
                        document.getElementById('workout-screen').innerHTML = `
                            <div class="flex flex-col items-center justify-center h-screen bg-gray-900 text-white p-8 text-center">
                                <div class="text-6xl mb-4">⚠️</div>
                                <h1 class="text-4xl font-black mb-2">Workout Not Found</h1>
                                <p class="text-gray-400 mb-8">The requested workout could not be loaded.</p>
                                <a href="/?gym_id=${gymId}&role=${APP_CONFIG.role}" class="px-8 py-3 bg-white/10 rounded-xl font-bold hover:bg-white/20 transition">Back to Dashboard</a>
                            </div>
                        `;
                        return;
                    }
                    initWorkoutWithData(workout, true); // true = preview mode
                })
                .catch(err => {
                    console.error('Error loading preview workout:', err);
                });
            return;
        }

        const endpoint = role === 'trainer' ? `${apiBase}/api/trainer/data` : `${apiBase}/api/client/data`;

        fetch(endpoint)
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
                            <a href="/?gym_id=${gymId}&role=${APP_CONFIG.role}" class="px-8 py-3 bg-white/10 rounded-xl font-bold hover:bg-white/20 transition">Back to Dashboard</a>
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
                // EXPANDED ACTIVE CARD - Modern glass style
                div.className = `glass-card p-4 mb-4 relative overflow-visible transition-all duration-300 border border-orange-500/30 rounded-2xl`;
                div.onclick = null; // Disable collapse on click

                // Subtle glow effect
                const glow = document.createElement('div');
                glow.className = "absolute -inset-1 bg-orange-500/10 blur-xl rounded-2xl pointer-events-none -z-10";
                div.appendChild(glow);

                // Generate Sets Rows - Modern clean style
                const isDisabled = workoutState.isCompletedView ? 'disabled' : '';
                const baseInputClass = "w-full bg-transparent border-none text-white text-right font-bold outline-none text-base placeholder-white/20";
                const inputClass = isDisabled ? `${baseInputClass} opacity-50 cursor-not-allowed` : baseInputClass;

                let setsHtml = '';
                for (let i = 0; i < item.sets; i++) {
                    const perf = item.performance[i];

                    const isSetCompleted = perf.completed;
                    const isSetActive = (i === (workoutState.currentSet - 1));

                    // Dynamic styles - use 4 columns when in completed view to fit edit button
                    const gridCols = workoutState.isCompletedView ? 'grid-cols-[1.2fr,1fr,1fr,auto]' : 'grid-cols-[1.2fr,1fr,1fr]';
                    let rowClass = `grid ${gridCols} gap-2 mb-2 items-center relative z-10 transition-all duration-200 rounded-xl p-2.5`;
                    let currentInputClass = inputClass;
                    let statusIcon = "";

                    if (isSetCompleted) {
                        rowClass += " bg-green-500/5 border border-green-500/10";
                        statusIcon = `<div class="absolute left-2 top-1/2 transform -translate-y-1/2 w-5 h-5 bg-green-500/20 rounded-md flex items-center justify-center text-green-500 z-20">
                            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                        </div>`;
                        currentInputClass += " cursor-not-allowed text-white/60";
                    } else if (isSetActive) {
                        rowClass += " bg-orange-500/5 border border-orange-500/20";
                        statusIcon = `<div class="absolute left-2 top-1/2 transform -translate-y-1/2 w-5 h-5 bg-orange-500 rounded-md flex items-center justify-center text-white z-20">
                            <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                        </div>`;
                    } else {
                        rowClass += " border border-white/5 bg-white/[0.02]";
                    }

                    const isInputDisabled = isDisabled || isSetCompleted ? 'disabled' : '';

                    // EDIT MODE LOGIC - now as grid item, not absolute
                    let editBtnHtml = '';
                    if (workoutState.isCompletedView) {
                        const isEditing = perf.isEditing || false;

                        if (isEditing) {
                            currentInputClass = baseInputClass + " border-b border-orange-500";
                            editBtnHtml = `
                                <button onclick="event.stopPropagation(); window.updateSetData(${idx}, ${i}, this.closest('.grid').querySelector('input[placeholder=\\'${item.reps}\\']').value, this.closest('.grid').querySelector('input[placeholder=\\'-\\' ]').value); workoutState.exercises[${idx}].performance[${i}].isEditing = false; updateWorkoutUI();"
                                    class="w-8 h-8 bg-green-500 rounded-lg flex items-center justify-center text-white hover:scale-105 transition flex-shrink-0">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                                </button>
                            `;
                        } else {
                            editBtnHtml = `
                                <button onclick="event.stopPropagation(); workoutState.exercises[${idx}].performance[${i}].isEditing = true; updateWorkoutUI();"
                                    class="w-8 h-8 bg-white/5 border border-white/10 rounded-lg flex items-center justify-center text-white/40 hover:bg-white/10 hover:text-white transition flex-shrink-0">
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/></svg>
                                </button>
                            `;
                        }
                    }

                    setsHtml += `
                        <div class="${rowClass}">
                            ${statusIcon}
                            <span class="text-xs font-medium text-white/40 pl-8 uppercase tracking-wider ${isSetActive ? 'text-orange-500' : ''}">Set ${i + 1}</span>
                            <div class="flex items-center bg-white/5 border border-white/5 rounded-lg px-3 py-2.5 focus-within:border-orange-500/50 transition">
                                <input type="number" value="${perf.reps}"
                                    oninput="window.updatePerformance(${idx}, ${i}, 'reps', this.value)"
                                    onclick="event.stopPropagation()"
                                    ${workoutState.isCompletedView && !perf.isEditing ? 'disabled' : (isInputDisabled && !perf.isEditing ? 'disabled' : '')}
                                    class="${currentInputClass}" placeholder="${item.reps}">
                                <span class="text-[10px] text-white/30 font-medium ml-1 uppercase">reps</span>
                            </div>
                            <div class="flex items-center bg-white/5 border border-white/5 rounded-lg px-3 py-2.5 focus-within:border-orange-500/50 transition">
                                <input type="number" value="${perf.weight}"
                                    oninput="window.updatePerformance(${idx}, ${i}, 'weight', this.value)"
                                    onclick="event.stopPropagation()"
                                    ${workoutState.isCompletedView && !perf.isEditing ? 'disabled' : (isInputDisabled && !perf.isEditing ? 'disabled' : '')}
                                    class="${currentInputClass}" placeholder="-">
                                <span class="text-[10px] text-white/30 font-medium ml-1 uppercase">kg</span>
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
                    <span class="text-[10px] font-medium text-green-500 bg-green-500/10 px-2.5 py-1 rounded-lg border border-green-500/20 uppercase tracking-wider flex items-center gap-1.5">
                        <span class="w-1.5 h-1.5 bg-green-500 rounded-full"></span> Done
                    </span>`;
                } else {
                    badgeHtml = `
                    <span class="text-[10px] font-medium text-orange-500 bg-orange-500/10 px-2.5 py-1 rounded-lg border border-orange-500/20 uppercase tracking-wider flex items-center gap-1.5">
                        <span class="w-1.5 h-1.5 bg-orange-500 rounded-full animate-pulse"></span> Active
                    </span>`;
                }

                div.innerHTML += `
                    <div class="flex items-center justify-between mb-4 pb-3 border-b border-white/5 relative z-10 cursor-pointer group"
                        onclick="window.toggleCollapse(${idx}, event)">
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 rounded-xl bg-orange-500 flex items-center justify-center text-white text-sm">
                                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                            </div>
                            <div>
                                <h4 class="font-bold text-white text-lg">${item.name}</h4>
                                <p class="text-xs text-orange-500 font-medium">${item.sets} Sets &bull; ${item.reps} Target</p>
                            </div>
                        </div>
                        <div class="flex items-center gap-2">
                             ${badgeHtml}
                            <div class="w-7 h-7 rounded-lg bg-white/5 flex items-center justify-center transition-transform duration-300 ${chevronRotate} group-hover:bg-white/10 text-white/50">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
                            </div>
                        </div>
                    </div>

                    <div class="space-y-2 relative z-10 transition-all duration-300 overflow-hidden ${isCollapsed ? 'max-h-0 opacity-0' : 'max-h-[1000px] opacity-100'}">
                        ${setsHtml}
                    </div>
                `;

            } else {
                // COMPACT CARD (Inactive) - Clean minimal style
                div.className = `p-3 rounded-xl flex items-center mb-2 cursor-pointer transition-all bg-white/[0.02] hover:bg-white/5 border border-white/5 ${idx < workoutState.currentExerciseIdx ? 'opacity-60' : 'opacity-40'} hover:opacity-100`;
                div.onclick = () => window.switchExercise(idx);

                let icon = `<div class="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-xs text-white/50 font-medium">${idx + 1}</div>`;
                if (idx < workoutState.currentExerciseIdx || workoutState.isCompletedView) {
                    icon = `<div class="w-8 h-8 rounded-lg bg-green-500/20 flex items-center justify-center text-green-500">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                    </div>`;
                }

                div.innerHTML = `
                    <div class="flex items-center gap-3 pointer-events-none w-full">
                        ${icon}
                        <div class="flex-1">
                            <h4 class="font-medium text-white text-sm">${item.name}</h4>
                            <p class="text-xs text-white/40">${item.sets} Sets &bull; ${item.reps} Reps</p>
                        </div>
                        ${idx < workoutState.currentExerciseIdx ? '<span class="text-[10px] text-green-500 font-medium uppercase tracking-wider">Done</span>' : ''}
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

// [Duplicate openAssignSplitModal and assignSplit functions removed]


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



window.fetchAndRenderSplits = async function () {
    const trainerId = getCurrentTrainerId();
    try {
        const res = await fetch(`${apiBase}/api/trainer/splits`, {
            headers: { 'x-trainer-id': trainerId }
        });

        if (!res.ok) throw new Error("Failed to fetch splits");

        const splits = await res.json();
        const container = document.getElementById('split-library');
        if (!container) return;

        container.innerHTML = '';
        if (splits.length === 0) {
            container.innerHTML = `
                <button data-action="openCreateSplit"
                    class="w-full py-6 border-2 border-dashed border-white/10 rounded-xl text-white/40 hover:text-white/70 hover:border-white/20 transition flex flex-col items-center justify-center gap-2 group">
                    <span class="text-2xl group-hover:scale-110 transition-transform">📅</span>
                    <span class="text-xs uppercase tracking-wider font-medium">Create Your First Split</span>
                </button>
            `;
            return;
        }

        splits.forEach(s => {
            const div = document.createElement('div');
            div.className = "glass-card p-3 flex justify-between items-center mb-2";
            div.innerHTML = `
                <div>
                    <p class="font-bold text-sm text-white">${s.name}</p>
                    <p class="text-[10px] text-gray-400">${s.description || 'No description'}</p>
                    <p class="text-[10px] text-primary mt-1">${s.days_per_week} Days</p>
                </div>
                <div class="flex gap-2">
                    <button class="text-xs bg-white/5 hover:bg-white/10 px-2 py-1 rounded text-gray-300 transition" onclick="openAssignSplitModal('${s.id}')">Assign</button>
                    <button class="text-xs bg-white/5 hover:bg-white/10 px-2 py-1 rounded text-gray-300 transition" onclick="openEditSplitModal('${s.id}')">✏️</button>
                    <button class="text-xs bg-white/5 hover:bg-white/10 px-2 py-1 rounded text-gray-300 transition" onclick="deleteSplit('${s.id}')">🗑️</button>
                </div>
            `;
            container.appendChild(div);
        });

        // Store splits for editing
        window.loadedSplits = splits;

    } catch (e) {
        console.error("Error loading splits:", e);
    }
}

window.openEditSplitModal = function (splitId) {
    const split = window.loadedSplits.find(s => s.id === splitId);
    if (!split) return;

    document.getElementById('edit-split-id').value = split.id;
    document.getElementById('edit-split-name').value = split.name;
    document.getElementById('edit-split-desc').value = split.description || '';

    // Populate state
    splitScheduleState = JSON.parse(JSON.stringify(split.schedule)); // Deep copy

    renderSplitScheduleBuilder('edit-split-schedule-builder');
    showModal('edit-split-modal');
}

window.updateSplit = async function () {
    const id = document.getElementById('edit-split-id').value;
    const name = document.getElementById('edit-split-name').value;
    const desc = document.getElementById('edit-split-desc').value;

    if (!name) {
        showToast('Please enter a split name');
        return;
    }

    const payload = {
        name: name,
        description: desc,
        days_per_week: 7,
        schedule: splitScheduleState
    };

    try {
        const trainerId = getCurrentTrainerId();
        const res = await fetch(`${apiBase}/api/trainer/splits/${id}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast('Split updated! 💾');
            hideModal('edit-split-modal');
            fetchAndRenderSplits();
        } else {
            const err = await res.text();
            showToast('Failed to update split: ' + err);
        }
    } catch (e) {
        console.error(e);
        showToast('Error updating split');
    }
}

// Initialize splits and courses on load if trainer
document.addEventListener('DOMContentLoaded', () => {
    if (APP_CONFIG.role === 'trainer') {
        // Small delay to ensure auth is ready
        setTimeout(() => {
            if (window.fetchAndRenderSplits) window.fetchAndRenderSplits();
            if (window.loadCourses) window.loadCourses();
        }, 500);
    }
});

window.deleteSplit = async function (splitId) {
    if (!confirm("Are you sure you want to delete this split?")) return;

    const trainerId = getCurrentTrainerId();
    try {
        const res = await fetch(`${apiBase}/api/trainer/splits/${splitId}`, {
            method: 'DELETE',
            headers: { 'x-trainer-id': trainerId }
        });

        if (res.ok) {
            showToast("Split deleted");
            fetchAndRenderSplits();
        } else {
            showToast("Failed to delete split");
        }
    } catch (e) {
        console.error(e);
        showToast("Error deleting split");
    }
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

    renderSplitScheduleBuilder('split-schedule-builder');
    showModal('create-split-modal');
}

function renderSplitScheduleBuilder(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;

    container.innerHTML = '';
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    days.forEach(day => {
        const div = document.createElement('div');
        div.className = "flex items-center justify-between bg-white/5 p-3 rounded-xl";

        const workout = splitScheduleState[day];
        let content = `<span class="text-gray-500 italic text-xs">Rest Day</span>`;

        if (workout && workout.id) {
            content = `<span class="text-primary font-bold text-xs">${workout.title}</span>`;
        }

        div.innerHTML = `
            <span class="text-sm font-bold text-white w-24">${day}</span>
            <div class="flex-1 mx-4 text-center truncate">${content}</div>
            <button onclick="openSplitWorkoutSelector('${day}', '${containerId}')" class="text-xs bg-white/10 px-2 py-1 rounded hover:bg-white/20 transition">
                ${workout ? 'Change' : '+ Add Workout'}
            </button>
        `;
        container.appendChild(div);
    });
}

window.openSplitWorkoutSelector = async function (day, containerId) {
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
        const select = document.getElementById('temp-split-selector');
        const val = select.value;
        const title = select.options[select.selectedIndex].text;

        splitScheduleState[day] = val ? { id: val, title: title } : null;
        renderSplitScheduleBuilder(containerId);
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
        days_per_week: 7,
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
            if (window.fetchAndRenderSplits) {
                window.fetchAndRenderSplits();
            }
        } else {
            const err = await res.text();
            console.error("Create Split Error:", err);
            showToast('Failed to create split: ' + err);
        }
    } catch (e) {
        console.error(e);
        showToast('Error creating split');
    }
}
window.openAssignSplitModal = async function (splitId, explicitClientId) {
    const trainerId = getCurrentTrainerId();
    const clientSelect = document.getElementById('assign-split-client-selector');
    const container = document.getElementById('assign-split-client-selector-container');

    if (!container || !clientSelect) {
        console.error("Critical Error: Client selector UI elements missing!");
        showToast("Error: UI element missing");
        return;
    }

    try {
        // 1. Fetch Clients
        console.log("Fetching clients for trainer:", trainerId);
        const res = await fetch(`${apiBase}/api/trainer/clients`, {
            headers: { 'x-trainer-id': trainerId },
            credentials: 'include'
        });

        if (!res.ok) {
            const err = await res.text();
            console.error("Fetch clients failed:", res.status, err);
            showToast("Error fetching clients: " + res.status);
        } else {
            const clients = await res.json();
            console.log("Clients received:", clients);

            clientSelect.innerHTML = '<option value="">Select a Client</option>';
            if (clients.length === 0) {
                const opt = document.createElement('option');
                opt.innerText = "No clients found";
                opt.disabled = true;
                clientSelect.appendChild(opt);
            } else {
                clients.forEach(c => {
                    const opt = document.createElement('option');
                    opt.value = c.id;
                    opt.innerText = c.name || c.username || "Unknown";
                    clientSelect.appendChild(opt);
                });
            }
            container.classList.remove('hidden');

            // Add listener to update hidden ID
            console.log("Attaching onchange listener to client selector");
            clientSelect.onchange = () => {
                console.log("Client selected:", clientSelect.value);
                document.getElementById('assign-split-client-id').value = clientSelect.value;
            };

            // AUTO-SELECT LOGIC
            let targetClientId = explicitClientId;
            if (!targetClientId) {
                // Check if we are in the context of a specific client (Client Modal)
                const clientModal = document.getElementById('client-modal');

                // DEBUG LOGS
                if (clientModal) {
                    console.log("[DEBUG] Client Modal Found. Hidden:", clientModal.classList.contains('hidden'));
                    console.log("[DEBUG] Client Modal Dataset:", clientModal.dataset);
                    console.log("[DEBUG] Dataset Client ID:", clientModal.dataset.clientId);
                } else {
                    console.log("[DEBUG] Client Modal NOT found in DOM");
                }

                // Check if client modal is visible AND has an ID
                // Relaxed check: verify dataset.clientId is present, ignore hidden state for a moment if z-indexing is complex
                if (clientModal && clientModal.dataset.clientId) {
                    targetClientId = clientModal.dataset.clientId;
                }
            }

            if (targetClientId) {
                console.log("Auto-selecting client:", targetClientId);

                // Verify option exists
                const optionExists = [...clientSelect.options].some(o => o.value == targetClientId);
                console.log("[DEBUG] Target ID exists in options?", optionExists);

                if (optionExists) {
                    clientSelect.value = targetClientId;
                    // Manually trigger the update
                    document.getElementById('assign-split-client-id').value = targetClientId;
                } else {
                    console.warn("[DEBUG] Target client ID found but not in list:", targetClientId);
                }
            } else {
                // Reset hidden ID if no auto-selection
                document.getElementById('assign-split-client-id').value = "";
            }
        }

        // 2. Fetch Splits to populate selector (and select current)
        const splitSelect = document.getElementById('assign-split-select');
        const resSplits = await fetch(`${apiBase}/api/trainer/splits`, {
            headers: { 'x-trainer-id': trainerId }
        });
        const splits = await resSplits.json();

        splitSelect.innerHTML = '';
        splits.forEach(s => {
            const opt = document.createElement('option');
            opt.value = s.id;
            opt.innerText = s.name;
            if (s.id === splitId) opt.selected = true;
            splitSelect.appendChild(opt);
        });

        showModal('assign-split-modal');

    } catch (e) {
        console.error("Error in openAssignSplitModal:", e);
        showToast("Error loading assignment data");
    }
};

window.assignSplit = async function () {
    const splitId = document.getElementById('assign-split-select').value;
    const clientId = document.getElementById('assign-split-client-selector').value;
    const startDate = document.getElementById('assign-split-date').value;

    if (!splitId || !clientId || !startDate) {
        showToast("Please fill in all fields");
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
                split_id: splitId,
                client_id: clientId,
                start_date: startDate
            })
        });

        if (res.ok) {
            const data = await res.json();
            if (data.warnings) {
                showToast("⚠️ Assigned with some errors. Check console.");
                console.warn("Assignment Logs:", data.logs);
            } else {
                showToast("Split assigned successfully! 📅");
            }
            hideModal('assign-split-modal');
        } else {
            const err = await res.text();
            showToast("Failed to assign: " + err);
        }
    } catch (e) {
        console.error(e);
        showToast("Error assigning split");
    }
};

// --- CHAT / MESSAGING FUNCTIONS ---

// Scroll lock helpers
let scrollLockCount = 0;
let savedScrollY = 0;

function lockBodyScroll() {
    if (scrollLockCount === 0) {
        savedScrollY = window.scrollY;
        document.body.style.position = 'fixed';
        document.body.style.top = `-${savedScrollY}px`;
        document.body.style.left = '0';
        document.body.style.right = '0';
        document.body.style.overflow = 'hidden';
    }
    scrollLockCount++;
}

function unlockBodyScroll() {
    scrollLockCount--;
    if (scrollLockCount <= 0) {
        scrollLockCount = 0;
        document.body.style.position = '';
        document.body.style.top = '';
        document.body.style.left = '';
        document.body.style.right = '';
        document.body.style.overflow = '';
        window.scrollTo(0, savedScrollY);
    }
}

let currentChatState = {
    conversationId: null,
    otherUserId: null,
    otherUserName: null,
    messages: []
};

// Open chat with a user from leaderboard or other places
window.openChatWithUser = async function(userId, userName, avatarUrl) {
    try {
        // First check if we can message this user
        const checkRes = await fetch(`${apiBase}/api/client/can-message/${userId}`, {
            headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` }
        });
        const checkData = await checkRes.json();

        if (!checkData.can_message) {
            // Can't message - handle different reasons
            if (checkData.reason === 'staff_only') {
                showToast('This user only accepts messages from gym staff', 'info');
                return;
            } else if (checkData.reason === 'private' && checkData.needs_request) {
                // Show option to send chat request
                if (confirm(`${userName} has a private profile. Send them a chat request?`)) {
                    const reqRes = await fetch(`${apiBase}/api/client/chat-requests`, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${localStorage.getItem('token')}`,
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ to_user_id: userId })
                    });
                    const reqData = await reqRes.json();
                    if (reqData.success) {
                        showToast('Chat request sent!', 'success');
                    } else {
                        showToast(reqData.detail || 'Failed to send request', 'error');
                    }
                }
                return;
            } else if (checkData.reason === 'request_pending') {
                showToast('Your chat request is pending approval', 'info');
                return;
            } else {
                showToast('Cannot message this user', 'error');
                return;
            }
        }

        // Can message - open the chat
        const chatUserAvatar = document.getElementById('chat-user-avatar');
        if (chatUserAvatar && avatarUrl) {
            chatUserAvatar.src = avatarUrl;
            chatUserAvatar.dataset.customSet = 'true';
        }
        window.openChatModal(userId, userName);
    } catch (err) {
        console.error('Error checking message permission:', err);
        showToast('Error opening chat', 'error');
    }
};

window.openChatModal = async function(otherUserId, otherUserName) {
    // If called from client modal, get info from there
    if (!otherUserId) {
        const clientModal = document.getElementById('client-modal');
        if (clientModal && clientModal.dataset.clientId) {
            otherUserId = clientModal.dataset.clientId;
            otherUserName = clientModal.dataset.clientName || 'Client';
        }
    }

    if (!otherUserId) {
        showToast('No user selected for chat');
        return;
    }

    currentChatState.otherUserId = otherUserId;
    currentChatState.otherUserName = otherUserName || 'User';
    currentChatState.conversationId = null;
    currentChatState.messages = [];

    // Update chat header
    const chatUserName = document.getElementById('chat-user-name');
    if (chatUserName) chatUserName.innerText = currentChatState.otherUserName;

    // Set default avatar if not already set by openChatWithUser
    const chatUserAvatar = document.getElementById('chat-user-avatar');
    if (chatUserAvatar && !chatUserAvatar.dataset.customSet) {
        chatUserAvatar.src = `https://api.dicebear.com/7.x/avataaars/svg?seed=${currentChatState.otherUserName}`;
    }
    // Reset the custom flag
    if (chatUserAvatar) chatUserAvatar.dataset.customSet = '';

    // Clear messages container
    const messagesContainer = document.getElementById('chat-messages');
    if (messagesContainer) {
        messagesContainer.innerHTML = '<div class="text-center text-gray-500 py-8">Loading messages...</div>';
    }

    // Show modal with animation
    const chatModal = document.getElementById('chat-modal');
    if (chatModal) {
        chatModal.classList.remove('hidden', 'slide-out-right');
        chatModal.classList.add('slide-in-right');
        // Lock body scroll
        lockBodyScroll();
    }

    // Load messages
    await loadChatMessages();
};

// Client chat modal - opens the conversations list
window.openClientChatModal = async function() {
    // Open the conversations list modal (shows all conversations: trainer + gym members)
    window.openConversationsModal();
};

window.closeChatModal = function() {
    const chatModal = document.getElementById('chat-modal');
    if (chatModal) {
        chatModal.classList.remove('slide-in-right');
        chatModal.classList.add('slide-out-right');
        // Hide after animation completes
        setTimeout(() => {
            chatModal.classList.add('hidden');
            chatModal.classList.remove('slide-out-right');
            // Restore body scroll
            unlockBodyScroll();
        }, 250);
    }

    currentChatState = {
        conversationId: null,
        otherUserId: null,
        otherUserName: null,
        messages: []
    };
};

async function loadChatMessages() {
    try {
        // Fetch conversations to find existing one with this user
        const convsRes = await fetch(`${apiBase}/api/messages/conversations`, {
            credentials: 'include'
        });

        if (!convsRes.ok) {
            throw new Error('Failed to load conversations');
        }

        const conversations = await convsRes.json();

        // Find conversation with this user
        const existingConv = conversations.find(c => c.other_user_id === currentChatState.otherUserId);

        if (existingConv) {
            currentChatState.conversationId = existingConv.id;

            // Fetch messages for this conversation
            const msgsRes = await fetch(`${apiBase}/api/messages/conversation/${existingConv.id}`, {
                credentials: 'include'
            });

            if (msgsRes.ok) {
                const data = await msgsRes.json();
                currentChatState.messages = data.messages || [];

                // Mark as read and update badge
                await fetch(`${apiBase}/api/messages/conversation/${existingConv.id}/read`, {
                    method: 'POST',
                    credentials: 'include'
                });
                // Update the notification badge
                updateUnreadBadge();
            }
        }

        renderChatMessages();

    } catch (e) {
        console.error('Error loading chat:', e);
        const messagesContainer = document.getElementById('chat-messages');
        if (messagesContainer) {
            messagesContainer.innerHTML = '<div class="text-center text-red-400 py-8">Failed to load messages</div>';
        }
    }
}

function renderChatMessages() {
    const container = document.getElementById('chat-messages');
    if (!container) return;

    if (currentChatState.messages.length === 0) {
        container.innerHTML = `
            <div class="text-center text-gray-500 py-8">
                <div class="text-4xl mb-2">💬</div>
                <p>No messages yet</p>
                <p class="text-xs mt-1">Start the conversation!</p>
            </div>
        `;
        return;
    }

    container.innerHTML = '';

    currentChatState.messages.forEach(msg => {
        // If sender is not the other user, it must be from me
        // Also handle temp messages with sender_id === 'me'
        const isMe = msg.sender_id === 'me' || msg.sender_id !== currentChatState.otherUserId;
        const div = document.createElement('div');
        div.className = `flex ${isMe ? 'justify-end' : 'justify-start'}`;

        const time = new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

        div.innerHTML = `
            <div class="max-w-[80%] ${isMe ? 'bg-primary text-black' : 'bg-white/10 text-white'} rounded-2xl px-4 py-2 ${isMe ? 'rounded-br-sm' : 'rounded-bl-sm'}">
                <p class="text-sm">${escapeHtml(msg.content)}</p>
                <div class="flex items-center justify-end gap-1 mt-1">
                    <span class="text-[10px] ${isMe ? 'text-black/60' : 'text-gray-400'}">${time}</span>
                    ${isMe && msg.is_read ? '<span class="text-[10px]">✓✓</span>' : ''}
                </div>
            </div>
        `;
        container.appendChild(div);
    });

    // Scroll to bottom
    container.scrollTop = container.scrollHeight;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

window.sendChatMessage = async function() {
    const input = document.getElementById('chat-input');
    if (!input) return;

    const content = input.value.trim();
    if (!content) return;

    if (!currentChatState.otherUserId) {
        showToast('No recipient selected');
        return;
    }

    // Clear input immediately
    input.value = '';

    // Optimistically add message to UI
    const tempMsg = {
        id: 'temp-' + Date.now(),
        sender_id: 'me',
        sender_role: APP_CONFIG.role,
        content: content,
        is_read: false,
        created_at: new Date().toISOString()
    };
    currentChatState.messages.push(tempMsg);
    renderChatMessages();

    try {
        const res = await fetch(`${apiBase}/api/messages/send`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
                receiver_id: currentChatState.otherUserId,
                content: content
            })
        });

        if (!res.ok) {
            throw new Error('Failed to send message');
        }

        const result = await res.json();

        // Update conversation ID if this was the first message
        if (result.conversation_id && !currentChatState.conversationId) {
            currentChatState.conversationId = result.conversation_id;
        }

        // Replace temp message with real one
        const idx = currentChatState.messages.findIndex(m => m.id === tempMsg.id);
        if (idx !== -1 && result.message) {
            currentChatState.messages[idx] = result.message;
            renderChatMessages();
        }

    } catch (e) {
        console.error('Error sending message:', e);
        showToast('Failed to send message');

        // Remove temp message on error
        currentChatState.messages = currentChatState.messages.filter(m => m.id !== tempMsg.id);
        renderChatMessages();
    }
};

// Handle incoming WebSocket messages for chat
if (typeof window.handleWebSocketMessage === 'undefined') {
    window.handleWebSocketMessage = function(data) {
        if (data.type === 'new_message') {
            // If chat is open with this sender, add the message
            if (currentChatState.otherUserId === data.message.sender_id) {
                currentChatState.messages.push(data.message);
                renderChatMessages();

                // Mark as read since chat is open
                if (currentChatState.conversationId) {
                    fetch(`${apiBase}/api/messages/conversation/${currentChatState.conversationId}/read`, {
                        method: 'POST',
                        credentials: 'include'
                    });
                }
            } else {
                // Show notification for new message from someone else
                showToast(`New message from ${data.sender_name || 'User'}`);
            }

            // Update unread badge if exists
            updateUnreadBadge();
        }
    };
}

async function updateUnreadBadge() {
    try {
        const res = await fetch(`${apiBase}/api/messages/unread-count`, {
            credentials: 'include'
        });
        if (res.ok) {
            const data = await res.json();
            const badge = document.getElementById('unread-messages-badge');
            if (badge) {
                if (data.unread_count > 0) {
                    badge.innerText = data.unread_count;
                    badge.classList.remove('hidden');
                } else {
                    badge.classList.add('hidden');
                }
            }
        }
    } catch (e) {
        console.error('Error updating unread badge:', e);
    }
}

// Handle Enter key in chat input
document.addEventListener('DOMContentLoaded', () => {
    const chatInput = document.getElementById('chat-input');
    if (chatInput) {
        chatInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                window.sendChatMessage();
            }
        });
    }

    // Initial unread badge update
    if (APP_CONFIG.role === 'trainer' || APP_CONFIG.role === 'client') {
        updateUnreadBadge();
    }
});

// --- CONVERSATIONS LIST MODAL (for trainers to see all chats) ---

window.openConversationsModal = async function() {
    const modal = document.getElementById('conversations-modal');
    const list = document.getElementById('conversations-list');

    if (!modal || !list) return;

    // Show with animation
    modal.classList.remove('hidden', 'slide-out-right');
    modal.classList.add('slide-in-right');
    // Lock body scroll
    lockBodyScroll();
    list.innerHTML = '<div class="text-center text-gray-500 py-8">Loading conversations...</div>';

    try {
        const res = await fetch(`${apiBase}/api/messages/conversations`, {
            credentials: 'include'
        });

        if (!res.ok) {
            throw new Error('Failed to load conversations');
        }

        const conversations = await res.json();

        if (conversations.length === 0) {
            list.innerHTML = `
                <div class="text-center text-gray-500 py-8">
                    <div class="text-4xl mb-2">💬</div>
                    <p>No conversations yet</p>
                    <p class="text-xs mt-1 mb-4">Start chatting with someone!</p>
                    <button onclick="closeConversationsModal(); if(typeof openGymMembersModal === 'function') openGymMembersModal();"
                        class="px-4 py-2 bg-orange-500 text-white text-sm font-bold rounded-xl hover:bg-orange-400 transition">
                        Find Gym Members
                    </button>
                </div>
            `;
            return;
        }

        list.innerHTML = '';
        conversations.forEach(conv => {
            const div = document.createElement('div');
            div.className = 'bg-white/5 hover:bg-white/10 p-4 rounded-xl cursor-pointer transition tap-effect';
            div.onclick = () => {
                closeConversationsModal();
                window.openChatModal(conv.other_user_id, conv.other_user_name);
            };

            const time = conv.last_message_at ? new Date(conv.last_message_at).toLocaleString([], {
                month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
            }) : '';

            div.innerHTML = `
                <div class="flex items-center justify-between">
                    <div class="flex items-center space-x-3">
                        <div class="w-10 h-10 rounded-full bg-gradient-to-tr from-purple-600 to-pink-500 flex items-center justify-center">
                            <span class="text-lg">👤</span>
                        </div>
                        <div>
                            <p class="font-bold text-white">${conv.other_user_name}</p>
                            <p class="text-xs text-gray-400 truncate max-w-[200px]">${conv.last_message_preview || 'No messages yet'}</p>
                        </div>
                    </div>
                    <div class="text-right">
                        <p class="text-[10px] text-gray-500">${time}</p>
                        ${conv.unread_count > 0 ? `<span class="inline-block w-5 h-5 bg-red-500 text-white text-[10px] font-bold rounded-full text-center leading-5 mt-1">${conv.unread_count}</span>` : ''}
                    </div>
                </div>
            `;
            list.appendChild(div);
        });

    } catch (e) {
        console.error('Error loading conversations:', e);
        list.innerHTML = '<div class="text-center text-red-400 py-8">Failed to load conversations</div>';
    }
};

window.closeConversationsModal = function() {
    const modal = document.getElementById('conversations-modal');
    if (modal) {
        modal.classList.remove('slide-in-right');
        modal.classList.add('slide-out-right');
        // Hide after animation completes
        setTimeout(() => {
            modal.classList.add('hidden');
            modal.classList.remove('slide-out-right');
            // Restore body scroll
            unlockBodyScroll();
        }, 250);
    }
};

// --- TRAINER BOOK APPOINTMENT FUNCTIONS ---

let currentBookingClientId = null;
let currentBookingClientName = null;

window.openBookAppointmentModal = function() {
    const clientModal = document.getElementById('client-modal');
    const clientId = clientModal?.dataset?.clientId;
    const clientName = document.getElementById('modal-client-name')?.innerText;

    if (!clientId) {
        showToast('No client selected');
        return;
    }

    currentBookingClientId = clientId;
    currentBookingClientName = clientName;

    // Set client name in modal
    document.getElementById('book-appt-client-name').innerText = clientName;

    // Set min date to today
    const dateInput = document.getElementById('book-appt-date');
    const today = new Date().toISOString().split('T')[0];
    dateInput.min = today;
    dateInput.value = today;

    // Clear fields
    document.getElementById('book-appt-time').innerHTML = '<option value="">Select time...</option>';
    document.getElementById('book-appt-duration').value = '60';
    document.getElementById('book-appt-workout').innerHTML = '<option value="">None - General session</option>';
    document.getElementById('book-appt-notes').value = '';

    // Load available slots for today
    loadTrainerAvailableSlots(today);

    // Load workouts for selection
    loadWorkoutsForAppointment();

    // Listen for date changes
    dateInput.onchange = function() {
        loadTrainerAvailableSlots(this.value);
    };

    hideModal('client-modal');
    showModal('book-appointment-modal');
};

async function loadWorkoutsForAppointment() {
    const workoutSelect = document.getElementById('book-appt-workout');

    try {
        const res = await fetch(`${apiBase}/api/trainer/workouts`);

        if (!res.ok) {
            throw new Error('Failed to load workouts');
        }

        const workouts = await res.json();

        workoutSelect.innerHTML = '<option value="">None - General session</option>';

        workouts.forEach(workout => {
            const option = document.createElement('option');
            option.value = workout.id;
            option.textContent = `${workout.title} (${workout.exercises.length} exercises)`;
            workoutSelect.appendChild(option);
        });
    } catch (e) {
        console.error('Error loading workouts:', e);
    }
}

async function loadTrainerAvailableSlots(date) {
    const timeSelect = document.getElementById('book-appt-time');
    timeSelect.innerHTML = '<option value="">Loading...</option>';

    try {
        // Use trainer's own endpoint to get their available slots
        const res = await fetch(`${apiBase}/api/trainer/available-slots?date=${date}`);

        if (!res.ok) {
            throw new Error('Failed to load slots');
        }

        const slots = await res.json();

        timeSelect.innerHTML = '<option value="">Select time...</option>';

        if (slots.length === 0) {
            timeSelect.innerHTML = '<option value="">No available slots</option>';
            return;
        }

        slots.forEach(slot => {
            const option = document.createElement('option');
            option.value = slot.start_time;

            // Convert 24h to 12h format for display
            const [hour, min] = slot.start_time.split(':');
            const hour12 = hour % 12 || 12;
            const ampm = hour >= 12 ? 'PM' : 'AM';
            const displayTime = `${hour12}:${min} ${ampm}`;

            option.textContent = displayTime;
            timeSelect.appendChild(option);
        });
    } catch (e) {
        console.error('Error loading slots:', e);
        timeSelect.innerHTML = '<option value="">Error loading slots</option>';
        showToast('Failed to load available time slots');
    }
}

async function confirmBookAppointment() {
    const date = document.getElementById('book-appt-date').value;
    const time = document.getElementById('book-appt-time').value;
    const duration = parseInt(document.getElementById('book-appt-duration').value);
    const workoutId = document.getElementById('book-appt-workout').value;
    let notes = document.getElementById('book-appt-notes').value;

    if (!date || !time) {
        showToast('Please select date and time');
        return;
    }

    if (!currentBookingClientId) {
        showToast('No client selected');
        return;
    }

    try {
        // If workout is selected, add it to notes
        let workoutTitle = '';
        if (workoutId) {
            const workoutSelect = document.getElementById('book-appt-workout');
            workoutTitle = workoutSelect.options[workoutSelect.selectedIndex].text;
            if (notes) {
                notes = `Workout: ${workoutTitle}\n${notes}`;
            } else {
                notes = `Workout: ${workoutTitle}`;
            }
        }

        // Book the appointment
        const res = await fetch(`${apiBase}/api/trainer/book-appointment`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                trainer_id: currentBookingClientId,
                date: date,
                start_time: time,
                duration: duration,
                notes: notes
            })
        });

        if (!res.ok) {
            const error = await res.json();
            throw new Error(error.detail || 'Failed to book appointment');
        }

        const result = await res.json();

        // If a workout was selected, also assign it to the client
        if (workoutId) {
            try {
                const assignRes = await fetch(`${apiBase}/api/trainer/assign_workout`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        workout_id: workoutId,
                        client_id: currentBookingClientId,
                        date: date
                    })
                });

                if (assignRes.ok) {
                    showToast(`Appointment & workout assigned to ${currentBookingClientName}! 💪📅`);
                } else {
                    showToast(`Appointment booked! Note: Workout assignment failed.`);
                }
            } catch (assignError) {
                console.error('Error assigning workout:', assignError);
                showToast(`Appointment booked with ${currentBookingClientName}! 📅`);
            }
        } else {
            showToast(`Appointment booked with ${currentBookingClientName}! 📅`);
        }

        hideModal('book-appointment-modal');

        // Refresh calendar if open
        if (window.location.href.includes('mode=calendar')) {
            window.location.reload();
        }
    } catch (e) {
        console.error('Error booking appointment:', e);
        showToast('Failed to book appointment: ' + e.message);
    }
}

// --- CLIENT APPOINTMENT BOOKING ---

let selectedTrainerForBooking = null;
let availableTrainers = [];

window.openClientBookAppointmentModal = async function() {
    try {
        // Load gym trainers
        const res = await fetch(`${apiBase}/api/client/gym-trainers`, {
            credentials: 'include'
        });
        if (!res.ok) {
            throw new Error('Failed to load trainers');
        }

        const trainers = await res.json();

        if (trainers.length === 0) {
            showToast('No trainers available in your gym');
            return;
        }

        // Store trainers globally for reference
        availableTrainers = trainers;

        // Populate trainer list with profile pictures
        const trainerList = document.getElementById('client-trainer-list');
        trainerList.innerHTML = '';

        trainers.forEach(trainer => {
            const trainerCard = document.createElement('div');
            const isDisabled = !trainer.has_availability;

            trainerCard.className = `flex items-center gap-3 p-3 rounded-xl border transition cursor-pointer ${
                isDisabled
                    ? 'bg-white/5 border-white/10 opacity-50 cursor-not-allowed'
                    : 'bg-white/5 border-white/10 hover:border-blue-500/50 hover:bg-blue-500/10'
            }`;

            if (!isDisabled) {
                trainerCard.onclick = () => selectTrainerForBooking(trainer.id, trainer.name);
            }

            // Profile picture
            const profilePic = document.createElement('div');
            profilePic.className = 'w-12 h-12 rounded-full bg-orange-500/20 flex items-center justify-center overflow-hidden flex-shrink-0';

            if (trainer.profile_picture) {
                const img = document.createElement('img');
                img.src = trainer.profile_picture;
                img.className = 'w-full h-full object-cover';
                img.alt = trainer.name;
                profilePic.appendChild(img);
            } else {
                const icon = document.createElement('span');
                icon.textContent = '👤';
                icon.className = 'text-2xl';
                profilePic.appendChild(icon);
            }

            // Trainer info
            const trainerInfo = document.createElement('div');
            trainerInfo.className = 'flex-1';

            const trainerName = document.createElement('div');
            trainerName.className = 'font-bold text-white';
            trainerName.textContent = trainer.name;

            const trainerStatus = document.createElement('div');
            trainerStatus.className = 'text-xs text-gray-400';
            trainerStatus.textContent = trainer.has_availability ? 'Available for booking' : 'No availability set';

            trainerInfo.appendChild(trainerName);
            trainerInfo.appendChild(trainerStatus);

            trainerCard.appendChild(profilePic);
            trainerCard.appendChild(trainerInfo);

            if (!isDisabled) {
                const arrow = document.createElement('div');
                arrow.className = 'text-blue-400';
                arrow.textContent = '→';
                trainerCard.appendChild(arrow);
            }

            trainerList.appendChild(trainerCard);
        });

        // Reset form
        document.getElementById('client-book-date').value = '';
        document.getElementById('client-book-time').innerHTML = '<option value="">Select time...</option>';
        document.getElementById('client-book-duration').value = '60';
        document.getElementById('client-book-notes').value = '';
        selectedTrainerForBooking = null;

        // Set min date to today
        const dateInput = document.getElementById('client-book-date');
        const today = new Date().toISOString().split('T')[0];
        dateInput.min = today;

        showModal('client-book-appointment-modal');
    } catch (e) {
        console.error('Error opening booking modal:', e);
        showToast('Failed to load trainers: ' + e.message);
    }
};

function toggleTrainerList() {
    const trainerList = document.getElementById('client-trainer-list');
    const chevron = document.getElementById('client-trainer-chevron');

    if (trainerList.classList.contains('hidden')) {
        trainerList.classList.remove('hidden');
        chevron.style.transform = 'rotate(180deg)';
    } else {
        trainerList.classList.add('hidden');
        chevron.style.transform = 'rotate(0deg)';
    }
}

function updateCollapsedTrainerView(trainerId, trainerName, trainerPicture) {
    const nameEl = document.getElementById('client-trainer-name');
    const statusEl = document.getElementById('client-trainer-status');
    const avatarEl = document.getElementById('client-trainer-avatar');

    nameEl.textContent = trainerName;
    statusEl.textContent = 'Selected';

    // Update avatar
    avatarEl.innerHTML = '';
    if (trainerPicture) {
        const img = document.createElement('img');
        img.src = trainerPicture;
        img.className = 'w-full h-full object-cover';
        img.alt = trainerName;
        avatarEl.appendChild(img);
    } else {
        const icon = document.createElement('span');
        icon.textContent = '👤';
        icon.className = 'text-xl';
        avatarEl.appendChild(icon);
    }
}

function selectTrainerForBooking(trainerId, trainerName) {
    selectedTrainerForBooking = trainerId;
    document.getElementById('client-book-trainer').value = trainerId;

    // Find trainer data
    const trainer = availableTrainers.find(t => t.id === trainerId);

    // Update collapsed view
    if (trainer) {
        updateCollapsedTrainerView(trainerId, trainerName, trainer.profile_picture);
    }

    // Highlight selected trainer
    const trainerCards = document.querySelectorAll('#client-trainer-list > div');
    trainerCards.forEach(card => {
        if (card.onclick && card.onclick.toString().includes(trainerId)) {
            card.classList.remove('border-white/10', 'bg-white/5');
            card.classList.add('border-blue-500', 'bg-blue-500/20');
        } else {
            card.classList.remove('border-blue-500', 'bg-blue-500/20');
            card.classList.add('border-white/10', 'bg-white/5');
        }
    });

    // Collapse the list
    toggleTrainerList();

    // Reset date and time when trainer changes
    document.getElementById('client-book-date').value = '';
    document.getElementById('client-book-time').innerHTML = '<option value="">Select time...</option>';

    showToast(`Selected ${trainerName}`);
}

function clientTrainerSelected() {
    // This function is kept for compatibility but selection is now handled by selectTrainerForBooking
    const trainerId = document.getElementById('client-book-trainer').value;
    selectedTrainerForBooking = trainerId;
}

async function clientDateSelected() {
    const trainerId = selectedTrainerForBooking;
    const date = document.getElementById('client-book-date').value;

    if (!trainerId || !date) {
        return;
    }

    try {
        // Load available slots for selected trainer and date
        const res = await fetch(`${apiBase}/api/client/trainers/${trainerId}/available-slots?date=${date}`, {
            credentials: 'include'
        });
        if (!res.ok) {
            throw new Error('Failed to load available slots');
        }

        const slots = await res.json();
        const timeSelect = document.getElementById('client-book-time');
        timeSelect.innerHTML = '<option value="">Select time...</option>';

        if (slots.length === 0) {
            timeSelect.innerHTML = '<option value="">No slots available</option>';
            return;
        }

        slots.forEach(slot => {
            const option = document.createElement('option');
            option.value = slot.start_time;
            option.textContent = slot.start_time;
            timeSelect.appendChild(option);
        });
    } catch (e) {
        console.error('Error loading slots:', e);
        showToast('Failed to load available times: ' + e.message);
    }
}

async function confirmClientBookAppointment() {
    const trainerId = selectedTrainerForBooking;
    const date = document.getElementById('client-book-date').value;
    const time = document.getElementById('client-book-time').value;
    const duration = parseInt(document.getElementById('client-book-duration').value);
    const notes = document.getElementById('client-book-notes').value;

    if (!trainerId) {
        showToast('Please select a trainer');
        return;
    }

    if (!date || !time) {
        showToast('Please select date and time');
        return;
    }

    try {
        const res = await fetch(`${apiBase}/api/client/appointments`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                trainer_id: trainerId,
                date: date,
                start_time: time,
                duration: duration,
                notes: notes
            })
        });

        if (!res.ok) {
            const error = await res.json();
            throw new Error(error.detail || 'Failed to book appointment');
        }

        const result = await res.json();

        // Get trainer name for toast
        const trainerSelect = document.getElementById('client-book-trainer');
        const trainerName = trainerSelect.options[trainerSelect.selectedIndex].text.split(' (')[0];

        showToast(`Appointment booked with ${trainerName}! 📅`);
        hideModal('client-book-appointment-modal');

        // Refresh calendar if open
        if (window.location.href.includes('mode=calendar')) {
            window.location.reload();
        }
    } catch (e) {
        console.error('Error booking appointment:', e);
        showToast('Failed to book appointment: ' + e.message);
    }
}

// ==================== GROUP COURSES MANAGEMENT ====================

let currentCourseId = null;
let courseExercisesList = [];
let courseMusicLinks = [];
let selectedEngagement = 0;
let allCoursesData = [];

// Day name helper
function getDayName(dayNum) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[dayNum] || '';
}

// Load and render courses
window.loadCourses = async function() {
    // Check for courses page first
    if (document.getElementById('courses-page-list')) {
        return loadCoursesPage();
    }

    const container = document.getElementById('course-library');
    if (!container) return;

    try {
        const res = await fetch(`${apiBase}/api/trainer/courses`, { credentials: 'include' });
        const courses = await res.json();
        allCoursesData = courses;

        if (courses.length === 0) {
            container.innerHTML = `
                <button data-action="openCreateCourse"
                    class="w-full py-6 border-2 border-dashed border-white/10 rounded-xl text-white/40 hover:text-white/70 hover:border-white/20 transition flex flex-col items-center justify-center gap-2 group">
                    <span class="text-2xl group-hover:scale-110 transition-transform">📚</span>
                    <span class="text-xs uppercase tracking-wider font-medium">Create Your First Course</span>
                </button>
            `;
            return;
        }

        container.innerHTML = courses.map(c => `
            <div class="glass-card p-3 flex justify-between items-center cursor-pointer hover:bg-white/5 transition"
                 onclick="openCourseDetail('${c.id}')">
                <div>
                    <p class="font-bold text-sm text-white">${c.name}</p>
                    <p class="text-[10px] text-gray-400">
                        ${c.day_of_week !== null ? getDayName(c.day_of_week) + ' ' + (c.time_slot || '') : 'Not scheduled'}
                        ${c.is_shared ? ' <span class="text-primary">• Shared</span>' : ''}
                    </p>
                </div>
                <div class="flex gap-2">
                    <button onclick="event.stopPropagation(); openEditCourse('${c.id}')"
                        class="text-xs bg-white/5 hover:bg-white/10 px-2 py-1 rounded text-gray-300 transition">Edit</button>
                    <button onclick="event.stopPropagation(); deleteCourse('${c.id}')"
                        class="text-xs bg-red-500/20 hover:bg-red-500/40 px-2 py-1 rounded text-red-400 transition">Delete</button>
                </div>
            </div>
        `).join('');
    } catch (e) {
        console.error('Error loading courses:', e);
    }
}

// Load courses for dedicated page (with stats and better cards)
window.loadCoursesPage = async function() {
    const ownCoursesContainer = document.getElementById('courses-page-list');
    const sharedCoursesContainer = document.getElementById('shared-courses-list');

    if (!ownCoursesContainer) return;

    try {
        const res = await fetch(`${apiBase}/api/trainer/courses`, { credentials: 'include' });
        const courses = await res.json();
        allCoursesData = courses;

        // Separate own courses from shared courses by other trainers
        const ownCourses = [];
        const sharedCourses = [];

        // Get current user ID from JWT
        let currentUserId = null;
        const token = localStorage.getItem('jwt_token');
        if (token) {
            try {
                const payload = JSON.parse(atob(token.split('.')[1]));
                currentUserId = payload.user_id;
            } catch (e) {}
        }

        courses.forEach(c => {
            // Check if this is the user's own course or a shared one from another trainer
            if (c.owner_id === currentUserId || !c.is_shared) {
                ownCourses.push(c);
            } else {
                sharedCourses.push(c);
            }
        });

        // Update stats
        document.getElementById('total-courses-count').textContent = ownCourses.length;

        // Calculate lessons this week (would need lessons data)
        // For now show course count
        const thisWeekLessons = 0; // TODO: fetch from API
        document.getElementById('lessons-this-week').textContent = thisWeekLessons;

        // Calculate average engagement
        document.getElementById('avg-engagement').textContent = '-';

        // Render own courses
        if (ownCourses.length === 0) {
            ownCoursesContainer.innerHTML = `
                <div class="glass-card p-8 text-center">
                    <span class="text-4xl mb-3 block">📚</span>
                    <p class="text-gray-400 text-sm mb-2">No courses yet</p>
                    <p class="text-gray-500 text-xs">Create your first group fitness course to get started</p>
                </div>
            `;
        } else {
            ownCoursesContainer.innerHTML = ownCourses.map(c => renderCourseCard(c, true)).join('');
        }

        // Render shared courses
        if (sharedCoursesContainer) {
            if (sharedCourses.length === 0) {
                sharedCoursesContainer.innerHTML = `
                    <div class="glass-card p-4 text-center">
                        <p class="text-gray-400/50 text-xs">No shared courses from other trainers</p>
                    </div>
                `;
            } else {
                sharedCoursesContainer.innerHTML = sharedCourses.map(c => renderCourseCard(c, false)).join('');
            }
        }
    } catch (e) {
        console.error('Error loading courses:', e);
        ownCoursesContainer.innerHTML = `
            <div class="glass-card p-4 text-center text-red-400">
                <p class="text-sm">Failed to load courses</p>
            </div>
        `;
    }
};

// Render a course card for the courses page
function renderCourseCard(course, isOwner) {
    const scheduleText = course.day_of_week !== null
        ? `${getDayName(course.day_of_week)}${course.time_slot ? ' @ ' + course.time_slot : ''}`
        : 'Not scheduled';

    const exerciseCount = (course.exercises || []).length;
    const musicCount = (course.music_links || []).length;

    return `
        <div class="glass-card p-4 cursor-pointer hover:bg-white/5 transition group"
             onclick="openCourseDetail('${course.id}')">
            <div class="flex justify-between items-start mb-3">
                <div class="flex-1">
                    <h4 class="font-bold text-white text-base mb-1">${course.name}</h4>
                    <p class="text-xs text-gray-400">${scheduleText}</p>
                </div>
                ${course.is_shared ? '<span class="text-[10px] bg-primary/20 text-primary px-2 py-0.5 rounded-full uppercase font-bold">Shared</span>' : ''}
            </div>

            ${course.description ? `<p class="text-xs text-gray-500 mb-3 line-clamp-2">${course.description}</p>` : ''}

            <div class="flex items-center gap-4 text-[11px] text-gray-400 mb-3">
                <span>⏱️ ${course.duration || 60} min</span>
                <span>💪 ${exerciseCount} exercise${exerciseCount !== 1 ? 's' : ''}</span>
                <span>🎵 ${musicCount} playlist${musicCount !== 1 ? 's' : ''}</span>
            </div>

            ${isOwner ? `
            <div class="flex gap-2 pt-2 border-t border-white/5">
                <button onclick="event.stopPropagation(); openScheduleLessonModal('${course.id}')"
                    class="flex-1 text-xs bg-primary/20 hover:bg-primary/30 px-3 py-2 rounded-lg text-primary font-medium transition">
                    Schedule Lesson
                </button>
                <button onclick="event.stopPropagation(); openEditCourse('${course.id}')"
                    class="text-xs bg-white/5 hover:bg-white/10 px-3 py-2 rounded-lg text-gray-300 transition">
                    Edit
                </button>
                <button onclick="event.stopPropagation(); deleteCourse('${course.id}')"
                    class="text-xs bg-red-500/10 hover:bg-red-500/20 px-3 py-2 rounded-lg text-red-400 transition">
                    Delete
                </button>
            </div>
            ` : `
            <div class="flex gap-2 pt-2 border-t border-white/5">
                <button onclick="event.stopPropagation(); openCourseDetail('${course.id}')"
                    class="flex-1 text-xs bg-white/10 hover:bg-white/20 px-3 py-2 rounded-lg text-white font-medium transition">
                    View Details
                </button>
            </div>
            `}
        </div>
    `;
}

// Course type color mapping
const courseTypeColors = {
    yoga: { color: 'purple', gradient: 'from-purple-500 to-pink-500', bg: 'bg-purple-500/20', border: 'border-purple-500', emoji: '🧘' },
    pilates: { color: 'pink', gradient: 'from-pink-500 to-rose-500', bg: 'bg-pink-500/20', border: 'border-pink-500', emoji: '🤸' },
    hiit: { color: 'orange', gradient: 'from-orange-500 to-red-500', bg: 'bg-orange-500/20', border: 'border-orange-500', emoji: '🔥' },
    dance: { color: 'cyan', gradient: 'from-cyan-500 to-blue-500', bg: 'bg-cyan-500/20', border: 'border-cyan-500', emoji: '💃' },
    spin: { color: 'green', gradient: 'from-green-500 to-emerald-500', bg: 'bg-green-500/20', border: 'border-green-500', emoji: '🚴' },
    strength: { color: 'red', gradient: 'from-red-500 to-orange-500', bg: 'bg-red-500/20', border: 'border-red-500', emoji: '💪' },
    stretch: { color: 'teal', gradient: 'from-teal-500 to-cyan-500', bg: 'bg-teal-500/20', border: 'border-teal-500', emoji: '🙆' },
    cardio: { color: 'yellow', gradient: 'from-yellow-500 to-orange-500', bg: 'bg-yellow-500/20', border: 'border-yellow-500', emoji: '🏃' }
};

let selectedCourseType = 'yoga';
let selectedCourseDays = [];  // Now an array for multiple days

// Select course type (visual)
window.selectCourseType = function(btn, type, color) {
    selectedCourseType = type;
    const config = courseTypeColors[type];

    // Update all buttons
    document.querySelectorAll('.course-type-btn').forEach(b => {
        b.classList.remove('selected', 'border-purple-500', 'border-pink-500', 'border-orange-500', 'border-cyan-500', 'border-green-500', 'border-red-500', 'border-teal-500', 'border-yellow-500');
        b.classList.remove('bg-purple-500/20', 'bg-pink-500/20', 'bg-orange-500/20', 'bg-cyan-500/20', 'bg-green-500/20', 'bg-red-500/20', 'bg-teal-500/20', 'bg-yellow-500/20');
        b.classList.add('bg-white/5', 'border-transparent');
    });

    // Highlight selected
    btn.classList.remove('bg-white/5', 'border-transparent');
    btn.classList.add('selected', config.bg, config.border);

    // Update header gradient
    const gradient = document.getElementById('course-header-gradient');
    if (gradient) {
        gradient.className = `absolute inset-0 opacity-20 bg-gradient-to-br ${config.gradient} transition-all duration-300`;
    }

    // Update name icon
    const nameIcon = document.getElementById('course-name-icon');
    if (nameIcon) nameIcon.innerText = config.emoji;

    // Update save button gradient
    const saveBtn = document.getElementById('btn-save-course');
    if (saveBtn) {
        saveBtn.className = `w-full bg-gradient-to-r ${config.gradient} text-white font-bold py-4 rounded-xl hover:opacity-90 transition shadow-lg`;
    }

    // Store color
    document.getElementById('course-color').value = color;

    // Update "Add Exercises" button hint to show current type
    const exerciseBtn = document.querySelector('[onclick="openCourseExercisePicker()"]');
    if (exerciseBtn) {
        const span = exerciseBtn.querySelector('span:last-child');
        if (span && span.innerText.includes('Add')) {
            span.innerText = `Add ${type.charAt(0).toUpperCase() + type.slice(1)} Exercises`;
        }
    }

    // Refresh exercise picker if it's open
    const pickerModal = document.getElementById('course-exercise-picker');
    if (pickerModal && pickerModal.style.display !== 'none') {
        populateCourseExerciseList();
    }
};

// Select course day (visual) - now supports multiple days
window.selectCourseDay = function(btn, day) {
    const wasSelected = btn.classList.contains('selected');

    if (wasSelected) {
        // Deselect this day
        btn.classList.remove('selected');
        btn.style.backgroundColor = 'rgba(255,255,255,0.05)';
        btn.style.color = 'rgba(255,255,255,0.6)';
        selectedCourseDays = selectedCourseDays.filter(d => d !== day);
    } else {
        // Select this day - use red color
        btn.classList.add('selected');
        btn.style.backgroundColor = '#ef4444';  // red-500
        btn.style.color = 'white';
        if (!selectedCourseDays.includes(day)) {
            selectedCourseDays.push(day);
            selectedCourseDays.sort((a, b) => parseInt(a) - parseInt(b));  // Keep sorted Mon-Sun
        }
    }

    // Update hidden input with JSON array
    document.getElementById('course-day').value = JSON.stringify(selectedCourseDays.map(d => parseInt(d)));
};

// Adjust duration
window.adjustDuration = function(delta) {
    const input = document.getElementById('course-duration');
    const display = document.getElementById('course-duration-display');
    let val = parseInt(input.value) || 60;
    val = Math.max(15, Math.min(180, val + delta));
    input.value = val;
    if (display) display.innerText = val;
};

// Toggle course visibility
window.toggleCourseVisibility = function() {
    const input = document.getElementById('course-shared');
    const toggle = document.getElementById('visibility-toggle');
    const dot = document.getElementById('visibility-dot');
    const icon = document.getElementById('visibility-icon');
    const label = document.getElementById('visibility-label');
    const desc = document.getElementById('visibility-desc');

    const isShared = input.value === 'true';

    if (isShared) {
        // Switch to private
        input.value = 'false';
        toggle.classList.remove('bg-primary');
        toggle.classList.add('bg-white/10');
        dot.style.transform = 'translateX(0)';
        icon.innerText = '🔒';
        label.innerText = 'Private Course';
        desc.innerText = 'Only visible to you';
    } else {
        // Switch to shared
        input.value = 'true';
        toggle.classList.remove('bg-white/10');
        toggle.classList.add('bg-primary');
        dot.style.transform = 'translateX(20px)';
        icon.innerText = '👥';
        label.innerText = 'Shared with Gym';
        desc.innerText = 'Other trainers can see this';
    }
};

// Reset course modal to defaults
function resetCourseModal() {
    selectedCourseType = 'yoga';
    selectedCourseDays = [];  // Reset to empty array

    // Reset type buttons
    document.querySelectorAll('.course-type-btn').forEach(b => {
        b.classList.remove('selected', 'border-purple-500', 'border-pink-500', 'border-orange-500', 'border-cyan-500', 'border-green-500', 'border-red-500', 'border-teal-500', 'border-yellow-500');
        b.classList.remove('bg-purple-500/20', 'bg-pink-500/20', 'bg-orange-500/20', 'bg-cyan-500/20', 'bg-green-500/20', 'bg-red-500/20', 'bg-teal-500/20', 'bg-yellow-500/20');
        b.classList.add('bg-white/5', 'border-transparent');
    });
    const yogaBtn = document.querySelector('.course-type-btn[data-type="yoga"]');
    if (yogaBtn) {
        yogaBtn.classList.remove('bg-white/5', 'border-transparent');
        yogaBtn.classList.add('selected', 'bg-purple-500/20', 'border-purple-500');
    }

    // Reset header gradient
    const gradient = document.getElementById('course-header-gradient');
    if (gradient) gradient.className = 'absolute inset-0 opacity-20 bg-gradient-to-br from-purple-500 to-pink-500 transition-all duration-300';

    // Reset name icon
    const nameIcon = document.getElementById('course-name-icon');
    if (nameIcon) nameIcon.innerText = '🧘';

    // Reset save button
    const saveBtn = document.getElementById('btn-save-course');
    if (saveBtn) saveBtn.className = 'w-full bg-gradient-to-r from-purple-500 to-pink-500 text-white font-bold py-4 rounded-xl hover:opacity-90 transition shadow-lg';

    // Reset "Add Exercises" button text
    const exerciseBtn = document.querySelector('[onclick="openCourseExercisePicker()"]');
    if (exerciseBtn) {
        const span = exerciseBtn.querySelector('span:last-child');
        if (span) span.innerText = 'Add Yoga Exercises';
    }

    // Reset day buttons
    document.querySelectorAll('.course-day-btn').forEach(b => {
        b.classList.remove('selected');
        b.style.backgroundColor = 'rgba(255,255,255,0.05)';
        b.style.color = 'rgba(255,255,255,0.6)';
    });

    // Reset visibility
    const toggle = document.getElementById('visibility-toggle');
    const dot = document.getElementById('visibility-dot');
    const icon = document.getElementById('visibility-icon');
    const label = document.getElementById('visibility-label');
    const desc = document.getElementById('visibility-desc');
    if (toggle) { toggle.classList.remove('bg-primary'); toggle.classList.add('bg-white/10'); }
    if (dot) dot.style.transform = 'translateX(0)';
    if (icon) icon.innerText = '🔒';
    if (label) label.innerText = 'Private Course';
    if (desc) desc.innerText = 'Only visible to you';

    // Reset duration display
    const durationDisplay = document.getElementById('course-duration-display');
    if (durationDisplay) durationDisplay.innerText = '60';

    // Reset client preview fields
    const coverImg = document.getElementById('course-cover-img');
    const coverPlaceholder = document.getElementById('course-cover-placeholder');
    const coverRemove = document.getElementById('course-cover-remove');
    const coverUrl = document.getElementById('course-cover-url');
    const coverUrlInput = document.getElementById('course-cover-url-input');
    if (coverImg) { coverImg.src = ''; coverImg.classList.add('hidden'); }
    if (coverPlaceholder) coverPlaceholder.classList.remove('hidden');
    if (coverRemove) coverRemove.classList.add('hidden');
    if (coverUrl) coverUrl.value = '';
    if (coverUrlInput) coverUrlInput.value = '';

    const trailerPreview = document.getElementById('course-trailer-preview');
    const trailerPlaceholder = document.getElementById('course-trailer-placeholder');
    const trailerIframe = document.getElementById('course-trailer-iframe');
    const trailerUrl = document.getElementById('course-trailer-url');
    if (trailerPreview) trailerPreview.classList.add('hidden');
    if (trailerPlaceholder) trailerPlaceholder.classList.remove('hidden');
    if (trailerIframe) trailerIframe.src = '';
    if (trailerUrl) trailerUrl.value = '';

    // Reset preview title
    const previewTitle = document.getElementById('course-preview-title');
    if (previewTitle) previewTitle.innerText = 'Course Title';
}

// --- COURSE CLIENT PREVIEW FUNCTIONS ---

// Handle cover image file selection
window.handleCoverImageSelect = function(event) {
    const file = event.target.files[0];
    if (!file) return;

    // Upload file to server
    const formData = new FormData();
    formData.append('file', file);

    fetch(`${apiBase}/api/upload`, {
        method: 'POST',
        credentials: 'include',
        body: formData
    })
    .then(res => res.json())
    .then(data => {
        if (data.url) {
            setCoverImageFromUrl(data.url);
        } else {
            showToast('Failed to upload image');
        }
    })
    .catch(err => {
        console.error('Error uploading cover image:', err);
        showToast('Failed to upload image');
    });
};

// Set cover image from URL
window.setCoverImageFromUrl = function(url) {
    if (!url) return;

    const coverImg = document.getElementById('course-cover-img');
    const coverPlaceholder = document.getElementById('course-cover-placeholder');
    const coverRemove = document.getElementById('course-cover-remove');
    const coverUrl = document.getElementById('course-cover-url');

    if (coverImg) {
        coverImg.src = url;
        coverImg.classList.remove('hidden');
    }
    if (coverPlaceholder) coverPlaceholder.classList.add('hidden');
    if (coverRemove) coverRemove.classList.remove('hidden');
    if (coverUrl) coverUrl.value = url;
};

// Remove cover image
window.removeCoverImage = function() {
    const coverImg = document.getElementById('course-cover-img');
    const coverPlaceholder = document.getElementById('course-cover-placeholder');
    const coverRemove = document.getElementById('course-cover-remove');
    const coverUrl = document.getElementById('course-cover-url');
    const coverUrlInput = document.getElementById('course-cover-url-input');

    if (coverImg) { coverImg.src = ''; coverImg.classList.add('hidden'); }
    if (coverPlaceholder) coverPlaceholder.classList.remove('hidden');
    if (coverRemove) coverRemove.classList.add('hidden');
    if (coverUrl) coverUrl.value = '';
    if (coverUrlInput) coverUrlInput.value = '';
};

// Preview trailer video from YouTube/Vimeo URL
window.previewTrailer = function(url) {
    if (!url) return;

    const trailerPreview = document.getElementById('course-trailer-preview');
    const trailerPlaceholder = document.getElementById('course-trailer-placeholder');
    const trailerIframe = document.getElementById('course-trailer-iframe');

    // Extract embed URL from YouTube or Vimeo
    let embedUrl = null;

    // YouTube patterns
    const ytMatch = url.match(/(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
    if (ytMatch) {
        // Add parameters for proper playback
        embedUrl = `https://www.youtube.com/embed/${ytMatch[1]}?rel=0&modestbranding=1&playsinline=1`;
    }

    // Vimeo patterns
    const vimeoMatch = url.match(/(?:vimeo\.com\/)(\d+)/);
    if (vimeoMatch) {
        embedUrl = `https://player.vimeo.com/video/${vimeoMatch[1]}?title=0&byline=0&portrait=0`;
    }

    if (embedUrl && trailerIframe) {
        trailerIframe.src = embedUrl;
        if (trailerPreview) trailerPreview.classList.remove('hidden');
        if (trailerPlaceholder) trailerPlaceholder.classList.add('hidden');
    } else if (url) {
        // Invalid URL - show warning
        showToast('Please enter a valid YouTube or Vimeo URL');
    }
};

// Remove trailer
window.removeTrailer = function() {
    const trailerPreview = document.getElementById('course-trailer-preview');
    const trailerPlaceholder = document.getElementById('course-trailer-placeholder');
    const trailerIframe = document.getElementById('course-trailer-iframe');
    const trailerUrl = document.getElementById('course-trailer-url');

    if (trailerPreview) trailerPreview.classList.add('hidden');
    if (trailerPlaceholder) trailerPlaceholder.classList.remove('hidden');
    if (trailerIframe) trailerIframe.src = '';
    if (trailerUrl) trailerUrl.value = '';
};

// Populate trainer profile in course modal preview (both overlays)
function populateCourseTrainerProfile() {
    // Get trainer data from global state
    const trainer = window.trainerData || {};
    const name = trainer.name || trainer.username || 'Trainer';
    const profilePic = trainer.profile_picture;

    // Elements in video overlay
    const trainerImg = document.getElementById('course-trainer-img');
    const trainerInitial = document.getElementById('course-trainer-initial');
    const trainerName = document.getElementById('course-trainer-name');

    // Elements in placeholder overlay
    const trainerImgPlaceholder = document.getElementById('course-trainer-img-placeholder');
    const trainerInitialPlaceholder = document.getElementById('course-trainer-initial-placeholder');
    const trainerNamePlaceholder = document.getElementById('course-trainer-name-placeholder');

    // Set name in both overlays
    if (trainerName) trainerName.innerText = name;
    if (trainerNamePlaceholder) trainerNamePlaceholder.innerText = name;

    // Set profile picture or initial in video overlay
    if (trainerImg && trainerInitial) {
        if (profilePic) {
            trainerImg.src = profilePic;
            trainerImg.classList.remove('hidden');
            trainerInitial.classList.add('hidden');
        } else {
            trainerImg.classList.add('hidden');
            trainerInitial.classList.remove('hidden');
            trainerInitial.innerText = name.charAt(0).toUpperCase();
        }
    }

    // Set profile picture or initial in placeholder overlay
    if (trainerImgPlaceholder && trainerInitialPlaceholder) {
        if (profilePic) {
            trainerImgPlaceholder.src = profilePic;
            trainerImgPlaceholder.classList.remove('hidden');
            trainerInitialPlaceholder.classList.add('hidden');
        } else {
            trainerImgPlaceholder.classList.add('hidden');
            trainerInitialPlaceholder.classList.remove('hidden');
            trainerInitialPlaceholder.innerText = name.charAt(0).toUpperCase();
        }
    }
}

// Update course preview title from input
function updateCoursePreviewTitle() {
    const nameInput = document.getElementById('course-name');
    const previewTitle = document.getElementById('course-preview-title');
    if (nameInput && previewTitle) {
        previewTitle.innerText = nameInput.value.trim() || 'Course Title';
    }
}

// Setup course name input listener (called once)
let courseNameListenerAdded = false;
function setupCourseNamePreviewListener() {
    if (courseNameListenerAdded) return;
    const nameInput = document.getElementById('course-name');
    if (nameInput) {
        nameInput.addEventListener('input', updateCoursePreviewTitle);
        courseNameListenerAdded = true;
    }
}

// Open create course modal
window.openCreateCourseModal = function() {
    document.getElementById('edit-course-id').value = '';
    document.getElementById('modal-course-title').innerText = 'New Course';
    document.getElementById('btn-save-course').innerText = 'Create Course';

    document.getElementById('course-name').value = '';
    document.getElementById('course-description').value = '';
    document.getElementById('course-day').value = '';

    // Handle both old and new time inputs
    const timeInput = document.getElementById('course-time-input');
    const oldTimeInput = document.getElementById('course-time');
    if (timeInput) timeInput.value = '09:00';
    if (oldTimeInput) oldTimeInput.value = '';

    document.getElementById('course-duration').value = '60';
    document.getElementById('course-shared').value = 'false';
    document.getElementById('course-color').value = 'purple';

    resetCourseModal();
    populateCourseTrainerProfile();
    setupCourseNamePreviewListener();

    courseExercisesList = [];
    courseMusicLinks = [];
    renderCourseExercises();
    renderMusicLinks();

    showModal('create-course-modal');
};

// Open edit course modal
window.openEditCourse = async function(courseId) {
    try {
        const res = await fetch(`${apiBase}/api/trainer/courses/${courseId}`, { credentials: 'include' });
        const course = await res.json();

        document.getElementById('edit-course-id').value = course.id;
        document.getElementById('modal-course-title').innerText = 'Edit Course';
        document.getElementById('btn-save-course').innerText = 'Save Changes';

        document.getElementById('course-name').value = course.name || '';
        document.getElementById('course-description').value = course.description || '';
        document.getElementById('course-day').value = course.day_of_week !== null ? course.day_of_week : '';
        document.getElementById('course-duration').value = course.duration || 60;
        document.getElementById('course-shared').value = course.is_shared ? 'true' : 'false';

        // Handle time input (new format)
        const timeInput = document.getElementById('course-time-input');
        const oldTimeInput = document.getElementById('course-time');
        if (timeInput && course.time_slot) {
            // Convert "9:00 AM" to "09:00" format
            const time = course.time_slot;
            const match = time.match(/(\d+):(\d+)\s*(AM|PM)?/i);
            if (match) {
                let hours = parseInt(match[1]);
                const mins = match[2];
                const period = match[3];
                if (period && period.toUpperCase() === 'PM' && hours < 12) hours += 12;
                if (period && period.toUpperCase() === 'AM' && hours === 12) hours = 0;
                timeInput.value = `${hours.toString().padStart(2, '0')}:${mins}`;
            } else {
                timeInput.value = course.time_slot;
            }
        }
        if (oldTimeInput) oldTimeInput.value = course.time_slot || '';

        // Update duration display
        const durationDisplay = document.getElementById('course-duration-display');
        if (durationDisplay) durationDisplay.innerText = course.duration || 60;

        // Reset visual elements first
        resetCourseModal();

        // Set course type from color/name (try to detect)
        const courseType = detectCourseType(course.name, course.color);
        if (courseType && courseTypeColors[courseType]) {
            const typeBtn = document.querySelector(`.course-type-btn[data-type="${courseType}"]`);
            if (typeBtn) selectCourseType(typeBtn, courseType, courseTypeColors[courseType].color);
        }

        // Set day selection - handle both array (new) and single value (old)
        const daysToSelect = course.days_of_week || (course.day_of_week !== null && course.day_of_week !== undefined ? [course.day_of_week] : []);
        daysToSelect.forEach(day => {
            const dayBtn = document.querySelector(`.course-day-btn[data-day="${day}"]`);
            if (dayBtn) selectCourseDay(dayBtn, day.toString());
        });

        // Set visibility toggle
        if (course.is_shared) {
            const toggle = document.getElementById('visibility-toggle');
            const dot = document.getElementById('visibility-dot');
            const icon = document.getElementById('visibility-icon');
            const label = document.getElementById('visibility-label');
            const desc = document.getElementById('visibility-desc');
            if (toggle) { toggle.classList.remove('bg-white/10'); toggle.classList.add('bg-primary'); }
            if (dot) dot.style.transform = 'translateX(20px)';
            if (icon) icon.innerText = '👥';
            if (label) label.innerText = 'Shared with Gym';
            if (desc) desc.innerText = 'Other trainers can see this';
        }

        courseExercisesList = course.exercises || [];
        courseMusicLinks = course.music_links || [];
        renderCourseExercises();
        renderMusicLinks();

        // Set cover image if exists
        if (course.cover_image_url) {
            setCoverImageFromUrl(course.cover_image_url);
            const coverUrlInput = document.getElementById('course-cover-url-input');
            if (coverUrlInput) coverUrlInput.value = course.cover_image_url;
        }

        // Set trailer if exists
        if (course.trailer_url) {
            document.getElementById('course-trailer-url').value = course.trailer_url;
            previewTrailer(course.trailer_url);
        }

        // Populate trainer profile in preview
        populateCourseTrainerProfile();
        setupCourseNamePreviewListener();
        updateCoursePreviewTitle();

        showModal('create-course-modal');
    } catch (e) {
        console.error('Error loading course:', e);
        showToast('Failed to load course');
    }
};

// Detect course type from name
function detectCourseType(name, color) {
    if (!name) return 'yoga';
    const lower = name.toLowerCase();
    if (lower.includes('yoga')) return 'yoga';
    if (lower.includes('pilates')) return 'pilates';
    if (lower.includes('hiit') || lower.includes('high intensity')) return 'hiit';
    if (lower.includes('dance') || lower.includes('zumba')) return 'dance';
    if (lower.includes('spin') || lower.includes('cycling') || lower.includes('bike')) return 'spin';
    if (lower.includes('strength') || lower.includes('weight') || lower.includes('pump')) return 'strength';
    if (lower.includes('stretch') || lower.includes('flexibility')) return 'stretch';
    if (lower.includes('cardio') || lower.includes('aerobic')) return 'cardio';
    // Try to match by color
    if (color) {
        for (const [type, config] of Object.entries(courseTypeColors)) {
            if (config.color === color) return type;
        }
    }
    return 'yoga';
}

// Save course (create or update)
window.saveCourse = async function() {
    const id = document.getElementById('edit-course-id').value;
    const name = document.getElementById('course-name').value;
    const description = document.getElementById('course-description').value;
    const dayValue = document.getElementById('course-day').value;
    const duration = parseInt(document.getElementById('course-duration').value) || 60;
    const isShared = document.getElementById('course-shared').value === 'true';
    const color = document.getElementById('course-color')?.value || 'purple';

    // Parse days - can be JSON array or single value for backwards compatibility
    let days = [];
    if (dayValue) {
        try {
            days = JSON.parse(dayValue);
            if (!Array.isArray(days)) days = [days];
        } catch (e) {
            days = dayValue !== '' ? [parseInt(dayValue)] : [];
        }
    }

    // Handle time from either new or old input
    let time = '';
    const timeInput = document.getElementById('course-time-input');
    const oldTimeInput = document.getElementById('course-time');
    if (timeInput && timeInput.value) {
        // Convert "09:00" to "9:00 AM" format
        const [hours, mins] = timeInput.value.split(':');
        let h = parseInt(hours);
        const period = h >= 12 ? 'PM' : 'AM';
        if (h > 12) h -= 12;
        if (h === 0) h = 12;
        time = `${h}:${mins} ${period}`;
    } else if (oldTimeInput) {
        time = oldTimeInput.value;
    }

    if (!name) {
        showToast('Please enter a course name');
        return;
    }

    // Get client preview fields
    const coverImageUrl = document.getElementById('course-cover-url').value || null;
    const trailerUrl = document.getElementById('course-trailer-url').value || null;

    const payload = {
        name,
        description: description || null,
        days_of_week: days.length > 0 ? days : null,  // New field: array of days
        day_of_week: days.length > 0 ? days[0] : null,  // Backwards compat: first day
        time_slot: time || null,
        duration,
        is_shared: isShared,
        exercises: courseExercisesList,
        music_links: courseMusicLinks,
        color: color,
        course_type: selectedCourseType,
        cover_image_url: coverImageUrl,
        trailer_url: trailerUrl
    };

    try {
        const method = id ? 'PUT' : 'POST';
        const url = id ? `${apiBase}/api/trainer/courses/${id}` : `${apiBase}/api/trainer/courses`;

        const res = await fetch(url, {
            method,
            credentials: 'include',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (!res.ok) throw new Error('Failed to save course');

        showToast(id ? 'Course updated!' : 'Course created!');
        hideModal('create-course-modal');
        loadCourses();
        if (document.getElementById('courses-page-list')) loadCoursesPage();
    } catch (e) {
        console.error('Error saving course:', e);
        showToast('Failed to save course');
    }
};

// Delete course
window.deleteCourse = async function(courseId) {
    if (!confirm('Delete this course and all its lessons?')) return;

    try {
        const res = await fetch(`${apiBase}/api/trainer/courses/${courseId}`, {
            method: 'DELETE',
            credentials: 'include'
        });

        if (!res.ok) throw new Error('Failed to delete course');

        showToast('Course deleted');
        loadCourses();
        if (document.getElementById('courses-page-list')) loadCoursesPage();
    } catch (e) {
        console.error('Error deleting course:', e);
        showToast('Failed to delete course');
    }
};

// Music link management
window.addMusicLinkInput = function() {
    courseMusicLinks.push({ title: '', url: '', type: 'spotify' });
    renderMusicLinks();
};

function renderMusicLinks() {
    const container = document.getElementById('music-links-container');
    if (!container) return;

    if (courseMusicLinks.length === 0) {
        container.innerHTML = '<p class="text-xs text-gray-500 italic text-center py-2">Add Spotify or YouTube playlists</p>';
        return;
    }

    container.innerHTML = courseMusicLinks.map((link, i) => `
        <div class="bg-white/5 rounded-xl p-3 group hover:bg-white/10 transition">
            <div class="flex items-center gap-3 mb-2">
                <span class="text-xl">${link.type === 'spotify' ? '🟢' : '🔴'}</span>
                <input type="text" value="${link.title || ''}" placeholder="Playlist name"
                    onchange="updateMusicLink(${i}, 'title', this.value)"
                    class="flex-1 bg-transparent text-sm text-white font-medium outline-none placeholder-white/30">
                <button onclick="removeMusicLink(${i})" class="text-white/30 hover:text-red-400 opacity-0 group-hover:opacity-100 transition">✕</button>
            </div>
            <div class="flex gap-2">
                <select onchange="updateMusicLink(${i}, 'type', this.value)"
                    class="bg-white/10 border-0 rounded-lg px-2 py-1.5 text-[10px] text-white/70 w-20">
                    <option value="spotify" ${link.type === 'spotify' ? 'selected' : ''}>Spotify</option>
                    <option value="youtube" ${link.type === 'youtube' ? 'selected' : ''}>YouTube</option>
                </select>
                <input type="text" value="${link.url || ''}" placeholder="Paste playlist URL..."
                    onchange="updateMusicLink(${i}, 'url', this.value)"
                    class="flex-1 bg-white/10 border-0 rounded-lg px-3 py-1.5 text-[10px] text-white/70 outline-none min-w-0 placeholder-white/30">
            </div>
        </div>
    `).join('');
}

window.updateMusicLink = function(index, field, value) {
    if (courseMusicLinks[index]) {
        courseMusicLinks[index][field] = value;
    }
};

window.removeMusicLink = function(index) {
    courseMusicLinks.splice(index, 1);
    renderMusicLinks();
};

// Course exercises management
function renderCourseExercises() {
    const container = document.getElementById('course-selected-exercises');
    if (!container) return;

    // Update exercise count badge
    const badge = document.getElementById('exercise-count-badge');
    if (badge) {
        badge.innerText = `${courseExercisesList.length} selected`;
    }

    if (courseExercisesList.length === 0) {
        container.innerHTML = `
            <div class="text-center py-4">
                <span class="text-3xl mb-2 block opacity-30">🏃</span>
                <p class="text-xs text-gray-500">No exercises added yet</p>
            </div>
        `;
        return;
    }

    container.innerHTML = courseExercisesList.map((ex, i) => `
        <div class="bg-white/5 rounded-xl p-3 flex justify-between items-center group hover:bg-white/10 transition">
            <div class="flex items-center gap-3">
                <span class="text-lg">${getCourseExerciseEmoji(ex)}</span>
                <div>
                    <p class="text-sm font-medium text-white">${ex.name}</p>
                    <p class="text-[10px] text-gray-400">${ex.duration ? ex.duration + 's' : (ex.sets + ' x ' + ex.reps)}</p>
                </div>
            </div>
            <button onclick="removeCourseExercise(${i})" class="text-white/30 hover:text-red-400 px-2 opacity-0 group-hover:opacity-100 transition">✕</button>
        </div>
    `).join('');
}

function getCourseExerciseEmoji(ex) {
    const cat = (ex.muscle_group || ex.category || '').toLowerCase();
    const emojiMap = {
        yoga: '🧘', pilates: '🤸', stretch: '🙆', cardio: '🏃',
        warmup: '🔥', cooldown: '❄️', hiit: '⚡', dance: '💃',
        strength: '💪', balance: '⚖️', breathing: '🌬️', core: '🎯'
    };
    return emojiMap[cat] || '🏋️';
}

window.removeCourseExercise = function(index) {
    courseExercisesList.splice(index, 1);
    renderCourseExercises();
};

// Exercise picker for courses
window.openCourseExercisePicker = async function() {
    showModal('course-exercise-picker');
    await populateCourseExerciseList();

    // Setup search handler
    const searchInput = document.getElementById('course-ex-search');
    if (searchInput) {
        searchInput.value = ''; // Reset search
        searchInput.oninput = () => filterCourseExercisePickerList(searchInput.value);
    }
};

function filterCourseExercisePickerList(searchTerm) {
    const container = document.getElementById('course-exercise-list');
    if (!container) return;

    const allExercises = window.APP_STATE?.exercises || allCourseExercises || [];

    // Filter for Course-type exercises that match the selected course type
    const allCourseTypeExercises = allExercises.filter(ex => ex.type === 'Course');
    const matchingExercises = allCourseTypeExercises.filter(ex => {
        const category = (ex.muscle_group || ex.muscle || ex.category || '').toLowerCase();
        return category === selectedCourseType.toLowerCase();
    });

    // Use matching exercises if available, otherwise use all course exercises
    const baseExercises = matchingExercises.length > 0 ? matchingExercises : allCourseTypeExercises;
    const showingAll = matchingExercises.length === 0 && allCourseTypeExercises.length > 0;

    // Apply search filter
    const filtered = baseExercises.filter(ex =>
        ex.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (ex.muscle || ex.muscle_group || '').toLowerCase().includes(searchTerm.toLowerCase())
    );

    if (filtered.length === 0) {
        container.innerHTML = '<div class="p-4 text-center text-gray-400 text-sm">No exercises match your search</div>';
        return;
    }

    const headerNote = showingAll
        ? `<div class="p-3 mb-2 bg-amber-500/20 border border-amber-500/30 rounded-xl text-amber-300 text-xs text-center">
            No ${selectedCourseType} exercises found. Showing all course exercises.
           </div>`
        : '';

    container.innerHTML = headerNote + filtered.map(ex => {
        const safeName = (ex.name || '').replace(/'/g, "\\'");
        const safeId = (ex.id || '').toString().replace(/'/g, "\\'");
        const safeVideoId = (ex.video_id || '').replace(/'/g, "\\'");
        return `
        <div class="glass-card p-3 flex justify-between items-center cursor-pointer hover:bg-white/10 transition"
             onclick="selectCourseExercise('${safeId}', '${safeName}', '${safeVideoId}')">
            <div>
                <p class="text-sm font-medium text-white">${ex.name}</p>
                <p class="text-[10px] text-gray-400">${ex.muscle || ex.muscle_group || ''}</p>
            </div>
            <span class="text-primary">+</span>
        </div>
    `}).join('');
}

async function populateCourseExerciseList() {
    const container = document.getElementById('course-exercise-list');
    if (!container) return;

    // Show loading state
    container.innerHTML = '<div class="p-4 text-center text-gray-400 text-sm">Loading exercises...</div>';

    // Get exercises from APP_STATE, allCourseExercises, or fetch fresh
    let allExercises = window.APP_STATE?.exercises || allCourseExercises || [];

    // If no exercises loaded yet, fetch them
    if (allExercises.length === 0) {
        try {
            const res = await fetch(`${apiBase}/api/exercises`, { credentials: 'include' });
            if (res.ok) {
                allExercises = await res.json();
                // Store for future use
                if (!window.APP_STATE) window.APP_STATE = {};
                window.APP_STATE.exercises = allExercises;
            }
        } catch (e) {
            console.error('Error fetching exercises:', e);
            container.innerHTML = '<div class="p-4 text-center text-red-400 text-sm">Failed to load exercises</div>';
            return;
        }
    }

    // Filter for Course-type exercises that match the selected course type
    const courseTypeExercises = allExercises.filter(ex => ex.type === 'Course');
    const matchingExercises = courseTypeExercises.filter(ex => {
        const category = (ex.muscle_group || ex.muscle || ex.category || '').toLowerCase();
        return category === selectedCourseType.toLowerCase();
    });

    // Use matching exercises if available, otherwise show all course exercises with a note
    const exercisesToShow = matchingExercises.length > 0 ? matchingExercises : courseTypeExercises;
    const showingAll = matchingExercises.length === 0 && courseTypeExercises.length > 0;

    if (exercisesToShow.length === 0) {
        container.innerHTML = '<div class="p-4 text-center text-gray-400 text-sm">No course exercises available. Create some in the Exercise Library below!</div>';
        return;
    }

    const headerNote = showingAll
        ? `<div class="p-3 mb-2 bg-amber-500/20 border border-amber-500/30 rounded-xl text-amber-300 text-xs text-center">
            No ${selectedCourseType} exercises found. Showing all course exercises.
           </div>`
        : `<div class="p-2 mb-2 text-center text-xs text-gray-400">
            Showing ${selectedCourseType} exercises
           </div>`;

    container.innerHTML = headerNote + exercisesToShow.map(ex => {
        const safeName = (ex.name || '').replace(/'/g, "\\'");
        const safeId = (ex.id || '').toString().replace(/'/g, "\\'");
        const safeVideoId = (ex.video_id || '').replace(/'/g, "\\'");
        return `
        <div class="glass-card p-3 flex justify-between items-center cursor-pointer hover:bg-white/10 transition"
             onclick="selectCourseExercise('${safeId}', '${safeName}', '${safeVideoId}')">
            <div>
                <p class="text-sm font-medium text-white">${ex.name}</p>
                <p class="text-[10px] text-gray-400">${ex.muscle || ex.muscle_group || ''}</p>
            </div>
            <span class="text-primary">+</span>
        </div>
    `}).join('');
}

window.selectCourseExercise = function(id, name, videoId) {
    // Add to list with default values
    courseExercisesList.push({
        name: name,
        sets: 3,
        reps: 10,
        rest: 60,
        video_id: videoId || ''
    });
    renderCourseExercises();
    showToast(`Added ${name}`);
};

window.confirmCourseExercises = function() {
    hideModal('course-exercise-picker');
};

// Course detail view
window.openCourseDetail = async function(courseId) {
    currentCourseId = courseId;

    try {
        const [courseRes, lessonsRes] = await Promise.all([
            fetch(`${apiBase}/api/trainer/courses/${courseId}`, { credentials: 'include' }),
            fetch(`${apiBase}/api/trainer/courses/${courseId}/lessons`, { credentials: 'include' })
        ]);

        const course = await courseRes.json();
        const lessons = await lessonsRes.json();

        // Populate course info
        document.getElementById('detail-course-name').innerText = course.name;
        document.getElementById('detail-course-schedule').innerText =
            course.day_of_week !== null ? `${getDayName(course.day_of_week)} ${course.time_slot || ''}` : 'No schedule set';
        document.getElementById('detail-course-description').innerText = course.description || '';

        // Music links
        const musicContainer = document.getElementById('detail-music-links');
        if (course.music_links && course.music_links.length > 0) {
            musicContainer.innerHTML = course.music_links.map(link => `
                <a href="${link.url}" target="_blank" rel="noopener"
                   class="glass-card p-2 flex items-center gap-2 hover:bg-white/10 transition">
                    <span class="text-lg">${link.type === 'spotify' ? '🎵' : '▶️'}</span>
                    <span class="text-sm text-white">${link.title || link.url}</span>
                </a>
            `).join('');
        } else {
            musicContainer.innerHTML = '<p class="text-xs text-gray-500 italic">No playlists</p>';
        }

        // Exercises
        const exercisesContainer = document.getElementById('detail-exercises');
        if (course.exercises && course.exercises.length > 0) {
            exercisesContainer.innerHTML = course.exercises.map(ex => `
                <div class="glass-card p-2 flex justify-between items-center">
                    <span class="text-sm text-white">${ex.name}</span>
                    <span class="text-xs text-gray-400">${ex.sets}x${ex.reps}</span>
                </div>
            `).join('');
        } else {
            exercisesContainer.innerHTML = '<p class="text-xs text-gray-500 italic">No exercises</p>';
        }

        // Lessons history
        const lessonsContainer = document.getElementById('lesson-history-list');
        if (lessons.length > 0) {
            lessonsContainer.innerHTML = lessons.map(l => `
                <div class="glass-card p-3 flex justify-between items-center">
                    <div>
                        <p class="text-sm text-white">${l.date} at ${l.time}</p>
                        <p class="text-[10px] text-gray-400">
                            ${l.completed ? `Completed • Engagement: ${l.engagement_level}/5` : 'Scheduled'}
                            ${l.attendee_count ? ` • ${l.attendee_count} attendees` : ''}
                        </p>
                    </div>
                    <div class="flex gap-2">
                        ${!l.completed ? `
                            <button onclick="openCompleteLessonModal(${l.id}, '${l.date}')"
                                class="text-xs bg-green-600/20 hover:bg-green-600/40 px-2 py-1 rounded text-green-400 transition">Complete</button>
                            <button onclick="deleteLesson(${l.id})"
                                class="text-xs bg-red-500/20 hover:bg-red-500/40 px-2 py-1 rounded text-red-400 transition">Delete</button>
                        ` : `
                            <span class="text-xs text-green-400">✓</span>
                        `}
                    </div>
                </div>
            `).join('');
        } else {
            lessonsContainer.innerHTML = '<p class="text-xs text-gray-500 italic">No lessons scheduled yet</p>';
        }

        showModal('course-detail-modal');
    } catch (e) {
        console.error('Error loading course detail:', e);
        showToast('Failed to load course');
    }
};

window.openEditCourseFromDetail = function() {
    hideModal('course-detail-modal');
    openEditCourse(currentCourseId);
};

// Schedule lesson
window.openScheduleLessonModal = function(courseId = null) {
    // Use provided courseId or fallback to currentCourseId
    const targetCourseId = courseId || currentCourseId;
    const course = allCoursesData.find(c => c.id === targetCourseId);
    if (!course) return;

    // Update currentCourseId for other functions
    currentCourseId = targetCourseId;

    document.getElementById('schedule-lesson-course-id').value = currentCourseId;
    document.getElementById('schedule-lesson-course-name').innerText = course.name;
    document.getElementById('schedule-lesson-time').value = course.time_slot || '';
    document.getElementById('schedule-lesson-duration').value = course.duration || 60;

    // Default to today's date
    const today = new Date().toISOString().split('T')[0];
    document.getElementById('schedule-lesson-date').value = today;

    showModal('schedule-lesson-modal');
};

window.confirmScheduleLesson = async function() {
    const courseId = document.getElementById('schedule-lesson-course-id').value;
    const date = document.getElementById('schedule-lesson-date').value;
    const time = document.getElementById('schedule-lesson-time').value;
    const duration = parseInt(document.getElementById('schedule-lesson-duration').value) || 60;

    if (!date) {
        showToast('Please select a date');
        return;
    }

    try {
        const res = await fetch(`${apiBase}/api/trainer/courses/${courseId}/schedule`, {
            method: 'POST',
            credentials: 'include',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ date, time: time || null, duration })
        });

        if (!res.ok) throw new Error('Failed to schedule lesson');

        showToast('Lesson scheduled!');
        hideModal('schedule-lesson-modal');
        openCourseDetail(courseId); // Refresh detail view
    } catch (e) {
        console.error('Error scheduling lesson:', e);
        showToast('Failed to schedule lesson');
    }
};

// Complete lesson with engagement
window.openCompleteLessonModal = function(lessonId, dateStr) {
    document.getElementById('complete-lesson-id').value = lessonId;
    document.getElementById('complete-lesson-title').innerText = `Lesson on ${dateStr}`;
    document.getElementById('complete-attendees').value = '';
    document.getElementById('complete-notes').value = '';

    selectedEngagement = 0;
    document.querySelectorAll('.engagement-star').forEach(btn => {
        btn.classList.remove('opacity-100', 'bg-green-600');
        btn.classList.add('opacity-50');
    });

    showModal('complete-lesson-modal');
};

window.setEngagement = function(level) {
    selectedEngagement = level;
    document.querySelectorAll('.engagement-star').forEach(btn => {
        const rating = parseInt(btn.dataset.rating);
        if (rating <= level) {
            btn.classList.remove('opacity-50');
            btn.classList.add('opacity-100', 'bg-green-600');
        } else {
            btn.classList.remove('opacity-100', 'bg-green-600');
            btn.classList.add('opacity-50');
        }
    });
};

window.submitLessonCompletion = async function() {
    const lessonId = document.getElementById('complete-lesson-id').value;
    const notes = document.getElementById('complete-notes').value;
    const attendees = document.getElementById('complete-attendees').value;

    if (selectedEngagement < 1 || selectedEngagement > 5) {
        showToast('Please rate the class engagement');
        return;
    }

    try {
        const res = await fetch(`${apiBase}/api/trainer/courses/lessons/${lessonId}/complete`, {
            method: 'POST',
            credentials: 'include',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                engagement_level: selectedEngagement,
                notes: notes || null,
                attendee_count: attendees ? parseInt(attendees) : null
            })
        });

        if (!res.ok) throw new Error('Failed to complete lesson');

        showToast('Lesson completed!');
        hideModal('complete-lesson-modal');
        if (currentCourseId) {
            openCourseDetail(currentCourseId); // Refresh detail view
        }
    } catch (e) {
        console.error('Error completing lesson:', e);
        showToast('Failed to complete lesson');
    }
};

// Delete lesson
window.deleteLesson = async function(lessonId) {
    if (!confirm('Delete this scheduled lesson?')) return;

    try {
        const res = await fetch(`${apiBase}/api/trainer/courses/lessons/${lessonId}`, {
            method: 'DELETE',
            credentials: 'include'
        });

        if (!res.ok) throw new Error('Failed to delete lesson');

        showToast('Lesson deleted');
        if (currentCourseId) {
            openCourseDetail(currentCourseId); // Refresh detail view
        }
    } catch (e) {
        console.error('Error deleting lesson:', e);
        showToast('Failed to delete lesson');
    }
};

// Exercise search for course picker
document.addEventListener('DOMContentLoaded', () => {
    const courseExSearch = document.getElementById('course-ex-search');
    if (courseExSearch) {
        courseExSearch.addEventListener('input', (e) => {
            const query = e.target.value.toLowerCase();
            const container = document.getElementById('course-exercise-list');
            if (!container || !window.APP_STATE?.exercises) return;

            const filtered = window.APP_STATE?.exercises.filter(ex =>
                ex.name.toLowerCase().includes(query) ||
                ex.muscle.toLowerCase().includes(query)
            );

            container.innerHTML = filtered.map(ex => `
                <div class="glass-card p-3 flex justify-between items-center cursor-pointer hover:bg-white/10 transition"
                     onclick="selectCourseExercise('${ex.id}', '${ex.name}', '${ex.video_id || ''}')">
                    <div>
                        <p class="text-sm font-medium text-white">${ex.name}</p>
                        <p class="text-[10px] text-gray-400">${ex.muscle} • ${ex.type}</p>
                    </div>
                    <span class="text-primary">+</span>
                </div>
            `).join('');
        });
    }
});

// ============================================
// LIVE CLASS MODE
// ============================================

let liveClassData = {
    course: null,
    exercises: [],
    currentExerciseIndex: 0,
    musicLinks: [],
    timerSeconds: 0,
    timerInterval: null,
    timerRunning: false,
    musicPlaying: false
};

// Start live class from course detail
window.startLiveClass = function() {
    const course = allCoursesData.find(c => c.id === currentCourseId);
    if (!course) {
        showToast('Course not found');
        return;
    }

    liveClassData.course = course;
    liveClassData.exercises = course.exercises || [];
    liveClassData.musicLinks = course.music_links || [];
    liveClassData.currentExerciseIndex = 0;
    liveClassData.timerSeconds = 0;
    liveClassData.timerRunning = false;

    if (liveClassData.exercises.length === 0) {
        showToast('Add exercises to this course first');
        return;
    }

    // Update UI
    document.getElementById('live-class-name').textContent = course.name;

    // Render music links
    renderLiveMusicLinks();

    // Render exercise list
    renderLiveExerciseList();

    // Show first exercise
    showLiveExercise(0);

    // Hide course detail and show live class
    hideModal('course-detail-modal');
    showModal('live-class-modal');

    // Reset timer display
    updateTimerDisplay();
};

// Render music links in sidebar
function renderLiveMusicLinks() {
    const container = document.getElementById('live-music-container');
    if (!container) return;

    if (liveClassData.musicLinks.length === 0) {
        container.innerHTML = '<p class="text-xs text-gray-500 italic">No playlists added</p>';
        return;
    }

    container.innerHTML = liveClassData.musicLinks.map((link, i) => {
        const icon = link.type === 'spotify' ? '🟢' : '🔴';
        const embedUrl = getMusicEmbedUrl(link.url, link.type);

        return `
            <div class="bg-white/5 rounded-lg p-2">
                <div class="flex items-center justify-between mb-2">
                    <span class="text-xs text-white font-medium truncate">${icon} ${link.title || 'Playlist ' + (i+1)}</span>
                    <a href="${link.url}" target="_blank" class="text-xs text-primary hover:underline">Open</a>
                </div>
                ${embedUrl ? `
                    <iframe src="${embedUrl}" width="100%" height="80" frameborder="0"
                        allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
                        loading="lazy" class="rounded"></iframe>
                ` : ''}
            </div>
        `;
    }).join('');
}

// Get embed URL for music services
function getMusicEmbedUrl(url, type) {
    if (!url) return null;

    if (type === 'spotify') {
        // Convert spotify URL to embed
        // https://open.spotify.com/playlist/xxx -> https://open.spotify.com/embed/playlist/xxx
        const match = url.match(/spotify\.com\/(playlist|album|track)\/([a-zA-Z0-9]+)/);
        if (match) {
            return `https://open.spotify.com/embed/${match[1]}/${match[2]}?utm_source=generator&theme=0`;
        }
    } else if (type === 'youtube') {
        // Convert youtube URL to embed
        // https://www.youtube.com/watch?v=xxx -> https://www.youtube.com/embed/xxx
        // https://youtu.be/xxx -> https://www.youtube.com/embed/xxx
        // https://www.youtube.com/playlist?list=xxx -> https://www.youtube.com/embed/videoseries?list=xxx
        let videoId = null;
        let playlistId = null;

        if (url.includes('list=')) {
            const match = url.match(/list=([a-zA-Z0-9_-]+)/);
            if (match) playlistId = match[1];
        }

        if (url.includes('v=')) {
            const match = url.match(/v=([a-zA-Z0-9_-]+)/);
            if (match) videoId = match[1];
        } else if (url.includes('youtu.be/')) {
            const match = url.match(/youtu\.be\/([a-zA-Z0-9_-]+)/);
            if (match) videoId = match[1];
        }

        if (playlistId) {
            return `https://www.youtube.com/embed/videoseries?list=${playlistId}`;
        } else if (videoId) {
            return `https://www.youtube.com/embed/${videoId}`;
        }
    }

    return null;
}

// Render exercise list in sidebar
function renderLiveExerciseList() {
    const container = document.getElementById('live-exercise-list');
    if (!container) return;

    container.innerHTML = liveClassData.exercises.map((ex, i) => `
        <div onclick="showLiveExercise(${i})" data-exercise-index="${i}"
            class="live-exercise-item p-3 rounded-xl cursor-pointer transition ${i === liveClassData.currentExerciseIndex ? 'bg-primary/20 border border-primary/50' : 'bg-white/5 hover:bg-white/10'}">
            <p class="text-sm font-medium text-white">${ex.name}</p>
            <p class="text-[10px] text-gray-400">${ex.sets} sets × ${ex.reps} reps</p>
        </div>
    `).join('');
}

// Show specific exercise
window.showLiveExercise = function(index) {
    if (index < 0 || index >= liveClassData.exercises.length) return;

    liveClassData.currentExerciseIndex = index;
    const exercise = liveClassData.exercises[index];

    // Update exercise count
    document.getElementById('live-class-exercise-count').textContent =
        `Exercise ${index + 1} of ${liveClassData.exercises.length}`;

    // Update exercise info
    document.getElementById('live-exercise-name').textContent = exercise.name;
    document.getElementById('live-exercise-sets').innerHTML = `<span class="text-primary font-bold">${exercise.sets}</span> Sets`;
    document.getElementById('live-exercise-reps').innerHTML = `<span class="text-primary font-bold">${exercise.reps}</span> Reps`;
    document.getElementById('live-exercise-rest').innerHTML = `<span class="text-primary font-bold">${exercise.rest || 60}</span>s Rest`;

    // Update video/media display
    const mediaContainer = document.getElementById('live-exercise-media');
    if (exercise.video_id) {
        mediaContainer.innerHTML = `
            <iframe src="https://www.youtube.com/embed/${exercise.video_id}?rel=0"
                class="w-full h-full" frameborder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowfullscreen></iframe>
        `;
    } else {
        mediaContainer.innerHTML = `
            <div class="text-gray-500 text-center">
                <span class="text-6xl block mb-2">🏋️</span>
                <p class="text-sm">No video for this exercise</p>
            </div>
        `;
    }

    // Update navigation buttons
    document.getElementById('prev-exercise-btn').disabled = index === 0;
    document.getElementById('next-exercise-btn').disabled = index === liveClassData.exercises.length - 1;

    // Update exercise list highlighting
    renderLiveExerciseList();

    // Set default timer to rest time
    liveClassData.timerSeconds = exercise.rest || 60;
    updateTimerDisplay();
    stopTimer();
};

// Navigation
window.prevExercise = function() {
    if (liveClassData.currentExerciseIndex > 0) {
        showLiveExercise(liveClassData.currentExerciseIndex - 1);
    }
};

window.nextExercise = function() {
    if (liveClassData.currentExerciseIndex < liveClassData.exercises.length - 1) {
        showLiveExercise(liveClassData.currentExerciseIndex + 1);
    }
};

// Timer functions
window.setQuickTimer = function(seconds) {
    liveClassData.timerSeconds = seconds;
    updateTimerDisplay();
    stopTimer();
};

window.openCustomTimer = function() {
    document.getElementById('custom-timer-minutes').value = Math.floor(liveClassData.timerSeconds / 60);
    document.getElementById('custom-timer-seconds').value = liveClassData.timerSeconds % 60;
    showModal('custom-timer-modal');
};

window.applyCustomTimer = function() {
    const minutes = parseInt(document.getElementById('custom-timer-minutes').value) || 0;
    const seconds = parseInt(document.getElementById('custom-timer-seconds').value) || 0;
    liveClassData.timerSeconds = (minutes * 60) + seconds;
    updateTimerDisplay();
    hideModal('custom-timer-modal');
};

window.toggleTimer = function() {
    if (liveClassData.timerRunning) {
        stopTimer();
    } else {
        startTimer();
    }
};

function startTimer() {
    if (liveClassData.timerSeconds <= 0) return;

    liveClassData.timerRunning = true;
    document.getElementById('timer-toggle-btn').innerHTML = '⏸ Pause';
    document.getElementById('timer-toggle-btn').classList.remove('bg-green-600', 'hover:bg-green-700');
    document.getElementById('timer-toggle-btn').classList.add('bg-yellow-600', 'hover:bg-yellow-700');

    liveClassData.timerInterval = setInterval(() => {
        liveClassData.timerSeconds--;
        updateTimerDisplay();

        if (liveClassData.timerSeconds <= 0) {
            stopTimer();
            playTimerEndSound();
            showToast('Timer complete!');
        }
    }, 1000);
}

function stopTimer() {
    liveClassData.timerRunning = false;
    if (liveClassData.timerInterval) {
        clearInterval(liveClassData.timerInterval);
        liveClassData.timerInterval = null;
    }
    document.getElementById('timer-toggle-btn').innerHTML = '▶ Start';
    document.getElementById('timer-toggle-btn').classList.remove('bg-yellow-600', 'hover:bg-yellow-700');
    document.getElementById('timer-toggle-btn').classList.add('bg-green-600', 'hover:bg-green-700');
}

window.resetTimer = function() {
    stopTimer();
    const exercise = liveClassData.exercises[liveClassData.currentExerciseIndex];
    liveClassData.timerSeconds = exercise?.rest || 60;
    updateTimerDisplay();
};

function updateTimerDisplay() {
    const minutes = Math.floor(liveClassData.timerSeconds / 60);
    const seconds = liveClassData.timerSeconds % 60;
    document.getElementById('live-timer-display').textContent =
        `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

function playTimerEndSound() {
    // Create a simple beep sound using Web Audio API
    try {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const oscillator = audioContext.createOscillator();
        const gainNode = audioContext.createGain();

        oscillator.connect(gainNode);
        gainNode.connect(audioContext.destination);

        oscillator.frequency.value = 800;
        oscillator.type = 'sine';
        gainNode.gain.value = 0.3;

        oscillator.start();
        oscillator.stop(audioContext.currentTime + 0.3);

        // Play three beeps
        setTimeout(() => {
            const osc2 = audioContext.createOscillator();
            osc2.connect(gainNode);
            osc2.frequency.value = 800;
            osc2.type = 'sine';
            osc2.start();
            osc2.stop(audioContext.currentTime + 0.3);
        }, 400);

        setTimeout(() => {
            const osc3 = audioContext.createOscillator();
            osc3.connect(gainNode);
            osc3.frequency.value = 1000;
            osc3.type = 'sine';
            osc3.start();
            osc3.stop(audioContext.currentTime + 0.5);
        }, 800);
    } catch (e) {
        console.log('Could not play timer sound:', e);
    }
}

// Music toggle (just shows/hides sidebar on mobile)
window.toggleLiveMusic = function() {
    const sidebar = document.getElementById('live-sidebar');
    sidebar.classList.toggle('hidden');
    sidebar.classList.toggle('lg:flex');
};

// End class
window.endLiveClass = function() {
    if (!confirm('End this class?')) return;

    stopTimer();
    hideModal('live-class-modal');

    // Ask if they want to mark a scheduled lesson as complete
    // For now just close
    showToast('Class ended');
};

// ======================
// COURSE EXERCISES
// ======================

let allCourseExercises = [];
let courseExerciseSteps = [];
let currentCourseExerciseFilter = 'all';
let currentCourseExerciseId = null;

// Load course exercises - only shows exercises with type="Course"
// These are course-specific exercises (yoga poses, pilates moves, aerobics, stretches, etc.)
window.loadCourseExercises = async function() {
    const container = document.getElementById('course-exercise-library');
    if (!container) return;

    try {
        const res = await fetch(`${apiBase}/api/exercises`, { credentials: 'include' });
        const exercises = await res.json();

        // Only show exercises with type="Course" - separate from regular gym exercises
        allCourseExercises = exercises
            .filter(ex => ex.type === 'Course')
            .map(ex => ({
                ...ex,
                course_category: mapToCourseCategoryDisplay(ex.muscle_group || 'flexibility')
            }));

        renderCourseExerciseLibrary();
    } catch (e) {
        console.error('Error loading course exercises:', e);
        container.innerHTML = `<div class="col-span-2 glass-card p-6 text-center"><p class="text-red-400 text-xs">Failed to load exercises</p></div>`;
    }
};

// Map course exercise categories
function mapToCourseCategoryDisplay(category) {
    const mapping = {
        'warmup': { emoji: '🔥', label: 'Warmup' },
        'cardio': { emoji: '🏃', label: 'Cardio' },
        'flexibility': { emoji: '🧘', label: 'Flexibility' },
        'cooldown': { emoji: '❄️', label: 'Cooldown' },
        'yoga': { emoji: '🧘', label: 'Yoga' },
        'pilates': { emoji: '🤸', label: 'Pilates' },
        'stretch': { emoji: '🙆', label: 'Stretch' },
        'balance': { emoji: '⚖️', label: 'Balance' },
        'breathing': { emoji: '🌬️', label: 'Breathing' },
        'core': { emoji: '🎯', label: 'Core' },
        'hiit': { emoji: '⚡', label: 'HIIT' },
        'dance': { emoji: '💃', label: 'Dance' },
        'aerobics': { emoji: '🕺', label: 'Aerobics' },
        'strength': { emoji: '💪', label: 'Strength' }
    };

    const key = (category || '').toLowerCase();
    return mapping[key] || { emoji: '🏃', label: 'General' };
}

// Render exercise cards in the library view
function renderCourseExerciseLibrary() {
    const container = document.getElementById('course-exercise-library');
    if (!container) return;

    const searchTerm = (document.getElementById('course-exercise-search')?.value || '').toLowerCase();

    let filtered = allCourseExercises;

    // Apply category filter
    if (currentCourseExerciseFilter !== 'all') {
        filtered = filtered.filter(ex => {
            const cat = (ex.muscle_group || ex.type || '').toLowerCase();
            return cat === currentCourseExerciseFilter;
        });
    }

    // Apply search filter
    if (searchTerm) {
        filtered = filtered.filter(ex =>
            ex.name.toLowerCase().includes(searchTerm) ||
            (ex.description || '').toLowerCase().includes(searchTerm)
        );
    }

    if (filtered.length === 0) {
        const isFiltered = currentCourseExerciseFilter !== 'all' || searchTerm;
        container.innerHTML = `
            <div class="col-span-2 glass-card p-6 text-center">
                <p class="text-4xl mb-2">🧘</p>
                <p class="text-gray-400 text-sm">${isFiltered ? 'No matching exercises' : 'No course exercises yet'}</p>
                <p class="text-gray-500 text-xs mt-1">${isFiltered ? 'Try a different filter or search' : 'Create yoga poses, pilates moves, stretches and more'}</p>
            </div>`;
        return;
    }

    container.innerHTML = filtered.map(ex => {
        const catInfo = mapToCourseCategoryDisplay(ex.muscle_group || ex.type);
        const duration = ex.default_duration || 60;
        const durationText = duration > 0 ? `${duration}s` : 'No timer';

        return `
            <div class="glass-card p-3 cursor-pointer hover:bg-white/10 transition tap-effect"
                onclick="openCourseExerciseDetail('${ex.id}')">
                <div class="relative w-full h-20 bg-black/30 rounded-lg mb-2 overflow-hidden flex items-center justify-center">
                    ${ex.thumbnail_url || ex.video_url ?
                        `<img src="${ex.thumbnail_url || getYouTubeThumbnail(ex.video_url)}"
                            alt="${ex.name}" class="w-full h-full object-cover"
                            onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';">
                        <div class="absolute inset-0 items-center justify-center text-3xl" style="display: none;">${catInfo.emoji}</div>` :
                        `<span class="text-3xl">${catInfo.emoji}</span>`
                    }
                </div>
                <h4 class="text-sm font-bold truncate">${ex.name}</h4>
                <div class="flex items-center justify-between mt-1">
                    <span class="text-[10px] px-1.5 py-0.5 rounded bg-white/10 text-white/60">${catInfo.label}</span>
                    <span class="text-[10px] text-white/40">${durationText}</span>
                </div>
            </div>`;
    }).join('');
}

// Get YouTube thumbnail from URL
function getYouTubeThumbnail(url) {
    if (!url) return '';
    const videoId = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&]+)/)?.[1];
    return videoId ? `https://img.youtube.com/vi/${videoId}/mqdefault.jpg` : '';
}

// Filter exercises by category
window.filterCourseExercises = function(category) {
    currentCourseExerciseFilter = category;

    // Update button states
    document.querySelectorAll('.course-ex-filter-btn').forEach(btn => {
        if (btn.dataset.filter === category) {
            btn.classList.add('active', 'bg-primary/20', 'text-primary', 'border-primary/30');
            btn.classList.remove('bg-white/5', 'text-white/60', 'border-white/10');
        } else {
            btn.classList.remove('active', 'bg-primary/20', 'text-primary', 'border-primary/30');
            btn.classList.add('bg-white/5', 'text-white/60', 'border-white/10');
        }
    });

    renderCourseExerciseLibrary();
};

// Search filter
window.filterCourseExercisesBySearch = function(term) {
    renderCourseExerciseLibrary();
};

// Open create exercise modal
window.openCourseExerciseModal = function(exerciseId = null) {
    currentCourseExerciseId = exerciseId;
    courseExerciseSteps = [];

    const modal = document.getElementById('course-exercise-modal');
    const title = document.getElementById('course-exercise-modal-title');

    // Reset form
    document.getElementById('course-exercise-id').value = '';
    document.getElementById('course-exercise-name').value = '';
    document.getElementById('course-exercise-category').value = 'cardio';
    document.getElementById('course-exercise-description').value = '';
    document.getElementById('course-exercise-duration').value = '60';
    document.getElementById('course-exercise-difficulty').value = 'intermediate';
    document.getElementById('course-exercise-video').value = '';
    document.getElementById('course-exercise-image').value = '';
    document.getElementById('course-exercise-image-preview').classList.add('hidden');
    document.getElementById('course-exercise-steps').innerHTML = '';

    if (exerciseId) {
        title.textContent = 'Edit Exercise';
        // Load exercise data
        const exercise = allCourseExercises.find(ex => ex.id === exerciseId);
        if (exercise) {
            document.getElementById('course-exercise-id').value = exercise.id;
            document.getElementById('course-exercise-name').value = exercise.name || '';
            document.getElementById('course-exercise-category').value = (exercise.muscle_group || 'cardio').toLowerCase();
            document.getElementById('course-exercise-description').value = exercise.description || '';
            document.getElementById('course-exercise-duration').value = exercise.default_duration || 60;
            document.getElementById('course-exercise-difficulty').value = exercise.difficulty || 'intermediate';
            document.getElementById('course-exercise-video').value = exercise.video_url || '';
            document.getElementById('course-exercise-image').value = exercise.thumbnail_url || '';

            if (exercise.thumbnail_url) {
                const preview = document.getElementById('course-exercise-image-preview');
                preview.querySelector('img').src = exercise.thumbnail_url;
                preview.classList.remove('hidden');
            }

            // Load steps if available
            if (exercise.steps && Array.isArray(exercise.steps)) {
                courseExerciseSteps = [...exercise.steps];
                renderCourseExerciseSteps();
            }
        }
    } else {
        title.textContent = 'Create Exercise';
    }

    showModal('course-exercise-modal');
};

// Add step input
window.addCourseExerciseStep = function() {
    courseExerciseSteps.push('');
    renderCourseExerciseSteps();
};

// Render steps
function renderCourseExerciseSteps() {
    const container = document.getElementById('course-exercise-steps');
    if (!container) return;

    container.innerHTML = courseExerciseSteps.map((step, i) => `
        <div class="flex gap-2 items-start">
            <span class="text-xs text-white/40 mt-2.5">${i + 1}.</span>
            <input type="text" value="${step}" onchange="updateCourseExerciseStep(${i}, this.value)"
                placeholder="Step ${i + 1}..."
                class="flex-1 bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm text-white focus:border-primary outline-none">
            <button onclick="removeCourseExerciseStep(${i})" class="text-red-400 hover:text-red-300 px-2 py-2">✕</button>
        </div>
    `).join('');
}

// Update step
window.updateCourseExerciseStep = function(index, value) {
    courseExerciseSteps[index] = value;
};

// Remove step
window.removeCourseExerciseStep = function(index) {
    courseExerciseSteps.splice(index, 1);
    renderCourseExerciseSteps();
};

// Upload exercise image
window.uploadCourseExerciseImage = async function(input) {
    if (!input.files || !input.files[0]) return;

    const file = input.files[0];
    const formData = new FormData();
    formData.append('file', file);

    try {
        const res = await fetch(`${apiBase}/api/upload`, {
            method: 'POST',
            credentials: 'include',
            body: formData
        });

        if (!res.ok) throw new Error('Upload failed');

        const data = await res.json();
        document.getElementById('course-exercise-image').value = data.url;

        const preview = document.getElementById('course-exercise-image-preview');
        preview.querySelector('img').src = data.url;
        preview.classList.remove('hidden');

        showToast('Image uploaded');
    } catch (e) {
        console.error('Upload error:', e);
        showToast('Failed to upload image');
    }
};

// Save exercise
window.saveCourseExercise = async function() {
    const name = document.getElementById('course-exercise-name').value.trim();
    const category = document.getElementById('course-exercise-category').value;
    const description = document.getElementById('course-exercise-description').value.trim();
    const duration = parseInt(document.getElementById('course-exercise-duration').value) || 60;
    const difficulty = document.getElementById('course-exercise-difficulty').value;
    const videoUrl = document.getElementById('course-exercise-video').value.trim();
    const imageUrl = document.getElementById('course-exercise-image').value.trim();
    const exerciseId = document.getElementById('course-exercise-id').value;

    if (!name) {
        showToast('Please enter an exercise name');
        return;
    }

    const exerciseData = {
        name,
        muscle_group: category, // Using muscle_group field for category
        type: 'Course', // Mark as course exercise
        description,
        default_duration: duration,
        difficulty,
        video_url: videoUrl || null,
        thumbnail_url: imageUrl || null,
        steps: courseExerciseSteps.filter(s => s.trim())
    };

    try {
        let res;
        if (exerciseId) {
            // Update existing
            res = await fetch(`${apiBase}/api/exercises/${exerciseId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify(exerciseData)
            });
        } else {
            // Create new
            res = await fetch(`${apiBase}/api/exercises`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify(exerciseData)
            });
        }

        if (!res.ok) throw new Error('Failed to save exercise');

        showToast(exerciseId ? 'Exercise updated' : 'Exercise created');
        hideModal('course-exercise-modal');
        loadCourseExercises();
    } catch (e) {
        console.error('Error saving exercise:', e);
        showToast('Failed to save exercise');
    }
};

// Open exercise detail modal
window.openCourseExerciseDetail = function(exerciseId) {
    const exercise = allCourseExercises.find(ex => ex.id === exerciseId);
    if (!exercise) return;

    currentCourseExerciseId = exerciseId;

    const catInfo = mapToCourseCategoryDisplay(exercise.muscle_group || exercise.type);
    const duration = exercise.default_duration || 60;
    const durationText = duration > 0 ? `${duration}s` : 'No timer';

    // Set media
    const mediaContainer = document.getElementById('course-exercise-detail-media');
    if (exercise.video_url) {
        const videoId = exercise.video_url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&]+)/)?.[1];
        if (videoId) {
            mediaContainer.innerHTML = `
                <iframe src="https://www.youtube.com/embed/${videoId}"
                    class="w-full h-full" frameborder="0"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowfullscreen></iframe>`;
        } else {
            mediaContainer.innerHTML = `<span class="text-6xl">${catInfo.emoji}</span>`;
        }
    } else if (exercise.thumbnail_url) {
        mediaContainer.innerHTML = `<img src="${exercise.thumbnail_url}" alt="${exercise.name}" class="w-full h-full object-cover">`;
    } else {
        mediaContainer.innerHTML = `<span class="text-6xl">${catInfo.emoji}</span>`;
    }

    // Set details
    document.getElementById('course-exercise-detail-name').textContent = exercise.name;
    document.getElementById('course-exercise-detail-category').textContent = `${catInfo.emoji} ${catInfo.label}`;
    document.getElementById('course-exercise-detail-difficulty').textContent = exercise.difficulty || 'Intermediate';
    document.getElementById('course-exercise-detail-duration').textContent = durationText;
    document.getElementById('course-exercise-detail-description').textContent = exercise.description || 'No description provided.';

    // Set steps
    const stepsSection = document.getElementById('course-exercise-detail-steps-section');
    const stepsList = document.getElementById('course-exercise-detail-steps');

    if (exercise.steps && exercise.steps.length > 0) {
        stepsSection.classList.remove('hidden');
        stepsList.innerHTML = exercise.steps.map(step => `<li class="mb-1">${step}</li>`).join('');
    } else {
        stepsSection.classList.add('hidden');
    }

    showModal('course-exercise-detail-modal');
};

// Edit from detail modal
window.editCourseExerciseFromDetail = function() {
    hideModal('course-exercise-detail-modal');
    openCourseExerciseModal(currentCourseExerciseId);
};

// Delete from detail modal
window.deleteCourseExerciseFromDetail = async function() {
    if (!currentCourseExerciseId) return;
    if (!confirm('Delete this exercise?')) return;

    try {
        const res = await fetch(`${apiBase}/api/exercises/${currentCourseExerciseId}`, {
            method: 'DELETE',
            credentials: 'include'
        });

        if (!res.ok) throw new Error('Failed to delete');

        showToast('Exercise deleted');
        hideModal('course-exercise-detail-modal');
        loadCourseExercises();
    } catch (e) {
        console.error('Error deleting exercise:', e);
        showToast('Failed to delete exercise');
    }
};
