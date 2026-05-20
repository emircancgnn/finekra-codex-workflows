# Finekra API Reference

Source documentation: https://finekra.gitbook.io/finekra-api

Last checked while creating this skill: 2026-05-11.

## Base Documentation Structure

- Authentication: https://finekra.gitbook.io/finekra-api
- Test erisim bilgileri: https://finekra.gitbook.io/finekra-api/test-erisim-bilgileri (do not use unless the user explicitly asks for test environment access)
- Genel Servisler: https://finekra.gitbook.io/finekra-api/genel-servisler
- Hesap Hareketleri Servisi: https://finekra.gitbook.io/finekra-api/hesap-hareketleri-servisi
- POS Rapor Servisi: https://finekra.gitbook.io/finekra-api/pos-rapor-servisi
- Online DBS Servisleri: browse from the GitBook sidebar
- Toplu Odeme Servisi: browse from the GitBook sidebar
- Sanal Pos Tahsilat Servisi: browse from the GitBook sidebar

## Authentication

Purpose: create the Bearer token used by other Finekra API endpoints.

Endpoint:

```text
POST https://polynom-api.finekra.com/api/Auth/DealerLogin
```

Request body shape:

```json
{
  "email": "<api email>",
  "password": "<api password>",
  "tenantCode": "<tenant code>",
  "screenOption": 0
}
```

Notes:

- `screenOption` is sent as `0`.
- Email, password, and tenant code are supplied by Finekra or by the user.
- The response contains `data.token` and `data.expiration`.
- Use the returned token as `Authorization: Bearer <token>` for other API requests.

Do not use the public documentation's test credentials unless the user explicitly requests the test environment. For normal use, ask the user for the real API email, password, and tenant code or use a token they provide.

## General Request Rules

Default headers for JSON endpoints:

```text
Authorization: Bearer <token>
Content-Type: application/json
Accept: application/json
```

Use the exact HTTP method, URL, query parameters, and body from the relevant Finekra GitBook page. Many listing endpoints support OData-style filtering according to the docs; verify the exact supported filter syntax on the endpoint page before using it.

## Required Network Route

For this user's environment, Finekra API calls should normally be executed from the Windows server `172.16.220.58`, not directly from the local Codex machine. Connect over SSH as user `emircancagin`, then run PowerShell commands on that server. Do not save the SSH password, Finekra password, tenant code, or returned token in the skill files.

Use `scripts/invoke-finekra-remote.ps1` from the skill folder when authenticating through the server.

The script returns a Postman-like JSON object with:

- `auth.request` and `auth.response`
- `api.request` and `api.response` when a second API path is supplied
- `remoteHost` so the caller can confirm the request ran on `172.16.220.58`

Use `-ShowFullToken` only if the user explicitly asks for the full token.

## Service Notes

### Genel Servisler

Used for reference data such as banks, bank branches, currencies, and customer/account related operations. Read this section to resolve IDs such as `BankID` and `CurrencyID` before calling account, transaction, or POS endpoints.

### Hesap Hareketleri Servisi

High-level flow:

1. Authenticate and obtain a Bearer token.
2. Ensure bank access definitions exist. If the customer manages bank access through Finekra screens, API-side bank access setup may not be required.
3. Wait for accounts and transactions to appear after bank access setup; the docs mention data can start reflecting within about 30 minutes.
4. Use account listing before querying account movements when bank/currency/account IDs are needed.

Use this section for:

- Bank access operations
- Account listing
- Account movement listing
- Account movement receipt/dekont service

Account movement listing:

```text
GET /api/AccountTransaction
```

Example OData date filter:

```text
$filter=date(TransactionDateValue) ge 2025-03-12T00:00:00Z and date(TransactionDateValue) le 2025-03-12T21:00:00Z
```

The base URL for this environment is `https://polynom-api.finekra.com/api`, so the full URL is:

```text
https://polynom-api.finekra.com/api/AccountTransaction?$filter=...
```

### POS Rapor Servisi

Used for listing and reporting bank POS movements. The docs state POS data is generally provided after end-of-day completion, so data received today may represent the previous day's POS transactions.

Use this section for:

- POS access operations
- POS movement listing
- POS valor reports by day/month
- POS turnover reports by day/month

### Online DBS, Toplu Odeme, Sanal POS

These sections require reading the live GitBook page for the exact endpoint, payload, required identifiers, and side-effect risks before preparing or executing requests.

## Execution Checklist

Before sending a Finekra request:

1. Use `https://polynom-api.finekra.com/api` as the default base URL.
2. Confirm before using any other base URL, especially the test API.
3. Confirm auth credentials or token source.
4. Verify the exact endpoint from the docs.
5. Build URL, headers, query params, and body.
6. Show the request preview unless the user explicitly authorized immediate execution.
7. Redact secrets in all displayed output.
