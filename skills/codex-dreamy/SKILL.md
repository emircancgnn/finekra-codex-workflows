---
name: codex-dreamy
description: Use when the user asks for a weekly/background Codex maintenance pass, "dreamy", memory/skill optimization, stale workflow cleanup, or a report on whether persistent Codex/Finekra instructions still line up. This is a report-first Codex adaptation of the user's Claude dreamy command.
---

# Codex Dreamy

This is the Codex-compatible adaptation of the user's Claude `dreamy.md`.

It is intentionally less aggressive than the Claude version. Codex should not silently delete files, rotate credentials, restart services, modify production systems, clean branches, or auto-fix broad infrastructure. The default output is a maintenance report plus small, explicit patches when the risk is low.

## Scope

Check:

- Global instructions: `$HOME\.codex\AGENTS.md`
- Global skills: `$HOME\.codex\skills\`
- Finekra project: `$HOME\Documents\Projects\finekra-api-work\`
- Finekra local skill: `$HOME\Documents\Projects\finekra-api-work\.codex\skills\finekra-api\`
- Memory update notes: `$HOME\.codex\memories\extensions\ad_hoc\notes\`
- Logs/output folder: `$HOME\.codex\logs\codex-dreamy\`

## Weekly Workflow

1. Inspect recent memory notes, skill files, AGENTS blocks, and project scripts.
2. Detect drift:
   - Global Finekra skill differs from project Finekra skill.
   - AGENTS instructions contradict skill instructions.
   - A learned operational rule exists only in chat history or an ad-hoc note but not in the relevant skill.
   - A script referenced by a skill no longer exists.
   - A workflow still references Claude-only tools, missing MCP servers, Unix-only daemon tools, or unavailable local commands.
3. Produce a markdown report under:
   `$HOME\.codex\logs\codex-dreamy\YYYYMMDD-HHMMSS-report.md`
4. Apply only low-risk documentation or skill-routing fixes when the user explicitly asked for auto-fix.
5. Ask before destructive, production, credential, network, VPN, or service changes.

## Report Sections

Use these headings:

```markdown
# Codex Dreamy Report

## Summary
## Drift Found
## Proposed Fixes
## Applied Fixes
## Needs User Decision
## Sensitive Data Check
```

## Automation Guidance

For weekly background execution, create a Codex automation that runs this maintenance pass against the persistent Finekra workspace. The automation prompt should request a report-first audit and should not ask the agent to perform production side effects.

## Safety Rules

- Do not print or persist raw secrets.
- Do not read credential files unless the maintenance task specifically needs to verify that routing exists; even then, report only item names or file existence.
- Do not modify `MEMORY.md` directly.
- Use ad-hoc memory notes for new durable lessons only when the user explicitly asked for memory updates.
- Prefer small patches to `AGENTS.md` or skill files over broad rewrites.
