# Finekra VPN and Elastic Observability

## Credential Sources

- Vaultwarden URL: `https://localhost:8080`
- Vaultwarden account email: `emircancgn.35@gmail.com`
- FortiClient VPN item: `Finekra VPN - polynom.usr09`
- Elastic/Kibana item: `Elastic - 172.16.220.59`
- Server 58 SSH item: `Server 58 - emircancagin`

Never store or print passwords, tokens, or MFA codes.

## VPN Workflow

Use FortiClient profile `Finekra` before accessing internal resources:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/skills/finekra-api/scripts/connect-finekra-vpn.ps1 -Username "<from vault>" -Password "<from vault>"
```

To verify profile selection without entering credentials:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/skills/finekra-api/scripts/connect-finekra-vpn.ps1 -Username "placeholder" -Password "placeholder" -ValidateProfileOnly
```

Required order for Codex automation:

1. Open FortiClient.
2. Go to `Remote Access`.
3. Explicitly select `VPN Name = Finekra`.
4. Enter the VPN username/password.
5. Click/connect and wait for phone approval when prompted.
6. Only after connection, verify `172.16.220.58:22`, `172.16.220.59:9200`, and `172.16.220.59:5601`.

Never assume the currently selected FortiClient profile is correct. If the `Finekra` profile cannot be selected, stop and report that instead of entering credentials into another profile.

If the script prints `WAITING_FOR_PHONE_APPROVAL`, ask the user for phone approval or the current token, then keep waiting and verify the network again.

Verify access:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/skills/finekra-api/scripts/verify-finekra-network.ps1
```

Search logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/skills/finekra-api/scripts/search-finekra-logs.ps1 -TenantId "<tenant-id>" -Date "2026-05-10" -Module transactionV2 -IncludeApiCheck
```

Default mode is direct Elasticsearch on `http://172.16.220.59:9200` with HTTP Basic auth. Use `-Mode Kibana` only if direct ES access is insufficient and you need Kibana-backed search behavior.

Supported `-Module` values:

- `transactionV2`
- `api`
- `b2b`
- `dbs`
- `pos`
- `tos`

Use `-ErrorsOnly` to return only strict error/failure matches in the sample set. The script always returns `totalLogs`, `errorLogs`, level/message distributions, and samples.

Expected reachable resources after VPN:

- `172.16.220.58:22` for SSH
- `172.16.220.50:1433` for Finekra SQL read access
- `172.16.220.59:9200` for direct Elasticsearch
- `172.16.220.59:5601` for Kibana
- VPN source address commonly appears as `10.212.153.202`

## SQL Read Workflow

Use this workflow when the user asks to inspect Finekra SQL data, map tenant/bankInfo relationships, or run read-only SQL queries.

Connection target:

```text
Server: 172.16.220.50
Port: 1433
Login item: Finekra SQL Read - 172.16.220.50
Known server name after connection: POLYNOMSRV
Default database for connection test: master
```

Required order:

1. Check VPN/internal reachability first:

```powershell
Test-NetConnection 172.16.220.50 -Port 1433
```

2. If SQL is not reachable, connect Finekra VPN. Open FortiClient, go to `Remote Access`, explicitly select VPN profile `Finekra`, enter the VPN credentials from the vault, and wait for the user's phone approval/token if prompted.
3. After VPN connects, re-check `172.16.220.50:1433`.
4. Read SQL credentials from Vaultwarden item `Finekra SQL Read - 172.16.220.50`. If Vaultwarden is unavailable, read only the `SQL` section from the desktop account-info file at runtime and do not print the password.
5. Start with minimal read-only queries:

```sql
SELECT @@SERVERNAME AS ServerName, DB_NAME() AS CurrentDatabase, SUSER_SNAME() AS LoginName, SYSTEM_USER AS SystemUser;
SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

Safety:

- Treat this as read-only access.
- Do not run `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `TRUNCATE`, `DROP`, `ALTER`, `CREATE`, `EXEC` side-effect procedures, or any job-triggering SQL unless the user explicitly asks and confirms the risk.
- Do not dump broad customer tables. Prefer schema discovery and targeted lookups.
- Do not store connection strings, passwords, customer private data, or bank credentials in memory, AGENTS, or skill files.
- When reporting findings, summarize table/column relationships and query templates rather than sensitive row payloads.

## Kibana Workflow

Kibana URL:

```text
http://172.16.220.59:5601/
```

Use Vaultwarden item `Elastic - 172.16.220.59` for login.

For account movement investigations, use the Finekra API reference terms to guide log search:

- API service: `Hesap Hareketleri Servisi`
- Endpoint clue: `/api/AccountTransaction`
- Main date field in API requests: `TransactionDateValue`
- User-provided filters: `tenantId` and date/date range

Known Discover data views / log groups:

- `finekra-api-prod-log`: logs for requests passing through the main Finekra API.
- `finekra-api-prod-log-*`: logs for requests passing through the main Finekra API.
- `finekra-b2b-api-prod-log-*`: B2B module logs.
- `finekra-dbs-job-prod-log-*`: DBS module logs.
- `finekra-pos-transaction-job-prod-log-*`: POS report / POS transaction logs.
- `finekra-tos-job-prod-log-*`: TOS module logs.
- `finekra-transactionv2-job-prod-log-*`: account movement / hesap hareketi logs.

For "hesap hareketleri" or account transaction log requests, start with `finekra-transactionv2-job-prod-log-*`. If the question is about whether the public API request reached the API layer, also check `finekra-api-prod-log-*`.

## transactionV2 Field Filters

For account movement request/log lookups where the user gives `tenantId`, `bankInfoId`, and `bankId`, prefer direct Elasticsearch field filters instead of broad text search:

- `Data.TenantId.keyword`
- `Data.BankInfoId.keyword`
- `Data.BankCode.keyword`

Normalize GUIDs to lowercase before `term` queries because transactionV2 logs store values lowercase. Normalize numeric bank ids to the bank code string when filtering `Data.BankCode.keyword`: `15` should also be searched as `"0015"`, `32` as `"0032"`, `210` as `"0210"`. If a `Data.BankCode.keyword` query returns no results, also try `Data.BankId` and `Data.Request.BankId` as fallback fields.

Known successful example from 2026-05-12:

```text
TenantId: A430454A-97E1-F011-A2D9-005056B667E2 -> a430454a-97e1-f011-a2d9-005056b667e2
BankInfoId: A6E60CCC-C5E4-F011-A2D9-005056B667E2 -> a6e60ccc-c5e4-f011-a2d9-005056b667e2
bankId: 15 -> Data.BankCode.keyword = "0015"
Index: finekra-transactionv2-job-prod-log-*
Result: 780 logs, all Information; BankService.Process finish logs had StatusDetail.Status = true.
```

For this pattern, report grouped request start times from `message = "Hesap görevi başladı."`, bank completion times from `message = "Banka isteği tamamlandı."`, and whether `Data.StatusDetail.Status` is true or exceptions exist.

Initial Kibana search strategy when the exact index pattern is not yet known:

1. Open Kibana Discover.
2. Select the relevant data view. For account movement logs, select `finekra-transactionv2-job-prod-log-*`.
3. Set the date picker to the user-provided date or date range. For a single date, use the full local day from `00:00:00` through `23:59:59`.
4. Search first by exact tenant id.
5. For error checks, add or inspect error clues such as `error`, `exception`, `fail`, `failed`, `statusCode >= 400`, `level:error`, `LogLevel:Error`, or equivalent fields shown in the documents.
6. Narrow account movement searches with clues such as `AccountTransaction`, `TransactionDateValue`, `Hesap`, `Hareket`, `BankAccount`, or the exact endpoint path.
7. Inspect matching documents to identify the stable timestamp field, tenant field, message field, log level field, request path field, and correlation/request id fields.
8. Report whether logs exist for that tenant/date, whether error logs exist, and include relevant timestamps, messages, exception summaries, endpoint names, status codes, and correlation ids. Redact secrets and customer-private payload values unless the user explicitly needs a specific field.

Known data view ids:

- `finekra-transactionv2-job-prod-log-*`: `f6f59420-8fb4-11f0-96db-1d1317ce4365`
- `finekra-api-prod-log-*`: `d6cba180-8fb4-11f0-96db-1d1317ce4365`

Known fields from 2026-05-10 checks:

- Common timestamp field: `@timestamp`
- Common log level field: `level.keyword`
- Common message template field: `messageTemplate.keyword`
- Common source context field: `SourceContext.keyword`
- API request path field in `finekra-api-prod-log-*`: `RequestPath.keyword`
- `transactionV2` account movement docs commonly include `BankAccountJobId`, `BankJobId`, and `Data`.

When reporting results, include total tenant log count, level distribution, message distribution, and strict error query result count.
