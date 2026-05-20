# Finekra GitHub Workflow

Use this when updating durable Finekra Codex workflows, skills, AGENTS instructions, restore scripts, or workflow documentation.

## Repository

```text
Local: C:\Users\EmircanÇağın\Documents\Projects\finekra-codex-workflows
Remote: https://github.com/emircancgnn/finekra-codex-workflows
Branch: main
```

## Push Rule

Do not auto-push.

After important updates, ask:

```text
GitHub'a pushlayalım mı?
```

Only run `git add`, `git commit`, or `git push` after the user confirms.

## Normal Commands

```powershell
git status
git add .
git commit -m "Update Finekra workflow docs"
git push
```

## Do Not Commit

- `secrets/`
- `.env`
- local credential files
- Vaultwarden data
- `outputs/`
- live customer log dumps
- tokens, passwords, API keys, MFA values
