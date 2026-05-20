# Finekra DailyAccountTransaction

Use this workflow for manually generating daily end-of-day account balance reports.

## Endpoint

- Route: execute from server `172.16.220.58`
- Method: `POST`
- URL: `http://172.16.220.52:8080/api/DailyAccountTransaction`
- Headers:
  - `Content-Type: application/json`
  - `Accept: application/json`
- Authorization: not required for this internal route

## Body

```json
{
  "BankId": 64,
  "TenantId": "D6B307BF-B8F4-ED11-A2D3-005056B667E2",
  "Date": "2026-01-01"
}
```

## Local Runner

```powershell
.\scripts\run-daily-account-transaction.bat 64 D6B307BF-B8F4-ED11-A2D3-005056B667E2 2026-05-01 2026-05-12 3
```

If `END_DATE` is omitted, the runner uses today. The final argument is delay seconds between daily requests. If omitted, the default is 3 seconds.

The runner previews requests first and only executes when the user types `YES`.
