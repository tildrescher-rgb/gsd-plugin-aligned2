---
slug: 260420-vfb-hook-version-fallback
type: quick
created: 2026-04-20
status: in-progress
---

# Quick: Hook commands fall back to newest cached plugin version when baked path is stale

## Problem

Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}` in hook commands at session start with the version-scoped install dir (e.g. `.../gsd-plugin/gsd/2.38.1`). Confirmed from CC internals: `CLAUDE_PLUGIN_ROOT` is "version-scoped install dir (recreated on update)" — new version → new dir. If another session updates the plugin and the old version dir gets pruned from the cache, the running session's hooks fail with ENOENT.

Current cache state here: 1.33.0, 1.35.0, 1.37.1, 2.37.1, 2.38.1 all present — pruning isn't aggressive on this install, but the failure mode is real for long-running sessions that outlive cache cleanup.

## Fix (scope A, per user pick)

Replace the 4 hook commands in `hooks/hooks.json` with a Node-inline resolver that:

1. Tries `${CLAUDE_PLUGIN_ROOT}/bin/gsd-tools.cjs` first (honour the session-baked path when present).
2. On ENOENT, scans `~/.claude/plugins/cache/gsd-plugin/gsd/X.Y.Z/bin/gsd-tools.cjs`, picks the newest semver available, `require()`s that.
3. Pads `process.argv` so `gsd-tools.cjs`'s `process.argv.slice(2)` parses the command correctly (needed because `node -e "code" arg1 arg2` gives `argv.length === 3`, not 4).
4. Emits a one-line stderr notice ONLY when falling back (not when the baked path works).

Resolver is cross-platform: uses `os.homedir()` + `path.join`, no shell-specific syntax.

## Why inline (not a helper file)

A helper file at `bin/lib/resolve-plugin.cjs` would also be version-stamped under `${CLAUDE_PLUGIN_ROOT}`. When the baked path is gone, the helper is gone too — same ENOENT. The resolver must live in the hook command string itself, which `node -e` makes feasible.

## Out of scope

- Drift warning when `CLAUDE_PLUGIN_ROOT` is present but older than newest available (that was option B).
- Auto-exec into newer version (that was option C).
- Symlink shim at a stable path (would need plugin install-side support, which CC doesn't provide).
- Rewriting `${CLAUDE_PLUGIN_ROOT}/...` references in SKILL.md / agent / template files (those are read by Claude, not shell-executed; stale refs there cause a different failure class that's worth its own task).
