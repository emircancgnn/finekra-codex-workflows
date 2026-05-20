# Finekra Remote Execution

Use this when Finekra API calls must run from the Windows server `172.16.220.58`.

## Default Target

```text
Host: 172.16.220.58
User: emircancagin
Route: SSH to Windows, then run PowerShell on the server
```

Use `scripts/invoke-finekra-remote.ps1` for repeatable API calls. Pass credentials as parameters or prompt-time values; never write them into files.

Use `-ShowFullToken` only when the user explicitly asks to see the full token.

## Examples

Auth only, redacted token:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-finekra-remote.ps1 -SshPassword "<ssh-password>" -FinekraEmail "<email>" -FinekraPassword "<password>" -TenantCode "<tenant-code>" -AuthOnly
```

Auth plus account transactions:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/invoke-finekra-remote.ps1 -SshPassword "<ssh-password>" -FinekraEmail "<email>" -FinekraPassword "<password>" -TenantCode "<tenant-code>" -Path "/AccountTransaction" -QueryString '$filter=date(TransactionDateValue) ge 2026-05-11T00:00:00Z and date(TransactionDateValue) le 2026-05-11T21:00:00Z'
```

## Output Expectations

The script returns a Postman-like JSON object with:

- `auth.request` and `auth.response`
- `api.request` and `api.response` when a second API path is supplied
- `remoteHost` so the caller can confirm the request ran on `172.16.220.58`

## Credential Handling

- Prefer Vaultwarden item `Server 58 - emircancagin`.
- If Vaultwarden is unavailable, ask at runtime.
- Do not persist SSH passwords, Finekra API passwords, tenant codes, or returned tokens in files.
