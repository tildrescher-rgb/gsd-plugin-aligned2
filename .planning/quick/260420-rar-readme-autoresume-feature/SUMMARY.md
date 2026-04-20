---
slug: 260420-rar-readme-autoresume-feature
type: quick
created: 2026-04-20
completed: 2026-04-20
status: complete
commit: 21ee182
---

# Summary: Add autoresume feature bullet to README

## What changed

`README.md` — one bullet added under **What GSD Plugin provides**, between the existing *Hooks* bullet and the *Execution context profiles* bullet:

> **Auto-resume across `/compact`** -- PreCompact hook writes `.planning/HANDOFF.json`; on the next session, SessionStart auto-invokes `/gsd:resume-work` so Claude continues at the same phase/plan/task with zero manual intervention

## Verification

- `git diff HEAD~1 README.md` shows a single additive line (no other edits).
- Bullet sits in the right list section (`## What GSD Plugin provides`) and reads consistently with surrounding bullets in tone and structure.
- Feature described matches implemented behavior (Phase 4 live UAT passed earlier today).

## Commit

`21ee182` — docs(quick-260420-rar): advertise auto-resume across /compact in README
