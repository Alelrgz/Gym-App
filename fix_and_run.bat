@echo off
echo [1/5] Checking Python Dependencies...
python check_env.py

echo [2/5] Building Static Web Assets...
python build_static.py

echo [3/5] Syncing Assets to Android...
:: This ensures the Android app sees the latest HTML/JS
call npx cap copy android

echo [4/5] Starting Backend Server (Port 9007)...
start "Gym App Backend" /B python main.py

echo [5/5] Launching...
timeout /t 3 /nobreak >nul
start brave "http://127.0.0.1:9007"

echo ======================================================
echo SERVER IS RUNNING.
echo If you are using Android Studio, press 'Run' now.
echo ======================================================
pause
