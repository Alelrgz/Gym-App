/**
 * icons.js - Centralized Lucide icon system for FitOS
 * Provides icon() helper and consolidated config maps.
 * Loaded BEFORE app.js; requires Lucide CDN in base.html.
 */

// --- ICON HELPER ---
/**
 * Returns an <i data-lucide="..."> tag string for use in innerHTML / template literals.
 * After insertion, the MutationObserver (below) auto-renders them into SVGs.
 *
 * @param {string} name  - Lucide icon name (e.g. 'home', 'dumbbell')
 * @param {number} size  - pixel size (default 16)
 * @param {string} cls   - extra CSS classes
 */
function icon(name, size, cls) {
    size = size || 16;
    cls = cls || '';
    return '<i data-lucide="' + name + '"' +
        ' class="lucide-icon ' + cls + '"' +
        ' style="width:' + size + 'px;height:' + size + 'px;display:inline-block;vertical-align:middle;stroke:currentColor;"></i>';
}

/** Manually trigger Lucide rendering (rarely needed thanks to observer). */
function refreshIcons() {
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
    }
}

// --- AUTO-RENDER: MutationObserver ---
// Watches for new <i data-lucide> elements and auto-renders them.
document.addEventListener('DOMContentLoaded', function () {
    // Initial render
    refreshIcons();

    // Auto-render any dynamically inserted icons
    var debounceTimer = null;
    var observer = new MutationObserver(function () {
        if (debounceTimer) return;
        debounceTimer = setTimeout(function () {
            debounceTimer = null;
            if (document.querySelector('i[data-lucide]')) {
                lucide.createIcons();
            }
        }, 50);
    });
    observer.observe(document.body, { childList: true, subtree: true });
});


// ============================================================
//  CENTRALIZED CONFIG MAPS
//  These replace duplicated emoji maps across app.js, client.html,
//  base.html, trainer.html, modals.html, owner.html
// ============================================================

// --- NOTIFICATION ICONS ---
var NOTIFICATION_ICONS = {
    'appointment_booked': 'calendar',
    'appointment_canceled': 'x-circle',
    'message': 'message-circle',
    'streak': 'flame',
    'achievement': 'trophy',
    'reminder': 'alarm-clock',
    'offer': 'gift',
    'friend_request': 'hand',
    'coop_workout': 'dumbbell',
    'course': 'dumbbell'
};

function getNotifIcon(type) {
    var name = NOTIFICATION_ICONS[type] || 'bell';
    return icon(name, 20);
}

// --- SESSION TYPES / TRAINER SPECIALTIES ---
var CATEGORY_LABELS = {
    'bodybuilding': { icon: 'dumbbell',          label: 'Bodybuilding' },
    'crossfit':     { icon: 'dumbbell',          label: 'Crossfit' },
    'calisthenics': { icon: 'person-standing',   label: 'Calisthenics' },
    'cardio':       { icon: 'footprints',        label: 'Cardio' },
    'hiit':         { icon: 'zap',               label: 'HIIT' },
    'yoga':         { icon: 'heart',             label: 'Yoga' },
    'boxing':       { icon: 'swords',            label: 'Boxing' },
    'rehabilitation': { icon: 'heart-pulse',     label: 'Rehabilitation' }
};

/** Returns "icon + label" HTML for a session-type key. */
function getCategoryLabel(key) {
    var cat = CATEGORY_LABELS[key];
    if (cat) return icon(cat.icon, 14, 'mr-1') + ' ' + cat.label;
    return key;
}

/** Returns just the Lucide name for a session-type key. */
function getCategoryIconName(key) {
    var cat = CATEGORY_LABELS[key];
    return cat ? cat.icon : 'dumbbell';
}

// --- COURSE TYPE CONFIG ---
var COURSE_TYPE_CONFIG = {
    yoga:     { icon: 'heart',           label: 'Yoga',      color: 'purple', gradient: 'from-purple-500 to-pink-500', bg: 'bg-purple-500/20', border: 'border-purple-500' },
    pilates:  { icon: 'person-standing', label: 'Pilates',   color: 'pink',   gradient: 'from-pink-500 to-rose-500',   bg: 'bg-pink-500/20',   border: 'border-pink-500' },
    hiit:     { icon: 'zap',            label: 'HIIT',      color: 'orange', gradient: 'from-orange-500 to-red-500',  bg: 'bg-orange-500/20', border: 'border-orange-500' },
    strength: { icon: 'dumbbell',       label: 'Strength',  color: 'red',    gradient: 'from-red-500 to-orange-500',  bg: 'bg-red-500/20',    border: 'border-red-500' },
    cardio:   { icon: 'footprints',     label: 'Cardio',    color: 'yellow', gradient: 'from-yellow-500 to-orange-500', bg: 'bg-yellow-500/20', border: 'border-yellow-500' }
};

// --- EXERCISE CATEGORY ICONS ---
var EXERCISE_CATEGORY_ICONS = {
    yoga: 'heart',            pilates: 'person-standing', stretch: 'move',
    cardio: 'footprints',     warmup: 'flame',            cooldown: 'snowflake',
    hiit: 'zap',              dance: 'music',             strength: 'dumbbell',
    balance: 'scale',         breathing: 'wind',          core: 'target'
};

function getExerciseCategoryIcon(cat) {
    return EXERCISE_CATEGORY_ICONS[cat] || 'dumbbell';
}

/** Full exercise category mapping (label + icon). */
var EXERCISE_CATEGORY_MAP = {
    'warmup':      { icon: 'flame',            label: 'Warmup' },
    'cardio':      { icon: 'footprints',       label: 'Cardio' },
    'flexibility': { icon: 'heart',            label: 'Flexibility' },
    'cooldown':    { icon: 'snowflake',        label: 'Cooldown' },
    'yoga':        { icon: 'heart',            label: 'Yoga' },
    'pilates':     { icon: 'person-standing',  label: 'Pilates' },
    'balance':     { icon: 'scale',            label: 'Balance' },
    'breathing':   { icon: 'wind',             label: 'Breathing' },
    'core':        { icon: 'target',           label: 'Core' },
    'hiit':        { icon: 'zap',              label: 'HIIT' },
    'strength':    { icon: 'dumbbell',         label: 'Strength' }
};

function getExerciseCategoryMapping(key) {
    return EXERCISE_CATEGORY_MAP[key] || { icon: 'footprints', label: 'General' };
}

// --- MUSCLE GROUP ICONS ---
var MUSCLE_ICONS = {
    'Chest':     'shield',
    'Back':      'arrow-up-from-line',
    'Legs':      'footprints',
    'Shoulders': 'dumbbell',
    'Arms':      'dumbbell',
    'Abs':       'target',
    'Cardio':    'footprints'
};

// --- BODY METRIC ICONS ---
var METRIC_ICONS = {
    weight:       { icon: 'scale',    label: 'Weight',   unit: 'kg', color: '#3B82F6', goodDirection: 'down' },
    body_fat_pct: { icon: 'flame',    label: 'Body Fat', unit: '%',  color: '#F59E0B', goodDirection: 'down' },
    lean_mass:    { icon: 'dumbbell', label: 'Lean Mass', unit: 'kg', color: '#10B981', goodDirection: 'up' }
};

// --- CRM ACTIVITY ICONS (owner.html) ---
var CRM_ACTIVITY_ICONS = {
    'workout':      'dumbbell',
    'appointment':  'calendar',
    'message':      'message-circle',
    'subscription': 'credit-card'
};

// --- EXPOSE GLOBALLY ---
window.icon = icon;
window.refreshIcons = refreshIcons;
window.NOTIFICATION_ICONS = NOTIFICATION_ICONS;
window.getNotifIcon = getNotifIcon;
window.CATEGORY_LABELS = CATEGORY_LABELS;
window.getCategoryLabel = getCategoryLabel;
window.getCategoryIconName = getCategoryIconName;
window.COURSE_TYPE_CONFIG = COURSE_TYPE_CONFIG;
window.EXERCISE_CATEGORY_ICONS = EXERCISE_CATEGORY_ICONS;
window.getExerciseCategoryIcon = getExerciseCategoryIcon;
window.EXERCISE_CATEGORY_MAP = EXERCISE_CATEGORY_MAP;
window.getExerciseCategoryMapping = getExerciseCategoryMapping;
window.MUSCLE_ICONS = MUSCLE_ICONS;
window.METRIC_ICONS = METRIC_ICONS;
window.CRM_ACTIVITY_ICONS = CRM_ACTIVITY_ICONS;
