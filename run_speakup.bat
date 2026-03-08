@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: SpeakUp Single-Click Launcher
:: ==========================================

echo [1/3] Detecting local IP address...
:: Find local IP address (IPv4)
set "IP=localhost"
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr "IPv4 Address"') do (
    set "tempIP=%%a"
    set "tempIP=!tempIP: =!"
    if "!tempIP!" neq "" (
        set "IP=!tempIP!"
        goto :found
    )
)

:found
echo Detected local IP: %IP%
echo.

:: Set Flutter path (adjust if needed, but this matches your environment)
set "PATH=%PATH%;C:\Users\Nauti\flutter\bin"

echo [2/3] Starting Backend (FastAPI)...
:: Start Backend in a new window
start "SpeakUp Backend" cmd /k "echo Starting Backend... && cd /d %~dp0backend && .\VENV\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload"

:: Wait for backend to initialize
timeout /t 3 /nobreak > nul

echo [3/3] Starting Frontend (Flutter Web)...
:: Start Frontend in a new window
start "SpeakUp Frontend" cmd /k "echo Starting Frontend... && cd /d %~dp0apps\mobile_web_app && flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0"

echo.
echo ==========================================
echo SpeakUp is launching!
echo ==========================================
echo PC Access:      http://localhost:8080
echo Mobile Access:  http://%IP%:8080
echo Backend API:    http://%IP%:8000
echo ==========================================
echo.
echo Note: Keep the two new windows open while using the app.
echo Press any key to close this launcher window.
pause > nul
