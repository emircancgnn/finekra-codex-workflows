# Finekra GetFromBank

Use this workflow for POS report manual pulls by `bankInfoId` and date range.

## Endpoint

- Route: execute from server `172.16.220.58`
- Method: `POST`
- URL: `http://172.16.220.53:8080/api/Transaction/GetFromBank`
- Headers:
  - `Content-Type: application/json`
  - `Accept: application/json`
- Authorization: not required for this internal route

## Body

```json
{
  "startDate": "2026-01-01T00:00:00",
  "endDate": "2026-01-01T23:59:59",
  "bankInfoId": "AB1DD89A-38BA-F011-A2D9-005056B667E2"
}
```

## Local Runner

```powershell
.\scripts\run-getfrombank.bat AB1DD89A-38BA-F011-A2D9-005056B667E2 2026-01-01 2026-01-01 3
```

The final argument is delay seconds between daily requests. If omitted, the default is 3 seconds.

The runner previews requests first and only executes when the user types `YES`.

## Required Visible Behavior

- The normal `.bat` execution path must not use Vaultwarden and must never ask for a Vaultwarden master password.
- Load server 58 SSH credentials from the encrypted local credential file:

```text
secrets\manual-process.local.json
```

- Execute GetFromBank requests through server `172.16.220.58`.
- Split date ranges into daily requests.
- After the user types `YES`, print live progress in the visible terminal for each day:

```text
START [1/14] 2026-05-12
OK    [1/14] 2026-05-12
WAIT  3 seconds
START [2/14] 2026-05-13
ERROR [2/14] 2026-05-13
Summary: OK=... ERROR=... TOTAL=...
```

- Save output under `outputs\getfrombank`.
- Do not buffer all request output until the end; the user must be able to see day-by-day progress while the `.bat` is running.
