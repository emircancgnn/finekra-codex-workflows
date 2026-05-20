---
name: finekra-api
description: Use when working with the Finekra API, including GitBook docs, API calls, Auth/DealerLogin, Bearer tokens, VPN, server 58, Elastic/Kibana, SQL read access, account movement logs, ManualProcess, GetFromBank, and DailyAccountTransaction.
---

# Finekra API

This skill is the router for Finekra operational work. Keep this file short; put durable details in `references/*.md` and runnable automation in `scripts/*.ps1`.

## Routing

Read only the references needed for the user's current task:

- API request prep/execution, Auth/DealerLogin, endpoint rules: `references/finekra-api.md`
- Remote execution through server `172.16.220.58`: `references/finekra-remote-execution.md`
- GitBook documentation lookup/routing: `references/finekra-gitbook.md`
- VPN, Elastic/Kibana, transactionV2 logs, SQL read workflow: `references/finekra-observability.md`
- ManualProcess / missing account movements: `references/finekra-manual-process.md`
- GetFromBank / POS report manual pull: `references/finekra-getfrombank.md`
- DailyAccountTransaction / end-of-day account balance report: `references/finekra-daily-account-transaction.md`
- Visible `.bat` runner behavior: `references/finekra-visible-bat-runners.md`
- Safety, credential handling, production-risk rules: `references/finekra-safety.md`
- Repo persistence and GitHub push behavior: `references/finekra-github-workflow.md`

## Default Rules

- Verify endpoint, field, date, enum, and ID details from the relevant reference or live docs before acting.
- Use `https://polynom-api.finekra.com/api` as the default API base unless the user explicitly requests another environment.
- Execute Finekra API calls through server `172.16.220.58` over SSH unless the user explicitly requests a different route.
- For internal resources, verify VPN/network reachability first; if needed, connect FortiClient with profile `Finekra`.
- Treat SQL as read-only by default.
- Ask for confirmation before production side effects.
- Redact secrets in chat output.

## Response Pattern

When preparing a request, show:

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

When executing a request, summarize status code, success flag/message, and relevant response fields. Do not paste full tokens.
