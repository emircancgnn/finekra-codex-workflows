# Finekra Visible BAT Runners

Use these persistent project runners when the user asks to run an operation as `.bat`, "bat olarak calistir", or "ekrandan goreyim".

Persistent project directory:

```text
C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work
```

## ManualProcess

Purpose: missing account movements / hesap hareketleri manual pull.

```powershell
Start-Process -FilePath "cmd.exe" -ArgumentList @(
  "/c", "start", '"ManualProcess"',
  "cmd.exe", "/k",
  '"C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\run-manual-process.bat" <bankInfoId> <startDate> <endDate> <delaySeconds>'
)
```

Example:

```powershell
Start-Process -FilePath "cmd.exe" -ArgumentList @("/c","start",'"ManualProcess"',"cmd.exe","/k",'"C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\run-manual-process.bat" D7816CD6-BC38-F111-A2DA-005056B667E2 2026-04-15 2026-05-12 3')
```

## GetFromBank

Purpose: POS report manual pull.

```powershell
Start-Process -FilePath "cmd.exe" -ArgumentList @(
  "/c", "start", '"GetFromBank"',
  "cmd.exe", "/k",
  '"C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\run-getfrombank.bat" <bankInfoId> <startDate> <endDate> <delaySeconds>'
)
```

Example:

```powershell
Start-Process -FilePath "cmd.exe" -ArgumentList @("/c","start",'"GetFromBank"',"cmd.exe","/k",'"C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\run-getfrombank.bat" AB1DD89A-38BA-F011-A2D9-005056B667E2 2026-01-01 2026-01-01 3')
```

## DailyAccountTransaction

Purpose: end-of-day account balance report / gun sonu raporu.

If `endDate` is omitted, the runner uses today.

```powershell
Start-Process -FilePath "cmd.exe" -ArgumentList @(
  "/c", "start", '"DailyAccountTransaction"',
  "cmd.exe", "/k",
  '"C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\run-daily-account-transaction.bat" <bankId> <tenantId> <startDate> [endDate] [delaySeconds]'
)
```

Example:

```powershell
Start-Process -FilePath "cmd.exe" -ArgumentList @("/c","start",'"DailyAccountTransaction"',"cmd.exe","/k",'"C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\run-daily-account-transaction.bat" 64 D6B307BF-B8F4-ED11-A2D3-005056B667E2 2026-05-01 2026-05-12 3')
```

## Execution Behavior

- Open a visible terminal window so the user can watch the preview and type `YES`.
- Do not run these production operations silently unless the user explicitly asks for background execution.
- After the user runs it, inspect the newest JSON under the relevant `outputs\...` folder when they ask for results.
- Results directories:
  - `outputs\manual-process`
  - `outputs\getfrombank`
  - `outputs\daily-account-transaction`

## Restore If Project Folder Is Missing

If `C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work` is missing, restore the runner workspace from the global skill:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\EmircanÇağın\.codex\skills\finekra-api\scripts\restore-finekra-runners.ps1"
```

After restore, if `secrets\manual-process.local.json` is missing, run:

```powershell
C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\setup-manual-process-credentials.bat
```

## Sync New Local Runners To Global

When a new reusable runner, skill script, or reference is added under the persistent project, sync it into the global skill so future restores include it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\EmircanÇağın\.codex\skills\finekra-api\scripts\sync-finekra-runners-to-global.ps1"
```

This copies runner templates, skill scripts, and references. It does not copy `secrets`, `.env`, or `outputs`.
