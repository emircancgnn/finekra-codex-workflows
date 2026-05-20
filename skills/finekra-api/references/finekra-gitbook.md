# Finekra GitBook

Use the local GitBook helper to search Finekra internal documentation directly through the GitBook REST API.

## Spaces

- Yardim Bankasi: `wpgc6v8I6H39GYxICOwS` alias `yardim`
- API: `6cN4pqv0CDlceuteo6zV` alias `api`

## Routing Order

For Finekra technical questions, use this lookup order:

1. Search `yardim`
2. Search `api`
3. If needed, open a specific page by page id or page path

## Helper Script

Path:

```text
C:\Users\EmircanÇağın\.codex\bin\gitbook.ps1
```

Token source:

```text
C:\Users\EmircanÇağın\.codex\secrets.ps1
```

## Commands

List pages:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\bin\gitbook.ps1" list yardim
```

Search:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\bin\gitbook.ps1" search api "DealerLogin" 10
```

Ask:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\bin\gitbook.ps1" ask yardim "odeme"
```

Open page by page id or page path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.codex\bin\gitbook.ps1" page api "<page-id-or-path>"
```

## Notes

- Do not write the GitBook token into AGENTS, repo files, or versioned files.
- If GitBook queries fail with `401`, update `C:\Users\EmircanÇağın\.codex\secrets.ps1`.
- If `403`, the token does not have access to the requested space.
- If `429`, wait and retry.
