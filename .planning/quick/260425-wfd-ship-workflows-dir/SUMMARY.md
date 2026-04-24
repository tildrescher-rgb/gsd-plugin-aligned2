---
slug: 260425-wfd-ship-workflows-dir
type: quick
created: 2026-04-25
completed: 2026-04-25
status: complete
commit: 8d3fbf9
---

# Summary: Ship `workflows/` dir + rewrite all `@`-includes to `${CLAUDE_PLUGIN_ROOT}` form

## Outcome

Closed all Category B drift (genuinely-missing dangling `@`-includes). Baseline goes from `109 / 38 / 71` → `122 / 122 / 0` — total goes UP because the detector now catches the new plugin-local form, **genuinely missing goes to ZERO**. Phase 7's largest deferred item is closed.

User's failing scenario (`/gsd:gsd-ui-phase 2` "Falling back to legacy workflow file") is fixed: `workflows/ui-phase.md` now exists in the plugin tree at 10kB and the skill's `@${CLAUDE_PLUGIN_ROOT}/workflows/ui-phase.md` resolves cleanly.

## Diff

| Aspect | Before | After |
|--------|--------|-------|
| Plugin tree includes `workflows/` | No | Yes — 78 files (covers all referenced workflows + 8 not-yet-referenced bodies) |
| `@~/.claude/get-shit-done/...` refs in skills/agents/refs/templates | 109 dangling | 0 |
| `@${CLAUDE_PLUGIN_ROOT}/...` refs (new pattern) | 0 | 122 (all resolve to plugin tree) |
| File-layout detector | Detects 2 forms (`~/`, `$HOME`) | Detects 3 forms (added `${CLAUDE_PLUGIN_ROOT}`) |
| Genuinely-missing (Category B) baseline | 71 | 0 |
| PROJECT.md sync checklist | Doesn't mention workflows/ | Step 1 includes copying `get-shit-done/workflows/` into `workflows/` |

## Mechanics

1. **Copy in upstream's workflow bodies.** `cp /tmp/gsd-sync-1.38.3/get-shit-done-1.38.3/get-shit-done/workflows/*.md workflows/` — 78 files. Git-stage so the namespace-rewrite script sees them.
2. **Run namespace rewrite over the new content.** Upstream uses `/gsd-<skill>` dash form; project convention is `/gsd:<skill>` colon form. `bin/maintenance/rewrite-command-namespace.cjs` handles it.
3. **Mass-rewrite path refs.** Single regex pass via Node:
   ```js
   /@~\/\.claude\/get-shit-done\/(workflows|references|templates|contexts)\//g
   →  '@${CLAUDE_PLUGIN_ROOT}/$1/'
   ```
   Applied across `git ls-files`, filtered to text extensions, skipping `_research/` and `.planning/` (per project's standard skip list). 270 replacements in 99 files.
4. **Extend the detector.** Added a third `REF_PATTERNS` entry for `@${CLAUDE_PLUGIN_ROOT}/<sub>` so the detector validates the new pattern + catches future drift in it.
5. **Regenerate baseline.** `--write-baseline` → `122/122/0`. The `0` is the headline.
6. **Process update.** PROJECT.md sync checklist step 1 now includes `workflows/` so future upstream syncs keep it in lockstep.

## Why `${CLAUDE_PLUGIN_ROOT}` (not relative paths)

Claude Code's plugin loader (`_research/claude-code-internals/utils/plugins/pluginOptionsStorage.ts` `substitutePluginVariables`) substitutes `${CLAUDE_PLUGIN_ROOT}` in skill/agent content. At runtime the variable expands to the version-stamped install dir, so the `@`-include resolves to the real plugin file. Explicit, version-pinned, works without relying on CWD.

The alternative (`@./workflows/X.md` relative to CWD) was considered but rejected — depends on where CC resolves relative `@`-paths, which isn't documented and we'd be guessing.

## What's left (not in this task)

- **Detector classification refinement.** Current binary scheme classifies the new `${CLAUDE_PLUGIN_ROOT}/` refs as Category A (wrong-form-but-resolvable) when they're actually correct-form-and-resolvable. Both yield "0 drift" under current logic, but the labels are imprecise. Future detector cleanup could split into 3 buckets: legacy-form-resolvable, plugin-local-form-resolvable, dangling. Deferred.
- **Mid-flow skill workflow refs.** Some workflows reference each other via `@`-includes. After this rewrite, those cross-refs are also `${CLAUDE_PLUGIN_ROOT}/` form and resolve. No further action needed.
- **Version bump.** Stays at 2.38.5. Quick task; rolls into next milestone tag.

## Smoke tests

| Test | Result |
|------|--------|
| `node bin/maintenance/check-drift.cjs` umbrella | PASS — all 3 detectors clean |
| `tests/drift-baseline.json` | `total_dangling: 122, has_plugin_counterpart: 122, genuinely_missing: 0` |
| `node bin/gsd-tools.cjs current-timestamp date` | Works |
| `workflows/ui-phase.md` exists | Yes, 10kB |
| `grep -r "@~/.claude/get-shit-done/" skills/ agents/` | 0 hits in plugin content (1 hit in `check-file-layout.cjs` doc comment is intentional — cites the legacy regex pattern) |
| Spot read `skills/ui-phase/SKILL.md` line 23 | Now references `@${CLAUDE_PLUGIN_ROOT}/workflows/ui-phase.md` |

## Commit

`8d3fbf9` — fix(quick-260425-wfd): ship workflows/ dir + rewrite @~/.claude/get-shit-done/* refs to ${CLAUDE_PLUGIN_ROOT}/* form (closes Category B drift)

162 files changed, 29,247 insertions(+), 228 deletions(-).

## For users

Skills that delegated to upstream workflow bodies (most `/gsd:*` commands) now have those bodies *inside the plugin*, resolved at runtime via `${CLAUDE_PLUGIN_ROOT}` substitution. The "Falling back to legacy workflow file" graceful-degradation message should disappear.

Plugin install size grows by ~78 files / ~30k lines of workflow markdown. Acceptable: these are the operational logic the skills were always supposed to load.
