# Finekra Manual Process

Use this workflow when the user asks to manually fetch missing account movements after bank credentials were broken or restored.

## Endpoint

Default endpoint:

```text
POST http://172.16.220.53:8181/api/Account/ManualProcess
```

Default route:

```text
Local Codex -> Finekra VPN -> SSH to 172.16.220.58 -> call 172.16.220.53:8181 from server 58
```

## Request Body

```json
{
  "startDate": "2026-04-01T00:00:00",
  "endDate": "2026-04-01T23:59:59",
  "bankInfoId": "<bankInfoId>"
}
```

## Script

Preview without sending requests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/skills/finekra-api/scripts/invoke-manual-process.ps1 -BankInfoId "<bankInfoId>" -StartDate "2026-04-01" -EndDate "2026-05-01" -Daily
```

Execute after explicit user confirmation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/skills/finekra-api/scripts/invoke-manual-process.ps1 -BankInfoId "<bankInfoId>" -StartDate "2026-04-01" -EndDate "2026-05-01" -Daily -BearerToken "<token>" -Execute
```

If no `-BearerToken` is supplied, the script can authenticate with:

```powershell
-FinekraEmail "<email>" -FinekraPassword "<password>" -TenantCode "<tenant-code>"
```

Never write token, password, tenant-specific secrets, or customer-private data into skill files or the repository.

## Safety

- Always show preview output first.
- Ask for explicit confirmation before running with `-Execute`.
- Prefer daily split (`-Daily`) for month-long gaps.
- Summarize each day's status, response, and error without printing full tokens.
- If a day fails, do not blindly retry the full range; retry the failed day only after reviewing the error.
