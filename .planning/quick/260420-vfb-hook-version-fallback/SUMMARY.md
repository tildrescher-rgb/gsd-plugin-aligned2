---
slug: 260420-vfb-hook-version-fallback
type: quick
created: 2026-04-20
completed: 2026-04-20
status: complete
commit: 7a80d47
---

# Summary: Hook version fallback

## What changed

`hooks/hooks.json` — all 4 hook commands (SessionStart, PreToolUse, PostToolUse, PreCompact) now invoke an inline Node resolver instead of `node "${CLAUDE_PLUGIN_ROOT}/bin/gsd-tools.cjs"` directly.

Resolver logic:
1. Candidate 1: `${CLAUDE_PLUGIN_ROOT}/bin/gsd-tools.cjs` (honours baked path when present)
2. Candidates 2+: scan `~/.claude/plugins/cache/gsd-plugin/gsd/X.Y.Z/bin/gsd-tools.cjs`, sorted newest semver first
3. First existing candidate wins; argv padded (`process.argv.splice(1, 0, x)`) so `gsd-tools.cjs`'s `slice(2)` parses the command correctly
4. One-line stderr notice emitted only on fallback (so debugging is possible without noise on the happy path)

## Verification

| Case | Env | Expected | Actual |
|------|-----|----------|--------|
| A | `CLAUDE_PLUGIN_ROOT=.../2.38.1` (valid) | Uses baked path, no stderr | ✓ |
| B | `CLAUDE_PLUGIN_ROOT=/tmp/nonexistent` (stale) | Falls back to newest (2.38.1), emits stderr notice | ✓ |
| C | `unset CLAUDE_PLUGIN_ROOT` | Falls back to newest silently | ✓ |
| D | Stale env + PreCompact with stdin JSON | Fallback + writes valid HANDOFF.json | ✓ |

Test D confirms the full "save work on stale plugin path" path: PreCompact hook fires even when the session's baked version dir is gone, and HANDOFF.json is written normally. The existing Phase 4 resume flow then handles continuation on next session start — no additional save/resume plumbing needed.

## Out of scope (deferred)

- Drift warning when baked path exists but is older than newest available (user rejected as option B)
- Auto-exec into newer version (user rejected as option C)
- `${CLAUDE_PLUGIN_ROOT}` references inside SKILL.md / agent / template files — those are read by Claude as prose, not shell-executed, and have a different failure class

## Commit

`7a80d47` — fix(quick-260420-vfb): hook commands fall back to newest cached plugin version
