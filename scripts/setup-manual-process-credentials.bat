@echo off
setlocal
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-manual-process-credentials.ps1"
echo.
pause
