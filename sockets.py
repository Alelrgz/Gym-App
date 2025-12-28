import os
import time
import threading
import asyncio
from typing import List
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        # Iterate over a copy to avoid modification issues during iteration
        for connection in self.active_connections[:]:
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect(connection)

# Global instance
manager = ConnectionManager()

import shutil

class FileWatcher:
    def __init__(self, directories: List[str], callback, sync_source: str = None, sync_dest: str = None):
        self.directories = directories
        self.callback = callback
        self.sync_source = sync_source
        self.sync_dest = sync_dest
        self.last_mtimes = {}
        self.running = False
        
        # Snapshot local directories
        self._snapshot(self.directories)
        # Snapshot sync source if it exists
        if self.sync_source:
            self._snapshot([self.sync_source])

    def _snapshot(self, dirs):
        for directory in dirs:
            for root, _, files in os.walk(directory):
                for file in files:
                    path = os.path.join(root, file)
                    try:
                        self.last_mtimes[path] = os.stat(path).st_mtime
                    except OSError:
                        pass

    def start(self):
        self.running = True
        thread = threading.Thread(target=self._loop, daemon=True)
        thread.start()

    def _loop(self):
        while self.running:
            time.sleep(1)
            changed = False
            
            # 1. Check for Cloud/Drive Changes (if configured)
            if self.sync_source and self.sync_dest:
                for root, _, files in os.walk(self.sync_source):
                    for file in files:
                        src_path = os.path.join(root, file)
                        try:
                            mtime = os.stat(src_path).st_mtime
                            if src_path not in self.last_mtimes or mtime != self.last_mtimes[src_path]:
                                # File changed in Drive! Sync to Local.
                                self.last_mtimes[src_path] = mtime
                                
                                # Calculate relative path to map to destination
                                rel_path = os.path.relpath(src_path, self.sync_source)
                                dest_path = os.path.join(self.sync_dest, rel_path)
                                
                                # Ignore git/node_modules
                                if ".git" in rel_path or "node_modules" in rel_path or "__pycache__" in rel_path:
                                    continue
                                    
                                print(f"Cloud change detected: {rel_path} -> Syncing to Local...")
                                
                                # Ensure dir exists
                                os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                                shutil.copy2(src_path, dest_path)
                                changed = True
                        except OSError:
                            pass

            # 2. Check for Local Changes (Standard Watcher)
            for directory in self.directories:
                for root, _, files in os.walk(directory):
                    for file in files:
                        path = os.path.join(root, file)
                        try:
                            mtime = os.stat(path).st_mtime
                            if path not in self.last_mtimes:
                                self.last_mtimes[path] = mtime
                                changed = True
                            elif mtime != self.last_mtimes[path]:
                                self.last_mtimes[path] = mtime
                                changed = True
                        except OSError:
                            pass
            
            if changed:
                print("Change detected! Reloading clients...")
                time.sleep(0.5)
                asyncio.run(self.callback({"type": "reload"}))

# Helper to start watcher
def start_file_watcher():
    # Watch local static/templates AND Sync from Drive
    local_dirs = ["static", "templates"]
    
    # Drive Configuration
    drive_path = r"G:\My Drive\GymApp"
    local_root = os.getcwd() # e:\Antigravity\gym_app_prototype
    
    # Only enable sync if Drive exists
    sync_src = drive_path if os.path.exists(drive_path) else None
    sync_dst = local_root if sync_src else None
    
    if sync_src:
        print(f"Cloud Sync Enabled: Watching {sync_src}")
    
    watcher = FileWatcher(local_dirs, manager.broadcast, sync_source=sync_src, sync_dest=sync_dst)
    watcher.start()
