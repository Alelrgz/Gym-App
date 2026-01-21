/**
 * Trainer Personal Notes Enhancement
 * Adds save button, saved notes section, and CRUD functionality
 */

(function () {
    'use strict';

    const username = localStorage.getItem('username') || 'Trainer';
    let editingNoteId = null;

    document.addEventListener('DOMContentLoaded', () => {
        initNotesUI();
    });

    function initNotesUI() {
        const notesArea = document.getElementById('personal-notes');
        if (!notesArea) return;

        // Find the notes header and enhance it
        const notesHeader = notesArea.parentElement.querySelector('.flex.justify-between');
        if (notesHeader) {
            notesHeader.innerHTML = `
                <h3 class="text-xs font-bold text-gray-400 uppercase tracking-wider">Personal Notes</h3>
                <div class="flex items-center space-x-2">
                    <span class="text-[10px] text-green-400 opacity-0 transition-opacity duration-500" id="personal-notes-saved-indicator">Saved</span>
                    <button id="save-note-btn" class="bg-primary hover:bg-red-700 text-white text-xs px-3 py-1.5 rounded-lg font-bold transition flex items-center space-x-1">
                        <span>💾</span>
                        <span>Save</span>
                    </button>
                </div>
            `;
        }

        // Add title input before textarea
        const titleInput = document.createElement('input');
        titleInput.type = 'text';
        titleInput.id = 'note-title-input';
        titleInput.className = 'w-full bg-black/20 text-white text-sm rounded-xl p-2 mb-2 border border-white/5 focus:border-white/20 outline-none placeholder-white/30 transition';
        titleInput.placeholder = 'Note Title (optional)';
        notesArea.parentElement.insertBefore(titleInput, notesArea);

        // Add Saved Notes section after notes card
        const notesCard = notesArea.closest('.glass-card');
        if (notesCard && notesCard.parentElement) {
            const savedNotesSection = document.createElement('div');
            savedNotesSection.className = 'mt-4';
            savedNotesSection.innerHTML = `
                <button id="toggle-saved-notes-btn" class="w-full py-2 text-sm bg-purple-600 text-white font-bold rounded-xl mb-4 hover:bg-purple-700 transition shadow-lg shadow-purple-600/20">
                    📝 Saved Notes
                </button>
                <div id="saved-notes-section" class="hidden transition-all duration-300 ease-in-out">
                    <div id="saved-notes-container">
                        <p class="text-gray-400 text-sm text-center py-4">Click to load notes...</p>
                    </div>
                </div>
            `;
            notesCard.parentElement.insertBefore(savedNotesSection, notesCard.nextSibling);

            // Toggle handler
            document.getElementById('toggle-saved-notes-btn').addEventListener('click', () => {
                const section = document.getElementById('saved-notes-section');
                if (section) {
                    section.classList.toggle('hidden');
                    if (!section.classList.contains('hidden')) {
                        loadSavedNotes();
                    }
                }
            });
        }

        // Save button click handler
        document.getElementById('save-note-btn')?.addEventListener('click', saveNote);

        // Load localStorage scratch
        const savedScratch = localStorage.getItem(`personal_notes_${username}`);
        if (savedScratch) notesArea.value = savedScratch;

        // Auto-save to localStorage (scratchpad)
        let saveTimeout;
        notesArea.addEventListener('input', () => {
            const indicator = document.getElementById('personal-notes-saved-indicator');
            if (indicator) indicator.style.opacity = '0';
            clearTimeout(saveTimeout);
            saveTimeout = setTimeout(() => {
                localStorage.setItem(`personal_notes_${username}`, notesArea.value);
                if (indicator) indicator.style.opacity = '1';
            }, 1000);
        });
    }

    async function saveNote() {
        const titleInput = document.getElementById('note-title-input');
        const notesArea = document.getElementById('personal-notes');
        const saveBtn = document.getElementById('save-note-btn');

        const title = titleInput?.value || 'Untitled Note';
        const content = notesArea?.value || '';

        if (!content.trim()) {
            alert('Please enter some note content first.');
            return;
        }

        try {
            saveBtn.disabled = true;
            saveBtn.innerHTML = '<span>⏳</span><span>Saving...</span>';

            let res;
            if (editingNoteId) {
                // Update existing note
                res = await fetch(`/api/trainer/notes/${editingNoteId}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ title, content })
                });
            } else {
                // Create new note
                res = await fetch('/api/trainer/notes', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ title, content })
                });
            }

            if (res.ok) {
                titleInput.value = '';
                notesArea.value = '';
                localStorage.removeItem(`personal_notes_${username}`);
                editingNoteId = null;
                saveBtn.innerHTML = '<span>💾</span><span>Save</span>';
                loadSavedNotes();

                // Show success toast
                const indicator = document.getElementById('personal-notes-saved-indicator');
                if (indicator) {
                    indicator.textContent = 'Note saved!';
                    indicator.style.opacity = '1';
                    setTimeout(() => {
                        indicator.textContent = 'Saved';
                        indicator.style.opacity = '0';
                    }, 2000);
                }
            } else {
                const err = await res.json();
                alert('Failed to save: ' + (err.detail || 'Unknown error'));
            }
        } catch (e) {
            alert('Error saving note: ' + e.message);
        } finally {
            saveBtn.disabled = false;
            saveBtn.innerHTML = editingNoteId ? '<span>✏️</span><span>Update</span>' : '<span>💾</span><span>Save</span>';
        }
    }

    async function loadSavedNotes() {
        const container = document.getElementById('saved-notes-container');
        if (!container) return;

        container.innerHTML = '<p class="text-gray-400 text-sm text-center py-4">Loading...</p>';

        try {
            const res = await fetch('/api/trainer/notes');
            if (!res.ok) throw new Error('Failed to fetch notes');

            const notes = await res.json();

            if (notes.length === 0) {
                container.innerHTML = '<p class="text-gray-400 text-sm text-center py-4 italic">No saved notes yet.</p>';
                return;
            }

            container.innerHTML = '';
            notes.forEach(note => {
                const div = document.createElement('div');
                div.className = 'glass-card p-3 mb-2 hover:bg-white/5 transition';
                const preview = note.content.length > 100 ? note.content.substring(0, 100) + '...' : note.content;
                const dateStr = new Date(note.updated_at).toLocaleDateString();
                div.innerHTML = `
                    <div class="flex justify-between items-start">
                        <div class="flex-1 cursor-pointer" data-note-id="${note.id}">
                            <h4 class="font-bold text-sm text-white">${escapeHtml(note.title)}</h4>
                            <p class="text-[10px] text-gray-400 mt-1">${escapeHtml(preview)}</p>
                            <p class="text-[10px] text-gray-500 mt-2">${dateStr}</p>
                        </div>
                        <button class="delete-note-btn text-red-500 hover:text-red-400 ml-2 p-1" data-note-id="${note.id}" title="Delete">✕</button>
                    </div>
                `;

                // Edit click
                div.querySelector('[data-note-id]').addEventListener('click', () => editNote(note));

                // Delete click
                div.querySelector('.delete-note-btn').addEventListener('click', (e) => {
                    e.stopPropagation();
                    deleteNote(note.id);
                });

                container.appendChild(div);
            });
        } catch (e) {
            container.innerHTML = '<p class="text-red-400 text-sm text-center py-4">Failed to load notes.</p>';
            console.error('Error loading notes:', e);
        }
    }

    function editNote(note) {
        const titleInput = document.getElementById('note-title-input');
        const notesArea = document.getElementById('personal-notes');
        const saveBtn = document.getElementById('save-note-btn');

        if (titleInput) titleInput.value = note.title;
        if (notesArea) notesArea.value = note.content;

        editingNoteId = note.id;
        if (saveBtn) saveBtn.innerHTML = '<span>✏️</span><span>Update</span>';

        // Scroll to notes area
        notesArea?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }

    async function deleteNote(noteId) {
        if (!confirm('Delete this note permanently?')) return;

        try {
            const res = await fetch(`/api/trainer/notes/${noteId}`, { method: 'DELETE' });
            if (res.ok) {
                // If we were editing this note, clear the form
                if (editingNoteId === noteId) {
                    document.getElementById('note-title-input').value = '';
                    document.getElementById('personal-notes').value = '';
                    editingNoteId = null;
                    document.getElementById('save-note-btn').innerHTML = '<span>💾</span><span>Save</span>';
                }
                loadSavedNotes();
            } else {
                alert('Failed to delete note.');
            }
        } catch (e) {
            alert('Error: ' + e.message);
        }
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // Expose functions globally for debugging
    window.trainerNotes = {
        loadSavedNotes,
        saveNote
    };
})();
