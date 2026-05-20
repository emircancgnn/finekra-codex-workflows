# Finekra Safety Rules

Use this before operations involving credentials, production endpoints, SQL, Elastic logs, or customer data.

## Credentials

- Do not store real customer credentials, production tokens, VPN secrets, SQL passwords, Elastic passwords, or server credentials in skills, AGENTS, memory notes, or git.
- Prefer Vaultwarden/Bitwarden items:
  - `Server 58 - emircancagin`
  - `Finekra VPN - polynom.usr09`
  - `Finekra SQL Read - 172.16.220.50`
  - `Elastic - 172.16.220.59`
- If Vaultwarden is unavailable, read the approved local account-info source only at runtime and do not print passwords.
- Redact tokens and passwords in chat output. Show only prefixes/suffixes when needed for debugging.

## Vaultwarden Priority

- Treat Vaultwarden/Bitwarden CLI as the primary credential source.
- Use `scripts/get-finekra-vault-item.ps1` for reusable script access to vault login items.
- Use local encrypted files such as `secrets\manual-process.local.json` only as fallback.
- Use `C:\Users\EmircanÇağın\Desktop\HESAP BİLGİLERİ.txt` only as last-resort runtime fallback for specific sections, and never print secrets from it.

Expected reusable vault items:

- `Server 58 - emircancagin`
- `Finekra VPN - polynom.usr09`
- `Finekra SQL Read - 172.16.220.50`
- `Elastic - 172.16.220.59`
- `Finekra ManualProcess API - finekra-api@emircan.com`

For `Finekra ManualProcess API - finekra-api@emircan.com`, include `tenantCode` as a custom field.

## Production Changes

Ask for confirmation before:

- Creating or updating records
- Initiating payments or financial side effects
- Running ManualProcess, GetFromBank, DailyAccountTransaction, or similar job-triggering endpoints
- Running non-read-only SQL
- Restarting services or changing VPN/server configuration

## SQL

- SQL access is read-only by default.
- Do not run `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `TRUNCATE`, `DROP`, `ALTER`, `CREATE`, side-effect stored procedures, or job-triggering SQL unless the user explicitly confirms.
- Prefer targeted schema discovery and filtered lookup queries.

## Logs and Customer Data

- Summarize sensitive logs instead of dumping broad customer payloads.
- Do not persist live customer log exports in git.
- When a log contains credentials, tokens, bank passwords, access tokens, or authentication payloads, redact them before sharing.

## Environment

- Use `https://polynom-api.finekra.com/api` as the default Finekra API base URL.
- Do not use test API unless the user explicitly asks for test environment access.
