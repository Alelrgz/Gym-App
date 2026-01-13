import re
import os

file_path = "e:/Antigravity/gym_app_prototype/templates/modals.html"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Regex to find the input block
# We look for input with id="assign-split-date" and the class attribute on the next line
# We use capturing group to keep the input tag
pattern = r'(\s*<input type="date" id="assign-split-date"\s*\n\s*class="[^"]+">)'

replacement = r'''
                <div class="relative">
\1
                    <button onclick="openSchedulePicker()" class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white p-2" title="View Schedule">
                        📅
                    </button>
                </div>'''

# We need to be careful with backreferences in replacement string
# \g<1> is safer
replacement_fixed = r'''
                <div class="relative">
\g<1>
                    <button onclick="openSchedulePicker()" class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white p-2" title="View Schedule">
                        📅
                    </button>
                </div>'''

new_content = re.sub(pattern, replacement_fixed, content)

if new_content == content:
    print("No replacement made!")
    # Debug: print context around the id
    idx = content.find('id="assign-split-date"')
    if idx != -1:
        print("Found ID at index:", idx)
        print("Context:", content[idx-50:idx+150])
else:
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("Replacement successful!")
