@echo off
echo [1/4] Aggressively killing ALL python processes...
taskkill /F /IM python.exe /T >nul 2>&1
taskkill /F /IM python3.11.exe /T >nul 2>&1
:: Wait a moment to ensure ports are freed
timeout /t 2 /nobreak >nul

echo [2/4] Starting Gym App Server on Port 9007...
start /B python main.py

echo [3/4] Waiting for server to initialize...
timeout /t 3 /nobreak >nul

echo [4/4] Opening Brave with Cache Busting...
 :: Adding a random number to the URL forces the browser to treat it as a new page
start chrome "http://127.0.0.1:9007/?v=%RANDOM%"

echo Done! You should see v5.5 now.
