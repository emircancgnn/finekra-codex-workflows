---
name: learn-it
description: Use when the user explicitly asks Codex to learn from a session, says "learn-it", "bunu ogren", "bunu unutma", "kalici kaydet", or asks to turn repeated mistakes/corrections into durable Codex behavior. Extract lessons from the current work, create Codex-compatible memory update notes, and optionally update relevant skills or AGENTS.md guidance without storing secrets.
---

# Learn It

This is the Codex-compatible version of the user's Claude `learn-it` workflow.

Use it only when the user explicitly asks to persist a lesson or workflow. Codex memory updates must be represented as small files under:

`$HOME\.codex\memories\extensions\ad_hoc\notes\`

Do not edit `MEMORY.md`, `memory_summary.md`, or rollout summaries directly.

## What To Capture

Extract durable lessons from:

- User corrections after Codex made a wrong assumption.
- Repeated operational workflows that should not be rediscovered.
- Project-specific lookup rules, field mappings, endpoint conventions, or command sequences.
- Verification steps that prevented a wrong result.
- Communication preferences that materially affect future work.

Skip:

- One-off facts that are unlikely to repeat.
- Raw passwords, tokens, cookies, API keys, MFA secrets, customer credentials, or bearer tokens.
- Full private logs containing sensitive payloads.
- Temporary command output unless the exact error text is needed for diagnosis.

## Codex Flow

1. Identify the lesson.
2. Decide scope:
   - Global behavior: write an ad-hoc memory note.
   - Reusable procedure: update or create a global skill under `$HOME\.codex\skills\`.
   - Finekra project procedure: update `$HOME\Documents\Projects\finekra-api-work\.codex\skills\finekra-api\` and sync to the global copy when relevant.
   - Current repo only: update project docs or project-local `AGENTS.md`.
3. Before file edits, tell the user what will be persisted.
4. Add one small memory note for each coherent lesson.
5. If a skill was changed, keep instructions operational and testable.
6. Report what was saved and where.

## Memory Note Format

Create a timestamped markdown file:

`YYYYMMDD-HHMMSS-short-slug.md`

Use this structure:

```markdown
# Title

Source: ad-hoc note from user-requested learn-it run
Date: YYYY-MM-DD
Scope: global | finekra-api | project

## Lesson

Short durable lesson.

## Use When

When this should influence future Codex behavior.

## Do

- Concrete actions Codex should take.

## Avoid

- Concrete mistakes Codex should avoid.

## Sensitive Data

No raw secrets stored. Any credentials must remain in Vaultwarden or be requested at runtime.
```

## Safety Rules

- Never persist raw secrets.
- Never claim a fact is current if it only came from old memory; refresh live when cheap and important.
- If the user asks to remember a credential, store only the vault item name or retrieval route, not the credential.
- If the lesson came from Elastic or production logs, summarize field names and query strategy, not sensitive payloads.
