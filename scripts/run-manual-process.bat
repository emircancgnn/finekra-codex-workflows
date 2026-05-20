@echo off
setlocal
cd /d "%~dp0.."
echo ManualProcess Runner
echo.
echo Usage:
echo   run-manual-process.bat BANK_INFO_ID START_DATE END_DATE [DELAY_SECONDS]
echo.
echo Example:
echo   run-manual-process.bat D7816CD6-BC38-F111-A2DA-005056B667E2 2026-04-15 2026-05-12 3
echo.

if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-manual-process.ps1"
) else (
  if "%~4"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-manual-process.ps1" -BankInfoId "%~1" -StartDate "%~2" -EndDate "%~3"
  ) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-manual-process.ps1" -BankInfoId "%~1" -StartDate "%~2" -EndDate "%~3" -DelaySeconds "%~4"
  )
)

echo.
pause
