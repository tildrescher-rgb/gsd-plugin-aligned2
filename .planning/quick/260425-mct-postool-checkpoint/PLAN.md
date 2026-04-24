---
slug: 260425-mct-postool-checkpoint
type: quick
created: 2026-04-25
status: in-progress
---

# Quick: PostToolUse periodic checkpoint to bridge the microcompact gap

## Problem (from yesterday's investigation)

Claude Code has TWO compaction mechanisms:
1. `compactConversation` (full) — fires PreCompact → plugin checkpoints HANDOFF.json ✓
2. `microcompactMessages` (per-turn tool-output GC) — silently replaces stale Read/Bash/Grep/Glob/etc. outputs with `[Old tool result content cleared]`. **Does NOT fire PreCompact.** No event hookable from the plugin.

Between full-compact events, microcompact can shrink context substantially without writing any HANDOFF. If a session terminates between full compacts (crash, kill, network drop), the most-recent HANDOFF reflects an older state than what was actually executing.

## Fix

Side-channel checkpointing via the existing PostToolUse hook. Currently registered in `hooks/hooks.json` for `Bash` only, AND `bin/gsd-tools.cjs` has no handler branch (PostToolUse silently no-ops today). So this is filling absence, not stomping.

**Plan:**
1. Expand PostToolUse matcher: `Bash` → `Bash|Edit|Write|MultiEdit|NotebookEdit` (file-mutation tools).
2. Add `post-tool-use` handler in `bin/gsd-tools.cjs` that writes a fresh HANDOFF when the existing one is stale or missing. Throttle by mtime: write only if HANDOFF.json is older than 60 seconds (or absent).
3. Use `source: "auto-postool"` to distinguish from `auto-compact` and `manual-pause`. Add to schema enum.
4. Never crash the hook — wrap in try/catch, exit silently on any error (3s budget per hooks.json).

## Throttle design

- **Time-based, mtime of HANDOFF.json as the clock.** No separate state file. If `now - mtime > 60s` → write. Else skip.
- **Why 60s?** Roughly matches CC's microcompact cadence. Net guarantee: HANDOFF is at most 60s stale at any point during an active session. Most-recent-wins via overwrite (per Phase 4 D-05).
- **Rate-burst protection.** Bursty tool calls (10 in 1s) → only the first writes. Slow cadence (1 per minute) → every one writes. Cap is at most 1 write/minute. Tiny disk + I/O overhead.
- **No throttle file needed.** Cleanup is automatic: `/gsd:resume-work` deletes HANDOFF.json after restore (Phase 5 LIFE-01), so next session's first PostToolUse always writes a fresh one.

## Source field

Current schema enum: `["auto-compact", "manual-pause"]`. Add `"auto-postool"`. Backward-compat: existing consumers reading `source` as a string still work; only schema validators that strictly check the enum need updating.

Files affected:
- `bin/lib/checkpoint.cjs` — function already accepts arbitrary source string; no code change needed
- `schema/handoff-v1.json` — add `auto-postool` to enum
- `bin/gsd-tools.cjs` post-tool-use handler — new code, passes `{ source: 'auto-postool' }`

## Files modified

- `hooks/hooks.json` — matcher expansion (1 line change inside the existing inline-resolver string)
- `bin/gsd-tools.cjs` — new `else if (hookType === 'post-tool-use')` branch (~15 lines)
- `schema/handoff-v1.json` — `source` enum extension
- `README.md` — note in `## Session continuity + drift resilience` paragraph about the new periodic checkpoint
- `.planning/PROJECT.md` — short note in Validated section

## Smoke tests

1. Direct hook invocation:
   ```bash
   # Cold: no HANDOFF.json — should write
   rm -f .planning/HANDOFF.json
   node bin/gsd-tools.cjs hook post-tool-use < /dev/null
   ls -la .planning/HANDOFF.json   # exists, mtime = now
   grep '"source":' .planning/HANDOFF.json  # auto-postool

   # Warm within cooldown: should NOT rewrite
   sleep 1
   ts1=$(stat -f "%m" .planning/HANDOFF.json)
   node bin/gsd-tools.cjs hook post-tool-use < /dev/null
   ts2=$(stat -f "%m" .planning/HANDOFF.json)
   [ "$ts1" = "$ts2" ] && echo "PASS: throttled within cooldown"

   # Outside cooldown: should rewrite (fake the time by touching back 90s)
   touch -A -000130 .planning/HANDOFF.json   # back-date by 90s
   node bin/gsd-tools.cjs hook post-tool-use < /dev/null
   ts3=$(stat -f "%m" .planning/HANDOFF.json)
   [ "$ts3" -gt "$ts1" ] && echo "PASS: cooldown expired, rewrote"
   ```
2. Schema validator: `node bin/maintenance/check-handoff-schema.cjs` should still PASS (validates the enum extension by writing a manual-pause HANDOFF then checking; auto-postool is in the enum so any future capture validates too).

## Out of scope

- **Tool-result archive (option C from the analysis).** Preserves bytes microcompact discards; bigger feature, separate task or v1.3 phase.
- **Phase/plan transition explicit checkpoints (option B).** Could be added later; PostToolUse covers the 60s-cadence concern alone.
- **Version bump.** Stays at 2.38.4. Quick task; v1.3 milestone tag will roll it in if/when v1.3 ships.

## Risks

- **3s budget on PostToolUse.** writeCheckpoint scans STATE.md + git status + git log -5 — empirically ~50-200ms. Well under budget.
- **Hook fires on every Edit/Write/MultiEdit/NotebookEdit in addition to Bash.** That's ~5x more PostToolUse fires per session. The 60s throttle keeps actual writes bounded to ~1/min regardless of fire frequency.
- **Stat-based mtime check is filesystem-dependent.** macOS APFS, Linux ext4, Windows NTFS all have second-or-better resolution; 60s threshold is robust.
- **stdin from PostToolUse contains tool_response that we currently ignore.** No risk per se, just unused. If a future task wants the tool name, it's available.
