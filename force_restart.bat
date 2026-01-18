@echo off
echo [1/4] Aggressively killing ALL python processes...
taskkill /F /IM python.exe /T >nul 2>&1
taskkill /F /IM uvicorn.exe /T >nul 2>&1

echo [2/4] Waiting for ports to clear...
timeout /t 2 /nobreak >nul

echo [3/4] Starting Gym App Server on Port 9007...
start "GymApp Server" /B python main.py

echo [4/4] Waiting for server to initialize...
timeout /t 5 /nobreak >nul

echo Opening Trainer Page...
start chrome "http://127.0.0.1:9007/trainer/personal?v=%RANDOM%"

echo ===================================================
echo DONE! The app has been hard-restarted.
echo Please try adding an event now.
echo ===================================================
pause
