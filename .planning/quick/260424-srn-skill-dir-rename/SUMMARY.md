---
slug: 260424-srn-skill-dir-rename
type: quick
created: 2026-04-24
completed: 2026-04-24
status: complete
commit: b652f55
---

# Summary: Skill directory rename — fix duplicated command-ID prefix

## What changed

### Directory renames (81)
Every `skills/gsd-<name>/` → `skills/<name>/`. All 81 renames tracked by git as pure renames (100% similarity, no content changes).

### Reference updates (22 across 9 files)
Skill-registry-driven regex `skills/gsd-<skill>(boundary)` → `skills/<skill>` applied to all tracked plugin content except historical archives:
- `bin/lib/checkpoint.cjs` (1) — doc comment reference
- `bin/maintenance/rewrite-command-namespace.cjs` (1) — doc comment
- `.planning/phases/07-file-layout-drift-detector/07-01-PLAN.md` (5)
- `.planning/phases/07-file-layout-drift-detector/07-01-SUMMARY.md` (4)
- `.planning/phases/08-handoff-schema-detector/08-RESEARCH.md` (1)
- `.planning/phases/09-unified-check-and-docs/09-01-PLAN.md` (3)
- `.planning/quick/260420-cns-command-colon-fix/SUMMARY.md` (1)
- `.planning/quick/260421-u38-upgrade-gsd-plugin-to-version-1-38-3-mat/PLAN.md` (4)
- `.planning/quick/260421-u38-upgrade-gsd-plugin-to-version-1-38-3-mat/SUMMARY.md` (2)

### Script logic update
`bin/maintenance/rewrite-command-namespace.cjs` skill enumeration: the `filter(d => d.startsWith('gsd-'))` filter + `.replace(/^gsd-/, '')` mapping are now obsolete. Replaced with a SKILL.md-presence check. This also naturally excludes the pre-existing non-skill artifacts in `skills/bundled/` and the stray TypeScript files.

## Bug that got fixed

From Claude Code source (`_research/claude-code-internals/utils/plugins/loadPluginCommands.ts:67-81`):

```javascript
if (isSkill) {
  const commandBaseName = basename(skillDirectory)
  return `${pluginName}:${commandBaseName}`
}
```

Plugin loader derives the registered command ID from the skill's parent directory basename, **not** the frontmatter `name:` field. The `name:` field is used as the display label in tab completion.

**Before the rename:** dir `skills/gsd-add-todo/` + plugin `gsd` → registered command `/gsd:gsd-add-todo`. Tab menu showed `/gsd:add-todo` (from frontmatter `name: gsd:add-todo`), but accepting inserted the registered form. Visible-vs-actual mismatch on every command.

**After the rename:** dir `skills/add-todo/` + plugin `gsd` → registered command `/gsd:add-todo`. Matches the display string.

## Alignment with upstream

Upstream GSD uses `commands/gsd/<name>.md` (no `gsd-` prefix in basename). The plugin now mirrors that structure in `skills/<name>/SKILL.md` — reduces sync friction. Future upstream syncs map 1:1 without a filename-rewriting step.

## Smoke tests (all passed)

- `node bin/maintenance/check-drift.cjs` — exits 0, all 3 per-category detectors clean
- `node bin/maintenance/rewrite-command-namespace.cjs --dry` — 81 skills enumerated, 0 replacements needed (colon form already consistent)
- `node bin/maintenance/check-file-layout.cjs` — baseline 109/38/71 still matches (detector scans `@~/.claude/get-shit-done/<subpath>` refs; `<subpath>` targets `references/` and `workflows/`, never `skills/` — unaffected by this rename)
- `node bin/maintenance/check-handoff-schema.cjs` — PASS, 19/19 fields
- `node bin/gsd-tools.cjs current-timestamp date` — works

## Not in this task

- **Version bump.** Stays at 2.38.3. The v1.2 complete-milestone will tag `v2.38.4` and roll this change in with the other v1.2 deliverables.
- **Cleanup of `skills/bundled/` + stray `.ts` files.** Non-GSD artifacts from March (Claude Code internals that landed in skills/). Separate concern.

## Commit

`b652f55` — fix(quick-260424-srn): rename skills/gsd-<name>/ → skills/<name>/ to fix duplicated command-ID prefix

## For users

After they pull this change:
- **Old muscle memory:** `/gsd:gsd-<name>` no longer resolves cleanly. Claude Code's fuzzy match suggests the correct `/gsd:<name>` form, so no hard breakage.
- **Tab completion now works as expected:** typing `/gsd:a` then tab suggests and inserts `/gsd:add-todo` / `/gsd:audit-fix` / etc. — matching what the menu shows.
