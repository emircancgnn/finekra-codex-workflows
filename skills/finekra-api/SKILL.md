---
name: finekra-api
description: Use when working with the Finekra API, including reading the Finekra GitBook API documentation, preparing Finekra HTTP requests, authenticating with Auth/DealerLogin, using Bearer tokens, executing Finekra API calls, connecting Finekra VPN, accessing server 58, logging into Elastic/Kibana, investigating account transaction or hesap hareketleri logs by tenantId/date, and running ManualProcess for missing account movements by bankInfoId/date range.
---

# Finekra API

## Core Workflow

1. Read `references/finekra-api.md` before preparing or executing Finekra API calls.
2. For Finekra technical documentation, first use `references/finekra-gitbook.md` and the local GitBook helper to search `yardim`, then `api`, then a specific page if needed.
3. Determine whether the user wants only a prepared request or an actual network call.
4. For actual calls, route requests through the Windows server `172.16.220.58` over SSH unless the user explicitly asks for a different route. Use `scripts/invoke-finekra-remote.ps1` when possible.
5. Ensure a valid Bearer token is available. If not, authenticate with `POST https://polynom-api.finekra.com/api/Auth/DealerLogin` using credentials supplied by the user.
6. For non-auth endpoints, include `Authorization: Bearer <token>` and `Content-Type: application/json` unless the endpoint documentation says otherwise.
7. Show the method, URL, headers, and body before executing unless the user explicitly says to send/run the request immediately.
8. Never invent endpoint paths, enum values, IDs, date formats, or required fields. Verify them from the live docs when missing.

## GitBook Workflow

For requests like "GitBook'ta ara", "yardim bankasinda bul", "api docs'tan bak", or when endpoint details are unclear, read `references/finekra-gitbook.md`.

Use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\bin\gitbook.ps1" ask yardim "odeme"
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\bin\gitbook.ps1" search api "DealerLogin" 10
```

Search order is `yardim` first, then `api`, then a specific page lookup when required.

## VPN and Elastic Workflow

For requests like "connect VPN", "open Elastic", "check Kibana logs", "SQL'e baglan", "read sql", or "find account movement logs by tenantId/date", read `references/finekra-observability.md`.

VPN connection rule: open FortiClient, go to `Remote Access`, explicitly select VPN profile `Finekra`, then enter the VPN username/password. Do not rely on the currently selected FortiClient profile. If the `Finekra` profile cannot be selected, stop instead of trying another profile.

For transactionV2 account movement logs by tenantId/bankInfoId/bankId, use field filters from `references/finekra-observability.md`: lowercase GUID values, `Data.TenantId.keyword`, `Data.BankInfoId.keyword`, and bank id as `Data.BankCode.keyword` with 4-digit zero padding when needed, e.g. user `bankId=15` maps to `Data.BankCode.keyword = "0015"`.

Use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/connect-finekra-vpn.ps1 -Username "<from vault>" -Password "<from vault>"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-finekra-network.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/search-finekra-logs.ps1 -TenantId "<tenant-id>" -Date "2026-05-10" -Module transactionV2 -IncludeApiCheck
```

If FortiClient stalls around 40-50% or the script prints `WAITING_FOR_PHONE_APPROVAL`, ask the user to approve the phone prompt or provide the current token, then continue waiting and verify `172.16.220.58:22` and `172.16.220.59:5601`.

For SQL read access, first check whether VPN/internal SQL is reachable. If not reachable, connect VPN with the `Finekra` profile before attempting SQL. Use the SQL read credentials from Vaultwarden item `Finekra SQL Read - 172.16.220.50`; if the vault is unavailable, read the `SQL` section in the desktop `HESAP BILGILERI` account-info file at runtime and never print the password. Start with read-only discovery queries only.

## ManualProcess Workflow

For requests like "manuel process", "manualProcess", "eksik hesap hareketlerini getir", or "bankInfoId için gün gün çek", read `references/finekra-manual-process.md`.

Always preview first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-manual-process.ps1 -BankInfoId "<bankInfoId>" -StartDate "2026-04-01" -EndDate "2026-05-01" -Daily
```

Only execute after explicit confirmation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-manual-process.ps1 -BankInfoId "<bankInfoId>" -StartDate "2026-04-01" -EndDate "2026-05-01" -Daily -BearerToken "<token>" -Execute
```

## GetFromBank Workflow

For requests like "getFromBank", "POS raporu manuel cek", or "pos raporlarini getir", read `references/finekra-getfrombank.md`.

Use:

```powershell
.\scripts\run-getfrombank.bat "<bankInfoId>" "2026-01-01" "2026-01-01" 3
```

This endpoint runs without an API token. The runner still uses server `172.16.220.58` over SSH and previews requests before execution.

## DailyAccountTransaction Workflow

For requests like "gun sonu raporu", "dailyAccountTransaction", or "hesap bakiyelerini gun sonu raporuna yaz", read `references/finekra-daily-account-transaction.md`.

Use:

```powershell
.\scripts\run-daily-account-transaction.bat 64 "<tenantId>" "2026-05-01" "2026-05-12" 3
```

If the end date is omitted, the runner uses today. This endpoint runs without an API token and previews requests before execution.

## Visible BAT Runner Workflow

When the user asks to run ManualProcess, GetFromBank, or DailyAccountTransaction as `.bat`, "bat olarak calistir", or says they want to watch it on screen, read `references/finekra-visible-bat-runners.md`.

Use the persistent project BAT files under:

```text
C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts
```

Open them with `Start-Process` in a visible `cmd.exe` window. The user will type `YES` in that window after preview.

If the persistent project folder or runner files are missing, restore them with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\EmircanÇağın\.codex\skills\finekra-api\scripts\restore-finekra-runners.ps1"
```

After adding new reusable runner files, skill scripts, or references in the persistent project, sync them to the global skill with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\EmircanÇağın\.codex\skills\finekra-api\scripts\sync-finekra-runners-to-global.ps1"
```

## Safety Rules

- Do not store real customer credentials, production tokens, or private tenant details in the skill.
- Do not store the `172.16.220.58` Windows/SSH password in the skill or reference files.
- Ask for confirmation before calling production endpoints, creating or updating records, initiating payments, or making any request with financial side effects.
- Redact tokens and passwords in chat output. Show only prefixes/suffixes when needed for debugging.
- Use `https://polynom-api.finekra.com/api` as the default Finekra API base URL. Do not use `https://test-api.finekra.com/api` unless the user explicitly asks for test environment access.

## Remote Execution

Default remote execution target:

```text
Host: 172.16.220.58
User: emircancagin
Route: SSH to Windows, then run PowerShell on the server
```

Use `scripts/invoke-finekra-remote.ps1` for repeatable calls. Pass credentials as parameters or prompt-time values; never write them into files. Use `-ShowFullToken` only when the user explicitly asks to see the full token.

Common examples:

```powershell
# Auth only, redacted token
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-finekra-remote.ps1 -SshPassword "<ssh-password>" -FinekraEmail "<email>" -FinekraPassword "<password>" -TenantCode "<tenant-code>" -AuthOnly

# Auth + account transactions in Postman-like JSON output
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-finekra-remote.ps1 -SshPassword "<ssh-password>" -FinekraEmail "<email>" -FinekraPassword "<password>" -TenantCode "<tenant-code>" -Path "/AccountTransaction" -QueryString '$filter=date(TransactionDateValue) ge 2026-05-11T00:00:00Z and date(TransactionDateValue) le 2026-05-11T21:00:00Z'
```

## Response Pattern

When preparing a request, respond with:

```text
Method: ...
URL: ...
Headers:
  Authorization: Bearer <redacted>
  Content-Type: application/json
Body:
...
Notes:
...
```

When executing a request, summarize status code, success flag/message, and the relevant response fields. Do not paste full tokens.
