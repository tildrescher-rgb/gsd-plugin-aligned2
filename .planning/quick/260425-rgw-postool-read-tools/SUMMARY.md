---
slug: 260425-rgw-postool-read-tools
type: quick
created: 2026-04-25
completed: 2026-04-25
status: complete
commit: 7497cc6
---

# Summary: PostToolUse matcher broadened to include read tools

## What changed

`hooks/hooks.json` PostToolUse matcher:

```diff
-"matcher": "Bash|Edit|Write|MultiEdit|NotebookEdit"
+"matcher": "Bash|Edit|Write|MultiEdit|NotebookEdit|Read|Grep|Glob|WebFetch|WebSearch"
```

`bin/gsd-tools.cjs` post-tool-use handler comment updated to reflect the new matcher set + the reason for the broadening (research-phase usage-cap incident with 18-min checkpoint gap).

`README.md` "Session continuity + drift resilience" paragraph updated to list the broader tool set + note the read-heavy-research coverage benefit.

## Why

Real incident this morning in `/Users/jnuyens/sftp-manager/`:
- Last HANDOFF written 02:19 (`source: auto-postool`)
- Usage cap hit 02:37
- 18-minute gap

The 18 missing minutes were almost entirely `Read`/`Grep`/`Glob`/`WebFetch` calls — all non-mutating tools, none in the original matcher. PostToolUse never fired during the research-read sweep. Yesterday's 260425-mct change covered the *microcompact* gap but not the *no-mutations* gap. This task closes that.

## Throttle still bounds writes

The 60s mtime throttle in the post-tool-use handler unchanged. Smoke-tested:

| Test | Result |
|------|--------|
| Cold start + 1 read | Writes HANDOFF, source=auto-postool ✓ |
| 4 more rapid reads within 60s | All throttled, mtime unchanged ✓ |
| Backdate mtime −90s + 1 read | Rewrote (cooldown expired) ✓ |
| `check-drift.cjs` umbrella | All 3 detectors PASS ✓ |

So even with the matcher firing 50+ times per turn during a heavy research session, actual disk writes stay capped at ≤1/min. Worst case becomes "HANDOFF is ≤60s stale at any point during an active session" — which was always the design intent.

## Token cost

User asked mid-task whether the increased hook-firing frequency drives up token usage. Answer (verified in CC source `_research/claude-code-internals/utils/messages.ts:4099-4115`):

```javascript
case 'hook_success':
  if (attachment.hookEvent !== 'SessionStart' && attachment.hookEvent !== 'UserPromptSubmit') {
    return [];  // PostToolUse output → empty array → zero tokens
  }
```

**Zero tokens.** PostToolUse hook output is never injected into the model's context. CC only renders systemReminder messages for SessionStart and UserPromptSubmit events. PostToolUse hook activity is tracked as UI metadata, not as conversation content.

Other costs (all negligible):
- ~5-10ms per throttled fire (mtime stat + early return)
- ~50-200ms per actual write (gather state + serialize)
- 0 bytes of stdout when handler succeeds (silent design)
- ~1-2KB disk write per actual checkpoint

## Commit

`7497cc6` — fix(quick-260425-rgw): broaden PostToolUse matcher to include read tools

## What's still uncovered

Pure-conversation thinking with no tool calls at all. If Claude isn't running tools, there's nothing meaningful to checkpoint. STATE.md captures phase position separately. Acceptable gap; not worth a "tick" hook.
