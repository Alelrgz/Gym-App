
import { assignWorkout } from './api.js';

// Toast Notification System
export function showToast(msg) {
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

// Modal System
export function showModal(id) {
    const modal = document.getElementById(id);
    if (modal) modal.classList.remove('hidden');
}

export function hideModal(id) {
    const modal = document.getElementById(id);
    if (modal) modal.classList.add('hidden');
}

export function startConfetti() {
    const container = document.getElementById('confetti-container');
    if (!container) return;

    container.innerHTML = '';
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

export function showClientModal(name, plan, status) {
    document.getElementById('modal-client-name').innerText = name;
    document.getElementById('modal-client-plan').innerText = plan;
    const statusEl = document.getElementById('modal-client-status');
    statusEl.innerText = status;
    statusEl.className = `text-lg font-bold ${status === 'At Risk' ? 'text-red-400' : 'text-green-400'}`;

    // Inject Assign Workout UI
    const container = document.querySelector('#client-modal .space-y-4');
    // Remove existing assign UI if any to prevent duplicates
    const existingAssign = document.getElementById('assign-workout-container');
    if (existingAssign) existingAssign.remove();

    const assignDiv = document.createElement('div');
    assignDiv.id = 'assign-workout-container';
    assignDiv.className = "bg-white/5 p-4 rounded-xl mt-4";
    assignDiv.innerHTML = `
        <p class="text-xs text-gray-400 uppercase mb-2">Assign Workout</p>
        <div class="flex space-x-2">
            <select id="workout-select" class="flex-1 bg-black/30 text-white text-sm rounded-lg px-3 py-2 border border-white/10 outline-none focus:border-primary">
                <option value="Push">Push Day</option>
                <option value="Pull">Pull Day</option>
                <option value="Legs">Leg Day</option>
                <option value="Cardio">Cardio</option>
            </select>
            <button data-action="assignWorkout" data-client="${name}" class="bg-primary text-white font-bold px-4 py-2 rounded-lg text-sm tap-effect">Assign</button>
        </div>
    `;

    // Insert before the Message button (last child)
    container.insertBefore(assignDiv, container.lastElementChild);

    showModal('client-modal');
}

// Quick Actions
export function quickAction(action) {
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
export function addPhoto() {
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

// Hydration
export function addWater() {
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

// Quests
export function toggleQuest(el) {
    const check = el.querySelector('.rounded-full');
    const isComplete = check.classList.contains('bg-yellow-400');

    if (!isComplete) {
        check.classList.add('bg-yellow-400', 'text-black', 'border-none');
        check.innerText = '✓';
        el.style.borderColor = "rgba(255, 255, 0, 0.3)";

        // Celebration
        const reward = el.querySelector('.text-yellow-500').innerText;
        showToast(`Quest Complete! ${reward} 🔶`);

        // Update gems (mock)
        const gemEl = document.getElementById('gem-count');
        if (gemEl) {
            let gems = parseInt(gemEl.innerText);
            gemEl.innerText = gems + parseInt(reward.replace('+', ''));
        }
    }
}
