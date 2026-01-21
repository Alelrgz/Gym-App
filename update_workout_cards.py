import re

with open('templates/trainer_personal.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Find and replace the workout cards section
old_pattern = r'''workoutCardContainer\.innerHTML = '';
                    data\.workouts\.forEach\(w => \{
                        const div = document\.createElement\('div'\);
                        div\.className = "glass-card p-3 mb-2 flex justify-between items-center";
                        div\.innerHTML = `
                            <div>
                                <h4 class="font-bold text-sm text-white">\$\{w\.title\}</h4>
                                <p class="text-\[10px\] text-gray-400">\$\{w\.duration\} • \$\{w\.difficulty\}</p>
                            </div>
                            <button class="text-xs bg-white/10 hover:bg-white/20 px-2 py-1 rounded text-white transition" 
                                onclick="window\.location\.href='\?gym_id=\$\{localGymId\}&role=trainer&mode=workout&workout_id=\$\{w\.id\}'">
                                Preview
                            </button>
                        `;
                        workoutCardContainer\.appendChild\(div\);
                    \}\);'''

# Simple string replacement instead
old_code = '''workoutCardContainer.innerHTML = '';
                    data.workouts.forEach(w => {
                        const div = document.createElement('div');
                        div.className = "glass-card p-3 mb-2 flex justify-between items-center";
                        div.innerHTML = `
                            <div>
                                <h4 class="font-bold text-sm text-white">${w.title}</h4>
                                <p class="text-[10px] text-gray-400">${w.duration} • ${w.difficulty}</p>
                            </div>
                            <button class="text-xs bg-white/10 hover:bg-white/20 px-2 py-1 rounded text-white transition" 
                                onclick="window.location.href='/?gym_id=${localGymId}&role=trainer&mode=workout&workout_id=${w.id}'">
                                Preview
                            </button>
                        `;
                        workoutCardContainer.appendChild(div);
                    });'''

new_code = '''workoutCardContainer.innerHTML = '';
                    data.workouts.forEach(w => {
                        const div = document.createElement('div');
                        div.className = "glass-card p-3 mb-2";
                        div.innerHTML = `
                            <div class="flex justify-between items-center mb-2">
                                <div>
                                    <h4 class="font-bold text-sm text-white">${w.title}</h4>
                                    <p class="text-[10px] text-gray-400">${w.duration} • ${w.difficulty}</p>
                                </div>
                                <button class="text-xs bg-white/10 hover:bg-white/20 px-2 py-1 rounded text-white transition" 
                                    onclick="window.location.href='/?gym_id=${localGymId}&role=trainer&mode=workout&workout_id=${w.id}'">
                                    Preview
                                </button>
                            </div>
                            <button class="w-full py-1.5 bg-green-600/20 hover:bg-green-600 text-green-400 hover:text-white text-xs font-bold rounded-lg transition border border-green-500/30"
                                onclick="window.assignWorkoutToSelf('${w.id}', '${w.title}')">✅ Assign to Me (Today)
                            </button>
                        `;
                        workoutCardContainer.appendChild(div);
                    });'''

if old_code in content:
    content = content.replace(old_code, new_code)
    with open('templates/trainer_personal.html', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Success: workout cards updated with Assign to Me button')
else:
    print('Warning: old code not found, checking content...')
    # Check if it already has the button
    if 'assignWorkoutToSelf' in content:
        print('Button already exists!')
    else:
        # Show what's actually there
        idx = content.find('workoutCardContainer.innerHTML')
        if idx > 0:
            print('Found at:', idx)
            print('Content around:', content[idx:idx+200])
