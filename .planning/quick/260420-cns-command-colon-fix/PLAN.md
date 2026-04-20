---
slug: 260420-cns-command-colon-fix
type: quick
created: 2026-04-20
status: in-progress
---

# Quick: Rewrite `/gsd-<skill>` → `/gsd:<skill>` across plugin content

## Problem

Claude Code's plugin namespace uses `/gsd:<name>` (colon). Confirmed: every `SKILL.md` in `skills/` has `name: gsd:<name>`, no dash-style registration. But ~145 occurrences of legacy dash-style `/gsd-<name>` live across SKILL.md bodies, agent prompts, references, templates, README, bin code. Inherited from upstream GSD (which registers commands without namespace, so `/gsd-foo` works there). Under the plugin, every dash-style reference is dead text that produces `Unknown command: /gsd-foo. Did you mean /gsd:foo?` when a user or Claude tries to run it.

## Fix (scope A, per user pick)

Precise rewrite driven by the actual skill registry:

1. Enumerate skill names from `skills/gsd-<name>/SKILL.md` directories (81 skills).
2. Build regex `/gsd-(<skill1>|<skill2>|...)(?![a-z-])` — exact skill-name match with negative lookahead so we don't partial-match longer names or adjacent hyphens. Alternatives sorted longest-first as a belt (not load-bearing — skill names don't share prefixes).
3. Walk `git ls-files`, filter to text extensions (`.md`, `.cjs`, `.js`, `.json`, etc.), skip historical/archive dirs (`_research/`, `.planning/milestones/v1.0-*`, `.planning/phases/04-*`, `.planning/quick/260418*` and earlier historical task summaries).
4. Replace in-place, atomically commit the whole rewrite in one commit.

## Why skill-registry-driven (not generic regex)

- Safe against false positives like `/gsd-local-patches` (a directory name in reapply-patches SKILL.md) — it's not a skill, so it's not in the alt, so it doesn't match.
- Self-updating: next time the skill list grows, the same script re-runs correctly.

## Why skip historical dirs

- `_research/` — Claude Code source snapshot. Not ours to edit.
- `.planning/milestones/v1.0-*` — shipped milestone archive. Historical record.
- `.planning/phases/04-*` — Phase 4 artifacts, already shipped. Historical record of a session where this text was live.
- Early quick-task dirs — historical records of commands that were run in past sessions (the commands ran because they weren't plugin-namespaced at the time).

## Out of scope

- The CI-guard / post-sync normalization step (option D). Adding that would prevent regression on upstream sync, but the user picked A only. If the next upstream sync reintroduces dashes, re-run this same rewrite.
- Changes outside text content (e.g., runtime shim in gsd-tools.cjs to rewrite emitted `/gsd-*` strings). Also option C-adjacent; rejected earlier.

## Verification

- After rewrite: `grep -rE '[^a-zA-Z/]/gsd-(<alt>)(?![a-z-])'` against the same file set should return 0 matches.
- JSON files still parse.
- `node bin/gsd-tools.cjs current-timestamp date` still runs (smoke test that bin/ wasn't broken).
