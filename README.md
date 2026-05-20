# Finekra Codex Workflows

This repository stores portable Codex workflows for Finekra work.

It is designed to be cloned into a fresh workstation or Codex environment and restored with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\restore-codex-workflows.ps1
```

## Contents

- `AGENTS.md`: Finekra-oriented Codex instructions.
- `skills/finekra-api`: VPN, SQL, Elastic, GitBook, API, ManualProcess, GetFromBank, and DailyAccountTransaction workflow skill.
- `skills/learn-it`: Codex-compatible session learning workflow.
- `skills/codex-dreamy`: Weekly/background maintenance workflow.
- `scripts`: visible BAT runners and credential setup helper.
- `docs`: operational notes and restore guidance.
- `templates`: reusable Elastic and SQL query notes.

## Secrets

Do not commit secrets here.

Keep these local only:

- VPN credentials
- server passwords
- SQL passwords
- Elastic passwords
- GitBook tokens
- bearer tokens
- customer credential exports
- live log dumps containing sensitive payloads

Use Vaultwarden/Bitwarden or local runtime prompts for credentials.

## Recommended Clone Path

```text
C:\Users\EmircanÇağın\Documents\Projects\finekra-codex-workflows
```

## Restore Target

The restore script copies:

- `skills/*` to `%USERPROFILE%\.codex\skills\`
- `skills/*` to the project-local `.codex\skills\` folder used by visible BAT runners
- `AGENTS.md` to `%USERPROFILE%\.codex\AGENTS.md`, after creating a timestamped backup if it exists
- runner scripts to `C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work\scripts\`

It does not copy `secrets`, `.env`, `outputs`, or runtime credential files.
