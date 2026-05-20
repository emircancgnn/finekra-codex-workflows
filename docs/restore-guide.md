# Restore Guide

Use this repository when a project folder is lost or a new Codex environment needs the same Finekra workflows.

## Restore

From this repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\restore-codex-workflows.ps1
```

## After Restore

1. Put credentials back into Vaultwarden/Bitwarden or local secure stores.
2. Do not write raw credentials into `AGENTS.md`, skills, scripts, or git.
3. Prefer these Vaultwarden items:

- `Server 58 - emircancagin`
- `Finekra VPN - polynom.usr09`
- `Finekra SQL Read - 172.16.220.50`
- `Elastic - 172.16.220.59`
- `Finekra ManualProcess API - finekra-api@emircan.com` with custom field `tenantCode`

4. Verify network workflow:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\skills\finekra-api\scripts\verify-finekra-network.ps1"
```

5. If Vaultwarden is unavailable and visible BAT runners need local fallback credentials:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\setup-manual-process-credentials.ps1"
```

## What Is Not Restored

- Raw passwords
- API tokens
- Elastic Basic Auth password
- GitBook token
- Vaultwarden data
- `outputs/`
- customer-specific log exports
