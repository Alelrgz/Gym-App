/**
 * Modals Module
 * Handles modal visibility, toast notifications, and global action listeners
 */

// Show modal by ID
export function showModal(id) {
    const el = document.getElementById(id);
    if (el) {
        el.classList.remove('hidden');
    } else {
        console.error("Modal not found:", id);
    }
}

// Hide modal by ID
export function hideModal(id) {
    const el = document.getElementById(id);
    if (el) {
        el.classList.add('hidden');
    }
}

// Show toast notification
export function showToast(message, duration = 3000) {
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
}

// Setup global action listener for data-action attributes
export function setupGlobalActionListener() {
    document.addEventListener('click', (e) => {
        const trigger = e.target.closest('[data-action]');
        if (trigger) {
            const action = trigger.dataset.action;
            const target = trigger.dataset.target;

            if (action === 'showModal' && target) {
                showModal(target);
            } else if (action === 'hideModal' && target) {
                hideModal(target);
            } else if (action === 'showToast') {
                const msg = trigger.dataset.message;
                if (msg) showToast(msg);
            }
        }
    });
}

// Make functions globally available for HTML onclick handlers
window.showModal = showModal;
window.hideModal = hideModal;
window.showToast = showToast;
