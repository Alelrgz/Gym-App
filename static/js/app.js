const { gymId, role, apiBase } = window.APP_CONFIG;
console.log("App.js loaded! apiBase: " + apiBase);
console.log("App.js loaded (Restored Monolithic) v" + Math.random());

// Global fetch wrapper: always send credentials (cookies) with API requests
const _originalFetch = window.fetch;
window.fetch = function(url, options = {}) {
    if (!options.credentials) {
        options.credentials = 'include';
    }
    return _originalFetch.call(this, url, options);
};

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
                <div class="mb-4">${icon('smartphone', 48)}</div>
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
    // CO-OP invitation received
    else if (data.type === 'coop_invite') {
        console.log('CO-OP invite received from:', data.from_name);
        if (typeof window.showCoopInviteModal === 'function') {
            window.showCoopInviteModal(data.from_id, data.from_name, data.from_picture);
        }
    }
    // CO-OP invitation was sent successfully
    else if (data.type === 'coop_invite_sent') {
        console.log('CO-OP invite sent, waiting for response...');
    }
    // CO-OP invitation failed (friend offline)
    else if (data.type === 'coop_invite_failed') {
        console.log('CO-OP invite failed:', data.reason);
        if (typeof window.handleCoopInviteFailed === 'function') {
            window.handleCoopInviteFailed(data.reason);
        }
    }
    // CO-OP invitation accepted by friend
    else if (data.type === 'coop_accepted') {
        console.log('CO-OP accepted by:', data.partner_name);
        if (typeof window.handleCoopAccepted === 'function') {
            window.handleCoopAccepted(data.partner_id, data.partner_name, data.partner_picture);
        }
    }
    // CO-OP invitation declined by friend
    else if (data.type === 'coop_declined') {
        console.log('CO-OP declined by:', data.partner_name);
        if (typeof window.handleCoopDeclined === 'function') {
            window.handleCoopDeclined(data.partner_name);
        }
    }
};

socket.onopen = () => console.log("Connected to Real-Time Engine");
socket.onclose = () => console.log("Disconnected from Real-Time Engine");

// Expose WebSocket send function for CO-OP and other features
window.sendWebSocketMessage = function(message) {
    if (socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify(message));
        return true;
    }
    console.warn('WebSocket not connected');
    return false;
};

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
        let eIcon, statusColor;
        if (e.type === 'course') {
            eIcon = icon('book-open', 20);
            statusColor = e.completed ? 'text-green-400' : 'text-purple-400';
        } else if (e.type === 'workout') {
            eIcon = icon('dumbbell', 20);
            statusColor = e.completed ? 'text-green-400' : 'text-orange-400';
        } else if (e.type === 'appointment') {
            eIcon = icon('calendar', 20);
            statusColor = e.completed ? 'text-green-400' : 'text-blue-400';
        } else {
            eIcon = icon('heart', 20);
            statusColor = e.completed ? 'text-green-400' : 'text-orange-400';
        }

        // Add edit/delete buttons for course events if trainer
        const isCourseEvent = e.type === 'course' && e.course_id;
        const courseActions = isCourseEvent && isTrainer ? `
            <div class="flex items-center gap-2 ml-2">
                <button onclick="event.stopPropagation(); window.editScheduleEvent('${e.id}', '${e.date}', '${e.time}', '${e.title}')"
                    class="text-white/50 hover:text-white text-xs px-2 py-1 rounded bg-white/10 hover:bg-white/20 transition">${icon('pencil', 14)}</button>
                <button onclick="event.stopPropagation(); window.deleteScheduleEvent('${e.id}', '${e.title}')"
                    class="text-white/50 hover:text-red-400 text-xs px-2 py-1 rounded bg-white/10 hover:bg-red-500/20 transition">${icon('trash-2', 14)}</button>
            </div>
        ` : '';

        div.innerHTML = `
            <div class="flex items-center flex-1">
                <span class="text-xl mr-3">${eIcon}</span>
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
            showToast('Schedule updated!');
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
            showToast('Removed from schedule');
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

// Certificate status cache for trainer client list
let clientCertificateMap = {};

async function loadClientCertificates() {
    try {
        const res = await fetch(`${apiBase}/api/medical/certificates/overview`, { credentials: 'include' });
        if (res.ok) {
            const data = await res.json();
            clientCertificateMap = {};
            (data.clients || []).forEach(c => { clientCertificateMap[c.client_id] = c.status; });
            // Re-render if clients already loaded
            if (allClients && allClients.length > 0) renderClientList(allClients);
        }
    } catch (e) {
        console.log('Could not load certificate status:', e);
    }
}

function renderClientList(clients) {
    const list = document.getElementById('client-list');
    if (!list) return;

    list.innerHTML = ''; // Clear current list

    if (clients.length === 0) {
        list.innerHTML = '<p class="text-gray-500 text-xs text-center py-4">No clients found.</p>';
        return;
    }

    const certBadge = {
        valid: '<span class="w-2 h-2 rounded-full bg-green-400 inline-block ml-1" title="Certificate valid"></span>',
        expiring: '<span class="w-2 h-2 rounded-full bg-yellow-400 inline-block ml-1" title="Certificate expiring soon"></span>',
        expired: '<span class="w-2 h-2 rounded-full bg-red-400 inline-block ml-1" title="Certificate expired"></span>',
        missing: '<span class="w-2 h-2 rounded-full bg-gray-500 inline-block ml-1" title="No certificate"></span>'
    };

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
            premiumBtn = `<span class="ml-2 bg-yellow-500/20 text-yellow-500 border border-yellow-500 px-2 py-0.5 rounded text-[10px] font-bold">PRO</span>`;
        }

        const certStatus = clientCertificateMap[c.id] || 'missing';
        const certDot = certBadge[certStatus] || certBadge.missing;

        const avatarUrl = c.profile_picture || `https://api.dicebear.com/7.x/avataaars/svg?seed=${c.name}`;
        div.innerHTML = `<div class="flex items-center"><div class="w-10 h-10 rounded-full bg-white/10 mr-3 overflow-hidden"><img src="${avatarUrl}" class="w-full h-full object-cover" /></div><div><p class="font-bold text-sm text-white flex items-center">${c.name} ${premiumBtn} ${certDot}</p><p class="text-[10px] text-gray-400">${c.plan} • Seen ${c.last_seen}</p></div></div><span class="text-xs font-bold ${statusColor}">${c.status}</span>`;
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
        const nameEls = document.querySelectorAll('#gym-name, #gym-name-owner, #desktop-gym-name');
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

                // Update streak display (day streak)
                setTxt('client-streak', user.streak);
                setTxt('streak-count', user.streak); // Legacy fallback

                // Calculate next goal for day streak (milestones: 3, 7, 14, 21, 30, 60, 90, 180, 365 days)
                const dayMilestones = [3, 7, 14, 21, 30, 60, 90, 180, 365];
                const nextDayGoal = dayMilestones.find(m => m > user.streak) || (user.streak + 30);
                setTxt('client-next-goal', `${nextDayGoal} Days`);

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
                        const startBtn = document.getElementById('workout-main-btn');
                        const coopBadgeBtn = document.getElementById('coop-badge-btn');
                        const coopCompletedBadge = document.getElementById('coop-completed-badge');

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

                        // Hide the CO-OP start button when completed
                        if (coopBadgeBtn) {
                            coopBadgeBtn.classList.add('hidden');
                        }

                        // Check if this was a CO-OP workout
                        let wasCoopWorkout = false;
                        if (user.todays_workout.details) {
                            try {
                                const details = typeof user.todays_workout.details === 'string'
                                    ? JSON.parse(user.todays_workout.details)
                                    : user.todays_workout.details;
                                if (details.coop && details.coop.partner) {
                                    wasCoopWorkout = true;
                                }
                            } catch (e) {
                                console.log('Could not parse workout details for CO-OP check');
                            }
                        }

                        // Show CO-OP badge if it was a CO-OP workout
                        if (wasCoopWorkout && coopCompletedBadge) {
                            coopCompletedBadge.classList.remove('hidden');
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
                if (m) {
                    const calsRemainingEl = document.getElementById('cals-remaining');
                    if (calsRemainingEl) {
                        const calsLeft = Math.round(m.calories.target - m.calories.current);
                        calsRemainingEl.innerText = `${calsLeft} kcal left`;
                    }
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
                                <span class="text-xl">${icon('dumbbell', 20)}</span>
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
                loadClientCertificates();

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
                    const label = toggleBtn.querySelector('span:first-child');

                    if (exercisesOpen) {
                        // Opening
                        exercisesSection.style.maxHeight = exercisesSection.scrollHeight + 500 + 'px';
                        exercisesSection.style.opacity = '1';
                        if (exercisesChevron) exercisesChevron.style.transform = 'rotate(180deg)';
                        if (label) label.textContent = 'Hide Exercises';
                    } else {
                        // Closing
                        exercisesSection.style.maxHeight = '0';
                        exercisesSection.style.opacity = '0';
                        if (exercisesChevron) exercisesChevron.style.transform = 'rotate(0deg)';
                        if (label) label.textContent = 'Show Exercises';
                    }
                });
            }

            // Fetch and Render Workouts (Library)
            if (document.getElementById('workout-library')) {
                fetchAndRenderWorkouts();
            }

            // --- MY WORKOUTS SECTION ---
            // Toggle handled by inline onclick in HTML

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
                                        <span class="text-xl">${icon('dumbbell', 20)}</span>
                                    </div>
                                    <h3 class="text-2xl font-black italic uppercase mb-1 text-white">${w.title}</h3>
                                    <p class="text-sm text-gray-300 mb-4">${w.duration} • ${w.difficulty}</p>
                                    <div class="flex gap-2 mb-2">
                                         <button onclick='openEditWorkout(JSON.parse(decodeURIComponent("${encodeURIComponent(JSON.stringify(w))}")))' class="flex-1 py-3 bg-white/10 text-white text-center font-bold rounded-xl hover:bg-white/20 transition">EDIT</button>
                                         <a href="/?gym_id=${gymId}&role=client&mode=workout&view=preview&workout_id=${w.id}" class="flex-1 py-3 bg-white text-black text-center font-bold rounded-xl hover:bg-gray-200 transition">PREVIEW</a>
                                    </div>
                                    <button onclick='window.assignWorkoutToSelf("${w.id}", "${w.title.replace(/'/g, "\\'")}")' 
                                        class="w-full py-2 bg-green-600/20 hover:bg-green-600 text-green-400 hover:text-white text-sm font-bold rounded-lg transition border border-green-500/30">
                                        ${icon('calendar', 14)} Assign to Me (Today)
                                    </button>
                                </div>
                            `;
                            container.appendChild(card);
                        });
                    }
                }
            }

            // --- MY SPLITS SECTION ---
            // Toggle handled by inline onclick in HTML

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
                                             ${icon('calendar', 20)}
                                         </div>
                                         <div>
                                             <h3 class="font-bold text-white text-lg leading-tight">${s.name}</h3>
                                             <p class="text-xs text-gray-500">${s.description || 'No description'}</p>
                                         </div>
                                     </div>
                                     
                                     <div class="flex gap-2">
                                         <button onclick='window.openEditSplit(JSON.parse(decodeURIComponent("${encodeURIComponent(JSON.stringify(s))}")))' 
                                            class="text-gray-500 hover:text-white transition p-1" title="Edit">
                                            ${icon('pencil', 14)}
                                         </button>
                                         <button onclick='window.deleteSplit("${s.id}")' 
                                            class="text-gray-500 hover:text-red-400 transition p-1" title="Delete">
                                            ${icon('trash-2', 14)}
                                         </button>
                                     </div>
                                </div>

                                <button onclick='window.assignSplitToSelf("${s.id}", "${s.name.replace(/'/g, "\\'")}")'
                                    class="w-full mt-3 py-2 bg-white/5 hover:bg-purple-600 hover:text-white text-gray-400 text-sm font-bold rounded-lg transition border border-white/10 group-hover:border-purple-500/50">
                                    ${icon('calendar', 14)} Assign to Me (This Week)
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
                    let aIcon = icon('activity', 18);
                    if (item.type === 'money') aIcon = icon('dollar-sign', 18);
                    if (item.type === 'staff') aIcon = icon('briefcase', 18);
                    div.innerHTML = `<span class="mr-3 text-lg">${aIcon}</span><div><p class="text-sm font-medium text-gray-200">${item.text}</p><p class="text-[10px] text-gray-500">${item.time}</p></div>`;
                    feed.appendChild(div);
                });
            }
        }

        // Leaderboard Mode
        if (document.getElementById('leaderboard-list')) {
            const [leaderboardRes, clientRes] = await Promise.all([
                fetch(`${apiBase}/api/leaderboard/data`),
                fetch(`${apiBase}/api/client/data`)
            ]);
            const leaderboard = await leaderboardRes.json();
            const clientData = await clientRes.json();

            // Update gem counter in header
            const gemCountEl = document.getElementById('gem-count');
            if (gemCountEl) gemCountEl.textContent = clientData.gems || 0;

            // Render league tier badges
            renderLeagueTiers(leaderboard.league);

            // League info
            const setTxt = (id, val) => { if (document.getElementById(id)) document.getElementById(id).innerText = val; };
            setTxt('league-name', `${leaderboard.league.current_tier.name} League`);

            const userCount = leaderboard.users.length;
            const advanceCount = Math.min(leaderboard.league.advance_count, userCount);
            if (leaderboard.league.current_tier.level < 5) {
                setTxt('league-subtitle', `Top ${advanceCount} advance to the next league`);
            } else {
                setTxt('league-subtitle', 'You reached the highest league!');
            }

            // Countdown timer
            startWeeklyCountdown();

            // Weekly challenge
            setTxt('challenge-title', leaderboard.weekly_challenge.title);
            setTxt('challenge-progress', leaderboard.weekly_challenge.progress);
            setTxt('challenge-target', leaderboard.weekly_challenge.target);
            setTxt('challenge-reward', leaderboard.weekly_challenge.reward_gems);
            const challengePct = (leaderboard.weekly_challenge.progress / leaderboard.weekly_challenge.target) * 100;
            if (document.getElementById('challenge-bar')) {
                document.getElementById('challenge-bar').style.width = `${Math.min(challengePct, 100)}%`;
            }

            // Rankings
            renderLeaderboardList(leaderboard.users);

            // Daily Quests
            renderLeaderboardQuests(clientData.daily_quests || []);
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
    console.log('[DEBUG] Global click listener - action:', action);

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
        console.log('[DEBUG] openCreateCourse action triggered');
        openCreateCourseModal();
    }
});


// --- MODAL SYSTEM & HELPERS ---

function showModal(id) {
    console.log('[DEBUG] showModal called for:', id);
    const modal = document.getElementById(id);
    if (!modal) {
        console.error('[ERROR] Modal not found:', id);
        alert('ERROR: Modal not found: ' + id);
        return;
    }
    console.log('[DEBUG] Modal found, removing hidden class');
    modal.classList.remove('hidden');
    console.log('[DEBUG] Modal classes after remove:', modal.className);
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

// ============ LEADERBOARD HELPERS ============

function renderLeagueTiers(league) {
    const container = document.getElementById('league-tiers-container');
    if (!container) return;
    container.innerHTML = '';

    const tierIcons = ['shield', 'shield', 'crown', 'gem', 'diamond'];

    league.all_tiers.forEach((tier, idx) => {
        const isCurrent = tier.level === league.current_tier.level;
        const isUnlocked = tier.level <= league.current_tier.level;

        const badge = document.createElement('div');
        badge.className = `flex flex-col items-center transition-all duration-300 ${
            isCurrent ? 'scale-110 z-10' : isUnlocked ? 'opacity-70' : 'opacity-25'
        }`;

        const size = isCurrent ? 'w-14 h-14' : 'w-10 h-10';
        const iconSize = isCurrent ? 24 : 16;
        const borderWidth = isCurrent ? 'border-2' : 'border';

        badge.innerHTML = `
            <div class="${size} rounded-xl ${borderWidth} flex items-center justify-center ${isCurrent ? 'league-tier-active' : ''}"
                 style="background: ${tier.color}15; border-color: ${tier.color}50; --tier-glow: ${tier.color}40;">
                ${icon(tierIcons[idx] || 'shield', iconSize)}
            </div>
            ${isCurrent ? `<div class="w-1.5 h-1.5 rounded-full mt-1.5" style="background: ${tier.color};"></div>` : ''}
            <span class="text-[9px] mt-1 font-medium ${isCurrent ? 'text-white' : 'text-gray-600'}">${tier.name}</span>
        `;
        badge.style.color = tier.color;

        container.appendChild(badge);
    });
}

function renderLeaderboardList(users) {
    const leaderList = document.getElementById('leaderboard-list');
    if (!leaderList) return;
    leaderList.innerHTML = '';

    users.forEach(u => {
        const div = document.createElement('div');
        const isUser = u.isCurrentUser || false;

        div.className = `glass-card p-3 flex items-center justify-between tap-effect ${
            isUser
                ? 'border border-lime-500/40 bg-lime-500/10'
                : 'cursor-pointer hover:bg-white/5'
        }`;

        const avatarUrl = u.profile_picture
            ? u.profile_picture
            : `https://api.dicebear.com/7.x/avataaars/svg?seed=${u.name}`;

        let rankDisplay;
        if (u.rank === 1) {
            rankDisplay = `<div class="w-8 h-8 rounded-full bg-yellow-500/20 flex items-center justify-center text-yellow-400">${icon('crown', 18)}</div>`;
        } else if (u.rank === 2) {
            rankDisplay = `<div class="w-8 h-8 rounded-full bg-gray-400/20 flex items-center justify-center text-gray-300">${icon('medal', 18)}</div>`;
        } else if (u.rank === 3) {
            rankDisplay = `<div class="w-8 h-8 rounded-full bg-amber-700/20 flex items-center justify-center text-amber-600">${icon('medal', 18)}</div>`;
        } else {
            rankDisplay = `<span class="w-8 text-center text-sm font-bold text-gray-500">${u.rank}</span>`;
        }

        div.innerHTML = `
            <div class="flex items-center gap-3">
                ${rankDisplay}
                <div class="w-10 h-10 rounded-full bg-white/10 overflow-hidden flex-shrink-0">
                    <img src="${avatarUrl}" class="w-full h-full object-cover" />
                </div>
                <div>
                    <p class="font-bold text-sm ${isUser ? 'text-lime-300' : 'text-white'}">${u.name}${isUser ? ' (You)' : ''}</p>
                    <div class="flex items-center gap-1 text-[10px] text-gray-400">
                        <span class="text-orange-400">${icon('flame', 12)}</span> <span>${u.streak}</span>
                    </div>
                </div>
            </div>
            <p class="text-yellow-400 font-bold text-sm">🔶 ${u.gems}</p>
        `;

        if (!isUser && u.user_id) {
            div.addEventListener('click', () => {
                if (typeof openMemberProfile === 'function') {
                    openMemberProfile(u.user_id);
                } else if (typeof window.openMemberProfile === 'function') {
                    window.openMemberProfile(u.user_id);
                }
            });
        }

        leaderList.appendChild(div);
    });
}

function renderLeaderboardQuests(quests) {
    const questList = document.getElementById('quest-list');
    if (!questList || !quests) return;
    questList.innerHTML = '';

    let completedCount = 0;

    quests.forEach((quest, index) => {
        if (quest.completed) completedCount++;

        const div = document.createElement('div');
        div.className = "glass-card p-4 flex justify-between items-center tap-effect";
        div.setAttribute('data-quest-index', index);
        div.onclick = function () { toggleQuest(this); };
        if (quest.completed) div.style.borderColor = "rgba(249, 115, 22, 0.3)";
        div.innerHTML = `
            <div class="flex items-center">
                <div class="w-5 h-5 rounded-full border border-white/20 mr-3 flex items-center justify-center ${quest.completed ? 'bg-orange-500 text-white border-none' : ''}">
                    ${quest.completed ? '✓' : ''}
                </div>
                <span class="text-sm font-medium text-gray-200">${quest.text}</span>
            </div>
            <span class="text-xs font-bold text-orange-500">+${quest.xp}</span>
        `;
        questList.appendChild(div);
    });

    const badge = document.getElementById('quest-progress-badge');
    if (badge) badge.textContent = `${completedCount}/${quests.length}`;
}

function startWeeklyCountdown() {
    const el = document.getElementById('weekly-countdown');
    if (!el) return;

    function update() {
        const now = new Date();
        const dayOfWeek = now.getDay(); // 0=Sun, 1=Mon...
        let daysUntilMonday = (8 - dayOfWeek) % 7;
        if (daysUntilMonday === 0) daysUntilMonday = 7;

        const nextMonday = new Date(now);
        nextMonday.setDate(now.getDate() + daysUntilMonday);
        nextMonday.setHours(0, 0, 0, 0);

        const diff = nextMonday - now;
        const days = Math.floor(diff / (1000 * 60 * 60 * 24));
        const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));

        el.textContent = `${days}d ${hours}h ${minutes}m`;
    }

    update();
    setInterval(update, 60000);
}

function toggleQuestSection() {
    const section = document.getElementById('quest-section');
    const chevron = document.getElementById('quest-chevron');
    if (!section) return;

    if (section.style.maxHeight && section.style.maxHeight !== '0px') {
        section.style.maxHeight = '0px';
        if (chevron) chevron.classList.remove('rotate-180');
    } else {
        section.style.maxHeight = (section.scrollHeight + 20) + 'px';
        if (chevron) chevron.classList.add('rotate-180');
    }
}

// ============ QUEST TOGGLE ============

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
            showToast('Daily limit reached! (10000ml)', 'error');
            return;
        }
        cur += 250;
        el.innerText = cur + 'ml';
        // Mock target 2500
        const pct = 100 - ((cur / 2500) * 100);
        wave.style.top = Math.max(0, pct) + '%';
        showToast('Hydration recorded!', 'success');
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
        showToast('Copied yesterday\'s meals');
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
        console.error('Camera access error:', err.name, err.message);
        if (err.name === 'NotAllowedError') {
            showToast('Camera permission denied. Please allow camera access in your browser settings.');
        } else if (err.name === 'NotFoundError') {
            showToast('No camera found on this device.');
        } else if (err.name === 'NotReadableError') {
            showToast('Camera is in use by another app.');
        } else {
            showToast('Could not access camera: ' + err.message);
        }
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

    showToast('Analyzing meal...');

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
        showToast('Error analyzing meal', 'error');
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
            showToast('Meal logged successfully!', 'success');
            // Close modal and refresh data
            closeCameraScanner();
            init();
        } else {
            showToast('Failed to log meal', 'error');
        }
    } catch (err) {
        console.error(err);
        showToast('Failed to log meal', 'error');
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
        const weightInput = document.getElementById('weight-input');
        const bodyFatInput = document.getElementById('body-fat-input');
        const preview = document.getElementById('composition-preview');

        if (weightInput && currentClientWeight) {
            weightInput.value = currentClientWeight;
        }
        // Clear body fat input and preview
        if (bodyFatInput) bodyFatInput.value = '';
        if (preview) preview.classList.add('hidden');

        weightInput?.focus();
    }
}

function closeWeightModal() {
    const modal = document.getElementById('weight-modal');
    if (modal) {
        modal.classList.add('hidden');
    }
}

async function saveWeight() {
    const weightInput = document.getElementById('weight-input');
    const bodyFatInput = document.getElementById('body-fat-input');
    const weight = parseFloat(weightInput?.value);
    const bodyFat = bodyFatInput?.value ? parseFloat(bodyFatInput.value) : null;

    if (!weight || weight < 20 || weight > 300) {
        showToast('Please enter a valid weight (20-300 kg)', 'error');
        return;
    }

    if (bodyFat !== null && (bodyFat < 1 || bodyFat > 70)) {
        showToast('Please enter a valid body fat % (1-70)', 'error');
        return;
    }

    const payload = { weight };
    if (bodyFat !== null) {
        payload.body_fat_pct = bodyFat;
    }

    try {
        const response = await fetch('/api/client/profile', {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('token') || ''}`
            },
            credentials: 'include',
            body: JSON.stringify(payload)
        });

        if (response.ok) {
            currentClientWeight = weight;
            updateWeightDisplay(weight);
            closeWeightModal();
            showToast('Body stats updated!', 'success');
            // Reload the weight chart
            loadWeightChart(currentWeightPeriod);
        } else {
            showToast('Failed to update stats', 'error');
        }
    } catch (error) {
        console.error('Error updating stats:', error);
        showToast('Failed to update stats', 'error');
    }
}

// Live preview of body composition calculations in modal
window.updateCompositionPreview = function() {
    const weight = parseFloat(document.getElementById('weight-input')?.value) || 0;
    const bodyFat = parseFloat(document.getElementById('body-fat-input')?.value) || 0;
    const preview = document.getElementById('composition-preview');

    if (weight > 0 && bodyFat > 0 && preview) {
        const fatMass = (weight * bodyFat / 100).toFixed(1);
        const leanMass = (weight - fatMass).toFixed(1);
        document.getElementById('preview-fat-mass').textContent = fatMass;
        document.getElementById('preview-lean-mass').textContent = leanMass;
        preview.classList.remove('hidden');
    } else if (preview) {
        preview.classList.add('hidden');
    }
};

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
let currentBodyMetric = 'weight'; // 'weight', 'body_fat_pct', or 'lean_mass'
let cachedWeightData = null;
let cachedStrengthData = null;

// Metric configuration for body composition charts
const bodyMetricConfig = METRIC_ICONS;

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

// Update trend badge for body composition metrics
function updateBodyMetricBadge(stats, config) {
    const trendBadge = document.getElementById('weight-trend-badge');
    if (!trendBadge || !stats) return;

    const change = stats.change || 0;
    const isGood = config.goodDirection === 'down' ? change < 0 : change > 0;
    const isBad = config.goodDirection === 'down' ? change > 0 : change < 0;

    if (change !== 0) {
        const arrow = change > 0 ? '↑' : '↓';
        trendBadge.textContent = `${arrow} ${Math.abs(change)} ${config.unit}`;
        trendBadge.className = `text-[10px] px-2 py-0.5 rounded-full font-bold ${isGood ? 'bg-green-500/20 text-green-400' : isBad ? 'bg-red-500/20 text-red-400' : 'bg-blue-500/20 text-blue-400'}`;
    } else {
        trendBadge.textContent = '→ Stable';
        trendBadge.className = 'text-[10px] px-2 py-0.5 rounded-full bg-blue-500/20 text-blue-400 font-bold';
    }
}

// Switch between body metrics (weight, body fat, lean mass)
window.switchBodyMetric = function(metric) {
    currentBodyMetric = metric;
    const config = bodyMetricConfig[metric];

    // Update metric tab buttons
    ['weight', 'body_fat_pct', 'lean_mass'].forEach(m => {
        const btn = document.getElementById(`body-metric-${m}`);
        if (btn) {
            if (m === metric) {
                btn.className = `text-[10px] px-3 py-1 rounded-lg bg-blue-500/20 text-blue-400 font-bold transition`;
                btn.style.backgroundColor = config.color + '33';
                btn.style.color = config.color;
            } else {
                btn.className = 'text-[10px] px-3 py-1 rounded-lg bg-white/5 text-gray-400 hover:bg-white/10 transition';
                btn.style.backgroundColor = '';
                btn.style.color = '';
            }
        }
    });

    // Update metric display in header
    const metricIcon = document.getElementById('metric-icon');
    const metricUnit = document.getElementById('metric-unit');
    if (metricIcon) metricIcon.innerHTML = icon(config.icon, 14);
    if (metricUnit) metricUnit.textContent = config.unit;

    // Re-render chart with current data
    if (cachedWeightData) {
        renderWeightChart(cachedWeightData.data, cachedWeightData.stats, metric);
    }
};

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

    const trend = strengthData.trend || 'stable';
    const categories = strengthData.categories || {};
    const visibility = window.strengthChartVisibility || { upper_body: true, lower_body: true, cardio: true };

    // Update category-specific stats
    const upperEl = document.getElementById('strength-stat-upper');
    const lowerEl = document.getElementById('strength-stat-lower');
    const cardioEl = document.getElementById('strength-stat-cardio');
    const trendEl = document.getElementById('strength-stat-trend');

    // Helper to format progress with color (respects visibility)
    function formatProgress(el, progress, baseColor, isVisible) {
        if (!el) return;
        if (progress === null || progress === undefined || !categories) {
            el.textContent = '--';
            el.className = `text-sm font-bold text-gray-500`;
            el.style.opacity = '1';
            return;
        }
        const prefix = progress > 0 ? '+' : '';
        el.textContent = `${prefix}${progress}%`;
        // Use base color but adjust for negative
        if (progress > 0) {
            el.className = `text-sm font-bold ${baseColor}`;
        } else if (progress < 0) {
            el.className = `text-sm font-bold text-red-400`;
        } else {
            el.className = `text-sm font-bold text-gray-400`;
        }
        // Dim if category is hidden in chart
        el.style.opacity = isVisible ? '1' : '0.35';
        el.style.textDecoration = isVisible ? 'none' : 'line-through';
    }

    // Upper body (orange)
    const upperProgress = categories.upper_body?.progress;
    const upperHasData = categories.upper_body?.data?.some(d => d.strength !== null);
    formatProgress(upperEl, upperHasData ? upperProgress : null, 'text-orange-400', visibility.upper_body);

    // Lower body (purple)
    const lowerProgress = categories.lower_body?.progress;
    const lowerHasData = categories.lower_body?.data?.some(d => d.strength !== null);
    formatProgress(lowerEl, lowerHasData ? lowerProgress : null, 'text-purple-400', visibility.lower_body);

    // Cardio (green)
    const cardioProgress = categories.cardio?.progress;
    const cardioHasData = categories.cardio?.data?.some(d => d.strength !== null);
    formatProgress(cardioEl, cardioHasData ? cardioProgress : null, 'text-green-400', visibility.cardio);

    // Overall trend
    if (trendEl) {
        trendEl.textContent = trend === 'up' ? '↑ Gaining' : trend === 'down' ? '↓ Losing' : '→ Stable';
        trendEl.className = `text-sm font-bold ${trend === 'up' ? 'text-green-400' : trend === 'down' ? 'text-red-400' : 'text-blue-400'}`;
    }
}

// Track which categories are visible (for legend toggle)
window.strengthChartVisibility = {
    upper_body: true,
    lower_body: true,
    cardio: true
};

// Store legend hit areas for click detection
window.strengthChartLegendAreas = [];

// Store rendered point positions for hover detection
window.strengthChartPoints = [];

function renderStrengthChart(strengthData, hoveredPoint = null) {
    const canvas = document.getElementById('weight-chart');

    const hasCategories = strengthData?.categories && (
        strengthData.categories.upper_body?.data?.some(d => d.strength !== null) ||
        strengthData.categories.lower_body?.data?.some(d => d.strength !== null) ||
        strengthData.categories.cardio?.data?.some(d => d.strength !== null)
    );
    const hasLegacyData = strengthData?.data?.length > 0;

    if (!canvas || !strengthData || (!hasCategories && !hasLegacyData)) {
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

    const ctx = canvas.getContext('2d');
    const rect = canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 2;
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    ctx.scale(dpr, dpr);

    // Enable high-quality rendering
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';

    const width = rect.width;
    const height = rect.height;
    const padding = { top: 30, right: 14, bottom: 24, left: 40 };  // Slightly more padding for clarity
    const chartWidth = width - padding.left - padding.right;
    const chartHeight = height - padding.top - padding.bottom;

    ctx.clearRect(0, 0, width, height);

    // Category config with distinct line styles
    const categoryConfig = {
        upper_body: {
            color: '#F97316',
            label: 'Upper',
            fillAlpha: 0.15,
            lineWidth: 3,
            dashPattern: [],           // Solid line
            pointRadius: 5,
            pointStyle: 'circle'
        },
        lower_body: {
            color: '#8B5CF6',
            label: 'Lower',
            fillAlpha: 0.15,
            lineWidth: 3,
            dashPattern: [8, 4],       // Dashed line
            pointRadius: 5,
            pointStyle: 'diamond'
        },
        cardio: {
            color: '#22C55E',
            label: 'Cardio',
            fillAlpha: 0.15,
            lineWidth: 3,
            dashPattern: [3, 3],       // Dotted line
            pointRadius: 5,
            pointStyle: 'triangle'
        }
    };

    // Collect values only from visible categories for optimal scaling
    let allValues = [];
    let referenceData = null;
    const visibility = window.strengthChartVisibility;

    if (hasCategories) {
        ['upper_body', 'lower_body', 'cardio'].forEach(cat => {
            if (!visibility[cat]) return; // Skip hidden categories
            const catData = strengthData.categories[cat]?.data || [];
            catData.forEach(d => {
                if (d.strength !== null) allValues.push(d.strength);
            });
            if (!referenceData && catData.length > 0) referenceData = catData;
        });
        // Fallback reference data if all hidden
        if (!referenceData) {
            referenceData = strengthData.categories.upper_body?.data ||
                           strengthData.categories.lower_body?.data ||
                           strengthData.categories.cardio?.data || [];
        }
    } else {
        allValues = strengthData.data.map(d => d.strength).filter(s => s !== null);
        referenceData = strengthData.data;
    }

    // Smart Y-axis scaling: use nice round numbers
    function getNiceScale(min, max) {
        const range = max - min || 10;
        const magnitude = Math.pow(10, Math.floor(Math.log10(range)));
        const residual = range / magnitude;

        let niceStep;
        if (residual <= 1) niceStep = magnitude / 5;
        else if (residual <= 2) niceStep = magnitude / 2;
        else if (residual <= 5) niceStep = magnitude;
        else niceStep = magnitude * 2;

        const niceMin = Math.floor(min / niceStep) * niceStep;
        const niceMax = Math.ceil(max / niceStep) * niceStep;

        return { min: niceMin, max: niceMax, step: niceStep };
    }

    let minStrength, maxStrength, strengthRange, yAxisStep;

    // Include goal values in scaling so goal lines are always visible
    if (strengthData.goals) {
        if (strengthData.goals.upper !== null && strengthData.goals.upper !== undefined) allValues.push(strengthData.goals.upper);
        if (strengthData.goals.lower !== null && strengthData.goals.lower !== undefined) allValues.push(strengthData.goals.lower);
        if (strengthData.goals.cardio !== null && strengthData.goals.cardio !== undefined) allValues.push(strengthData.goals.cardio);
    }

    if (allValues.length === 0) {
        // Default scale when no visible data
        minStrength = -10;
        maxStrength = 50;
        yAxisStep = 15;
    } else {
        const dataMin = Math.min(...allValues);
        const dataMax = Math.max(...allValues);
        const dataRange = dataMax - dataMin || 10;
        // Add 15% padding for breathing room
        const dataPadding = dataRange * 0.15;
        const scale = getNiceScale(dataMin - dataPadding, dataMax + dataPadding);
        minStrength = scale.min;
        maxStrength = scale.max;
        yAxisStep = scale.step;
    }
    strengthRange = maxStrength - minStrength || 1;

    // Helper: hex to rgba
    function hexToRgba(hex, alpha) {
        const r = parseInt(hex.slice(1, 3), 16);
        const g = parseInt(hex.slice(3, 5), 16);
        const b = parseInt(hex.slice(5, 7), 16);
        return `rgba(${r}, ${g}, ${b}, ${alpha})`;
    }

    // Helper: draw different point styles
    function drawPoint(ctx, x, y, style, radius) {
        ctx.beginPath();
        switch (style) {
            case 'diamond':
                ctx.moveTo(x, y - radius);
                ctx.lineTo(x + radius, y);
                ctx.lineTo(x, y + radius);
                ctx.lineTo(x - radius, y);
                ctx.closePath();
                break;
            case 'triangle':
                ctx.moveTo(x, y - radius);
                ctx.lineTo(x + radius * 0.866, y + radius * 0.5);
                ctx.lineTo(x - radius * 0.866, y + radius * 0.5);
                ctx.closePath();
                break;
            case 'circle':
            default:
                ctx.arc(x, y, radius, 0, Math.PI * 2);
                break;
        }
        ctx.fill();
    }

    // Draw interactive legend at top
    window.strengthChartLegendAreas = [];
    if (hasCategories) {
        ctx.font = '600 11px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
        let legendX = padding.left;

        ['upper_body', 'lower_body', 'cardio'].forEach(cat => {
            const config = categoryConfig[cat];
            const catData = strengthData.categories[cat]?.data || [];
            const hasData = catData.some(d => d.strength !== null);
            if (!hasData) return;

            const isVisible = visibility[cat];
            const alpha = isVisible ? 1 : 0.35;

            // Draw colored dot
            ctx.fillStyle = hexToRgba(config.color, alpha);
            ctx.beginPath();
            ctx.arc(legendX + 5, 14, 4, 0, Math.PI * 2);
            ctx.fill();

            // Draw label
            ctx.fillStyle = `rgba(255,255,255,${isVisible ? 0.9 : 0.4})`;
            ctx.textAlign = 'left';
            const labelWidth = ctx.measureText(config.label).width;
            ctx.fillText(config.label, legendX + 14, 18);

            // Store hit area for click detection
            window.strengthChartLegendAreas.push({
                cat,
                x: legendX - 2,
                y: 2,
                width: 18 + labelWidth + 8,
                height: 24
            });

            legendX += 20 + labelWidth + 16;
        });
    }

    // Draw grid lines
    const numGridLines = Math.round(strengthRange / yAxisStep);
    ctx.strokeStyle = 'rgba(255,255,255,0.06)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= numGridLines; i++) {
        const value = minStrength + (yAxisStep * i);
        const y = padding.top + chartHeight - ((value - minStrength) / strengthRange * chartHeight);
        if (y >= padding.top && y <= padding.top + chartHeight) {
            ctx.beginPath();
            ctx.moveTo(padding.left, y);
            ctx.lineTo(width - padding.right, y);
            ctx.stroke();
        }
    }

    // Draw zero line prominently if in range
    if (minStrength <= 0 && maxStrength >= 0) {
        const zeroY = padding.top + chartHeight - ((0 - minStrength) / strengthRange * chartHeight);
        ctx.strokeStyle = 'rgba(255,255,255,0.25)';
        ctx.lineWidth = 1.5;
        ctx.setLineDash([4, 4]);
        ctx.beginPath();
        ctx.moveTo(padding.left, zeroY);
        ctx.lineTo(width - padding.right, zeroY);
        ctx.stroke();
        ctx.setLineDash([]);

        // "0%" label
        ctx.fillStyle = 'rgba(255,255,255,0.7)';
        ctx.font = '600 10px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
        ctx.textAlign = 'right';
        ctx.fillText('0%', padding.left - 6, zeroY + 4);
    }

    // Draw Y-axis labels
    ctx.fillStyle = 'rgba(255,255,255,0.55)';
    ctx.font = '500 10px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
    ctx.textAlign = 'right';
    for (let i = 0; i <= numGridLines; i++) {
        const value = minStrength + (yAxisStep * i);
        if (value === 0) continue; // Already drawn
        const y = padding.top + chartHeight - ((value - minStrength) / strengthRange * chartHeight);
        if (y >= padding.top - 5 && y <= padding.top + chartHeight + 5) {
            const prefix = value > 0 ? '+' : '';
            ctx.fillText(`${prefix}${value.toFixed(0)}%`, padding.left - 5, y + 3);
        }
    }

    // Draw goal lines if goals exist
    if (strengthData.goals) {
        const goalConfig = {
            upper: { color: '#F97316', label: 'Upper Goal', goal: strengthData.goals.upper },
            lower: { color: '#8B5CF6', label: 'Lower Goal', goal: strengthData.goals.lower },
            cardio: { color: '#22C55E', label: 'Cardio Goal', goal: strengthData.goals.cardio }
        };

        Object.entries(goalConfig).forEach(([key, config]) => {
            if (config.goal !== null && config.goal !== undefined) {
                const goalY = padding.top + chartHeight - ((config.goal - minStrength) / strengthRange * chartHeight);

                // Only draw if within visible range
                if (goalY >= padding.top && goalY <= padding.top + chartHeight) {
                    ctx.save();

                    // Draw dashed goal line
                    ctx.strokeStyle = config.color;
                    ctx.lineWidth = 2;
                    ctx.setLineDash([8, 4]);
                    ctx.globalAlpha = 0.5;
                    ctx.beginPath();
                    ctx.moveTo(padding.left, goalY);
                    ctx.lineTo(width - padding.right, goalY);
                    ctx.stroke();

                    // Draw goal label INSIDE chart at right end
                    ctx.setLineDash([]);
                    ctx.globalAlpha = 1;

                    const labelText = `${config.goal}%`;
                    ctx.font = '700 10px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
                    const textWidth = ctx.measureText(labelText).width;

                    // Background pill at right end of line, inside chart
                    const pillPadding = 4;
                    const pillWidth = textWidth + pillPadding * 2;
                    const pillHeight = 12;
                    const pillX = width - padding.right - pillWidth - 4;
                    const pillY = goalY - pillHeight / 2;
                    const pillRadius = 3;

                    ctx.fillStyle = hexToRgba(config.color, 0.9);
                    ctx.beginPath();
                    ctx.moveTo(pillX + pillRadius, pillY);
                    ctx.lineTo(pillX + pillWidth - pillRadius, pillY);
                    ctx.quadraticCurveTo(pillX + pillWidth, pillY, pillX + pillWidth, pillY + pillRadius);
                    ctx.lineTo(pillX + pillWidth, pillY + pillHeight - pillRadius);
                    ctx.quadraticCurveTo(pillX + pillWidth, pillY + pillHeight, pillX + pillWidth - pillRadius, pillY + pillHeight);
                    ctx.lineTo(pillX + pillRadius, pillY + pillHeight);
                    ctx.quadraticCurveTo(pillX, pillY + pillHeight, pillX, pillY + pillHeight - pillRadius);
                    ctx.lineTo(pillX, pillY + pillRadius);
                    ctx.quadraticCurveTo(pillX, pillY, pillX + pillRadius, pillY);
                    ctx.closePath();
                    ctx.fill();

                    // White text on colored pill
                    ctx.fillStyle = '#fff';
                    ctx.textAlign = 'center';
                    ctx.fillText(labelText, pillX + pillWidth / 2, goalY + 3);

                    ctx.restore();
                }
            }
        });
    }

    // Helper: smooth bezier curve through points (Catmull-Rom spline)
    function drawSmoothLine(ctx, points, tension = 0.3) {
        if (points.length < 2) return;

        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);

        if (points.length === 2) {
            ctx.lineTo(points[1].x, points[1].y);
            return;
        }

        for (let i = 0; i < points.length - 1; i++) {
            const p0 = points[Math.max(0, i - 1)];
            const p1 = points[i];
            const p2 = points[i + 1];
            const p3 = points[Math.min(points.length - 1, i + 2)];

            // Calculate control points
            const cp1x = p1.x + (p2.x - p0.x) * tension;
            const cp1y = p1.y + (p2.y - p0.y) * tension;
            const cp2x = p2.x - (p3.x - p1.x) * tension;
            const cp2y = p2.y - (p3.y - p1.y) * tension;

            ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
        }
    }

    // Helper: draw category line with all styling
    function drawCategoryLine(data, config, catKey) {
        if (!data || data.length === 0 || !visibility[catKey]) return;

        const dataLen = data.length;
        const points = [];

        // Build points array
        data.forEach((d, i) => {
            if (d.strength !== null) {
                points.push({
                    x: padding.left + (chartWidth * i / (dataLen - 1 || 1)),
                    y: padding.top + chartHeight - ((d.strength - minStrength) / strengthRange * chartHeight),
                    strength: d.strength,
                    label: d.label
                });
            }
        });

        if (points.length === 0) return;

        // Draw gradient fill with smooth curve
        if (points.length > 1) {
            const gradient = ctx.createLinearGradient(0, padding.top, 0, height - padding.bottom);
            gradient.addColorStop(0, hexToRgba(config.color, config.fillAlpha));
            gradient.addColorStop(0.7, hexToRgba(config.color, config.fillAlpha * 0.3));
            gradient.addColorStop(1, hexToRgba(config.color, 0));

            ctx.beginPath();
            ctx.moveTo(points[0].x, height - padding.bottom);

            // Use smooth curve for fill
            ctx.lineTo(points[0].x, points[0].y);
            for (let i = 0; i < points.length - 1; i++) {
                const p0 = points[Math.max(0, i - 1)];
                const p1 = points[i];
                const p2 = points[i + 1];
                const p3 = points[Math.min(points.length - 1, i + 2)];

                const tension = 0.25;
                const cp1x = p1.x + (p2.x - p0.x) * tension;
                const cp1y = p1.y + (p2.y - p0.y) * tension;
                const cp2x = p2.x - (p3.x - p1.x) * tension;
                const cp2y = p2.y - (p3.y - p1.y) * tension;

                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
            }

            ctx.lineTo(points[points.length - 1].x, height - padding.bottom);
            ctx.closePath();
            ctx.fillStyle = gradient;
            ctx.fill();
        }

        // Draw line with category-specific style
        ctx.setLineDash(config.dashPattern);
        ctx.strokeStyle = config.color;
        ctx.lineWidth = config.lineWidth;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';

        drawSmoothLine(ctx, points, 0.25);
        ctx.stroke();
        ctx.setLineDash([]);

        // Draw points with glow effect
        points.forEach((p, idx) => {
            // Check if this point is being hovered
            const isHovered = hoveredPoint &&
                Math.abs(p.x - hoveredPoint.x) < 1 &&
                Math.abs(p.y - hoveredPoint.y) < 1;

            const radius = isHovered ? config.pointRadius * 2.5 : config.pointRadius;
            const glowSize = isHovered ? 15 : 6;

            // Glow (bigger for hovered)
            ctx.shadowColor = config.color;
            ctx.shadowBlur = glowSize;
            ctx.fillStyle = config.color;
            drawPoint(ctx, p.x, p.y, config.pointStyle, radius);

            // White center for last point or hovered point
            if (idx === points.length - 1 || isHovered) {
                ctx.shadowBlur = 0;
                ctx.fillStyle = '#fff';
                drawPoint(ctx, p.x, p.y, config.pointStyle, radius * 0.5);
            }
            ctx.shadowBlur = 0;

            // Draw zoom ring around hovered point
            if (isHovered) {
                ctx.strokeStyle = config.color;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(p.x, p.y, radius + 4, 0, Math.PI * 2);
                ctx.stroke();

                // Outer glow ring
                ctx.strokeStyle = `${config.color}40`;
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(p.x, p.y, radius + 8, 0, Math.PI * 2);
                ctx.stroke();
            }
        });

        // Return points for hover detection (with date info)
        return points.map(p => ({ ...p, date: p.label }));
    }

    // Clear stored points for hover detection
    window.strengthChartPoints = [];

    // Draw category lines and store points
    if (hasCategories) {
        // Draw in order: cardio (back), lower (mid), upper (front)
        ['cardio', 'lower_body', 'upper_body'].forEach(cat => {
            const config = categoryConfig[cat];
            const catData = strengthData.categories[cat]?.data || [];
            const drawnPoints = drawCategoryLine(catData, config, cat);
            if (drawnPoints) {
                drawnPoints.forEach(p => {
                    window.strengthChartPoints.push({
                        ...p,
                        category: cat,
                        color: config.color,
                        label: config.label
                    });
                });
            }
        });
    } else {
        const drawnPoints = drawCategoryLine(strengthData.data, categoryConfig.cardio, 'cardio');
        if (drawnPoints) {
            drawnPoints.forEach(p => {
                window.strengthChartPoints.push({
                    ...p,
                    category: 'cardio',
                    color: categoryConfig.cardio.color,
                    label: 'Strength'
                });
            });
        }
    }

    // Draw X-axis labels
    if (referenceData && referenceData.length > 0) {
        ctx.fillStyle = 'rgba(255,255,255,0.5)';
        ctx.font = '500 10px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
        ctx.textAlign = 'center';
        const labelStep = Math.max(1, Math.ceil(referenceData.length / 6));
        referenceData.forEach((d, i) => {
            if (i % labelStep === 0 || i === referenceData.length - 1) {
                const x = padding.left + (chartWidth * i / (referenceData.length - 1 || 1));
                ctx.fillText(d.label, x, height - 6);
            }
        });
    }
}

// Create tooltip element for chart hover
function getOrCreateChartTooltip() {
    let tooltip = document.getElementById('strength-chart-tooltip');
    if (!tooltip) {
        tooltip = document.createElement('div');
        tooltip.id = 'strength-chart-tooltip';
        tooltip.style.cssText = `
            position: fixed;
            pointer-events: none;
            background: rgba(20, 20, 25, 0.95);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.15);
            border-radius: 12px;
            padding: 10px 14px;
            font-size: 12px;
            color: white;
            z-index: 9999;
            opacity: 0;
            transform: translateY(5px) scale(0.95);
            transition: opacity 0.15s, transform 0.15s;
            box-shadow: 0 8px 32px rgba(0,0,0,0.4);
            min-width: 100px;
        `;
        document.body.appendChild(tooltip);
    }
    return tooltip;
}

// Add click and hover handlers for chart
document.addEventListener('DOMContentLoaded', function() {
    const canvas = document.getElementById('weight-chart');
    if (canvas) {
        const tooltip = getOrCreateChartTooltip();
        let hoveredPoint = null;

        canvas.addEventListener('click', function(e) {
            const rect = canvas.getBoundingClientRect();
            // Coordinates are in CSS pixels (ctx.scale handles the DPI scaling)
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;

            // Check if click is in any legend area
            for (const area of window.strengthChartLegendAreas || []) {
                if (x >= area.x && x <= area.x + area.width &&
                    y >= area.y && y <= area.y + area.height) {
                    window.strengthChartVisibility[area.cat] = !window.strengthChartVisibility[area.cat];
                    if (typeof cachedStrengthData !== 'undefined' && cachedStrengthData) {
                        renderStrengthChart(cachedStrengthData);
                        updateStrengthStats(cachedStrengthData);
                    }
                    break;
                }
            }
        });

        canvas.addEventListener('mousemove', function(e) {
            const rect = canvas.getBoundingClientRect();
            // Coordinates are in CSS pixels (ctx.scale handles the DPI scaling)
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;

            // Check legend hover
            let overLegend = false;
            for (const area of window.strengthChartLegendAreas || []) {
                if (x >= area.x && x <= area.x + area.width &&
                    y >= area.y && y <= area.y + area.height) {
                    overLegend = true;
                    break;
                }
            }

            // Check point hover (with 12px hit radius)
            let closestPoint = null;
            let closestDist = 12;
            for (const point of window.strengthChartPoints || []) {
                const dist = Math.sqrt(Math.pow(x - point.x, 2) + Math.pow(y - point.y, 2));
                if (dist < closestDist) {
                    closestDist = dist;
                    closestPoint = point;
                }
            }

            // Update cursor
            canvas.style.cursor = (overLegend || closestPoint) ? 'pointer' : 'default';

            // Show/hide tooltip
            if (closestPoint && closestPoint !== hoveredPoint) {
                hoveredPoint = closestPoint;
                const prefix = closestPoint.strength > 0 ? '+' : '';
                tooltip.innerHTML = `
                    <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 6px;">
                        <div style="width: 10px; height: 10px; border-radius: 50%; background: ${closestPoint.color};"></div>
                        <span style="font-weight: 600; color: ${closestPoint.color};">${closestPoint.label}</span>
                    </div>
                    <div style="font-size: 18px; font-weight: 700; margin-bottom: 2px;">${prefix}${closestPoint.strength.toFixed(1)}%</div>
                    <div style="font-size: 10px; color: rgba(255,255,255,0.5);">${closestPoint.date || ''}</div>
                `;

                // Position tooltip near cursor but keep on screen
                let tooltipX = e.clientX + 15;
                let tooltipY = e.clientY - 50;
                const tooltipRect = tooltip.getBoundingClientRect();
                if (tooltipX + 120 > window.innerWidth) tooltipX = e.clientX - 130;
                if (tooltipY < 10) tooltipY = e.clientY + 20;

                tooltip.style.left = tooltipX + 'px';
                tooltip.style.top = tooltipY + 'px';
                tooltip.style.opacity = '1';
                tooltip.style.transform = 'translateY(0) scale(1)';

                // Redraw chart with highlighted point
                if (typeof cachedStrengthData !== 'undefined' && cachedStrengthData) {
                    renderStrengthChart(cachedStrengthData, closestPoint);
                }
            } else if (!closestPoint && hoveredPoint) {
                hoveredPoint = null;
                tooltip.style.opacity = '0';
                tooltip.style.transform = 'translateY(5px) scale(0.95)';
                // Redraw without highlight
                if (typeof cachedStrengthData !== 'undefined' && cachedStrengthData) {
                    renderStrengthChart(cachedStrengthData, null);
                }
            }
        });

        canvas.addEventListener('mouseleave', function() {
            hoveredPoint = null;
            tooltip.style.opacity = '0';
            tooltip.style.transform = 'translateY(5px) scale(0.95)';
            if (typeof cachedStrengthData !== 'undefined' && cachedStrengthData) {
                renderStrengthChart(cachedStrengthData, null);
            }
        });
    }
});

// ==============================================
// Strength Details Modal
// ==============================================
let currentStrengthCategory = 'upper_body';
let strengthDetailsCache = {};

function openStrengthDetailsModal() {
    const modal = document.getElementById('strength-details-modal');
    if (modal) {
        modal.classList.remove('hidden');
        document.body.style.overflow = 'hidden';
        loadStrengthDetails('upper_body');
    }
}

function closeStrengthDetailsModal() {
    const modal = document.getElementById('strength-details-modal');
    if (modal) {
        modal.classList.add('hidden');
        document.body.style.overflow = '';
    }
}

function switchStrengthTab(category) {
    currentStrengthCategory = category;

    // Update tab styles
    const tabs = {
        upper_body: { el: document.getElementById('strength-tab-upper'), color: 'orange' },
        lower_body: { el: document.getElementById('strength-tab-lower'), color: 'purple' },
        cardio: { el: document.getElementById('strength-tab-cardio'), color: 'green' }
    };

    Object.entries(tabs).forEach(([cat, config]) => {
        if (config.el) {
            if (cat === category) {
                config.el.className = `flex-1 py-3 text-sm font-semibold text-center border-b-2 border-${config.color}-500 text-${config.color}-400 transition`;
            } else {
                config.el.className = 'flex-1 py-3 text-sm font-semibold text-center border-b-2 border-transparent text-gray-400 hover:text-white transition';
            }
        }
    });

    loadStrengthDetails(category);
}

function updateStrengthGoalSection(category, data) {
    const goalSection = document.getElementById('strength-goal-section');
    if (!goalSection) return;

    // Get goal from cached strength data
    const goals = cachedStrengthData?.goals || {};
    const goalMap = {
        upper_body: goals.upper,
        lower_body: goals.lower,
        cardio: goals.cardio
    };
    const goal = goalMap[category];

    // Get current progress (average across exercises in this category)
    let currentProgress = 0;
    if (data?.exercises?.length > 0) {
        const progressValues = data.exercises.map(ex => ex.progress_pct || 0);
        currentProgress = Math.round(progressValues.reduce((a, b) => a + b, 0) / progressValues.length);
    }

    // Category colors
    const categoryColors = {
        upper_body: {
            icon: 'bg-orange-500/20',
            iconText: 'text-orange-400',
            progress: 'text-orange-400',
            bar: 'from-orange-500 to-orange-400'
        },
        lower_body: {
            icon: 'bg-purple-500/20',
            iconText: 'text-purple-400',
            progress: 'text-purple-400',
            bar: 'from-purple-500 to-purple-400'
        },
        cardio: {
            icon: 'bg-green-500/20',
            iconText: 'text-green-400',
            progress: 'text-green-400',
            bar: 'from-green-500 to-green-400'
        }
    };
    const colors = categoryColors[category] || categoryColors.upper_body;

    // If no goal is set, hide the section
    if (goal === null || goal === undefined) {
        goalSection.classList.add('hidden');
        return;
    }

    // Show the section
    goalSection.classList.remove('hidden');

    // Update colors
    const iconEl = document.getElementById('strength-goal-icon');
    const currentEl = document.getElementById('strength-goal-current');
    const barEl = document.getElementById('strength-goal-bar');

    if (iconEl) {
        iconEl.className = `w-8 h-8 rounded-lg ${colors.icon} flex items-center justify-center`;
        const svg = iconEl.querySelector('svg');
        if (svg) svg.className = `w-4 h-4 ${colors.iconText}`;
    }
    if (currentEl) {
        currentEl.className = `text-lg font-bold ${colors.progress}`;
    }
    if (barEl) {
        barEl.className = `absolute inset-y-0 left-0 bg-gradient-to-r ${colors.bar} rounded-full transition-all duration-500`;
    }

    // Update values
    const targetEl = document.getElementById('strength-goal-target');
    const statusEl = document.getElementById('strength-goal-status');

    if (targetEl) targetEl.textContent = `+${goal}%`;
    if (currentEl) {
        const prefix = currentProgress >= 0 ? '+' : '';
        currentEl.textContent = `${prefix}${currentProgress}%`;
    }

    // Calculate progress percentage (capped at 100% for display)
    let progressPct = goal > 0 ? Math.round((currentProgress / goal) * 100) : 0;
    const cappedProgressPct = Math.min(progressPct, 100);
    if (barEl) barEl.style.width = `${cappedProgressPct}%`;

    // Update status text
    if (statusEl) {
        if (progressPct >= 100) {
            statusEl.textContent = 'Goal achieved!';
            statusEl.className = 'text-xs text-green-400 mt-2 text-center font-semibold';
        } else if (progressPct >= 80) {
            statusEl.textContent = `${progressPct}% of goal - Almost there!`;
            statusEl.className = 'text-xs text-yellow-400 mt-2 text-center';
        } else {
            statusEl.textContent = `${progressPct}% of goal reached`;
            statusEl.className = 'text-xs text-gray-500 mt-2 text-center';
        }
    }
}

async function loadStrengthDetails(category) {
    const listEl = document.getElementById('strength-details-list');
    const loadingEl = document.getElementById('strength-details-loading');
    const emptyEl = document.getElementById('strength-details-empty');

    if (!listEl) return;

    // Show loading
    listEl.innerHTML = '';
    loadingEl?.classList.remove('hidden');
    emptyEl?.classList.add('hidden');

    try {
        const url = `/api/client/exercise-details?category=${category}&period=${currentWeightPeriod || 'month'}`;
        console.log('[StrengthDetails] Fetching:', url);

        const response = await fetch(url, {
            headers: { 'Authorization': `Bearer ${localStorage.getItem('token') || ''}` },
            credentials: 'include'
        });

        console.log('[StrengthDetails] Response status:', response.status);

        if (!response.ok) throw new Error('Failed to load');

        const data = await response.json();
        console.log('[StrengthDetails] Data received:', data);
        strengthDetailsCache[category] = data;

        loadingEl?.classList.add('hidden');

        // Update goal section
        updateStrengthGoalSection(category, data);

        if (!data.exercises || data.exercises.length === 0) {
            emptyEl?.classList.remove('hidden');
            return;
        }

        // Get category color
        const colors = {
            upper_body: { main: '#F97316', bg: 'bg-orange-500/20', text: 'text-orange-400' },
            lower_body: { main: '#8B5CF6', bg: 'bg-purple-500/20', text: 'text-purple-400' },
            cardio: { main: '#22C55E', bg: 'bg-green-500/20', text: 'text-green-400' }
        };
        const color = colors[category] || colors.upper_body;

        // Render exercises
        listEl.innerHTML = data.exercises.map(ex => {
            const progressPrefix = ex.progress_pct > 0 ? '+' : '';
            const progressColor = ex.progress_pct > 0 ? 'text-green-400' : ex.progress_pct < 0 ? 'text-red-400' : 'text-gray-400';

            // Create mini chart data
            const chartId = `mini-chart-${ex.name.replace(/\s+/g, '-').toLowerCase()}`;

            // History items (last 5)
            const recentHistory = ex.history.slice(-5).reverse();
            const historyHtml = recentHistory.map(h => `
                <div class="flex justify-between items-center py-1.5 border-b border-white/5 last:border-0">
                    <span class="text-xs text-gray-400">${h.label}</span>
                    <span class="text-xs font-medium text-white">${h.display}</span>
                </div>
            `).join('');

            return `
                <div class="bg-white/5 rounded-xl p-4 border border-white/5">
                    <!-- Header -->
                    <div class="flex justify-between items-start mb-3">
                        <div class="flex-1">
                            <h4 class="font-semibold text-white text-sm">${ex.name}</h4>
                            <p class="text-xs text-gray-500 mt-0.5">${ex.history.length} sessions logged</p>
                        </div>
                        <div class="text-right">
                            <p class="text-lg font-bold ${progressColor}">${progressPrefix}${ex.progress_pct}%</p>
                            <p class="text-[10px] text-gray-500">progress</p>
                        </div>
                    </div>

                    <!-- Current / Best Stats -->
                    <div class="grid grid-cols-2 gap-3 mb-3">
                        <div class="${color.bg} rounded-lg p-2.5">
                            <p class="text-[10px] text-gray-400 uppercase tracking-wider mb-0.5">Current</p>
                            <p class="text-sm font-bold ${color.text}">${ex.current?.display || '--'}</p>
                        </div>
                        <div class="bg-yellow-500/10 rounded-lg p-2.5">
                            <p class="text-[10px] text-gray-400 uppercase tracking-wider mb-0.5">Best</p>
                            <p class="text-sm font-bold text-yellow-400">${ex.best?.display || '--'}</p>
                        </div>
                    </div>

                    <!-- Mini Sparkline Chart -->
                    <div class="mb-3">
                        <canvas id="${chartId}" class="w-full h-12 rounded-lg bg-white/5"></canvas>
                    </div>

                    <!-- Recent History -->
                    <details class="group">
                        <summary class="text-xs text-gray-400 cursor-pointer hover:text-white transition flex items-center gap-1">
                            <svg class="w-3 h-3 transition-transform group-open:rotate-90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                            </svg>
                            Recent History
                        </summary>
                        <div class="mt-2 pl-4">
                            ${historyHtml}
                        </div>
                    </details>
                </div>
            `;
        }).join('');

        // Render mini charts after DOM update
        setTimeout(() => {
            data.exercises.forEach(ex => {
                const chartId = `mini-chart-${ex.name.replace(/\s+/g, '-').toLowerCase()}`;
                renderMiniSparkline(chartId, ex.history, category);
            });
        }, 50);

    } catch (error) {
        console.error('Error loading strength details:', error);
        loadingEl?.classList.add('hidden');
        emptyEl?.classList.remove('hidden');
    }
}

function renderMiniSparkline(canvasId, history, category) {
    const canvas = document.getElementById(canvasId);
    if (!canvas || !history || history.length === 0) return;

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

    // Get values based on category
    const values = history.map(h => {
        if (category === 'cardio') {
            return (h.duration || 0) + (h.distance || 0) * 5;
        }
        return h.weight || 0;
    });

    if (values.length === 0 || values.every(v => v === 0)) return;

    const minVal = Math.min(...values) * 0.9;
    const maxVal = Math.max(...values) * 1.1;
    const range = maxVal - minVal || 1;

    // Color based on category
    const colors = {
        upper_body: '#F97316',
        lower_body: '#8B5CF6',
        cardio: '#22C55E'
    };
    const color = colors[category] || colors.upper_body;

    // Build points
    const points = values.map((v, i) => ({
        x: padding.left + (chartWidth * i / (values.length - 1 || 1)),
        y: padding.top + chartHeight - ((v - minVal) / range * chartHeight)
    }));

    // Draw gradient fill
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, color + '30');
    gradient.addColorStop(1, color + '00');

    ctx.beginPath();
    ctx.moveTo(points[0].x, height);
    points.forEach(p => ctx.lineTo(p.x, p.y));
    ctx.lineTo(points[points.length - 1].x, height);
    ctx.closePath();
    ctx.fillStyle = gradient;
    ctx.fill();

    // Draw line
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    points.forEach(p => ctx.lineTo(p.x, p.y));
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.stroke();

    // Draw last point
    const lastPoint = points[points.length - 1];
    ctx.beginPath();
    ctx.arc(lastPoint.x, lastPoint.y, 3, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
    ctx.beginPath();
    ctx.arc(lastPoint.x, lastPoint.y, 1.5, 0, Math.PI * 2);
    ctx.fillStyle = '#fff';
    ctx.fill();
}

// Make functions globally available
window.openStrengthDetailsModal = openStrengthDetailsModal;
window.closeStrengthDetailsModal = closeStrengthDetailsModal;
window.switchStrengthTab = switchStrengthTab;

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

function renderWeightChart(data, allStats, metric = currentBodyMetric) {
    const canvas = document.getElementById('weight-chart');
    if (!canvas || !data || data.length === 0) return;

    const config = bodyMetricConfig[metric] || bodyMetricConfig.weight;
    const stats = allStats[metric] || allStats.weight || allStats;

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

    // Get values for the current metric (filter out nulls)
    const values = data.map(d => d[metric]).filter(v => v != null);
    if (values.length === 0) {
        // No data for this metric
        ctx.fillStyle = 'rgba(255,255,255,0.3)';
        ctx.font = '12px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText(`No ${config.label.toLowerCase()} data yet`, width / 2, height / 2);
        return;
    }

    const minValue = Math.min(...values) - (metric === 'body_fat_pct' ? 1 : 1);
    const maxValue = Math.max(...values) + (metric === 'body_fat_pct' ? 1 : 1);
    const valueRange = maxValue - minValue || 1;

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

    // Draw Y-axis labels
    ctx.fillStyle = config.color + 'B3';
    ctx.font = '9px system-ui';
    ctx.textAlign = 'right';
    for (let i = 0; i <= 4; i++) {
        const value = maxValue - (valueRange * i / 4);
        const y = padding.top + (chartHeight * i / 4);
        ctx.fillText(value.toFixed(1), padding.left - 5, y + 3);
    }

    // Build points array, skipping null values
    const validData = data.filter(d => d[metric] != null);
    const points = validData.map((d, i) => ({
        x: padding.left + (chartWidth * i / (validData.length - 1 || 1)),
        y: padding.top + chartHeight - ((d[metric] - minValue) / valueRange * chartHeight),
        label: d.label,
        value: d[metric]
    }));

    // Draw gradient fill
    const gradient = ctx.createLinearGradient(0, padding.top, 0, height - padding.bottom);
    gradient.addColorStop(0, config.color + '4D');
    gradient.addColorStop(1, config.color + '00');

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
    ctx.strokeStyle = config.color;
    ctx.lineWidth = 2;
    ctx.stroke();

    // Draw points
    points.forEach(p => {
        ctx.beginPath();
        ctx.arc(p.x, p.y, 3, 0, Math.PI * 2);
        ctx.fillStyle = config.color;
        ctx.fill();
    });

    // Draw X-axis labels (only a few)
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    ctx.font = '8px system-ui';
    ctx.textAlign = 'center';
    const labelStep = Math.ceil(validData.length / 5);
    validData.forEach((d, i) => {
        if (i % labelStep === 0 || i === validData.length - 1) {
            const x = padding.left + (chartWidth * i / (validData.length - 1 || 1));
            ctx.fillText(d.label, x, height - 5);
        }
    });

    // Update stats display
    const startEl = document.getElementById('weight-stat-start');
    const minEl = document.getElementById('weight-stat-min');
    const maxEl = document.getElementById('weight-stat-max');
    const changeEl = document.getElementById('weight-stat-change');
    const unit = config.unit;

    if (startEl) startEl.textContent = stats.start != null ? `${stats.start} ${unit}` : '--';
    if (minEl) minEl.textContent = stats.min != null ? `${stats.min} ${unit}` : '--';
    if (maxEl) maxEl.textContent = stats.max != null ? `${stats.max} ${unit}` : '--';

    if (changeEl && stats.change != null) {
        const sign = stats.change > 0 ? '+' : '';
        changeEl.textContent = `${sign}${stats.change} ${unit}`;
        // For body fat and weight, decrease is good. For lean mass, increase is good.
        const isGood = config.goodDirection === 'down' ? stats.change < 0 : stats.change > 0;
        const isBad = config.goodDirection === 'down' ? stats.change > 0 : stats.change < 0;
        changeEl.className = `text-sm font-bold ${isGood ? 'text-green-400' : isBad ? 'text-red-400' : 'text-gray-400'}`;
    }

    // Update current value display
    const clientWeight = document.getElementById('client-weight');
    if (clientWeight && stats.current != null) {
        clientWeight.textContent = stats.current;
    }

    // Update trend badge
    updateBodyMetricBadge(stats, config);
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
                    showToast('Progress photo saved!', 'success');
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
        showToast("Name and Email are required!", "error");
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

        showToast("Profile updated successfully!", "success");

        // Clear password field
        document.getElementById('profile-password').value = '';

    } catch (e) {
        console.error(e);
        showToast("Error updating profile", "error");
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
        showToast('Video uploaded successfully!', 'success');
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
        credentials: 'include',
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

        const muscleIcons = MUSCLE_ICONS;

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

            const exIcon = icon(muscleIcons[ex.muscle] || 'dumbbell', 20);
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
                    <span class="text-8xl">${exIcon}</span>
                </div>
                <div class="relative z-10 w-full h-full flex flex-col justify-between pointer-events-none">
                    <div class="flex justify-between items-start mb-2 pointer-events-auto pl-1">
                        <span class="text-[10px] font-bold px-2 py-1 rounded-full ${badgeClass} uppercase tracking-wider">${ex.type}</span>
                        <button class="edit-btn w-8 h-8 flex items-center justify-center bg-white/10 rounded-full text-gray-300 hover:bg-white/20 hover:text-white transition tap-effect">
                            ${icon('settings', 14)}
                        </button>
                    </div>
                    <div>
                        <h4 class="font-bold text-lg text-white mb-1 leading-tight drop-shadow-md">${ex.name}</h4>
                        <div class="flex items-center text-xs text-gray-400 mt-1">
                            <span class="mr-2">${exIcon}</span>
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
            showToast("Diet plan assigned successfully!", "success");
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
                            showToast('Video uploaded!', 'success');

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
                            showToast('Upload failed', 'error');
                        }
                    } catch (err) {
                        console.error(err);
                        filenameDisplay.innerText = `Upload error`;
                        showToast('Upload error', 'error');
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
        showToast('Please enter an exercise name', 'error');
        return;
    }

    const trainerId = getCurrentTrainerId();
    const payload = { name, muscle, type, video_id: video };

    try {
        const res = await fetch(`${apiBase}/api/trainer/exercises/${id}`, {
            method: 'PUT',
            credentials: 'include',
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast('Exercise updated!', 'success');
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
            showToast('Failed to update exercise', 'error');
        }
    } catch (e) {
        console.error(e);
        showToast('Error updating exercise', 'error');
    }
}

window.createExercise = async function () {
    const name = document.getElementById('new-ex-name').value;
    const muscle = document.getElementById('new-ex-muscle').value;
    const type = document.getElementById('new-ex-type').value;
    const video = document.getElementById('new-ex-video').value;

    if (!name) {
        showToast('Please enter an exercise name', 'error');
        return;
    }

    const trainerId = getCurrentTrainerId();
    const payload = { name, muscle, type, video_id: video };

    try {
        const res = await fetch(`${apiBase}/api/trainer/exercises`, {
            method: 'POST',
            credentials: 'include',
            headers: {
                'Content-Type': 'application/json',
                'x-trainer-id': trainerId
            },
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast('Exercise created!', 'success');
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
            showToast('Failed to create exercise', 'error');
        }
    } catch (e) {
        console.error(e);
        showToast('Error creating exercise', 'error');
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
                <span class="text-2xl group-hover:scale-110 transition-transform">${icon('dumbbell', 24)}</span>
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
                <button class="delete-workout-btn text-xs bg-red-500/20 hover:bg-red-500/40 px-2 py-1 rounded text-red-400 transition">${icon('trash-2', 14)}</button>
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
            showToast(id ? 'Workout updated!' : 'Workout created!', 'success');
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
        showToast('Error saving workout', 'error');
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
        credentials: 'include',
        body: JSON.stringify({ client_id: clientId, date: date, workout_id: workoutId })
    });

    if (res.ok) {
        showToast('Workout assigned successfully!', 'success');
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
    // Check if we're in CO-OP partner mode
    const isCoopPartnerMode = window.coopState?.isCoopMode && window.coopState?.activeTab === 'partner';

    if (isCoopPartnerMode) {
        window.coopState.partnerCurrentReps = Math.max(0, parseInt(window.coopState.partnerCurrentReps || 10) + delta);
        document.getElementById('rep-counter').innerText = window.coopState.partnerCurrentReps;
    } else {
        if (!workoutState) return;
        workoutState.currentReps = Math.max(0, parseInt(workoutState.currentReps) + delta);
        document.getElementById('rep-counter').innerText = workoutState.currentReps;
    }
}

// Helper to detect if an exercise is cardio (uses duration/distance instead of reps/weight)
window.isCardioExercise = function(exerciseName) {
    if (!exerciseName) return false;
    const name = exerciseName.toLowerCase();

    // Cardio keywords
    const cardioKeywords = [
        'run', 'running', 'sprint', 'jog', 'jogging',
        'bike', 'cycling', 'cycle',
        'hiit', 'cardio',
        'treadmill', 'elliptical', 'stairmaster', 'stepper',
        'rowing', 'rower',
        'jump rope', 'jumping',
        'swimming', 'swim',
        'walk', 'walking'
    ];

    return cardioKeywords.some(kw => name.includes(kw));
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

        // Check for CO-OP partner
        const coopPartnerStr = localStorage.getItem('coopPartner');
        const coopPartner = coopPartnerStr ? JSON.parse(coopPartnerStr) : null;
        const isCoopWorkout = coopPartner && new URLSearchParams(window.location.search).get('coop') === 'true';

        // Use different endpoint for trainers vs clients vs co-op
        let endpoint;
        let requestBody;

        if (APP_CONFIG.role === 'trainer') {
            endpoint = `${apiBase}/api/trainer/schedule/complete`;
            requestBody = {
                date: todayStr,
                exercises: workoutState.exercises
            };
        } else if (isCoopWorkout) {
            endpoint = `${apiBase}/api/client/schedule/complete-coop`;
            requestBody = {
                date: todayStr,
                partner_id: coopPartner.id,
                exercises: workoutState.exercises,
                partner_exercises: window.coopState?.partnerExercises || workoutState.exercises
            };
        } else {
            endpoint = `${apiBase}/api/client/schedule/complete`;
            requestBody = {
                date: todayStr,
                exercises: workoutState.exercises
            };
        }

        const res = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify(requestBody)
        });

        if (res.ok) {
            const result = await res.json();
            console.log("Workout marked as complete on server", result);

            // Clear Cache to prevent stale data on reload
            localStorage.removeItem(getCacheKey());

            // Clear CO-OP partner data
            if (isCoopWorkout) {
                localStorage.removeItem('coopPartner');
                console.log(`CO-OP workout completed with ${coopPartner.name}!`);
            }

            // Show Success UI ONLY after server confirms
            document.getElementById('celebration-overlay').classList.remove('hidden');
            startConfetti();

            // Update celebration message and gems for CO-OP
            const gemsAmountEl = document.getElementById('celebration-gems-amount');
            if (isCoopWorkout && coopPartner) {
                const celebrationTitle = document.querySelector('#celebration-overlay h1');
                const celebrationMsg = document.querySelector('#celebration-overlay p');
                if (celebrationTitle) celebrationTitle.textContent = 'CO-OP Complete!';
                if (celebrationMsg) celebrationMsg.textContent = `Great teamwork with ${coopPartner.name}!`;
                // Show CO-OP bonus gems (50 base + 25 bonus = 75)
                if (gemsAmountEl) gemsAmountEl.innerHTML = '+75 <span class="text-lg">gems</span> <span class="text-xs text-purple-400">(+25 CO-OP bonus!)</span>';
            } else {
                // Regular workout gems
                if (gemsAmountEl) gemsAmountEl.innerHTML = '+50 <span class="text-lg">gems</span>';
            }

            // Update UI to show completed state
            const startBtn = document.getElementById('workout-main-btn') || document.querySelector('a[href*="mode=workout"]');
            const coopBadgeBtn = document.getElementById('coop-badge-btn');
            const coopCompletedBadge = document.getElementById('coop-completed-badge');

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

            // Hide CO-OP start button when completed
            if (coopBadgeBtn) {
                coopBadgeBtn.classList.add('hidden');
            }

            // Show CO-OP completed badge if this was a CO-OP workout
            if (isCoopWorkout && coopCompletedBadge) {
                coopCompletedBadge.classList.remove('hidden');
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

                        // Update next goal for day streak
                        const dayMilestones = [3, 7, 14, 21, 30, 60, 90, 180, 365];
                        const nextMilestone = dayMilestones.find(m => m > clientData.streak) || (clientData.streak + 30);
                        const nextGoalEl = document.getElementById('client-next-goal');
                        if (nextGoalEl) {
                            nextGoalEl.innerText = `${nextMilestone} Days`;
                        }
                        const legacyNextGoalEl = document.getElementById('next-goal');
                        if (legacyNextGoalEl) {
                            legacyNextGoalEl.innerText = `${nextMilestone} Days`;
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

window.updateSetData = async function (exIdx, setIdx, reps, weight, duration, distance) {
    if (!workoutState) return;

    const ex = workoutState.exercises[exIdx];
    const setNum = setIdx + 1;
    const dateStr = new Date().toLocaleDateString('en-CA');
    const isCardio = window.isCardioExercise(ex.name);

    const payload = {
        date: dateStr,
        workout_id: workoutState.workoutId,
        exercise_name: ex.name,
        set_number: setNum,
        reps: reps || 0,
        weight: weight || 0,
        duration: duration || null,
        distance: distance || null,
        metric_type: isCardio ? 'duration_distance' : 'weight_reps'
    };

    try {
        const res = await fetch(`${apiBase}/api/client/schedule/update_set`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify(payload)
        });

        if (res.ok) {
            showToast(isCardio ? "Cardio updated!" : "Set updated!", "success");
            // Update local state to reflect changes
            workoutState.exercises[exIdx].performance[setIdx].reps = reps;
            workoutState.exercises[exIdx].performance[setIdx].weight = weight;
            workoutState.exercises[exIdx].performance[setIdx].duration = duration;
            workoutState.exercises[exIdx].performance[setIdx].distance = distance;
        } else {
            const err = await res.text();
            showToast("Failed to update: " + err);
        }
    } catch (e) {
        console.error(e);
        showToast("Error updating set");
    }
};

// Helper to read values from inputs in the DOM and call updateSetData
window.updateSetDataFromInputs = function(exIdx, setIdx, isCardio) {
    const perf = workoutState?.exercises?.[exIdx]?.performance?.[setIdx];
    if (!perf) return;

    if (isCardio) {
        // For cardio, get duration and distance from local state
        const duration = perf.duration || 0;
        const distance = perf.distance || 0;
        window.updateSetData(exIdx, setIdx, 0, 0, duration, distance);
    } else {
        // For strength, get reps and weight from local state
        const reps = perf.reps || 0;
        const weight = perf.weight || 0;
        window.updateSetData(exIdx, setIdx, reps, weight, null, null);
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
            showToast('Split created successfully!', 'success');
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
            showToast('Split updated!', 'success');
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
            showToast('Split deleted', 'success');
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
                            <span class="text-xl">${icon('dumbbell', 20)}</span>
                        </div>
                        <h3 class="text-2xl font-black italic uppercase mb-1">${workout.title}</h3>
                        <p class="text-sm text-gray-300 mb-4">${workout.duration} min • ${workout.difficulty}</p>
                        <p class="text-xs text-gray-400 mb-3">${icon('calendar', 12)} From: ${splitName}</p>
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
                        <span class="text-xl">${icon('clipboard', 20)}</span>
                    </div>
                    <h3 class="text-xl font-bold text-white/50 mb-2">Rest Day</h3>
                    <p class="text-sm text-gray-400">Split "${splitName}" assigned! No workout scheduled for today.</p>
                </div>
            `;
        }

        showToast(`${splitName} assigned to you!`, 'success');
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
                        <span class="text-xl">${icon('dumbbell', 20)}</span>
                    </div>
                    <h3 class="text-2xl font-black italic uppercase mb-1">${workoutTitle}</h3>
                    <p class="text-sm text-gray-300 mb-4">60 min • Intermediate</p>
                    <button class="block w-full py-3 bg-white text-black hover:bg-gray-200 text-center font-bold rounded-xl transition">START SESSION</button>
                </div>
            </div>
        `;

        showToast(`${workoutTitle} set as today's plan!`, 'success');
    } catch (error) {
        console.error('Error assigning workout:', error);
        showToast(`Error: ${error.message}`);
    }
};

// --- METRICS MODAL LOGIC ---

let metricsChartInstance = null;
let metricsWeightChart = null;
let metricsStrengthChart = null;
let metricsDietChart = null;

// Toggle strength goals UI visibility
function toggleStrengthGoalsUI() {
    const ui = document.getElementById('strength-goals-ui');
    if (ui) {
        ui.classList.toggle('hidden');
    }
}

// Save strength goals for a client
async function saveStrengthGoals() {
    const clientId = document.getElementById('metrics-client-id')?.value;
    if (!clientId) {
        showToast('No client selected');
        return;
    }

    const upper = document.getElementById('goal-upper')?.value;
    const lower = document.getElementById('goal-lower')?.value;
    const cardio = document.getElementById('goal-cardio')?.value;

    try {
        const response = await fetch(`${apiBase}/api/trainer/client/${clientId}/strength-goals`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
                upper: upper ? parseInt(upper) : null,
                lower: lower ? parseInt(lower) : null,
                cardio: cardio ? parseInt(cardio) : null
            })
        });

        if (!response.ok) throw new Error('Failed to save goals');

        const data = await response.json();
        showToast('Goals saved!');

        // Hide the UI and refresh the chart
        toggleStrengthGoalsUI();
        await fetchAndRenderStrengthChart(clientId);
    } catch (e) {
        console.error('Error saving goals:', e);
        showToast('Error saving goals');
    }
}

// Load existing goals into the UI
async function loadStrengthGoals(clientId) {
    try {
        const response = await fetch(`${apiBase}/api/trainer/client/${clientId}/strength-goals`, {
            credentials: 'include'
        });
        if (response.ok) {
            const goals = await response.json();
            if (document.getElementById('goal-upper')) document.getElementById('goal-upper').value = goals.upper || '';
            if (document.getElementById('goal-lower')) document.getElementById('goal-lower').value = goals.lower || '';
            if (document.getElementById('goal-cardio')) document.getElementById('goal-cardio').value = goals.cardio || '';
        }
    } catch (e) {
        console.error('Error loading goals:', e);
    }
}

async function openMetricsModal(clientId = null) {
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
    const clientNameEl = document.getElementById('modal-client-name');
    const clientName = clientNameEl ? clientNameEl.innerText : 'Client';
    document.getElementById('metrics-client-name').innerText = `Performance Analytics for ${clientName}`;

    showModal('metrics-modal');

    // Reset all charts
    if (metricsChartInstance) { metricsChartInstance.destroy(); metricsChartInstance = null; }
    if (metricsWeightChart) { metricsWeightChart.destroy(); metricsWeightChart = null; }
    if (metricsStrengthChart) { metricsStrengthChart.destroy(); metricsStrengthChart = null; }
    if (metricsDietChart) { metricsDietChart.destroy(); metricsDietChart = null; }

    // Fetch and render all metrics
    await Promise.all([
        fetchAndRenderWeightChart(clientId),
        fetchAndRenderStrengthChart(clientId),
        fetchAndRenderDietChart(clientId),
        fetchAndRenderWeekStreak(clientId),
        loadStrengthGoals(clientId)
    ]);
}

async function fetchAndRenderWeightChart(clientId) {
    try {
        // Destroy existing chart if it exists
        if (metricsWeightChart) {
            metricsWeightChart.destroy();
            metricsWeightChart = null;
        }

        const response = await fetch(`${apiBase}/api/trainer/client/${clientId}/weight-history?period=month`, {
            credentials: 'include'
        });
        if (!response.ok) return;
        const data = await response.json();

        // Update stats
        const currentEl = document.getElementById('metrics-weight-current');
        const goalEl = document.getElementById('metrics-weight-goal');
        const changeEl = document.getElementById('metrics-weight-change');

        if (data.data && data.data.length > 0) {
            const current = data.data[data.data.length - 1].weight;
            const first = data.data[0].weight;
            const change = current - first;

            if (currentEl) currentEl.textContent = current.toFixed(1);
            if (goalEl) goalEl.textContent = data.goal_weight || '--';
            if (changeEl) {
                changeEl.textContent = (change >= 0 ? '+' : '') + change.toFixed(1) + ' kg';
                changeEl.className = 'text-sm font-bold ' + (change >= 0 ? 'text-green-400' : 'text-red-400');
            }
        }

        // Render chart
        const ctx = document.getElementById('metricsWeightChart');
        if (!ctx) return;

        metricsWeightChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: data.data.map(d => d.date.slice(5)),
                datasets: [{
                    label: 'Weight (kg)',
                    data: data.data.map(d => d.weight),
                    borderColor: '#F97316',
                    backgroundColor: 'rgba(249, 115, 22, 0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 3,
                    pointBackgroundColor: '#F97316'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    x: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#666', font: { size: 9 } } },
                    y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#666', font: { size: 9 } } }
                }
            }
        });
    } catch (e) {
        console.error('Error fetching weight data:', e);
    }
}

async function fetchAndRenderStrengthChart(clientId) {
    try {
        // Destroy existing chart if it exists
        if (metricsStrengthChart) {
            metricsStrengthChart.destroy();
            metricsStrengthChart = null;
        }

        const response = await fetch(`${apiBase}/api/trainer/client/${clientId}/strength-progress?period=month`, {
            credentials: 'include'
        });
        if (!response.ok) {
            console.log('Strength API response not ok:', response.status);
            return;
        }
        const data = await response.json();
        console.log('Strength data:', data);

        // Update stats
        const upperEl = document.getElementById('metrics-upper-pct');
        const lowerEl = document.getElementById('metrics-lower-pct');
        const cardioEl = document.getElementById('metrics-cardio-pct');
        const trendEl = document.getElementById('metrics-strength-trend');

        if (data.categories) {
            const upper = data.categories.upper_body?.progress || 0;
            const lower = data.categories.lower_body?.progress || 0;
            const cardio = data.categories.cardio?.progress || 0;

            if (upperEl) upperEl.textContent = (upper >= 0 ? '+' : '') + upper.toFixed(0) + '%';
            if (lowerEl) lowerEl.textContent = (lower >= 0 ? '+' : '') + lower.toFixed(0) + '%';
            if (cardioEl) cardioEl.textContent = (cardio >= 0 ? '+' : '') + cardio.toFixed(0) + '%';

            const avgProgress = (upper + lower + cardio) / 3;
            if (trendEl) {
                trendEl.textContent = avgProgress >= 0 ? '↑ Gaining' : '↓ Declining';
                trendEl.className = 'text-sm font-bold ' + (avgProgress >= 0 ? 'text-green-400' : 'text-red-400');
            }
        }

        // Render chart
        const ctx = document.getElementById('metricsStrengthChart');
        if (!ctx || !data.categories) return;

        const datasets = [];
        const colors = { upper_body: '#F97316', lower_body: '#8B5CF6', cardio: '#22C55E' };
        const labels = { upper_body: 'Upper', lower_body: 'Lower', cardio: 'Cardio' };

        for (const [key, cat] of Object.entries(data.categories)) {
            if (cat.data && cat.data.length > 0) {
                const validData = cat.data.filter(d => d.strength !== null);
                if (validData.length > 0) {
                    datasets.push({
                        label: labels[key],
                        data: cat.data.map(d => d.strength),
                        borderColor: colors[key],
                        backgroundColor: colors[key] + '15',  // Subtle fill
                        borderWidth: 3,
                        tension: 0.3,
                        pointRadius: 4,
                        pointBackgroundColor: colors[key],
                        pointBorderColor: '#1a1a1a',
                        pointBorderWidth: 2,
                        pointHoverRadius: 6,
                        fill: true,
                        spanGaps: true
                    });
                }
            }
        }

        // Get dates from first available category
        const firstCat = Object.values(data.categories).find(c => c.data && c.data.length > 0);
        const chartLabels = firstCat ? firstCat.data.map(d => d.date.slice(5)) : [];

        // Add goal lines as horizontal dashed datasets (hidden from legend)
        const goalData = [];
        if (data.goals) {
            const goalColors = { upper: '#F97316', lower: '#8B5CF6', cardio: '#22C55E' };
            const goalLabels = { upper: 'Upper Goal', lower: 'Lower Goal', cardio: 'Cardio Goal' };

            for (const [key, value] of Object.entries(data.goals)) {
                if (value !== null && value !== undefined) {
                    goalData.push({ key, value, color: goalColors[key], label: goalLabels[key] });
                    datasets.push({
                        label: goalLabels[key],
                        data: chartLabels.map(() => value),
                        borderColor: goalColors[key] + '80',  // 50% opacity
                        backgroundColor: 'transparent',
                        borderDash: [10, 5],
                        borderWidth: 2,
                        pointRadius: 0,
                        tension: 0,
                        hidden: false
                    });
                }
            }
        }

        metricsStrengthChart = new Chart(ctx, {
            type: 'line',
            data: { labels: chartLabels, datasets },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                layout: {
                    padding: { right: 60, top: 10, bottom: 10 }  // Room for goal labels
                },
                plugins: {
                    legend: {
                        display: true,
                        position: 'top',
                        align: 'start',
                        labels: {
                            boxWidth: 16,
                            boxHeight: 3,
                            font: { size: 12, weight: '500' },
                            color: '#ccc',
                            padding: 20,
                            usePointStyle: false,
                            filter: (item) => !item.text.includes('Goal')  // Hide goal lines from legend
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0,0,0,0.8)',
                        titleFont: { size: 13 },
                        bodyFont: { size: 12 },
                        padding: 12,
                        cornerRadius: 8
                    }
                },
                scales: {
                    x: {
                        grid: { color: 'rgba(255,255,255,0.05)', drawBorder: false },
                        ticks: { color: '#888', font: { size: 11 }, padding: 8 }
                    },
                    y: {
                        grid: { color: 'rgba(255,255,255,0.05)', drawBorder: false },
                        ticks: {
                            color: '#888',
                            font: { size: 11 },
                            padding: 8,
                            callback: v => v + '%'
                        }
                    }
                }
            }
        });

        // Add goal labels on the right side of the chart
        const labelsContainer = document.getElementById('strength-goal-labels');
        if (labelsContainer && goalData.length > 0) {
            labelsContainer.innerHTML = goalData.map(g => `
                <div class="flex items-center gap-1 bg-black/60 px-2 py-1 rounded text-xs" style="color: ${g.color}">
                    <span class="font-bold">${g.value}%</span>
                </div>
            `).join('');
        } else if (labelsContainer) {
            labelsContainer.innerHTML = '';
        }
    } catch (e) {
        console.error('Error fetching strength data:', e);
    }
}

async function fetchAndRenderDietChart(clientId) {
    try {
        // Destroy existing chart if it exists
        if (metricsDietChart) {
            metricsDietChart.destroy();
            metricsDietChart = null;
        }

        const response = await fetch(`${apiBase}/api/trainer/client/${clientId}/diet-consistency?period=month`, {
            credentials: 'include'
        });
        if (!response.ok) {
            console.log('Diet API response not ok:', response.status);
            return;
        }
        const data = await response.json();
        console.log('Diet data:', data);

        // Update stats
        const streakEl = document.getElementById('metrics-diet-streak');
        const avgEl = document.getElementById('metrics-diet-avg');
        const daysEl = document.getElementById('metrics-diet-days');

        if (streakEl) streakEl.textContent = (data.current_streak || 0) + ' day streak';
        if (avgEl) avgEl.textContent = data.average_score || 0;
        if (daysEl) daysEl.textContent = data.total_days || 0;

        // Render chart
        const ctx = document.getElementById('metricsDietChart');
        if (!ctx) return;

        // Handle empty data
        if (!data.data || data.data.length === 0) {
            // Show empty state message
            metricsDietChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: ['No diet data logged'],
                    datasets: [{
                        label: 'Health Score',
                        data: [0],
                        backgroundColor: 'rgba(100, 100, 100, 0.3)',
                        borderRadius: 4
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { display: false } },
                    scales: {
                        x: { grid: { display: false }, ticks: { color: '#666', font: { size: 9 } } },
                        y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#666', font: { size: 9 } }, min: 0, max: 100 }
                    }
                }
            });
            return;
        }

        metricsDietChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: data.data.map(d => d.date.slice(5)),
                datasets: [{
                    label: 'Health Score',
                    data: data.data.map(d => d.score),
                    backgroundColor: data.data.map(d =>
                        d.score >= 80 ? 'rgba(34, 197, 94, 0.7)' :
                        d.score >= 60 ? 'rgba(234, 179, 8, 0.7)' :
                        'rgba(239, 68, 68, 0.7)'
                    ),
                    borderRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    x: { grid: { display: false }, ticks: { color: '#666', font: { size: 8 }, maxRotation: 45 } },
                    y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#666', font: { size: 9 } }, min: 0, max: 100 }
                }
            }
        });
    } catch (e) {
        console.error('Error fetching diet data:', e);
    }
}

async function fetchAndRenderWeekStreak(clientId) {
    try {
        const response = await fetch(`${apiBase}/api/trainer/client/${clientId}/week-streak`, {
            credentials: 'include'
        });
        if (!response.ok) return;
        const data = await response.json();

        // Update streak number and label
        const streakEl = document.getElementById('metrics-day-streak');
        const numberEl = document.getElementById('metrics-streak-number');

        const streak = data.current_streak || 0;
        if (streakEl) streakEl.textContent = streak + ' day' + (streak !== 1 ? 's' : '');
        if (numberEl) numberEl.textContent = streak;

        // Render days grid
        const daysGrid = document.getElementById('metrics-days-grid');
        if (daysGrid && data.days) {
            daysGrid.innerHTML = data.days.map(day => {
                let bgClass, borderClass, icon;
                if (day.completed) {
                    bgClass = 'bg-gradient-to-br from-orange-500 to-orange-600';
                    borderClass = 'border-orange-400';
                    icon = '<svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>';
                } else if (day.is_today) {
                    bgClass = 'bg-white/10';
                    borderClass = 'border-orange-400 border-dashed';
                    icon = `<span class="text-orange-400 text-[8px] font-bold">${day.day_name}</span>`;
                } else if (day.total > 0) {
                    // Had workout scheduled but not completed
                    bgClass = 'bg-red-500/20';
                    borderClass = 'border-red-500/30';
                    icon = '<span class="text-red-400 text-[10px]">✕</span>';
                } else {
                    // No workout scheduled
                    bgClass = 'bg-white/5';
                    borderClass = 'border-white/10';
                    icon = `<span class="text-gray-600 text-[8px]">${day.day_name}</span>`;
                }
                return `<div class="w-6 h-6 rounded-md ${bgClass} border ${borderClass} flex items-center justify-center" title="${day.date}">${icon}</div>`;
            }).join('');
        }
    } catch (e) {
        console.error('Error fetching day streak:', e);
    }
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
                                <div class="mb-4">${icon('alert-triangle', 48)}</div>
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
                    document.getElementById('exercise-target').innerText = "Take it easy and recover!";
                    document.getElementById('workout-screen').innerHTML = `
                        <div class="flex flex-col items-center justify-center h-screen bg-gray-900 text-white p-8 text-center">
                            <div class="mb-4">${icon('heart', 48)}</div>
                            <h1 class="text-4xl font-black mb-2">Rest Day</h1>
                            <p class="text-gray-400 mb-8">No workout scheduled for today. Enjoy your recovery!</p>
                            <a href="/?gym_id=${gymId}&role=${APP_CONFIG.role}" class="px-8 py-3 bg-white/10 rounded-xl font-bold hover:bg-white/20 transition">Back to Dashboard</a>
                        </div>
                    `;
                    return;
                }

                // Store global user ID for cache keys
                window.currentUserId = user.id;

                // Check if this is a completed workout with structured details
                let exercisesData = workout.exercises;
                let coopData = null;

                // Parse details if completed - new format includes CO-OP info
                if (workout.completed && workout.details) {
                    try {
                        const details = typeof workout.details === 'string' ? JSON.parse(workout.details) : workout.details;
                        // New format: { exercises: [...], coop: { partner, partner_exercises } }
                        if (details.exercises) {
                            exercisesData = details.exercises;
                            coopData = details.coop || null;
                        } else if (Array.isArray(details)) {
                            // Legacy format: details is just the exercises array
                            exercisesData = details;
                        }
                    } catch (e) {
                        console.log("Could not parse workout details, using exercises directly");
                    }
                }

                workoutState = {
                    workoutId: workout.id, // Needed for cache key
                    exercises: exercisesData.map(ex => ({
                        ...ex,
                        collapsed: false, // Init collapsed state
                        performance: ex.performance || Array(ex.sets).fill().map(() => ({ reps: '', weight: '', completed: false }))
                    })),
                    currentExerciseIdx: 0,
                    currentSet: 1,
                    currentReps: parseInt(String(exercisesData[0].reps).split('-')[1] || exercisesData[0].reps),
                    isCompletedView: isCompletedView // Store in state
                };

                // Set up CO-OP state if this was a CO-OP workout
                if (coopData && coopData.partner) {
                    window.coopState = window.coopState || {};
                    window.coopState.isCoopMode = true;
                    window.coopState.partner = coopData.partner;
                    window.coopState.activeTab = 'me';
                    window.coopState.partnerExercises = (coopData.partner_exercises || []).map(ex => ({
                        ...ex,
                        collapsed: false,
                        performance: ex.performance || Array(ex.sets).fill().map(() => ({ reps: '', weight: '', completed: false }))
                    }));
                    window.coopState.partnerCurrentIdx = 0;
                    window.coopState.partnerCurrentSet = 1;
                    window.coopState.partnerCurrentReps = 10;

                    // Show CO-OP indicator in completed view
                    const indicator = document.getElementById('coop-indicator');
                    const nameEl = document.getElementById('coop-partner-name');
                    const avatarEl = document.getElementById('coop-partner-avatar');

                    if (indicator) {
                        indicator.classList.remove('hidden');
                        if (nameEl) nameEl.textContent = coopData.partner.name || 'Partner';
                        if (avatarEl && coopData.partner.profile_picture) {
                            avatarEl.innerHTML = `<img src="${coopData.partner.profile_picture}" class="w-full h-full object-cover rounded-full">`;
                        }
                    }
                    console.log("CO-OP workout loaded from completed data:", coopData.partner.name);
                }
                // Note: Only show partner tabs if coopData exists (meaning it was a CO-OP workout)

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

// Show option to load a friend's workout in completed view
async function showLoadFriendWorkoutOption() {
    // Fetch friends list
    try {
        const res = await fetch(`${apiBase}/api/friends`);
        if (!res.ok) return;

        const friends = await res.json();
        if (!friends || friends.length === 0) return;

        // Create a load partner button in the coop-indicator area
        const indicator = document.getElementById('coop-indicator');
        if (!indicator) return;

        // Show the indicator with a "Load friend's workout" button
        indicator.innerHTML = `
            <div class="text-center">
                <p class="text-xs text-gray-400 mb-2">View a friend's workout for today?</p>
                <div class="flex flex-wrap gap-2 justify-center">
                    ${friends.map(f => `
                        <button onclick="loadFriendWorkout('${f.id}', '${f.username}', '${f.profile_picture || ''}')"
                            class="flex items-center gap-2 px-3 py-2 bg-purple-500/20 rounded-xl border border-purple-500/30 hover:bg-purple-500/30 transition tap-effect">
                            <div class="w-6 h-6 rounded-full bg-purple-500/30 flex items-center justify-center overflow-hidden">
                                ${f.profile_picture ? `<img src="${f.profile_picture}" class="w-full h-full object-cover">` : '<span class="text-xs">' + icon('user', 12) + '</span>'}
                            </div>
                            <span class="text-sm text-purple-300">${f.username}</span>
                        </button>
                    `).join('')}
                </div>
            </div>
        `;
        indicator.classList.remove('hidden');
    } catch (e) {
        console.log('Could not load friends for workout view:', e);
    }
}

// Load a friend's workout for the current date
window.loadFriendWorkout = async function(friendId, friendName, friendPicture) {
    const todayStr = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD

    try {
        const res = await fetch(`${apiBase}/api/friends/${friendId}/workout?date=${todayStr}`);
        if (!res.ok) {
            showToast('Could not load friend\'s workout', 'error');
            return;
        }

        const data = await res.json();
        if (!data.found) {
            showToast(data.message || 'Friend has no workout for today', 'info');
            return;
        }

        // Set up CO-OP state with friend's data
        window.coopState = window.coopState || {};
        window.coopState.isCoopMode = true;
        window.coopState.partner = {
            id: friendId,
            name: friendName,
            profile_picture: friendPicture
        };
        window.coopState.activeTab = 'me';
        window.coopState.partnerExercises = (data.workout.exercises || []).map(ex => ({
            ...ex,
            collapsed: false,
            performance: ex.performance || Array(ex.sets || 3).fill().map(() => ({ reps: '', weight: '', completed: false }))
        }));
        window.coopState.partnerCurrentIdx = 0;
        window.coopState.partnerCurrentSet = 1;
        window.coopState.partnerCurrentReps = 10;

        // Update the indicator to show the tabs
        const indicator = document.getElementById('coop-indicator');
        if (indicator) {
            indicator.innerHTML = `
                <div class="flex gap-2 mb-3">
                    <button id="coop-tab-me" onclick="switchCoopTab('me')" class="flex-1 py-2 px-3 rounded-xl flex items-center justify-center gap-2 transition-all bg-gradient-to-r from-orange-500 to-orange-600 border-2 border-orange-500">
                        <div class="w-6 h-6 rounded-full bg-white/20 flex items-center justify-center overflow-hidden">
                            ${icon('user', 12)}
                        </div>
                        <span class="text-sm font-bold text-white">You</span>
                    </button>
                    <button id="coop-tab-partner" onclick="switchCoopTab('partner')" class="flex-1 py-2 px-3 rounded-xl flex items-center justify-center gap-2 transition-all bg-white/5 border-2 border-white/10">
                        <div id="coop-partner-avatar" class="w-6 h-6 rounded-full bg-purple-500/30 flex items-center justify-center overflow-hidden">
                            ${friendPicture ? `<img src="${friendPicture}" class="w-full h-full object-cover rounded-full">` : '<span class="text-xs">' + icon('users', 12) + '</span>'}
                        </div>
                        <span id="coop-partner-name" class="text-sm font-bold text-white/70">${friendName}</span>
                    </button>
                </div>
                <p id="coop-active-label" class="text-xs text-center text-purple-300 font-medium">
                    Viewing: <span id="coop-controlling-name" class="text-white">Your workout</span>
                </p>
            `;
        }

        showToast(`Loaded ${friendName}'s workout!`, 'success');
        console.log('Loaded friend workout:', data);

    } catch (e) {
        console.error('Error loading friend workout:', e);
        showToast('Failed to load friend\'s workout', 'error');
    }
};

// Helper to update performance data
window.updatePerformance = function (exIdx, setIdx, field, val, isPartner = false) {
    // Check if we're in CO-OP partner mode
    const isPartnerMode = isPartner || (window.coopState?.isCoopMode && window.coopState?.activeTab === 'partner');

    if (isPartnerMode && window.coopState?.partnerExercises?.[exIdx]) {
        window.coopState.partnerExercises[exIdx].performance[setIdx][field] = val;
        // Don't auto-save partner data to server - it gets saved on completion
    } else if (workoutState && workoutState.exercises[exIdx]) {
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

    // Check if we're in CO-OP mode and controlling partner
    const isCoopPartnerMode = window.coopState?.isCoopMode && window.coopState?.activeTab === 'partner';

    let exId, setId, exercises, currentReps;
    if (isCoopPartnerMode && window.coopState.partnerExercises) {
        // Use partner's state
        exId = window.coopState.partnerCurrentIdx;
        setId = window.coopState.partnerCurrentSet - 1;
        exercises = window.coopState.partnerExercises;
        currentReps = window.coopState.partnerCurrentReps;
    } else {
        // Use main user's state
        exId = workoutState.currentExerciseIdx;
        setId = workoutState.currentSet - 1;
        exercises = workoutState.exercises;
        currentReps = workoutState.currentReps;
    }

    // VALIDATION: Check required fields based on exercise type
    if (exercises[exId] && exercises[exId].performance[setId]) {
        const currentPerf = exercises[exId].performance[setId];
        const isCardio = window.isCardioExercise(exercises[exId].name);

        if (isCardio) {
            // For cardio, validate duration OR distance is entered
            if ((!currentPerf.duration && currentPerf.duration !== 0) &&
                (!currentPerf.distance && currentPerf.distance !== 0)) {
                showToast("Please enter duration or distance!", "error");
                return;
            }
        } else {
            // For strength, validate weight is entered
            if (!currentPerf.weight && currentPerf.weight !== 0) {
                showToast("Please enter weight for this set!", "error");
                return;
            }
            // AUTO-FILL REPS from Main Counter
            currentPerf.reps = currentReps;
        }

        currentPerf.completed = true; // Mark as done

        // AUTO-FILL NEXT SET (weight for strength, keep duration/distance for cardio)
        const nextSetPerf = exercises[exId].performance[setId + 1];
        if (nextSetPerf) {
            if (isCardio) {
                // Auto-fill duration/distance for next cardio session
                if (!nextSetPerf.duration && currentPerf.duration) {
                    nextSetPerf.duration = currentPerf.duration;
                }
                if (!nextSetPerf.distance && currentPerf.distance) {
                    nextSetPerf.distance = currentPerf.distance;
                }
            } else {
                // Only auto-fill if next set has no weight yet
                if (!nextSetPerf.weight && nextSetPerf.weight !== 0) {
                    nextSetPerf.weight = currentPerf.weight;
                }
            }
        }

        if (!isCoopPartnerMode) {
            saveProgress(); // Save the new data for main user
        }
    }

    const ex = isCoopPartnerMode ? window.coopState.partnerExercises[exId] : workoutState.exercises[workoutState.currentExerciseIdx];

    // Show Rest Timer
    showRestTimer(ex.rest || 60, () => {
        // Check partner mode again in callback (closure)
        const partnerMode = window.coopState?.isCoopMode && window.coopState?.activeTab === 'partner';

        if (partnerMode && window.coopState.partnerExercises) {
            // Handle partner's workout progression
            const partnerEx = window.coopState.partnerExercises[window.coopState.partnerCurrentIdx];
            if (window.coopState.partnerCurrentSet < partnerEx.sets) {
                window.coopState.partnerCurrentSet++;
                let targetReps = partnerEx.reps;
                if (typeof partnerEx.reps === 'string' && partnerEx.reps.includes('-')) {
                    targetReps = partnerEx.reps.split('-')[1];
                }
                window.coopState.partnerCurrentReps = parseInt(targetReps);
                updateWorkoutUI();
            } else {
                // Move to next exercise for partner
                if (window.coopState.partnerCurrentIdx < window.coopState.partnerExercises.length - 1) {
                    window.coopState.partnerCurrentIdx++;
                    window.coopState.partnerCurrentSet = 1;
                    const nextEx = window.coopState.partnerExercises[window.coopState.partnerCurrentIdx];
                    let nextReps = nextEx.reps;
                    if (typeof nextEx.reps === 'string' && nextEx.reps.includes('-')) {
                        nextReps = nextEx.reps.split('-')[1];
                    }
                    window.coopState.partnerCurrentReps = parseInt(nextReps);
                    updateWorkoutUI();
                } else {
                    showToast("Partner's workout complete! Switch back to your tab.", 'success');
                }
            }
        } else {
            // Handle main user's workout progression
            if (workoutState.currentSet < ex.sets) {
                workoutState.currentSet++;
                let targetReps = ex.reps;
                if (typeof ex.reps === 'string' && ex.reps.includes('-')) {
                    targetReps = ex.reps.split('-')[1];
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
        }
    });
}

function updateWorkoutUI() {
    if (!workoutState) return;

    // Check if we're in CO-OP partner mode
    const isPartnerMode = window.coopState?.isCoopMode && window.coopState?.activeTab === 'partner';

    // Use partner state if in partner mode
    let exercises, currentIdx, currentSet, currentReps;
    if (isPartnerMode && window.coopState.partnerExercises) {
        exercises = window.coopState.partnerExercises;
        currentIdx = window.coopState.partnerCurrentIdx;
        currentSet = window.coopState.partnerCurrentSet;
        currentReps = window.coopState.partnerCurrentReps;
    } else {
        exercises = workoutState.exercises;
        currentIdx = workoutState.currentExerciseIdx;
        currentSet = workoutState.currentSet;
        currentReps = workoutState.currentReps;
    }

    const ex = exercises[currentIdx];
    if (!ex) return;

    // Update Header & Counters
    const partnerLabel = isPartnerMode ? ` (${window.coopState.partner?.name || 'Partner'})` : '';
    document.getElementById('exercise-name').innerText = ex.name + partnerLabel;
    document.getElementById('exercise-target').innerText = `Set ${currentSet}/${ex.sets} • Target: ${ex.reps} Reps`;
    document.getElementById('rep-counter').innerText = currentReps;

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
        exercises.forEach((item, idx) => {
            const div = document.createElement('div');
            const isCurrent = idx === currentIdx;
            const accentColor = isPartnerMode ? 'purple' : 'orange';

            // Event Delegation Attributes
            div.dataset.action = 'switchExercise';
            div.dataset.idx = idx;
            if (isPartnerMode) div.dataset.partnerMode = 'true';

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
                    const isSetActive = (i === (currentSet - 1));

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
                        const exerciseIsCardio = window.isCardioExercise(item.name);

                        if (isEditing) {
                            currentInputClass = baseInputClass + " border-b border-orange-500";
                            // Different save logic for cardio vs strength
                            if (exerciseIsCardio) {
                                editBtnHtml = `
                                    <button onclick="event.stopPropagation(); window.updateSetDataFromInputs(${idx}, ${i}, true); workoutState.exercises[${idx}].performance[${i}].isEditing = false; updateWorkoutUI();"
                                        class="w-8 h-8 bg-green-500 rounded-lg flex items-center justify-center text-white hover:scale-105 transition flex-shrink-0">
                                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                                    </button>
                                `;
                            } else {
                                editBtnHtml = `
                                    <button onclick="event.stopPropagation(); window.updateSetDataFromInputs(${idx}, ${i}, false); workoutState.exercises[${idx}].performance[${i}].isEditing = false; updateWorkoutUI();"
                                        class="w-8 h-8 bg-green-500 rounded-lg flex items-center justify-center text-white hover:scale-105 transition flex-shrink-0">
                                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                                    </button>
                                `;
                            }
                        } else {
                            editBtnHtml = `
                                <button onclick="event.stopPropagation(); workoutState.exercises[${idx}].performance[${i}].isEditing = true; updateWorkoutUI();"
                                    class="w-8 h-8 bg-white/5 border border-white/10 rounded-lg flex items-center justify-center text-white/40 hover:bg-white/10 hover:text-white transition flex-shrink-0">
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/></svg>
                                </button>
                            `;
                        }
                    }

                    // Check if this is a cardio exercise
                    const isCardio = window.isCardioExercise(item.name);

                    // Build input fields based on exercise type
                    let inputFieldsHtml = '';
                    if (isCardio) {
                        // Cardio: Duration and Distance inputs
                        inputFieldsHtml = `
                            <div class="flex items-center bg-white/5 border border-white/5 rounded-lg px-3 py-2.5 focus-within:border-green-500/50 transition">
                                <input type="number" step="0.5" value="${perf.duration || ''}"
                                    oninput="window.updatePerformance(${idx}, ${i}, 'duration', this.value)"
                                    onclick="event.stopPropagation()"
                                    ${workoutState.isCompletedView && !perf.isEditing ? 'disabled' : (isInputDisabled && !perf.isEditing ? 'disabled' : '')}
                                    class="${currentInputClass}" placeholder="-">
                                <span class="text-[10px] text-white/30 font-medium ml-1 uppercase">min</span>
                            </div>
                            <div class="flex items-center bg-white/5 border border-white/5 rounded-lg px-3 py-2.5 focus-within:border-green-500/50 transition">
                                <input type="number" step="0.1" value="${perf.distance || ''}"
                                    oninput="window.updatePerformance(${idx}, ${i}, 'distance', this.value)"
                                    onclick="event.stopPropagation()"
                                    ${workoutState.isCompletedView && !perf.isEditing ? 'disabled' : (isInputDisabled && !perf.isEditing ? 'disabled' : '')}
                                    class="${currentInputClass}" placeholder="-">
                                <span class="text-[10px] text-white/30 font-medium ml-1 uppercase">km</span>
                            </div>`;
                    } else {
                        // Strength: Reps and Weight inputs
                        inputFieldsHtml = `
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
                            </div>`;
                    }

                    setsHtml += `
                        <div class="${rowClass}">
                            ${statusIcon}
                            <span class="text-xs font-medium text-white/40 pl-8 uppercase tracking-wider ${isSetActive ? 'text-orange-500' : ''}">${isCardio ? 'Session' : 'Set ' + (i + 1)}</span>
                            ${inputFieldsHtml}
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
                    <span class="text-2xl group-hover:scale-110 transition-transform">${icon('calendar', 24)}</span>
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
                    <button class="text-xs bg-white/5 hover:bg-white/10 px-2 py-1 rounded text-gray-300 transition" onclick="openEditSplitModal('${s.id}')">${icon('pencil', 14)}</button>
                    <button class="text-xs bg-white/5 hover:bg-white/10 px-2 py-1 rounded text-gray-300 transition" onclick="deleteSplit('${s.id}')">${icon('trash-2', 14)}</button>
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
            showToast('Split updated!', 'success');
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
            showToast('Split created successfully!', 'success');
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
                showToast("Assigned with some errors. Check console.", "error");
                console.warn("Assignment Logs:", data.logs);
            } else {
                showToast("Split assigned successfully!", "success");
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

        // Can message - open the chat with profile picture
        window.openChatModal(userId, userName, avatarUrl);
    } catch (err) {
        console.error('Error checking message permission:', err);
        showToast('Error opening chat', 'error');
    }
};

window.openChatModal = async function(otherUserId, otherUserName, profilePicture) {
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

    // Set avatar: use profile picture or default gradient icon
    const chatUserAvatar = document.getElementById('chat-user-avatar');
    if (chatUserAvatar) {
        if (profilePicture) {
            chatUserAvatar.innerHTML = `<img src="${profilePicture}" class="w-full h-full object-cover" />`;
        } else {
            chatUserAvatar.innerHTML = '<span class="text-lg">' + icon('user', 18) + '</span>';
        }
    }

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

// Client chat modal - always opens conversations list
window.openClientChatModal = async function() {
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
                <div class="mb-2">${icon('message-circle', 32)}</div>
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
            const errData = await res.json().catch(() => ({}));
            throw new Error(errData.detail || 'Failed to send message');
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
        showToast(e.message || 'Failed to send message', 'error');

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
            // Update all unread badge elements (desktop + mobile)
            const badges = document.querySelectorAll('#unread-messages-badge, #unread-messages-badge-mobile');
            badges.forEach(badge => {
                if (data.unread_count > 0) {
                    badge.innerText = data.unread_count;
                    badge.classList.remove('hidden');
                } else {
                    badge.classList.add('hidden');
                }
            });
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
    if (APP_CONFIG.role === 'trainer' || APP_CONFIG.role === 'client' || APP_CONFIG.role === 'staff') {
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
                    <div class="mb-2">${icon('message-circle', 32)}</div>
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
                window.openChatModal(conv.other_user_id, conv.other_user_name, conv.other_user_profile_picture);
            };

            const time = conv.last_message_at ? new Date(conv.last_message_at).toLocaleString([], {
                month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
            }) : '';

            const avatarHtml = conv.other_user_profile_picture
                ? `<img src="${conv.other_user_profile_picture}" alt="${conv.other_user_name}" class="w-10 h-10 rounded-full object-cover">`
                : `<div class="w-10 h-10 rounded-full bg-gradient-to-tr from-red-500 to-orange-500 flex items-center justify-center"><span class="text-lg">${icon('user', 18)}</span></div>`;

            div.innerHTML = `
                <div class="flex items-center justify-between">
                    <div class="flex items-center space-x-3">
                        ${avatarHtml}
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
                    showToast(`Appointment & workout assigned to ${currentBookingClientName}!`, 'success');
                } else {
                    showToast(`Appointment booked! Note: Workout assignment failed.`);
                }
            } catch (assignError) {
                console.error('Error assigning workout:', assignError);
                showToast(`Appointment booked with ${currentBookingClientName}!`, 'success');
            }
        } else {
            showToast(`Appointment booked with ${currentBookingClientName}!`, 'success');
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
let appointmentPaymentMethod = null;
let appointmentTrainerRate = null;

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
                icon.innerHTML = '<i data-lucide="user" style="width:18px;height:18px;display:inline-block;vertical-align:middle;stroke:currentColor;"></i>';
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
        appointmentPaymentMethod = null;
        appointmentTrainerRate = null;
        appointmentStripePaymentIntentId = null;

        // Reset payment section
        const paymentSection = document.getElementById('appointment-payment-section');
        const freeSection = document.getElementById('appointment-free-section');
        if (paymentSection) paymentSection.classList.add('hidden');
        if (freeSection) freeSection.classList.add('hidden');
        const cardForm = document.getElementById('appointment-card-form');
        const cashInfo = document.getElementById('appointment-cash-info');
        if (cardForm) cardForm.classList.add('hidden');
        if (cashInfo) cashInfo.classList.add('hidden');

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
        icon.innerHTML = '<i data-lucide="user" style="width:18px;height:18px;display:inline-block;vertical-align:middle;stroke:currentColor;"></i>';
        icon.className = 'text-xl';
        avatarEl.appendChild(icon);
    }
}

async function selectTrainerForBooking(trainerId, trainerName) {
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

    // Fetch trainer's session rate and show payment section
    appointmentPaymentMethod = null;
    appointmentTrainerRate = null;
    appointmentStripePaymentIntentId = null;
    try {
        const rateRes = await fetch(`${apiBase}/api/client/trainers/${trainerId}/session-rate`, {
            credentials: 'include'
        });
        if (rateRes.ok) {
            const rateData = await rateRes.json();
            appointmentTrainerRate = rateData.session_rate;
        }
    } catch (e) {
        console.log('Could not fetch trainer rate:', e);
    }

    updateAppointmentPriceDisplay();
    showToast(`Selected ${trainerName}`);
}

function updateAppointmentPriceDisplay() {
    const paymentSection = document.getElementById('appointment-payment-section');
    const freeSection = document.getElementById('appointment-free-section');
    const priceDisplay = document.getElementById('appointment-price-display');
    const cardForm = document.getElementById('appointment-card-form');
    const cashInfo = document.getElementById('appointment-cash-info');

    // Reset payment method selection visuals
    appointmentPaymentMethod = null;
    if (cardForm) cardForm.classList.add('hidden');
    if (cashInfo) cashInfo.classList.add('hidden');
    const cardBtn = document.getElementById('appt-pay-card-btn');
    const cashBtn = document.getElementById('appt-pay-cash-btn');
    if (cardBtn) {
        cardBtn.classList.remove('border-blue-500', 'bg-blue-500/20');
        cardBtn.classList.add('border-white/20');
    }
    if (cashBtn) {
        cashBtn.classList.remove('border-green-500', 'bg-green-500/20');
        cashBtn.classList.add('border-white/20');
    }

    if (appointmentTrainerRate && appointmentTrainerRate > 0) {
        const duration = parseInt(document.getElementById('client-book-duration').value) || 60;
        const price = (appointmentTrainerRate * (duration / 60)).toFixed(2);

        if (paymentSection) paymentSection.classList.remove('hidden');
        if (freeSection) freeSection.classList.add('hidden');
        if (priceDisplay) priceDisplay.textContent = `$${price}`;
    } else {
        if (paymentSection) paymentSection.classList.add('hidden');
        if (freeSection) freeSection.classList.remove('hidden');
    }
}

function clientTrainerSelected() {
    // This function is kept for compatibility but selection is now handled by selectTrainerForBooking
    const trainerId = document.getElementById('client-book-trainer').value;
    selectedTrainerForBooking = trainerId;
}

// Handle duration change - recalculate price
window.appointmentDurationChanged = function() {
    if (appointmentTrainerRate && appointmentTrainerRate > 0) {
        updateAppointmentPriceDisplay();
    }
};

// Select payment method for appointment
window.selectAppointmentPayment = function(method) {
    appointmentPaymentMethod = method;

    const cardBtn = document.getElementById('appt-pay-card-btn');
    const cashBtn = document.getElementById('appt-pay-cash-btn');
    const cashInfo = document.getElementById('appointment-cash-info');

    // Reset styles
    cardBtn.classList.remove('border-blue-500', 'bg-blue-500/20');
    cardBtn.classList.add('border-white/20');
    cashBtn.classList.remove('border-green-500', 'bg-green-500/20');
    cashBtn.classList.add('border-white/20');
    cashInfo.classList.add('hidden');

    if (method === 'card') {
        cardBtn.classList.remove('border-white/20');
        cardBtn.classList.add('border-blue-500', 'bg-blue-500/20');
    } else if (method === 'cash') {
        cashBtn.classList.remove('border-white/20');
        cashBtn.classList.add('border-green-500', 'bg-green-500/20');
        cashInfo.classList.remove('hidden');
    }
};

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

    // Validate payment method if trainer has a rate
    const hasPaidSession = appointmentTrainerRate && appointmentTrainerRate > 0;
    if (hasPaidSession && !appointmentPaymentMethod) {
        showToast('Please select a payment method');
        return;
    }

    const bookBtn = document.getElementById('book-appointment-btn');
    if (bookBtn) {
        bookBtn.disabled = true;
        bookBtn.textContent = 'Processing...';
    }

    try {
        if (hasPaidSession && appointmentPaymentMethod === 'card') {
            // Redirect to Stripe Checkout
            const checkoutRes = await fetch(`${apiBase}/api/client/appointment-checkout-session`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify({
                    trainer_id: trainerId,
                    date: date,
                    start_time: time,
                    duration: duration,
                    notes: notes,
                })
            });

            if (!checkoutRes.ok) {
                const err = await checkoutRes.json();
                throw new Error(err.detail || 'Failed to create checkout session');
            }

            const { checkout_url } = await checkoutRes.json();
            window.location.href = checkout_url;
            return;
        }

        // Cash or free booking
        const res = await fetch(`${apiBase}/api/client/appointments`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
                trainer_id: trainerId,
                date: date,
                start_time: time,
                duration: duration,
                notes: notes,
                payment_method: hasPaidSession ? appointmentPaymentMethod : null,
                stripe_payment_intent_id: null
            })
        });

        if (!res.ok) {
            const error = await res.json();
            throw new Error(error.detail || 'Failed to book appointment');
        }

        const result = await res.json();

        // Get trainer name for toast
        const trainer = availableTrainers.find(t => t.id === trainerId);
        const trainerName = trainer ? trainer.name : 'trainer';

        showToast(`Appointment booked with ${trainerName}!`);
        hideModal('client-book-appointment-modal');

        // Refresh calendar if open
        if (window.location.href.includes('mode=calendar')) {
            window.location.reload();
        }
    } catch (e) {
        console.error('Error booking appointment:', e);
        showToast('Failed to book appointment: ' + e.message);
    } finally {
        if (bookBtn) {
            bookBtn.disabled = false;
            bookBtn.textContent = 'Book Appointment';
        }
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
                    <span class="text-2xl group-hover:scale-110 transition-transform">${icon('book-open', 24)}</span>
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

        // Render own courses grouped by type
        if (ownCourses.length === 0) {
            ownCoursesContainer.innerHTML = `
                <div class="glass-card p-8 text-center">
                    <span class="mb-3 block">${icon('book-open', 32)}</span>
                    <p class="text-gray-400 text-sm mb-2">No courses yet</p>
                    <p class="text-gray-500 text-xs">Create your first group fitness course to get started</p>
                </div>
            `;
        } else {
            ownCoursesContainer.innerHTML = renderCoursesGroupedByType(ownCourses, true);
        }

        // Render shared courses grouped by type
        if (sharedCoursesContainer) {
            if (sharedCourses.length === 0) {
                sharedCoursesContainer.innerHTML = `
                    <div class="glass-card p-4 text-center">
                        <p class="text-gray-400/50 text-xs">No shared courses from other trainers</p>
                    </div>
                `;
            } else {
                sharedCoursesContainer.innerHTML = renderCoursesGroupedByType(sharedCourses, false);
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

// Course type icons and labels
const COURSE_TYPE_INFO = {
    yoga: { icon: 'heart', label: 'Yoga', color: 'purple' },
    pilates: { icon: 'person-standing', label: 'Pilates', color: 'pink' },
    hiit: { icon: 'flame', label: 'HIIT', color: 'orange' },
    dance: { icon: 'music', label: 'Dance', color: 'red' },
    spin: { icon: 'bike', label: 'Spinning', color: 'blue' },
    strength: { icon: 'dumbbell', label: 'Strength', color: 'green' },
    stretch: { icon: 'move', label: 'Stretch', color: 'yellow' },
    cardio: { icon: 'footprints', label: 'Cardio', color: 'cyan' }
};

// Group courses by type and render with section headers
function renderCoursesGroupedByType(courses, isOwner) {
    // Group courses by course_type
    const grouped = {};
    const uncategorized = [];

    courses.forEach(course => {
        const type = course.course_type || 'other';
        if (COURSE_TYPE_INFO[type]) {
            if (!grouped[type]) grouped[type] = [];
            grouped[type].push(course);
        } else {
            uncategorized.push(course);
        }
    });

    // Define order of sections
    const typeOrder = ['yoga', 'pilates', 'hiit', 'dance', 'spin', 'strength', 'stretch', 'cardio'];

    let html = '';

    // Render each type section
    typeOrder.forEach(type => {
        if (grouped[type] && grouped[type].length > 0) {
            const info = COURSE_TYPE_INFO[type];
            html += `
                <div class="mb-6">
                    <div class="flex items-center gap-2 mb-3 px-1">
                        <span class="text-xl">${icon(info.icon, 20)}</span>
                        <h4 class="text-sm font-bold text-white/80 uppercase tracking-wider">${info.label}</h4>
                        <span class="text-xs text-white/40">(${grouped[type].length})</span>
                    </div>
                    <div class="space-y-3">
                        ${grouped[type].map(c => renderCourseCard(c, isOwner)).join('')}
                    </div>
                </div>
            `;
        }
    });

    // Render uncategorized courses
    if (uncategorized.length > 0) {
        html += `
            <div class="mb-6">
                <div class="flex items-center gap-2 mb-3 px-1">
                    <span class="text-xl">${icon('book-open', 20)}</span>
                    <h4 class="text-sm font-bold text-white/80 uppercase tracking-wider">Other Courses</h4>
                    <span class="text-xs text-white/40">(${uncategorized.length})</span>
                </div>
                <div class="space-y-3">
                    ${uncategorized.map(c => renderCourseCard(c, isOwner)).join('')}
                </div>
            </div>
        `;
    }

    return html;
}

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
                <span>${icon('clock', 12)} ${course.duration || 60} min</span>
                <span>${icon('dumbbell', 12)} ${exerciseCount} exercise${exerciseCount !== 1 ? 's' : ''}</span>
                <span>${icon('music', 12)} ${musicCount} playlist${musicCount !== 1 ? 's' : ''}</span>
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
    yoga: { color: 'purple', gradient: 'from-purple-500 to-pink-500', bg: 'bg-purple-500/20', border: 'border-purple-500', icon: 'heart' },
    pilates: { color: 'pink', gradient: 'from-pink-500 to-rose-500', bg: 'bg-pink-500/20', border: 'border-pink-500', icon: 'person-standing' },
    hiit: { color: 'orange', gradient: 'from-orange-500 to-red-500', bg: 'bg-orange-500/20', border: 'border-orange-500', icon: 'flame' },
    dance: { color: 'cyan', gradient: 'from-cyan-500 to-blue-500', bg: 'bg-cyan-500/20', border: 'border-cyan-500', icon: 'music' },
    spin: { color: 'green', gradient: 'from-green-500 to-emerald-500', bg: 'bg-green-500/20', border: 'border-green-500', icon: 'bike' },
    strength: { color: 'red', gradient: 'from-red-500 to-orange-500', bg: 'bg-red-500/20', border: 'border-red-500', icon: 'dumbbell' },
    stretch: { color: 'teal', gradient: 'from-teal-500 to-cyan-500', bg: 'bg-teal-500/20', border: 'border-teal-500', icon: 'move' },
    cardio: { color: 'yellow', gradient: 'from-yellow-500 to-orange-500', bg: 'bg-yellow-500/20', border: 'border-yellow-500', icon: 'footprints' }
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
    if (nameIcon) nameIcon.innerHTML = icon(config.icon, 20);

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

// Adjust capacity
window.adjustCapacity = function(delta) {
    const hidden = document.getElementById('course-max-capacity');
    const visibleInput = document.getElementById('course-capacity-input');
    const unlimitedBtn = document.getElementById('unlimited-capacity-btn');

    // If currently unlimited, set to a starting value
    if (hidden.value === '' || hidden.value === 'null') {
        hidden.value = '20';
    }

    let val = parseInt(hidden.value) || 20;
    val = Math.max(1, Math.min(500, val + delta));
    hidden.value = val;
    if (visibleInput) visibleInput.value = val;

    // Update unlimited button state
    if (unlimitedBtn) {
        unlimitedBtn.classList.remove('bg-green-500', 'text-white');
        unlimitedBtn.classList.add('bg-white/10', 'text-white/60');
    }
};

// Handle manual capacity typing
window.onCapacityInput = function(el) {
    const hidden = document.getElementById('course-max-capacity');
    const unlimitedBtn = document.getElementById('unlimited-capacity-btn');
    let val = parseInt(el.value);
    if (isNaN(val) || val < 1) val = 1;
    if (val > 500) val = 500;
    hidden.value = val;
    if (unlimitedBtn) {
        unlimitedBtn.classList.remove('bg-green-500', 'text-white');
        unlimitedBtn.classList.add('bg-white/10', 'text-white/60');
    }
};

// Toggle unlimited capacity
window.toggleUnlimitedCapacity = function() {
    const hidden = document.getElementById('course-max-capacity');
    const visibleInput = document.getElementById('course-capacity-input');
    const unlimitedBtn = document.getElementById('unlimited-capacity-btn');

    const isUnlimited = hidden.value === '' || hidden.value === 'null';

    if (isUnlimited) {
        // Switch to limited
        hidden.value = '20';
        if (visibleInput) { visibleInput.value = '20'; visibleInput.disabled = false; }
        if (unlimitedBtn) {
            unlimitedBtn.classList.remove('bg-green-500', 'text-white');
            unlimitedBtn.classList.add('bg-white/10', 'text-white/60');
        }
    } else {
        // Switch to unlimited
        hidden.value = '';
        if (visibleInput) { visibleInput.value = '∞'; visibleInput.disabled = true; }
        if (unlimitedBtn) {
            unlimitedBtn.classList.remove('bg-white/10', 'text-white/60');
            unlimitedBtn.classList.add('bg-green-500', 'text-white');
        }
    }
};

// Toggle waitlist
window.toggleWaitlist = function() {
    const input = document.getElementById('course-waitlist-enabled');
    const toggle = document.getElementById('waitlist-toggle');
    const dot = document.getElementById('waitlist-dot');

    const isEnabled = input.value === 'true';

    if (isEnabled) {
        // Switch to disabled
        input.value = 'false';
        toggle.classList.remove('bg-green-500');
        toggle.classList.add('bg-white/10');
        dot.style.right = 'auto';
        dot.style.left = '4px';
    } else {
        // Switch to enabled
        input.value = 'true';
        toggle.classList.remove('bg-white/10');
        toggle.classList.add('bg-green-500');
        dot.style.left = 'auto';
        dot.style.right = '4px';
    }
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
        icon.innerHTML = '<i data-lucide="lock" style="width:20px;height:20px;display:inline-block;vertical-align:middle;stroke:currentColor;"></i>';
        label.innerText = 'Private Course';
        desc.innerText = 'Only visible to you';
    } else {
        // Switch to shared
        input.value = 'true';
        toggle.classList.remove('bg-white/10');
        toggle.classList.add('bg-primary');
        dot.style.transform = 'translateX(20px)';
        icon.innerHTML = '<i data-lucide="users" style="width:20px;height:20px;display:inline-block;vertical-align:middle;stroke:currentColor;"></i>';
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
    if (nameIcon && typeof window.icon === 'function') {
        nameIcon.innerHTML = window.icon('heart', 20);
    } else if (nameIcon) {
        nameIcon.innerHTML = '<i data-lucide="heart" class="w-5 h-5"></i>';
    }

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
    if (icon) icon.innerHTML = '<i data-lucide="lock" style="width:20px;height:20px;display:inline-block;vertical-align:middle;stroke:currentColor;"></i>';
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
    console.log('[DEBUG] openCreateCourseModal called');
    try {
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

        // Reset capacity fields
        const capacityHidden = document.getElementById('course-max-capacity');
        const capacityVisible = document.getElementById('course-capacity-input');
        const unlimitedBtn = document.getElementById('unlimited-capacity-btn');
        const waitlistInput = document.getElementById('course-waitlist-enabled');
        const waitlistToggle = document.getElementById('waitlist-toggle');
        const waitlistDot = document.getElementById('waitlist-dot');

        if (capacityHidden) capacityHidden.value = '20';
        if (capacityVisible) { capacityVisible.value = '20'; capacityVisible.disabled = false; }
        if (unlimitedBtn) {
            unlimitedBtn.classList.remove('bg-green-500', 'text-white');
            unlimitedBtn.classList.add('bg-white/10', 'text-white/60');
        }
        if (waitlistInput) waitlistInput.value = 'true';
        if (waitlistToggle) {
            waitlistToggle.classList.remove('bg-white/10');
            waitlistToggle.classList.add('bg-green-500');
        }
        if (waitlistDot) {
            waitlistDot.style.left = 'auto';
            waitlistDot.style.right = '4px';
        }

        console.log('[DEBUG] Calling resetCourseModal');
        resetCourseModal();
        console.log('[DEBUG] Calling populateCourseTrainerProfile');
        populateCourseTrainerProfile();
        console.log('[DEBUG] Calling setupCourseNamePreviewListener');
        setupCourseNamePreviewListener();

        courseExercisesList = [];
        courseMusicLinks = [];
        console.log('[DEBUG] Calling renderCourseExercises');
        renderCourseExercises();
        console.log('[DEBUG] Calling renderMusicLinks');
        renderMusicLinks();

        console.log('[DEBUG] Calling showModal');
        showModal('create-course-modal');
        console.log('[DEBUG] Modal should be visible now');
    } catch (error) {
        console.error('[ERROR] Failed to open create course modal:', error);
        console.error('[ERROR] Stack:', error.stack);
        alert('Error opening create course modal. Check console for details.');
    }
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
            if (icon) icon.innerHTML = '<i data-lucide="users" style="width:20px;height:20px;display:inline-block;vertical-align:middle;stroke:currentColor;"></i>';
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

        // Set capacity fields
        const capacityHidden = document.getElementById('course-max-capacity');
        const capacityVisible = document.getElementById('course-capacity-input');
        const unlimitedBtn = document.getElementById('unlimited-capacity-btn');
        const waitlistInput = document.getElementById('course-waitlist-enabled');
        const waitlistToggle = document.getElementById('waitlist-toggle');
        const waitlistDot = document.getElementById('waitlist-dot');

        if (course.max_capacity !== null && course.max_capacity !== undefined) {
            if (capacityHidden) capacityHidden.value = course.max_capacity;
            if (capacityVisible) { capacityVisible.value = course.max_capacity; capacityVisible.disabled = false; }
            if (unlimitedBtn) {
                unlimitedBtn.classList.remove('bg-green-500', 'text-white');
                unlimitedBtn.classList.add('bg-white/10', 'text-white/60');
            }
        } else {
            // Unlimited
            if (capacityHidden) capacityHidden.value = '';
            if (capacityVisible) { capacityVisible.value = '∞'; capacityVisible.disabled = true; }
            if (unlimitedBtn) {
                unlimitedBtn.classList.remove('bg-white/10', 'text-white/60');
                unlimitedBtn.classList.add('bg-green-500', 'text-white');
            }
        }

        // Set waitlist toggle
        const waitlistEnabled = course.waitlist_enabled !== false;
        if (waitlistInput) waitlistInput.value = waitlistEnabled ? 'true' : 'false';
        if (waitlistToggle) {
            if (waitlistEnabled) {
                waitlistToggle.classList.remove('bg-white/10');
                waitlistToggle.classList.add('bg-green-500');
            } else {
                waitlistToggle.classList.remove('bg-green-500');
                waitlistToggle.classList.add('bg-white/10');
            }
        }
        if (waitlistDot) {
            if (waitlistEnabled) {
                waitlistDot.style.left = 'auto';
                waitlistDot.style.right = '4px';
            } else {
                waitlistDot.style.right = 'auto';
                waitlistDot.style.left = '4px';
            }
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

    // Get capacity and waitlist fields
    const capacityInput = document.getElementById('course-max-capacity');
    const maxCapacity = capacityInput && capacityInput.value !== '' ? parseInt(capacityInput.value) : null;
    const waitlistEnabled = document.getElementById('course-waitlist-enabled')?.value === 'true';

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
        trailer_url: trailerUrl,
        max_capacity: maxCapacity,
        waitlist_enabled: waitlistEnabled
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
                <span class="inline-block w-5 h-5 rounded-full ${link.type === 'spotify' ? 'bg-green-500' : 'bg-red-500'}"></span>
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
                <span class="mb-2 block opacity-30">${icon('footprints', 28)}</span>
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
    return icon(getExerciseCategoryIcon(cat), 18);
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
                    <span class="text-lg">${link.type === 'spotify' ? icon('music', 18) : icon('play', 18)}</span>
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
    musicPlaying: false,
    autoAdvance: true
};

// YouTube player instance (global)
let youtubePlayer = null;
let ytInitAttempts = 0;
const MAX_YT_INIT_ATTEMPTS = 10;

// Spotify player instance (global)
let spotifyPlayer = null;
let spotifyDeviceId = null;
let spotifyAccessToken = null;
let spotifyPlaybackStarted = false; // Track if we've started playback in this session

// Initialize YouTube player
function initYouTubePlayer(videoId, playlistId = null, retryCount = 0) {
    // Check if YT API is loaded
    if (typeof YT === 'undefined' || typeof YT.Player === 'undefined') {
        if (retryCount >= MAX_YT_INIT_ATTEMPTS) {
            console.warn('⚠️ YouTube API failed to load - using fallback iframe');
            console.warn('Note: Pause/Play controls will not work automatically');
            // Fallback to regular iframe
            useFallbackIframe(videoId, playlistId);
            return;
        }
        console.log('⏳ Waiting for YouTube API... (attempt', retryCount + 1, '/', MAX_YT_INIT_ATTEMPTS, ')');
        setTimeout(() => initYouTubePlayer(videoId, playlistId, retryCount + 1), 500);
        return;
    }

    try {
        console.log('🎬 Creating YouTube player for video:', videoId);
        youtubePlayer = new YT.Player('youtube-player-iframe', {
            height: '315',
            width: '100%',
            videoId: videoId,
            playerVars: {
                autoplay: 0,
                controls: 1,
                modestbranding: 1,
                rel: 0,
                listType: playlistId ? 'playlist' : null,
                list: playlistId
            },
            events: {
                onReady: (event) => {
                    console.log('✅ YouTube player initialized and ready!');
                },
                onError: (err) => {
                    console.error('❌ YouTube player error:', err);
                }
            }
        });
    } catch (error) {
        console.error('❌ Failed to initialize YouTube player:', error);
        useFallbackIframe(videoId, playlistId);
    }
}

// Fallback to regular iframe if YouTube API fails
function useFallbackIframe(videoId, playlistId = null) {
    const container = document.getElementById('youtube-player-iframe');
    if (!container) return;

    let embedUrl = `https://www.youtube.com/embed/${videoId}?autoplay=0&controls=1`;
    if (playlistId) {
        embedUrl += `&list=${playlistId}`;
    }

    container.innerHTML = `
        <iframe src="${embedUrl}" width="100%" height="315" frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen"
            allowfullscreen loading="eager" class="rounded-lg w-full"></iframe>
    `;
    console.log('📺 Fallback iframe loaded - manual controls only');
}

// Control YouTube playback
window.controlYouTubePlayer = function(action) {
    if (!youtubePlayer || !youtubePlayer.playVideo) {
        console.log('⚠️ YouTube player not ready');
        return;
    }

    try {
        if (action === 'play') {
            youtubePlayer.playVideo();
            console.log('▶️ Playing YouTube video');
        } else if (action === 'pause') {
            youtubePlayer.pauseVideo();
            console.log('⏸️ Paused YouTube video');
        } else if (action === 'stop') {
            youtubePlayer.stopVideo();
            console.log('⏹️ Stopped YouTube video');
        }
    } catch (error) {
        console.error('Error controlling YouTube player:', error);
    }
};

// Initialize Spotify Web Playback SDK
// Manually check and initialize Spotify player (fallback if SDK callback doesn't fire)
async function manuallyInitializeSpotify() {
    console.log('🔍 Checking if Spotify SDK is loaded...');

    if (typeof Spotify === 'undefined') {
        console.warn('❌ Spotify SDK not loaded yet');
        return false;
    }

    console.log('✅ Spotify SDK is loaded!');

    // Check if player already exists
    if (spotifyPlayer) {
        console.log('ℹ️ Spotify player already initialized');
        return true;
    }

    // Check if user is authenticated
    try {
        const response = await fetch('/api/spotify/status');
        const status = await response.json();

        console.log('📊 Spotify auth status:', status);

        if (!status.connected) {
            console.log('ℹ️ Spotify not connected - user needs to authenticate');
            return false;
        }

        if (status.expired) {
            console.log('⏳ Token expired - refreshing...');
            const refreshedToken = await refreshSpotifyToken();
            if (refreshedToken) {
                await initSpotifyPlayer(refreshedToken);
                return true;
            }
        } else if (status.access_token) {
            // Token is valid, initialize player
            console.log('🚀 Initializing Spotify player with token...');
            await initSpotifyPlayer(status.access_token);
            return true;
        }
    } catch (error) {
        console.error('❌ Error initializing Spotify:', error);
        return false;
    }
    return false;
}

// SDK callback (may not fire reliably)
window.onSpotifyWebPlaybackSDKReady = async function() {
    console.log('🎵 Spotify SDK ready (callback fired)');
    await manuallyInitializeSpotify();
};

// Aggressive fallback: Try to initialize after page load
setTimeout(async () => {
    console.log('⏰ Manual Spotify initialization timer fired');
    await manuallyInitializeSpotify();
}, 2000);

// Try again after 5 seconds if still not initialized
setTimeout(async () => {
    if (!spotifyPlayer) {
        console.log('⏰ Second attempt at Spotify initialization');
        await manuallyInitializeSpotify();
    }
}, 5000);

// Initialize Spotify player with access token
async function initSpotifyPlayer(token) {
    spotifyAccessToken = token;

    spotifyPlayer = new Spotify.Player({
        name: 'FitOS Gym App',
        getOAuthToken: cb => { cb(spotifyAccessToken); },
        volume: 0.8
    });

    // Player ready
    spotifyPlayer.addListener('ready', ({ device_id }) => {
        console.log('✅ Spotify player ready with device ID:', device_id);
        spotifyDeviceId = device_id;
    });

    // Player errors
    spotifyPlayer.addListener('initialization_error', ({ message }) => {
        console.error('❌ Spotify initialization error:', message);
    });

    spotifyPlayer.addListener('authentication_error', ({ message }) => {
        console.error('❌ Spotify authentication error:', message);
        refreshSpotifyToken();
    });

    spotifyPlayer.addListener('account_error', ({ message }) => {
        console.error('❌ Spotify account error:', message);
        showToast('Spotify Premium required for playback');
    });

    spotifyPlayer.addListener('playback_error', ({ message }) => {
        console.error('❌ Spotify playback error:', message);
    });

    // Player state changes - update UI
    spotifyPlayer.addListener('player_state_changed', (state) => {
        if (!state) return;
        updateSpotifyPlayerUI(state);
    });

    // Connect player
    const connected = await spotifyPlayer.connect();
    if (connected) {
        console.log('🎵 Spotify player connected!');
    }
}

// Update Spotify player UI with current track info
function updateSpotifyPlayerUI(state) {
    const container = document.getElementById('spotify-player-container');
    if (!container) return;

    const track = state.track_window.current_track;
    const isPaused = state.paused;
    const position = state.position;
    const duration = state.duration;

    // Calculate progress percentage
    const progressPercent = (position / duration) * 100;

    container.innerHTML = `
        <div class="bg-gradient-to-br from-green-500/20 to-green-600/20 rounded-lg p-4 border border-green-500/30">
            <!-- Album Art & Track Info -->
            <div class="flex items-center gap-3 mb-3">
                <img src="${track.album.images[0].url}" alt="${track.name}"
                     class="w-16 h-16 rounded-lg shadow-lg">
                <div class="flex-1 min-w-0">
                    <p class="text-white font-bold text-sm truncate">${track.name}</p>
                    <p class="text-white/60 text-xs truncate">${track.artists.map(a => a.name).join(', ')}</p>
                </div>
            </div>

            <!-- Progress Bar -->
            <div class="mb-3">
                <div class="bg-white/10 rounded-full h-1.5 overflow-hidden">
                    <div class="bg-green-500 h-full transition-all duration-300"
                         style="width: ${progressPercent}%"></div>
                </div>
                <div class="flex justify-between text-[10px] text-white/40 mt-1">
                    <span>${formatTime(position)}</span>
                    <span>${formatTime(duration)}</span>
                </div>
            </div>

            <!-- Controls -->
            <div class="flex gap-2">
                <button onclick="controlSpotifyPlayer('${isPaused ? 'play' : 'pause'}')"
                        class="flex-1 px-4 py-2 bg-green-600 hover:bg-green-700 text-white text-sm rounded-xl transition font-bold shadow-lg flex items-center justify-center gap-2">
                    <span class="text-lg">${isPaused ? '▶️' : '⏸️'}</span>
                    <span>${isPaused ? 'Play' : 'Pause'}</span>
                </button>
            </div>

            <!-- Status -->
            <p class="text-center text-[10px] text-green-400/70 mt-2">
                ✅ Connected • Playing from FitOS
            </p>
        </div>
    `;
}

// Format milliseconds to MM:SS
function formatTime(ms) {
    const seconds = Math.floor(ms / 1000);
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
}

// Refresh Spotify access token
async function refreshSpotifyToken() {
    try {
        const response = await fetch('/api/spotify/refresh', { method: 'POST' });
        const data = await response.json();
        spotifyAccessToken = data.access_token;
        console.log('✅ Spotify token refreshed');
        return data.access_token;
    } catch (error) {
        console.error('Failed to refresh Spotify token:', error);
        return null;
    }
}

// Play Spotify track/playlist (via our backend to avoid CORS)
async function playSpotifyUri(uri) {
    if (!spotifyDeviceId || !spotifyAccessToken) {
        console.warn('⚠️ Spotify player not ready');
        return;
    }

    try {
        const response = await fetch('/api/spotify/play', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                device_id: spotifyDeviceId,
                context_uri: uri
            })
        });

        if (!response.ok) {
            const error = await response.json();
            console.error('❌ Spotify play failed:', error);
            return;
        }

        console.log('▶️ Playing Spotify:', uri);
    } catch (error) {
        console.error('❌ Error playing Spotify:', error);
    }
}

// Control Spotify playback (via Web Playback SDK)
window.controlSpotifyPlayer = async function(action) {
    // Check if user is authenticated
    try {
        const response = await fetch('/api/spotify/status');
        const status = await response.json();

        if (!status.connected) {
            console.log('ℹ️ Spotify not connected');
            return;
        }
    } catch (error) {
        console.error('Error checking Spotify status:', error);
        return;
    }

    try {
        if (action === 'play') {
            console.log('🎵 Attempting to play Spotify:', {
                hasPlaylistUri: !!window.spotifyPlaylistUri,
                hasDeviceId: !!spotifyDeviceId,
                hasAccessToken: !!spotifyAccessToken,
                hasPlayer: !!spotifyPlayer,
                playbackStarted: spotifyPlaybackStarted,
                playlistUri: window.spotifyPlaylistUri
            });

            // If playback hasn't started yet, start the playlist from beginning
            if (!spotifyPlaybackStarted && window.spotifyPlaylistUri && spotifyDeviceId && spotifyAccessToken) {
                await playSpotifyUri(window.spotifyPlaylistUri);
                spotifyPlaybackStarted = true;
            } else if (spotifyPlayer) {
                // Otherwise just resume where we left off
                await spotifyPlayer.resume();
                console.log('▶️ Resumed Spotify');
            } else {
                console.warn('⚠️ Spotify player not ready yet. Missing:', {
                    playlistUri: !window.spotifyPlaylistUri ? 'MISSING' : 'OK',
                    deviceId: !spotifyDeviceId ? 'MISSING' : 'OK',
                    accessToken: !spotifyAccessToken ? 'MISSING' : 'OK',
                    player: !spotifyPlayer ? 'MISSING' : 'OK'
                });
            }
        } else if (action === 'pause') {
            if (spotifyPlayer) {
                await spotifyPlayer.pause();
                console.log('⏸️ Paused Spotify');
            }
        } else if (action === 'stop') {
            if (spotifyPlayer) {
                await spotifyPlayer.pause();
                console.log('⏹️ Stopped Spotify');
            }
        }
    } catch (error) {
        console.error('Error controlling Spotify player:', error);
    }
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

    // Reset Spotify playback flag for new class
    spotifyPlaybackStarted = false;

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

// Toggle music player visibility (global function)
window.toggleMusicPlayer = function(show) {
    // Check for both YouTube and Spotify containers
    const youtubeContainer = document.getElementById('youtube-player-container');
    const spotifyContainer = document.getElementById('spotify-player-container');
    const container = youtubeContainer || spotifyContainer;

    const hideBtn = document.getElementById('hide-music-btn');
    const showBtn = document.getElementById('show-music-btn');

    if (!container || !hideBtn || !showBtn) return;

    const playerType = youtubeContainer ? 'YouTube' : 'Spotify';

    if (show) {
        // Show player
        container.classList.remove('hidden');
        hideBtn.classList.remove('hidden');
        hideBtn.classList.add('flex');
        showBtn.classList.add('hidden');
        showBtn.classList.remove('flex');
        console.log(`🎵 ${playerType} player shown`);
    } else {
        // Hide player
        container.classList.add('hidden');
        hideBtn.classList.add('hidden');
        hideBtn.classList.remove('flex');
        showBtn.classList.remove('hidden');
        showBtn.classList.add('flex');
        console.log(`🔇 ${playerType} player hidden`);
    }
};

// Render music links in sidebar
function renderLiveMusicLinks() {
    const container = document.getElementById('live-music-container');
    if (!container) return;

    if (liveClassData.musicLinks.length === 0) {
        container.innerHTML = '<p class="text-xs text-gray-500 italic">No playlists added</p>';
        return;
    }

    // Show first playlist prominently with auto-play attempt
    const firstLink = liveClassData.musicLinks[0];
    const embedUrl = getMusicEmbedUrl(firstLink.url, firstLink.type, true);
    const platformIcon = firstLink.type === 'spotify' ? '🎵' : '▶️';

    const isYouTube = firstLink.type === 'youtube';

    let html = `
        <div class="bg-gradient-to-br from-purple-500/20 to-pink-500/20 rounded-xl p-4 border border-purple-500/30 mb-3">
            <div class="mb-3">
                <div class="text-sm font-bold text-white mb-2 text-center">${platformIcon} ${firstLink.title || 'Workout Mix'}</div>
                ${embedUrl ? (isYouTube ? `
                    <!-- YouTube Embedded Player Container -->
                    <div id="youtube-player-container">
                        <div class="bg-black/30 rounded-lg p-2 mb-3">
                            <!-- YouTube API will replace this div with iframe -->
                            <div id="youtube-player-iframe" class="rounded-lg w-full"></div>
                        </div>
                    </div>

                    <!-- Music Control Buttons -->
                    <div class="flex gap-2 mb-3">
                        <button id="hide-music-btn" onclick="toggleMusicPlayer(false)"
                                class="flex-1 px-4 py-3 bg-red-600 hover:bg-red-700 text-white text-sm rounded-xl transition font-bold shadow-lg flex items-center justify-center gap-2">
                            <span class="text-lg">⏹️</span>
                            <span>Hide Player (Stop Music)</span>
                        </button>
                        <button id="show-music-btn" onclick="toggleMusicPlayer(true)"
                                class="hidden flex-1 px-4 py-3 bg-green-600 hover:bg-green-700 text-white text-sm rounded-xl transition font-bold shadow-lg items-center justify-center gap-2">
                            <span class="text-lg">▶️</span>
                            <span>Show Player</span>
                        </button>
                        <a href="${firstLink.url}" target="_blank"
                           class="flex-1 px-4 py-3 bg-purple-600 hover:bg-purple-700 text-white text-sm rounded-xl transition font-bold shadow-lg flex items-center justify-center gap-2">
                            <span class="text-lg">🔗</span>
                            <span>Open in App</span>
                        </a>
                    </div>

                    <div class="text-center">
                        <p class="text-[10px] text-purple-300/70 mb-1">
                            <strong>How to use:</strong> Click ▶️ inside video player to start music
                        </p>
                        <p class="text-[10px] text-purple-300/50">
                            Hide Player = Stops music completely (click ▶️ in player to restart when shown again)
                        </p>
                    </div>
                ` : `
                    <!-- Spotify Web Player (SDK) -->
                    <div id="spotify-player-container" class="spotify-player-section">
                        <!-- Will be populated based on auth status -->
                        <div class="bg-black/30 rounded-lg p-4 mb-3 text-center">
                            <p class="text-white/60 text-sm mb-3">🎵 Spotify Web Player</p>
                            <p class="text-white/40 text-xs">Loading...</p>
                        </div>
                    </div>

                    <!-- Music Control Buttons -->
                    <div class="flex gap-2 mb-3" id="spotify-controls">
                        <a href="${firstLink.url}" target="_blank"
                           class="flex-1 px-4 py-3 bg-green-600 hover:bg-green-700 text-white text-sm rounded-xl transition font-bold shadow-lg flex items-center justify-center gap-2">
                            <span class="text-lg">🔗</span>
                            <span>Open in App</span>
                        </a>
                    </div>

                    <div class="text-center">
                        <p class="text-[10px] text-purple-300/70 mb-1">
                            <strong>Note:</strong> Spotify Premium required for web player
                        </p>
                        <p class="text-[10px] text-purple-300/50">
                            Connect Spotify below for automatic playback control
                        </p>
                    </div>
                `) : `
                    <!-- No embed available -->
                    <div class="text-center">
                        <a href="${firstLink.url}" target="_blank"
                           class="inline-block w-full px-4 py-3 bg-gradient-to-r ${isYouTube ? 'from-red-600 to-red-700 hover:from-red-700 hover:to-red-800' : 'from-green-500 to-green-600 hover:from-green-600 hover:to-green-700'} text-white text-sm rounded-xl transition font-bold shadow-lg">
                            ▶️ Open in ${isYouTube ? 'YouTube' : 'Spotify'}
                        </a>
                    </div>
                `}
            </div>
        </div>
    `;

    // Show other playlists if any
    if (liveClassData.musicLinks.length > 1) {
        html += '<div class="text-[10px] text-gray-500 uppercase tracking-wider mb-2">Other Playlists</div>';
        html += liveClassData.musicLinks.slice(1).map((link, i) => {
            const icon = link.type === 'spotify' ? '🎵' : '▶️';
            return `
                <a href="${link.url}" target="_blank"
                   class="block bg-white/5 hover:bg-white/10 rounded-lg p-2 mb-1 transition">
                    <div class="flex items-center justify-between">
                        <span class="text-xs text-white truncate">${icon} ${link.title || 'Playlist ' + (i+2)}</span>
                        <span class="text-xs text-primary">→</span>
                    </div>
                </a>
            `;
        }).join('');
    }

    container.innerHTML = html;

    // Initialize YouTube player with API if it's a YouTube video
    if (isYouTube && embedUrl) {
        setTimeout(() => {
            // Extract video ID and playlist ID from embed URL
            const videoIdMatch = embedUrl.match(/embed\/([a-zA-Z0-9_-]+)/);
            const playlistMatch = embedUrl.match(/[?&]list=([a-zA-Z0-9_-]+)/);

            if (videoIdMatch) {
                const videoId = videoIdMatch[1];
                const playlistId = playlistMatch ? playlistMatch[1] : null;
                console.log('🎵 Initializing YouTube player - Video:', videoId, 'Playlist:', playlistId || 'none');
                initYouTubePlayer(videoId, playlistId, 0);
            } else {
                console.error('❌ Could not extract video ID from:', embedUrl);
            }
        }, 1000); // Wait 1 second for YouTube API to load
    }

    // Check Spotify authentication and update UI
    if (!isYouTube && firstLink.type === 'spotify') {
        setTimeout(async () => {
            await checkSpotifyAuthAndUpdateUI(firstLink.url);
        }, 100);
    }
}

// Check Spotify auth status and update UI
async function checkSpotifyAuthAndUpdateUI(playlistUrl) {
    const container = document.getElementById('spotify-player-container');
    const controlsDiv = document.getElementById('spotify-controls');
    if (!container) return;

    try {
        const response = await fetch('/api/spotify/status');
        const status = await response.json();

        if (!status.connected) {
            // Not connected - show Connect button
            container.innerHTML = `
                <div class="bg-gradient-to-br from-green-500/20 to-green-600/20 rounded-lg p-6 mb-3 text-center border-2 border-green-500/30">
                    <div class="text-4xl mb-3">🎵</div>
                    <p class="text-white font-bold mb-2">Connect Spotify</p>
                    <p class="text-white/60 text-xs mb-4">
                        Link your Spotify Premium account for automatic music control
                    </p>
                    <a href="/api/spotify/authorize"
                       class="inline-block px-6 py-3 bg-green-600 hover:bg-green-700 text-white text-sm rounded-xl transition font-bold shadow-lg">
                        🔗 Connect Spotify Premium
                    </a>
                </div>
            `;
        } else if (status.expired) {
            // Token expired - refresh it
            console.log('⏳ Refreshing Spotify token...');
            await refreshSpotifyToken();
            await checkSpotifyAuthAndUpdateUI(playlistUrl); // Retry
        } else {
            // Connected - show ready state with playlist info
            // Extract playlist URI from URL
            const playlistMatch = playlistUrl.match(/playlist\/([a-zA-Z0-9]+)/);
            if (playlistMatch) {
                const playlistId = playlistMatch[1];
                window.spotifyPlaylistUri = `spotify:playlist:${playlistId}`;
                console.log('🎵 Spotify playlist ready:', window.spotifyPlaylistUri);
            }

            // Show ready state (will be replaced when music starts playing)
            container.innerHTML = `
                <div class="bg-gradient-to-br from-green-500/20 to-green-600/20 rounded-lg p-4 border border-green-500/30">
                    <div class="text-center mb-3">
                        <div class="text-4xl mb-2">🎵</div>
                        <p class="text-green-400 font-bold mb-1">✅ Spotify Ready</p>
                        <p class="text-white/60 text-xs">
                            Music will play automatically when you start the workout
                        </p>
                    </div>
                    <button onclick="disconnectSpotify()"
                            class="w-full text-xs text-white/50 hover:text-white/80 underline">
                        Disconnect Spotify
                    </button>
                </div>
            `;

            // Manually initialize Spotify player if SDK is loaded but player not created yet
            if (!spotifyPlayer && status.access_token) {
                console.log('🔧 Manually initializing Spotify player...');
                if (typeof Spotify !== 'undefined') {
                    await initSpotifyPlayer(status.access_token);
                } else {
                    console.log('⏳ Waiting for Spotify SDK to load...');
                    // Retry after SDK loads
                    setTimeout(() => {
                        if (typeof Spotify !== 'undefined' && !spotifyPlayer) {
                            initSpotifyPlayer(status.access_token);
                        }
                    }, 2000);
                }
            }
        }
    } catch (error) {
        console.error('Error checking Spotify status:', error);
        container.innerHTML = `
            <div class="bg-red-500/20 rounded-lg p-4 text-center border border-red-500/30">
                <p class="text-red-400 text-sm">⚠️ Error connecting to Spotify</p>
            </div>
        `;
    }
}

// Disconnect Spotify
window.disconnectSpotify = async function() {
    if (!confirm('Disconnect Spotify?')) return;

    try {
        await fetch('/api/spotify/disconnect', { method: 'POST' });
        showToast('Spotify disconnected');
        // Refresh the UI
        location.reload();
    } catch (error) {
        console.error('Error disconnecting Spotify:', error);
        showToast('Failed to disconnect Spotify', 'error');
    }
}

// Get embed URL for music services
function getMusicEmbedUrl(url, type, autoplay = false) {
    if (!url) return null;

    if (type === 'spotify') {
        // Convert spotify URL to embed
        // https://open.spotify.com/playlist/xxx -> https://open.spotify.com/embed/playlist/xxx
        const match = url.match(/spotify\.com\/(playlist|album|track)\/([a-zA-Z0-9]+)/);
        if (match) {
            const autoplayParam = autoplay ? '&autoplay=1' : '';
            return `https://open.spotify.com/embed/${match[1]}/${match[2]}?utm_source=generator&theme=0${autoplayParam}`;
        }
    } else if (type === 'youtube') {
        // Convert youtube/youtube music URL to embed
        // Supports: youtube.com, music.youtube.com, youtu.be
        let videoId = null;
        let playlistId = null;

        // Extract playlist ID from any YouTube URL format
        if (url.includes('list=')) {
            const match = url.match(/list=([a-zA-Z0-9_-]+)/);
            if (match) playlistId = match[1];
        }

        // Extract video ID from various YouTube URL formats
        if (url.includes('v=')) {
            const match = url.match(/[?&]v=([a-zA-Z0-9_-]+)/);
            if (match) videoId = match[1];
        } else if (url.includes('youtu.be/')) {
            const match = url.match(/youtu\.be\/([a-zA-Z0-9_-]+)/);
            if (match) videoId = match[1];
        } else if (url.includes('music.youtube.com/watch')) {
            const match = url.match(/watch[?&]v=([a-zA-Z0-9_-]+)/);
            if (match) videoId = match[1];
        }

        // Build embed URL with playlist or video
        const autoplayParam = autoplay ? '1' : '0';
        if (playlistId && videoId) {
            // If both playlist and video, embed playlist starting with specific video
            return `https://www.youtube.com/embed/${videoId}?list=${playlistId}&autoplay=${autoplayParam}`;
        } else if (playlistId) {
            // Just playlist
            return `https://www.youtube.com/embed/videoseries?list=${playlistId}&autoplay=${autoplayParam}`;
        } else if (videoId) {
            // Just video
            return `https://www.youtube.com/embed/${videoId}?autoplay=${autoplayParam}`;
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
                <span class="block mb-2">${icon('dumbbell', 48)}</span>
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
    document.getElementById('timer-toggle-btn').innerHTML = icon('pause', 16) + ' Pause';
    document.getElementById('timer-toggle-btn').classList.remove('bg-green-600', 'hover:bg-green-700');
    document.getElementById('timer-toggle-btn').classList.add('bg-yellow-600', 'hover:bg-yellow-700');

    // Show music player and play video when starting workout
    if (typeof window.toggleMusicPlayer === 'function') {
        window.toggleMusicPlayer(true);
    }
    if (typeof window.controlYouTubePlayer === 'function') {
        window.controlYouTubePlayer('play');
    }
    if (typeof window.controlSpotifyPlayer === 'function') {
        window.controlSpotifyPlayer('play');
    }

    liveClassData.timerInterval = setInterval(() => {
        liveClassData.timerSeconds--;
        updateTimerDisplay();

        if (liveClassData.timerSeconds <= 0) {
            stopTimer();
            playTimerEndSound();

            // Auto-advance to next exercise if enabled
            if (liveClassData.autoAdvance && liveClassData.currentExerciseIndex < liveClassData.exercises.length - 1) {
                showToast('Moving to next exercise...');
                setTimeout(() => {
                    nextExercise();
                }, 1500);
            } else if (liveClassData.autoAdvance && liveClassData.currentExerciseIndex >= liveClassData.exercises.length - 1) {
                showToast('Workout complete!', 'success');
            } else {
                showToast('Timer complete!');
            }
        }
    }, 1000);
}

function stopTimer() {
    liveClassData.timerRunning = false;
    if (liveClassData.timerInterval) {
        clearInterval(liveClassData.timerInterval);
        liveClassData.timerInterval = null;
    }
    document.getElementById('timer-toggle-btn').innerHTML = icon('play', 16) + ' Start';
    document.getElementById('timer-toggle-btn').classList.remove('bg-yellow-600', 'hover:bg-yellow-700');
    document.getElementById('timer-toggle-btn').classList.add('bg-green-600', 'hover:bg-green-700');

    // Pause media players when timer stops
    if (typeof window.controlYouTubePlayer === 'function') {
        window.controlYouTubePlayer('pause');
    }
    if (typeof window.controlSpotifyPlayer === 'function') {
        window.controlSpotifyPlayer('pause');
    }
}

window.resetTimer = function() {
    stopTimer();
    const exercise = liveClassData.exercises[liveClassData.currentExerciseIndex];
    liveClassData.timerSeconds = exercise?.rest || 60;
    updateTimerDisplay();

    // Stop and hide music player when resetting workout
    if (typeof window.controlYouTubePlayer === 'function') {
        window.controlYouTubePlayer('stop');
    }
    if (typeof window.controlSpotifyPlayer === 'function') {
        window.controlSpotifyPlayer('stop');
    }
    if (typeof window.toggleMusicPlayer === 'function') {
        window.toggleMusicPlayer(false);
    }
};

window.toggleAutoAdvance = function() {
    liveClassData.autoAdvance = !liveClassData.autoAdvance;
    const toggle = document.getElementById('auto-advance-toggle');
    if (toggle) {
        toggle.classList.toggle('bg-primary', liveClassData.autoAdvance);
        toggle.classList.toggle('bg-white/20', !liveClassData.autoAdvance);
        toggle.querySelector('span').classList.toggle('translate-x-5', liveClassData.autoAdvance);
        toggle.querySelector('span').classList.toggle('translate-x-0', !liveClassData.autoAdvance);
    }
    showToast(liveClassData.autoAdvance ? 'Auto-advance enabled' : 'Auto-advance disabled');
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

    // Stop and hide music player when ending class
    if (typeof window.controlYouTubePlayer === 'function') {
        window.controlYouTubePlayer('stop');
    }
    if (typeof window.controlSpotifyPlayer === 'function') {
        window.controlSpotifyPlayer('stop');
    }
    if (typeof window.toggleMusicPlayer === 'function') {
        window.toggleMusicPlayer(false);
    }

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
    const key = (category || '').toLowerCase();
    const m = EXERCISE_CATEGORY_MAP[key];
    if (m) return { emoji: icon(m.icon, 18), label: m.label };
    return { emoji: icon('footprints', 18), label: 'General' };
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
                <p class="mb-2">${icon('heart', 32)}</p>
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
    document.getElementById('course-exercise-detail-category').innerHTML = `${catInfo.emoji} ${catInfo.label}`;
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

// =====================================================
// SUBSCRIPTION / STRIPE INTEGRATION
// =====================================================

let stripeInstance = null;
let cardElement = null;
let selectedPlanId = null;
let currentSubscription = null;
let selectedPlanData = null;  // Store full plan data
let appliedOffer = null;  // Store applied coupon/offer
let activeOffers = [];  // Available offers

// Initialize Stripe
function initStripe() {
    const { stripePublishableKey } = window.APP_CONFIG || {};
    if (stripePublishableKey && typeof Stripe !== 'undefined') {
        stripeInstance = Stripe(stripePublishableKey);
        console.log('Stripe initialized');
    } else {
        console.log('Stripe not configured or Stripe.js not loaded');
    }
}

// Open subscription plans modal
window.openSubscriptionPlans = async function() {
    showModal('subscription-plans-modal');
    await loadSubscriptionPlans();
};

// Load available subscription plans
async function loadSubscriptionPlans() {
    const plansList = document.getElementById('subscription-plans-list');
    const currentBanner = document.getElementById('current-subscription-banner');

    if (!plansList) return;

    // Show loading
    plansList.innerHTML = `
        <div class="text-center py-8 text-white/50">
            ${icon('loader-2', 32, 'animate-spin')}
            <p class="mt-2">Loading plans...</p>
        </div>
    `;

    try {
        // First check if client has a gym
        if (!window.clientGymId) {
            plansList.innerHTML = `
                <div class="text-center py-8">
                    <span class="mb-4 block">${icon('building', 48)}</span>
                    <p class="text-white/60">You need to join a gym first to view subscription plans.</p>
                </div>
            `;
            currentBanner.classList.add('hidden');
            return;
        }

        // Load current subscription
        const subRes = await fetch(`${apiBase}/api/client/subscription/${window.clientGymId}`, {
            credentials: 'include'
        });

        if (subRes.ok) {
            const subData = await subRes.json();
            if (subData && subData.status === 'active') {
                currentSubscription = subData;
                currentBanner.classList.remove('hidden');
                document.getElementById('current-plan-name').textContent = subData.plan_name || 'Active Plan';
            } else {
                currentSubscription = null;
                currentBanner.classList.add('hidden');
            }
        } else {
            currentSubscription = null;
            currentBanner.classList.add('hidden');
        }

        // Load available plans
        const res = await fetch(`${apiBase}/api/client/subscription-plans/${window.clientGymId}`, {
            credentials: 'include'
        });

        if (!res.ok) throw new Error('Failed to load plans');

        const plans = await res.json();

        if (!plans || plans.length === 0) {
            plansList.innerHTML = `
                <div class="text-center py-8">
                    <span class="mb-4 block">${icon('clipboard', 40)}</span>
                    <p class="text-white/60">No subscription plans available at this gym yet.</p>
                </div>
            `;
            return;
        }

        // Load active offers
        try {
            const offersRes = await fetch(`${apiBase}/api/client/offers/${window.clientGymId}`, {
                credentials: 'include'
            });
            if (offersRes.ok) {
                activeOffers = await offersRes.json();
                displayOffersBanner(activeOffers);
            }
        } catch (offersErr) {
            console.log('No offers available:', offersErr);
            activeOffers = [];
        }

        // Render plans with any applicable offers
        plansList.innerHTML = plans.map(plan => {
            const isCurrentPlan = currentSubscription && currentSubscription.plan_id === plan.id;
            const features = plan.features || [];

            // Check if there's an offer for this plan
            const planOffer = activeOffers.find(o => !o.plan_id || o.plan_id === plan.id);
            const hasOffer = planOffer && !isCurrentPlan;

            return `
                <div class="relative p-4 rounded-2xl border ${isCurrentPlan ? 'border-green-500/50 bg-green-500/10' : hasOffer ? 'border-green-500/30 bg-gradient-to-r from-green-500/5 to-transparent' : 'border-white/10 bg-white/5'} hover:bg-white/10 transition cursor-pointer group"
                    onclick="${isCurrentPlan ? '' : `selectPlan('${plan.id}', '${plan.name}', ${plan.price}, '${plan.currency}', '${plan.billing_interval}')`}">
                    ${isCurrentPlan ? '<div class="absolute top-2 right-2 text-xs bg-green-500 text-white px-2 py-0.5 rounded-full">Current</div>' : ''}
                    ${hasOffer ? `<div class="absolute top-2 right-2 text-xs bg-green-500 text-white px-2 py-0.5 rounded-full animate-pulse">${icon('gift', 12)} ${planOffer.discount_type === 'percent' ? planOffer.discount_value + '% OFF' : '€' + planOffer.discount_value + ' OFF'}</div>` : ''}
                    <div class="flex justify-between items-start mb-3">
                        <div>
                            <h3 class="font-bold text-lg text-white">${plan.name}</h3>
                            <p class="text-sm text-white/50">${plan.description || ''}</p>
                        </div>
                        <div class="text-right">
                            <div class="text-2xl font-bold text-primary">${formatCurrency(plan.price, plan.currency)}</div>
                            <div class="text-xs text-white/40">/${plan.billing_interval}</div>
                        </div>
                    </div>
                    ${features.length > 0 ? `
                        <ul class="space-y-1 mt-3">
                            ${features.map(f => `<li class="text-sm text-white/70 flex items-center gap-2"><span class="text-green-400">✓</span> ${f}</li>`).join('')}
                        </ul>
                    ` : ''}
                    ${hasOffer && planOffer.coupon_code ? `
                        <div class="mt-3 text-xs text-green-400">
                            Use code: <span class="font-mono bg-green-500/20 px-2 py-0.5 rounded">${planOffer.coupon_code}</span>
                        </div>
                    ` : ''}
                    ${!isCurrentPlan ? `
                        <div class="mt-4 opacity-0 group-hover:opacity-100 transition">
                            <div class="text-center text-sm text-primary font-semibold">Click to subscribe →</div>
                        </div>
                    ` : ''}
                </div>
            `;
        }).join('');

    } catch (e) {
        console.error('Error loading plans:', e);
        plansList.innerHTML = `
            <div class="text-center py-8">
                <span class="mb-4 block">${icon('alert-triangle', 40)}</span>
                <p class="text-red-400">Failed to load subscription plans</p>
                <button onclick="loadSubscriptionPlans()" class="mt-4 text-sm text-primary hover:underline">Try again</button>
            </div>
        `;
    }
}

// Format currency
function formatCurrency(amount, currency = 'USD') {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: currency.toUpperCase()
    }).format(amount);
}

// Display offers banner
function displayOffersBanner(offers) {
    const banner = document.getElementById('active-offers-banner');
    if (!banner) return;

    if (offers && offers.length > 0) {
        const firstOffer = offers[0];
        document.getElementById('offer-banner-title').textContent = firstOffer.title;
        document.getElementById('offer-banner-description').textContent =
            firstOffer.description || `Get ${firstOffer.discount_value}${firstOffer.discount_type === 'percent' ? '%' : '€'} off!`;
        banner.classList.remove('hidden');
    } else {
        banner.classList.add('hidden');
    }
}

// Apply coupon code
window.applyCouponCode = async function() {
    const codeInput = document.getElementById('coupon-code-input');
    const messageEl = document.getElementById('coupon-message');

    if (!codeInput || !messageEl) return;

    const code = codeInput.value.trim().toUpperCase();
    if (!code) {
        messageEl.textContent = 'Please enter a coupon code';
        messageEl.className = 'text-xs mt-2 text-yellow-400';
        messageEl.classList.remove('hidden');
        return;
    }

    try {
        const res = await fetch(`${apiBase}/api/client/validate-coupon`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
                gym_id: window.clientGymId,
                coupon_code: code,
                plan_id: selectedPlanId
            })
        });

        const data = await res.json();

        if (data.valid) {
            appliedOffer = data;
            messageEl.textContent = `✓ ${data.title} applied!`;
            messageEl.className = 'text-xs mt-2 text-green-400';
            messageEl.classList.remove('hidden');

            // Update price display
            updatePriceWithDiscount();
        } else {
            appliedOffer = null;
            messageEl.textContent = data.error || 'Invalid coupon code';
            messageEl.className = 'text-xs mt-2 text-red-400';
            messageEl.classList.remove('hidden');

            // Reset price display
            resetPriceDisplay();
        }
    } catch (e) {
        console.error('Error validating coupon:', e);
        messageEl.textContent = 'Error validating coupon';
        messageEl.className = 'text-xs mt-2 text-red-400';
        messageEl.classList.remove('hidden');
    }
};

// Update price display with discount
function updatePriceWithDiscount() {
    if (!selectedPlanData || !appliedOffer) return;

    const priceEl = document.getElementById('selected-plan-price');
    const originalPriceEl = document.getElementById('selected-plan-original-price');
    const discountInfoEl = document.getElementById('applied-discount-info');
    const discountTextEl = document.getElementById('applied-discount-text');

    const originalPrice = selectedPlanData.price;
    let discountedPrice;

    if (appliedOffer.discount_type === 'percent') {
        discountedPrice = originalPrice * (1 - appliedOffer.discount_value / 100);
    } else {
        discountedPrice = Math.max(0, originalPrice - appliedOffer.discount_value);
    }

    // Show discounted price
    priceEl.textContent = `${formatCurrency(discountedPrice, selectedPlanData.currency)}/${selectedPlanData.interval}`;
    priceEl.classList.add('text-green-400');

    // Show original price crossed out
    originalPriceEl.textContent = formatCurrency(originalPrice, selectedPlanData.currency);
    originalPriceEl.classList.remove('hidden');

    // Show discount info
    discountTextEl.textContent = `${appliedOffer.title} - ${appliedOffer.discount_value}${appliedOffer.discount_type === 'percent' ? '%' : '€'} off for ${appliedOffer.discount_duration_months} month(s)`;
    discountInfoEl.classList.remove('hidden');
}

// Reset price display
function resetPriceDisplay() {
    if (!selectedPlanData) return;

    const priceEl = document.getElementById('selected-plan-price');
    const originalPriceEl = document.getElementById('selected-plan-original-price');
    const discountInfoEl = document.getElementById('applied-discount-info');

    priceEl.textContent = `${formatCurrency(selectedPlanData.price, selectedPlanData.currency)}/${selectedPlanData.interval}`;
    priceEl.classList.remove('text-green-400');
    originalPriceEl.classList.add('hidden');
    discountInfoEl.classList.add('hidden');
}

// Select a plan and show payment form
window.selectPlan = function(planId, planName, price, currency, interval) {
    if (!stripeInstance) {
        initStripe();
        if (!stripeInstance) {
            showToast('Payment system not configured', 'error');
            return;
        }
    }

    selectedPlanId = planId;

    // Store plan data for discount calculations
    selectedPlanData = {
        id: planId,
        name: planName,
        price: price,
        currency: currency,
        interval: interval
    };

    // Reset coupon state
    appliedOffer = null;
    const couponInput = document.getElementById('coupon-code-input');
    const couponMessage = document.getElementById('coupon-message');
    if (couponInput) couponInput.value = '';
    if (couponMessage) couponMessage.classList.add('hidden');

    // Reset discount display
    const originalPriceEl = document.getElementById('selected-plan-original-price');
    const discountInfoEl = document.getElementById('applied-discount-info');
    if (originalPriceEl) originalPriceEl.classList.add('hidden');
    if (discountInfoEl) discountInfoEl.classList.add('hidden');

    // Check if there's an auto-applicable offer for this plan
    const autoOffer = activeOffers.find(o => (!o.plan_id || o.plan_id === planId) && o.coupon_code);
    if (autoOffer && autoOffer.coupon_code) {
        // Pre-fill the coupon code
        if (couponInput) couponInput.value = autoOffer.coupon_code;
    }

    // Update UI
    document.getElementById('subscription-plans-list').classList.add('hidden');
    document.getElementById('active-offers-banner')?.classList.add('hidden');
    document.getElementById('payment-form-section').classList.remove('hidden');
    document.getElementById('selected-plan-name').textContent = planName;
    document.getElementById('selected-plan-price').textContent = `${formatCurrency(price, currency)}/${interval}`;

    // Initialize Stripe Elements
    if (!cardElement) {
        const elements = stripeInstance.elements();
        cardElement = elements.create('card', {
            style: {
                base: {
                    color: '#ffffff',
                    fontFamily: 'Inter, sans-serif',
                    fontSize: '16px',
                    '::placeholder': {
                        color: '#6b7280'
                    }
                },
                invalid: {
                    color: '#f87171'
                }
            }
        });
        cardElement.mount('#card-element');

        // Handle errors
        cardElement.on('change', function(event) {
            const errorEl = document.getElementById('card-errors');
            if (event.error) {
                errorEl.textContent = event.error.message;
                errorEl.classList.remove('hidden');
            } else {
                errorEl.classList.add('hidden');
            }
        });
    }
};

// Cancel payment form and go back to plans
window.cancelPaymentForm = function() {
    document.getElementById('payment-form-section').classList.add('hidden');
    document.getElementById('subscription-plans-list').classList.remove('hidden');

    // Show offers banner again if there are offers
    if (activeOffers && activeOffers.length > 0) {
        document.getElementById('active-offers-banner')?.classList.remove('hidden');
    }

    // Reset state
    selectedPlanId = null;
    selectedPlanData = null;
    appliedOffer = null;
};

// Process subscription
window.processSubscription = async function() {
    if (!selectedPlanId || !cardElement || !stripeInstance) {
        showToast('Please select a plan', 'error');
        return;
    }

    const button = document.getElementById('subscribe-button');
    const buttonText = document.getElementById('subscribe-button-text');
    const spinner = document.getElementById('subscribe-spinner');

    // Disable button and show loading
    button.disabled = true;
    buttonText.textContent = 'Processing...';
    spinner.classList.remove('hidden');

    try {
        // Create payment method
        const { paymentMethod, error } = await stripeInstance.createPaymentMethod({
            type: 'card',
            card: cardElement
        });

        if (error) {
            throw new Error(error.message);
        }

        // Send to backend (include coupon if applied)
        const subscribePayload = {
            plan_id: selectedPlanId,
            payment_method_id: paymentMethod.id
        };
        if (appliedOffer && appliedOffer.coupon_code) {
            subscribePayload.coupon_code = appliedOffer.coupon_code;
        }

        const res = await fetch(`${apiBase}/api/client/subscribe`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify(subscribePayload)
        });

        const data = await res.json();

        if (!res.ok) {
            throw new Error(data.detail || 'Subscription failed');
        }

        // Handle 3D Secure if needed
        if (data.status === 'requires_action' && data.client_secret) {
            const { error: confirmError } = await stripeInstance.confirmCardPayment(data.client_secret);
            if (confirmError) {
                throw new Error(confirmError.message);
            }
        }

        // Success!
        showToast('Subscription activated!', 'success');
        hideModal('subscription-plans-modal');

        // Reset state
        selectedPlanId = null;
        cancelPaymentForm();

        // Reload client data to reflect subscription
        if (typeof loadClientData === 'function') {
            loadClientData();
        }

    } catch (e) {
        console.error('Subscription error:', e);
        showToast(e.message || 'Subscription failed', 'error');
    } finally {
        // Re-enable button
        button.disabled = false;
        buttonText.textContent = 'Subscribe Now';
        spinner.classList.add('hidden');
    }
};

// Show cancel subscription confirmation
window.showCancelSubscriptionConfirm = function() {
    showModal('cancel-subscription-modal');
};

// Confirm cancel subscription
window.confirmCancelSubscription = async function() {
    try {
        const res = await fetch(`${apiBase}/api/client/cancel-subscription`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
                gym_id: window.clientGymId,
                cancel_immediately: false
            })
        });

        if (!res.ok) {
            const data = await res.json();
            throw new Error(data.detail || 'Failed to cancel');
        }

        showToast('Subscription will be cancelled at the end of billing period', 'success');
        hideModal('cancel-subscription-modal');

        // Reload plans to update UI
        await loadSubscriptionPlans();

    } catch (e) {
        console.error('Cancel error:', e);
        showToast(e.message || 'Failed to cancel subscription', 'error');
    }
};

// Initialize Stripe when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initStripe);
} else {
    initStripe();
}
