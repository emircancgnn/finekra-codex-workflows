@echo off
setlocal
cd /d "%~dp0.."
echo DailyAccountTransaction Runner
echo.
echo Usage:
echo   run-daily-account-transaction.bat BANK_ID TENANT_ID START_DATE [END_DATE] [DELAY_SECONDS]
echo.
echo Example:
echo   run-daily-account-transaction.bat 64 D6B307BF-B8F4-ED11-A2D3-005056B667E2 2026-05-01 2026-05-12 3
echo.
echo If END_DATE is omitted, the runner uses today.
echo.

if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-daily-account-transaction.ps1"
) else (
  if "%~4"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-daily-account-transaction.ps1" -BankId "%~1" -TenantId "%~2" -StartDate "%~3"
  ) else (
    if "%~5"=="" (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-daily-account-transaction.ps1" -BankId "%~1" -TenantId "%~2" -StartDate "%~3" -EndDate "%~4"
    ) else (
      powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-daily-account-transaction.ps1" -BankId "%~1" -TenantId "%~2" -StartDate "%~3" -EndDate "%~4" -DelaySeconds "%~5"
    )
  )
)

echo.
pause
