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
- After `YES`, visible runners must print live progress for every request, including current index, total count, date/range, endpoint action, and final `OK` or error status. Do not leave the screen silent during long daily runs.
- Do not run these production operations silently unless the user explicitly asks for background execution.
- ManualProcess visible runners must not prompt for Vaultwarden master password during normal use. Use the encrypted local credential file first; only run setup/credential repair when that file is missing or invalid.
- GetFromBank visible runners must not prompt for Vaultwarden master password during normal use. Use the encrypted local credential file, execute through server `172.16.220.58`, split ranges into daily requests, and print `START`, `OK`, `ERROR`, `WAIT`, and final summary lines live in the visible terminal.
- Credential priority for visible runners is encrypted local credential file first. Do not use Vaultwarden in the hot path unless the user explicitly asks to reconfigure credentials.
- Expected Vaultwarden items:
  - `Server 58 - emircancagin` for SSH to server 58.
  - `Finekra ManualProcess API - finekra-api@emircan.com` for ManualProcess API login.
- The ManualProcess API vault item should use login username/password and include a custom field named `tenantCode`.
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

After restore, prefer Vaultwarden items above. If Vaultwarden is unavailable and `secrets\manual-process.local.json` is missing, run:

```powershell
C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\setup-manual-process-credentials.bat
```

## Sync New Local Runners To Global

When a new reusable runner, skill script, or reference is added under the persistent project, sync it into the global skill so future restores include it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\EmircanÇağın\.codex\skills\finekra-api\scripts\sync-finekra-runners-to-global.ps1"
```

This copies runner templates, skill scripts, and references. It does not copy `secrets`, `.env`, or `outputs`.
