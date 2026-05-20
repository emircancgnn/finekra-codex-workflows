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
