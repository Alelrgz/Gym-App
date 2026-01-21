with open('templates/trainer_personal.html', 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''    <!-- Today's Plan Section -->
    <div id="todays-plan-container" class="mb-6 hidden">
        <!-- Injected via JS -->
    </div>'''

new_code = '''    <!-- Today's Plan Section - Always Visible -->
    <div id="todays-plan-container" class="mb-6">
        <!-- Default: No workout assigned - will be replaced by JS if workout exists -->
        <div class="glass-card p-5 relative overflow-hidden" id="default-plan-placeholder">
            <div class="flex justify-between items-start mb-4">
                <span class="bg-white/10 px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider">Today's Plan</span>
                <span class="text-xl">📋</span>
            </div>
            <h3 class="text-xl font-bold text-white/50 mb-2">No Workout Assigned</h3>
            <p class="text-sm text-gray-400 mb-4">Select a workout from "My Workouts" and click "Assign to Me" to set today's workout.</p>
        </div>
    </div>'''

if old_code in content:
    content = content.replace(old_code, new_code)
    with open('templates/trainer_personal.html', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Success: Today\'s Plan section updated')
else:
    print('Warning: old code not found')
    # Check what's there
    idx = content.find('todays-plan-container')
    if idx > 0:
        print('Found at:', idx)
        print('Context:', content[idx-50:idx+200])
