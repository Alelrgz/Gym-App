"""Batch emoji-to-Lucide migration script for template files."""
import re
import sys

def icon_tag(name, cls="w-5 h-5"):
    return f'<i data-lucide="{name}" class="{cls}"></i>'

def migrate_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # === STATIC HTML REPLACEMENTS ===

    # Span-wrapped emojis (various sizes)
    span_map = {
        # User avatars
        ('text-2xl', '👤'): icon_tag('user', 'w-6 h-6'),
        ('text-3xl', '👤'): icon_tag('user', 'w-8 h-8'),
        ('text-4xl', '👤'): icon_tag('user', 'w-10 h-10'),
        ('text-xl', '👤'): icon_tag('user', 'w-5 h-5'),
        ('text-lg', '👤'): icon_tag('user', 'w-5 h-5'),
        ('text-sm', '👤'): icon_tag('user', 'w-4 h-4'),
        ('text-xs', '👤'): icon_tag('user', 'w-3 h-3'),
        # Users
        ('text-xl', '👥'): icon_tag('users', 'w-5 h-5'),
        ('text-lg', '👥'): icon_tag('users', 'w-5 h-5'),
        ('text-xs', '👥'): icon_tag('users', 'w-3 h-3'),
        # Trophy
        ('text-2xl', '🏆'): icon_tag('trophy', 'w-6 h-6'),
        # Fire/flame
        ('text-sm', '🔥'): icon_tag('flame', 'w-4 h-4'),
        ('text-xl', '🔥'): icon_tag('flame', 'w-5 h-5'),
        # Stats
        ('text-purple-400', '📊'): icon_tag('bar-chart-3', 'w-4 h-4 text-purple-400'),
        # Diet
        ('text-lg', '⚖️'): icon_tag('scale', 'w-5 h-5'),
        # Buttons
        ('text-sm', '✏️'): icon_tag('pencil', 'w-4 h-4'),
        ('text-sm', '📷'): icon_tag('camera', 'w-4 h-4'),
        ('text-sm', '🔍'): icon_tag('search', 'w-4 h-4'),
        ('text-sm', '📋'): icon_tag('clipboard', 'w-4 h-4'),
        # Leaderboard
        ('text-xl', '🌍'): icon_tag('globe', 'w-5 h-5'),
        ('text-xl', '🔒'): icon_tag('lock', 'w-5 h-5'),
        ('text-xl', '🛡️'): icon_tag('shield', 'w-5 h-5'),
        # Strength
        ('text-xl', '💪'): icon_tag('dumbbell', 'w-5 h-5'),
        ('text-2xl', '💪'): icon_tag('dumbbell', 'w-6 h-6'),
        # Notification bell
        ('text-lg', '💬'): icon_tag('message-circle', 'w-5 h-5'),
        ('text-lg', '🔔'): icon_tag('bell', 'w-5 h-5'),
        ('text-lg', '⚙️'): icon_tag('settings', 'w-5 h-5'),
        # Diet
        ('text-2xl', '🥗'): icon_tag('leaf', 'w-6 h-6'),
        # Camera
        ('text-white text-2xl', '📷'): icon_tag('camera', 'w-6 h-6 text-white'),
        # Nav icons
        ('nav-icon', '🏠'): icon_tag('home', 'w-5 h-5'),
        ('nav-icon', '📅'): icon_tag('calendar', 'w-5 h-5'),
        ('nav-icon', '📚'): icon_tag('book-open', 'w-5 h-5'),
        ('nav-icon', '⚙️'): icon_tag('settings', 'w-5 h-5'),
        ('nav-icon', '🚪'): icon_tag('log-out', 'w-5 h-5'),
        # Clipboard
        ('text-xl', '📋'): icon_tag('clipboard', 'w-5 h-5'),
        # Running
        ('text-xl', '🏃'): icon_tag('footprints', 'w-5 h-5'),
        # Search
        ('search-icon', '🔍'): icon_tag('search', 'w-4 h-4'),
        ('search-icon text-xs', '🔍'): icon_tag('search', 'w-3 h-3'),
        # Payment
        ('text-xl block mb-1', '💳'): icon_tag('credit-card', 'w-5 h-5 block mb-1'),
        ('text-2xl block mb-1', '💳'): icon_tag('credit-card', 'w-6 h-6 block mb-1'),
        # Gift
        ('text-2xl', '🎁'): icon_tag('gift', 'w-6 h-6'),
        # Course icons
        ('text-2xl mb-1', '🧘'): icon_tag('heart', 'w-6 h-6 mb-1'),
        ('text-2xl mb-1', '🤸'): icon_tag('person-standing', 'w-6 h-6 mb-1'),
        ('text-2xl mb-1', '🔥'): icon_tag('flame', 'w-6 h-6 mb-1'),
        ('text-2xl mb-1', '💪'): icon_tag('dumbbell', 'w-6 h-6 mb-1'),
        ('text-2xl mb-1', '🏃'): icon_tag('footprints', 'w-6 h-6 mb-1'),
        # Movie
        ('text-6xl opacity-30', '🎬'): icon_tag('clapperboard', 'w-12 h-12 opacity-30'),
        # Yoga course name icon
        ('text-xl', '🧘'): icon_tag('heart', 'w-5 h-5'),
        # Notification
        ('text-4xl mb-2 block', '🔔'): icon_tag('bell', 'w-10 h-10 mb-2 block'),
        # Camera
        ('text-4xl mb-2 block', '📷'): icon_tag('camera', 'w-10 h-10 mb-2 block'),
        # Book
        ('text-4xl mb-3 block', '📚'): icon_tag('book-open', 'w-10 h-10 mb-3 block'),
        # Workout
        ('text-6xl block mb-2', '🏋️'): icon_tag('dumbbell', 'w-12 h-12 block mb-2'),
        # Exercise runner
        ('text-6xl', '🏃'): icon_tag('footprints', 'w-12 h-12'),
        # Warning
        ('text-5xl', '⚠️'): icon_tag('alert-triangle', 'w-10 h-10'),
        ('text-6xl', '⚠️'): icon_tag('alert-triangle', 'w-12 h-12'),
        # Celebration
        ('text-5xl', '🎉'): icon_tag('party-popper', 'w-10 h-10'),
    }

    for (cls, emoji), replacement in span_map.items():
        old = f'<span class="{cls}">{emoji}</span>'
        content = content.replace(old, replacement)

    # Absolute positioned diet icon
    content = content.replace(
        '<span class="absolute text-xl">🥗</span>',
        '<i data-lucide="leaf" class="w-5 h-5 absolute"></i>'
    )

    # P-wrapped emojis
    content = content.replace('<p class="text-4xl mb-2">👥</p>', f'<p class="mb-2">{icon_tag("users", "w-10 h-10")}</p>')
    content = content.replace('<p class="text-4xl mb-2">👤</p>', f'<p class="mb-2">{icon_tag("user", "w-10 h-10")}</p>')

    # Div-wrapped emojis
    content = content.replace(
        '<div class="text-4xl mb-3">📚</div>',
        f'<div class="mb-3">{icon_tag("book-open", "w-10 h-10")}</div>'
    )
    content = content.replace(
        '<div class="text-3xl animate-bounce" style="animation-duration: 2s;">🔥</div>',
        f'<div class="animate-bounce" style="animation-duration: 2s;">{icon_tag("flame", "w-8 h-8")}</div>'
    )
    content = content.replace(
        '<div class="text-6xl mb-4">⚠️</div>',
        f'<div class="mb-4">{icon_tag("alert-triangle", "w-12 h-12")}</div>'
    )
    content = content.replace(
        '<div class="text-6xl mb-4">🧘</div>',
        f'<div class="mb-4">{icon_tag("heart", "w-12 h-12")}</div>'
    )
    content = content.replace(
        '<div class="text-4xl mb-4">🎉</div>',
        f'<div class="mb-4">{icon_tag("party-popper", "w-10 h-10")}</div>'
    )
    content = content.replace(
        '<div class="w-10 h-10 rounded-full bg-gray-500/20 flex items-center justify-center text-xl">📋</div>',
        f'<div class="w-10 h-10 rounded-full bg-gray-500/20 flex items-center justify-center">{icon_tag("clipboard", "w-5 h-5")}</div>'
    )

    # Standalone emoji nav items
    standalone = {
        '💬\n': f'{icon_tag("message-circle", "w-5 h-5")}\n',
        '🔔\n': f'{icon_tag("bell", "w-5 h-5")}\n',
        '📅\n': f'{icon_tag("calendar", "w-5 h-5")}\n',
    }
    for old, new in standalone.items():
        content = content.replace(old, new)

    # Inline text emojis
    inline = {
        '💬 Send Message': f'{icon_tag("message-circle", "w-4 h-4 inline-block align-middle")} Send Message',
        '📅 Book Session': f'{icon_tag("calendar", "w-4 h-4 inline-block align-middle")} Book Session',
        '📷 Photo': f'{icon_tag("camera", "w-4 h-4 inline-block align-middle")} Photo',
        '🖼️': icon_tag('image', 'w-4 h-4 inline-block align-middle'),
        '↩️ Retake': f'{icon_tag("undo-2", "w-4 h-4 inline-block align-middle")} Retake',
        '>🔄</button>': f'>{icon_tag("refresh-cw", "w-5 h-5")}</button>',
    }
    for old, new in inline.items():
        content = content.replace(old, new)

    # Settings menu emojis (standalone in text)
    content = re.sub(r'>\s*⭐\s*\n', f'>\n                    {icon_tag("star", "w-4 h-4 inline-block align-middle")}\n', content)
    content = re.sub(r'>\s*⚙️\s*\n', f'>\n                    {icon_tag("settings", "w-4 h-4 inline-block align-middle")}\n', content)
    content = re.sub(r'>\s*🚪\s*\n', f'>\n                    {icon_tag("log-out", "w-4 h-4 inline-block align-middle")}\n', content)

    # === JS STRING REPLACEMENTS ===

    # Avatar JS assignments
    content = content.replace(
        "avatarEl.innerHTML = '<span class=\"text-2xl\">👤</span>'",
        "avatarEl.innerHTML = '<i data-lucide=\"user\" class=\"w-6 h-6\"></i>'"
    )
    content = content.replace(
        "avatarEl.innerHTML = '<span class=\"text-3xl\">👤</span>'",
        "avatarEl.innerHTML = '<i data-lucide=\"user\" class=\"w-8 h-8\"></i>'"
    )
    content = content.replace(
        "avatarEl.textContent = '👤'",
        "avatarEl.innerHTML = '<i data-lucide=\"user\" class=\"w-5 h-5\"></i>'"
    )
    content = content.replace(
        'avatarContainer.innerHTML = `<span class="text-4xl">👤</span>`',
        'avatarContainer.innerHTML = `<i data-lucide="user" class="w-10 h-10"></i>`'
    )
    content = content.replace(
        "avatarContainer.innerHTML = `<span class=\"text-xl\">👤</span>`",
        "avatarContainer.innerHTML = `<i data-lucide=\"user\" class=\"w-5 h-5\"></i>`"
    )

    # icon.textContent
    content = content.replace(
        "icon.textContent = '⚠'",
        "icon.innerHTML = '<i data-lucide=\"alert-triangle\" class=\"w-5 h-5\"></i>'"
    )

    # Toast emojis
    content = re.sub(r"showToast\((['\"`])([^'\"`]*?) [🎉🍽️📅⚠️✅❌💪🏋️🏃⭐🔥📋📸🥗💾🗑️📷✏️]\1", r"showToast(\1\2\1", content)

    # Course type config - emoji to icon
    content = content.replace("emoji: '🧘', label: 'Yoga'", "icon: 'heart', label: 'Yoga'")
    content = content.replace("emoji: '🤸', label: 'Pilates'", "icon: 'person-standing', label: 'Pilates'")
    content = content.replace("emoji: '🔥', label: 'HIIT'", "icon: 'flame', label: 'HIIT'")
    content = content.replace("emoji: '💪', label: 'Strength'", "icon: 'dumbbell', label: 'Strength'")
    content = content.replace("emoji: '🏃', label: 'Cardio'", "icon: 'footprints', label: 'Cardio'")

    # Category labels
    content = content.replace("'bodybuilding': '💪 Bodybuilding'", "'bodybuilding': 'Bodybuilding'")
    content = content.replace("'crossfit': '🏋️ Crossfit'", "'crossfit': 'Crossfit'")
    content = content.replace("'calisthenics': '🤸 Calisthenics'", "'calisthenics': 'Calisthenics'")
    content = content.replace("'cardio': '🏃 Cardio'", "'cardio': 'Cardio'")
    content = content.replace("'hiit': '⚡ HIIT'", "'hiit': 'HIIT'")
    content = content.replace("'yoga': '🧘 Yoga'", "'yoga': 'Yoga'")
    content = content.replace("'boxing': '🥊 Boxing'", "'boxing': 'Boxing'")
    content = content.replace("'rehabilitation': '🩹 Rehabilitation'", "'rehabilitation': 'Rehabilitation'")

    # Course schedule/duration text (JS textContent)
    content = content.replace("textContent = `📅 ", "textContent = `")
    content = content.replace("textContent = `⏱️ ", "textContent = `")

    # Course type badge - emoji references in JS
    content = content.replace("{ emoji: '📚', label:", "{ icon: 'book-open', label:")

    # Default course icon
    content = content.replace(
        "${course.icon || '🏋️'}",
        "${icon(getCategoryIconName(course.course_type || 'strength'), 20)}"
    )

    # .emoji references -> .icon with icon() wrapper
    content = content.replace("cfg.emoji", "icon(cfg.icon, 16)")

    # Friend streak in template literals
    content = content.replace(
        "🔥 ${friend.streak",
        "${icon('flame', 12)} ${friend.streak"
    )

    # Course type badge inline
    content = content.replace(
        '🧘 Yoga</span>',
        f'{icon_tag("heart", "w-3 h-3 inline-block align-middle")} Yoga</span>'
    )

    # Notification map (trainer templates)
    notif_map_old = "{'appointment_booked':'📅','appointment_canceled':'❌','message':'💬','streak':'🔥','achievement':'🏆','reminder':'⏰','offer':'🎁','friend_request':'👋','coop_workout':'💪','course':'🏋️'}[n.type] || '🔔'"
    notif_map_new = "getNotifIcon(n.type)"
    content = content.replace(notif_map_old, notif_map_new)

    # Trainer notification inline map
    for old_map, new_call in [
        ("'appointment_booked': '📅'", "'appointment_booked': 'calendar'"),
        ("'appointment_canceled': '❌'", "'appointment_canceled': 'x-circle'"),
        ("'message': '💬'", "'message': 'message-circle'"),
        ("'streak': '🔥'", "'streak': 'flame'"),
        ("'achievement': '🏆'", "'achievement': 'trophy'"),
        ("'reminder': '⏰'", "'reminder': 'alarm-clock'"),
        ("'offer': '🎁'", "'offer': 'gift'"),
        ("'friend_request': '👋'", "'friend_request': 'hand'"),
        ("'coop_workout': '💪'", "'coop_workout': 'dumbbell'"),
        ("'course': '🏋️'", "'course': 'dumbbell'"),
    ]:
        content = content.replace(old_map, new_call)
    content = content.replace("return icons[type] || '🔔'", "return icons[type] || 'bell'")

    # Workout card emoji
    content = content.replace(
        "${w.completed ? '✅' : '💪'}",
        "${w.completed ? icon('check-circle', 20) : icon('dumbbell', 20)}"
    )
    content = content.replace(
        ">✅ Assign to Me (Today)</button>",
        f">{icon_tag('check-circle', 'w-4 h-4 inline-block align-middle')} Assign to Me (Today)</button>"
    )

    # Trainer stat Streak
    content = content.replace("Streak 🔥", f"Streak {icon_tag('flame', 'w-4 h-4 inline-block align-middle')}")

    # Owner sidebar nav
    content = content.replace("🏠 Dashboard", f"{icon_tag('home', 'w-5 h-5 inline-block align-middle')} Dashboard")
    content = content.replace("📬 Automation", f"{icon_tag('mail', 'w-5 h-5 inline-block align-middle')} Automation")
    content = content.replace("📊 CRM", f"{icon_tag('bar-chart-3', 'w-5 h-5 inline-block align-middle')} CRM")
    content = content.replace("⚙️ Settings", f"{icon_tag('settings', 'w-5 h-5 inline-block align-middle')} Settings")
    content = content.replace("🚪 Logout", f"{icon_tag('log-out', 'w-5 h-5 inline-block align-middle')} Logout")
    content = content.replace("🏠 Dashboard", f"{icon_tag('home', 'w-5 h-5 inline-block align-middle')} Dashboard")

    # Staff sidebar
    # (Uses same patterns as above)

    # Owner copy icon
    content = content.replace(
        '<span id="copy-icon">📋</span>',
        f'<span id="copy-icon">{icon_tag("clipboard", "w-4 h-4")}</span>'
    )

    # Owner view dashboard
    content = content.replace(
        '<span>💰</span> View Dashboard',
        f'{icon_tag("dollar-sign", "w-4 h-4 inline-block align-middle")} View Dashboard'
    )

    # Owner automation icon
    content = content.replace(
        '<span class="text-xl">📬</span>',
        icon_tag('mail', 'w-5 h-5')
    )

    # Owner warning
    content = content.replace(
        '<span class="text-xs text-yellow-400">⚠️ Needs attention</span>',
        f'<span class="text-xs text-yellow-400">{icon_tag("alert-triangle", "w-3 h-3 inline-block align-middle")} Needs attention</span>'
    )

    # Owner offers header
    content = content.replace(
        '🎁 Promotional Offers',
        f'{icon_tag("gift", "w-4 h-4 inline-block align-middle")} Promotional Offers'
    )

    # CRM activity icons
    content = content.replace("'workout': '🏋️'", "'workout': 'dumbbell'")
    content = content.replace("'appointment': '📅'", "'appointment': 'calendar'")
    content = content.replace("'message': '💬'", "'message': 'message-circle'")
    content = content.replace("'subscription': '💳'", "'subscription': 'credit-card'")

    # CRM status icon
    content = content.replace("icon: '⚠'", "icon: 'alert-triangle'")

    # Owner notification activating
    content = content.replace(
        '📢 Activating will notify all clients',
        f'{icon_tag("megaphone", "w-3 h-3 inline-block align-middle")} Activating will notify all clients'
    )

    # Owner toast
    content = re.sub(r"showToast\('([^']*?) 🎉'", r"showToast('\1'", content)

    # Modals - booking
    content = content.replace(
        '📅 Book Appointment',
        f'{icon_tag("calendar", "w-5 h-5 inline-block align-middle")} Book Appointment'
    )
    content = content.replace(
        '📊 <span class="text-xs">View Stats</span>',
        f'{icon_tag("bar-chart-3", "w-4 h-4 inline-block align-middle")} <span class="text-xs">View Stats</span>'
    )
    content = content.replace(
        'Metrics 📈',
        f'Metrics {icon_tag("trending-up", "w-4 h-4 inline-block align-middle")}'
    )

    # Modals - specialty labels
    content = content.replace("💪 Bodybuilding</span>", f'{icon_tag("dumbbell", "w-3 h-3 inline-block align-middle")} Bodybuilding</span>')
    content = content.replace("🏋️ Crossfit</span>", f'{icon_tag("dumbbell", "w-3 h-3 inline-block align-middle")} Crossfit</span>')
    content = content.replace("🤸 Calisthenics</span>", f'{icon_tag("person-standing", "w-3 h-3 inline-block align-middle")} Calisthenics</span>')
    content = content.replace("🏃 Cardio</span>", f'{icon_tag("footprints", "w-3 h-3 inline-block align-middle")} Cardio</span>')
    content = content.replace("⚡ HIIT</span>", f'{icon_tag("zap", "w-3 h-3 inline-block align-middle")} HIIT</span>')
    content = content.replace("🧘 Yoga</span>", f'{icon_tag("heart", "w-3 h-3 inline-block align-middle")} Yoga</span>')
    content = content.replace("🥊 Boxing</span>", f'{icon_tag("swords", "w-3 h-3 inline-block align-middle")} Boxing</span>')
    content = content.replace("🩹 Rehab</span>", f'{icon_tag("heart-pulse", "w-3 h-3 inline-block align-middle")} Rehab</span>')

    # Modals - course schedule
    content = content.replace(
        '<span class="mr-2">📅</span> Schedule',
        f'{icon_tag("calendar", "w-4 h-4 mr-2 inline-block align-middle")} Schedule'
    )
    content = content.replace(
        '<span class="mr-2">👥</span> Class Capacity',
        f'{icon_tag("users", "w-4 h-4 mr-2 inline-block align-middle")} Class Capacity'
    )
    content = content.replace(
        '<span class="mr-2">🎵</span> Music Playlists',
        f'{icon_tag("music", "w-4 h-4 mr-2 inline-block align-middle")} Music Playlists'
    )
    content = content.replace(
        '<span class="mr-2">🏋️</span> Exercises',
        f'{icon_tag("dumbbell", "w-4 h-4 mr-2 inline-block align-middle")} Exercises'
    )
    content = content.replace(
        '<span class="mr-2">👁️</span> Client Preview',
        f'{icon_tag("eye", "w-4 h-4 mr-2 inline-block align-middle")} Client Preview'
    )

    # Modals - visibility
    content = content.replace(
        '<span id="visibility-icon" class="text-xl">🔒</span>',
        f'<span id="visibility-icon" class="text-xl">{icon_tag("lock", "w-5 h-5")}</span>'
    )
    content = content.replace(
        '<span id="course-name-icon" class="absolute left-3 top-1/2 -translate-y-1/2 text-xl">🧘</span>',
        f'<span id="course-name-icon" class="absolute left-3 top-1/2 -translate-y-1/2 text-xl">{icon_tag("heart", "w-5 h-5")}</span>'
    )

    # Modals - movie/video placeholders
    content = content.replace(
        '<span class="text-5xl block mb-2 opacity-30">🎬</span>',
        f'<span class="block mb-2 opacity-30">{icon_tag("clapperboard", "w-10 h-10")}</span>'
    )
    content = content.replace(
        '<span class="text-6xl block mb-2">🏋️</span>',
        f'<span class="block mb-2">{icon_tag("dumbbell", "w-12 h-12")}</span>'
    )

    # Modals - exercise category dropdown
    content = content.replace('<option value="yoga">🧘 Yoga</option>', '<option value="yoga">Yoga</option>')
    content = content.replace('<option value="pilates">🤸 Pilates</option>', '<option value="pilates">Pilates</option>')
    content = content.replace('<option value="warmup">🔥 Warmup</option>', '<option value="warmup">Warmup</option>')
    content = content.replace('<option value="cardio">🏃 Cardio</option>', '<option value="cardio">Cardio</option>')
    content = content.replace('<option value="cooldown">❄️ Cooldown</option>', '<option value="cooldown">Cooldown</option>')
    content = content.replace('<option value="breathing">🌬️ Breathing</option>', '<option value="breathing">Breathing</option>')
    content = content.replace('<option value="balance">⚖️ Balance</option>', '<option value="balance">Balance</option>')
    content = content.replace('<option value="core">🎯 Core</option>', '<option value="core">Core</option>')
    content = content.replace('<option value="hiit">⚡ HIIT</option>', '<option value="hiit">HIIT</option>')

    # Modals - edit/delete buttons
    content = content.replace('✏️ Edit', f'{icon_tag("pencil", "w-4 h-4 inline-block align-middle")} Edit')
    content = content.replace('🗑️ Delete', f'{icon_tag("trash-2", "w-4 h-4 inline-block align-middle")} Delete')

    # Modals - secure payment
    content = content.replace(
        '🔒 Secure payment',
        f'{icon_tag("lock", "w-4 h-4 inline-block align-middle")} Secure payment'
    )

    # Modals - music tab
    content = content.replace('>\n                🎵\n', f'>\n                {icon_tag("music", "w-5 h-5")}\n')

    # Modals - search
    content = content.replace(
        '<span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-xs">🔍</span>',
        f'<span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-xs">{icon_tag("search", "w-3 h-3")}</span>'
    )
    content = content.replace(
        '<span class="absolute left-3 top-1/2 -translate-y-1/2 text-white/30 text-sm">🔍</span>',
        f'<span class="absolute left-3 top-1/2 -translate-y-1/2 text-white/30 text-sm">{icon_tag("search", "w-4 h-4")}</span>'
    )

    # Modals - course exercise placeholder
    content = content.replace(
        '<span class="text-3xl mb-2 block opacity-30">🏃</span>',
        f'<span class="mb-2 block opacity-30">{icon_tag("footprints", "w-8 h-8")}</span>'
    )

    # Modals - booking section date
    content = content.replace('>\n                        📅\n', f'>\n                        {icon_tag("calendar", "w-5 h-5")}\n')

    # Trainer tabs
    content = content.replace('<span>👥</span> Clients', f'{icon_tag("users", "w-4 h-4 inline-block align-middle")} Clients')
    content = content.replace('<span>📋</span> Programs', f'{icon_tag("clipboard", "w-4 h-4 inline-block align-middle")} Programs')
    content = content.replace('<span>📝</span> Quick Notes', f'{icon_tag("file-text", "w-4 h-4 inline-block align-middle")} Quick Notes')
    content = content.replace('<span>🏋️</span> Exercises', f'{icon_tag("dumbbell", "w-4 h-4 inline-block align-middle")} Exercises')

    # Trainer logout
    content = content.replace('🚪 Logout', f'{icon_tag("log-out", "w-4 h-4 inline-block align-middle")} Logout')

    # Trainer course filter buttons
    content = content.replace('>🧘 Yoga</button>', f'>{icon_tag("heart", "w-3 h-3 inline-block align-middle")} Yoga</button>')
    content = content.replace('>🤸 Pilates</button>', f'>{icon_tag("person-standing", "w-3 h-3 inline-block align-middle")} Pilates</button>')
    content = content.replace('>🏃 Cardio</button>', f'>{icon_tag("footprints", "w-3 h-3 inline-block align-middle")} Cardio</button>')
    content = content.replace('>🔥 Warmup</button>', f'>{icon_tag("flame", "w-3 h-3 inline-block align-middle")} Warmup</button>')
    content = content.replace('>❄️ Cooldown</button>', f'>{icon_tag("snowflake", "w-3 h-3 inline-block align-middle")} Cooldown</button>')

    # Trainer personal page icons
    content = content.replace(
        '<span class="text-2xl mb-1 group-hover:scale-110 transition-transform">💪</span>',
        f'<span class="text-2xl mb-1 group-hover:scale-110 transition-transform">{icon_tag("dumbbell", "w-6 h-6")}</span>'
    )
    content = content.replace(
        '<span class="text-2xl mb-1 group-hover:scale-110 transition-transform">📅</span>',
        f'<span class="text-2xl mb-1 group-hover:scale-110 transition-transform">{icon_tag("calendar", "w-6 h-6")}</span>'
    )

    # Staff nav
    content = content.replace('🏠 Dashboard', f'{icon_tag("home", "w-5 h-5 inline-block align-middle")} Dashboard')

    # Staff icons
    content = content.replace(
        '<span class="text-2xl block mb-1">💳</span>',
        f'<span class="block mb-1">{icon_tag("credit-card", "w-6 h-6")}</span>'
    )
    content = content.replace(
        '<span class="text-2xl block mb-1">📷</span>',
        f'<span class="block mb-1">{icon_tag("camera", "w-6 h-6")}</span>'
    )
    content = content.replace(
        '<span class="text-3xl block mb-2">📷</span>',
        f'<span class="block mb-2">{icon_tag("camera", "w-8 h-8")}</span>'
    )

    # Staff CRM status
    content = content.replace("icon: '⚠'", "icon: 'alert-triangle'")

    # Workout template icons
    content = content.replace(
        '<span class="text-xs">👤</span>',
        icon_tag('user', 'w-3 h-3')
    )
    content = content.replace(
        '<span class="text-xs">👥</span>',
        icon_tag('users', 'w-3 h-3')
    )

    # Remaining inline notification bar
    content = content.replace('>\n                🔔\n', f'>\n                {icon_tag("bell", "w-5 h-5")}\n')
    content = content.replace('>\n                ⚙️\n', f'>\n                {icon_tag("settings", "w-5 h-5")}\n')

    # Owner modal emoji buttons line (should NOT be replaced)
    # Already handled by not matching emoji-btn class

    # Megaphone
    content = content.replace('📢</button>', f'{icon_tag("megaphone", "w-5 h-5")}</button>')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    changes = sum(1 for a, b in zip(original, content) if a != b)
    return changes > 0

if __name__ == '__main__':
    files = sys.argv[1:]
    for f in files:
        result = migrate_file(f)
        print(f"{'Updated' if result else 'No changes'}: {f}")
