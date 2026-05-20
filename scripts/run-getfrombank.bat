@echo off
setlocal
cd /d "%~dp0.."
echo GetFromBank Runner
echo.
echo Usage:
echo   run-getfrombank.bat BANK_INFO_ID START_DATE END_DATE [DELAY_SECONDS]
echo.
echo Example:
echo   run-getfrombank.bat AB1DD89A-38BA-F011-A2D9-005056B667E2 2026-01-01 2026-01-01 3
echo.

if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-getfrombank.ps1"
) else (
  if "%~4"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-getfrombank.ps1" -BankInfoId "%~1" -StartDate "%~2" -EndDate "%~3"
  ) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-getfrombank.ps1" -BankInfoId "%~1" -StartDate "%~2" -EndDate "%~3" -DelaySeconds "%~4"
  )
)

echo.
pause
