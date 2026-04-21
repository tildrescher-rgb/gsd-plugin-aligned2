---
slug: 260421-rnu-readme-new-user-reorg
type: quick
created: 2026-04-21
status: in-progress
---

# Quick: README reorganization — new-user flow first, upstream-migration content trailing

## Problem

Current README interleaves new-user content and upstream-migration content:

1. Installation ✓ (new user)
2. What GSD Plugin provides ✓ (new user — feature list)
3. Session continuity + drift resilience ✓ (new user — feature tour)
4. What changed from upstream GSD ← upstream-comparison context; only useful if reader knows upstream
5. Quick start ✓ (new user — how to use)
6. **Testing without affecting your current GSD install** ← upstream-user-only content
7. Updating ✓ (new user)
8. Maintenance scripts ✓ (developer overview)
9. **Migrating from legacy install** ← upstream-user-only content (largest upstream-user section)
10. Credits / License

Two problems:
- Upstream-user content (sections 6 and 9) sits in the middle of the new-user flow, forcing new users to skim past or wonder if it applies.
- Versioning explanation (lines 9-22) is between the tagline and the install steps — it's useful context but not first-interest for new users.

## Target structure

Put the new-user path front-to-back, then a clear umbrella section for upstream-user concerns.

```
# GSD Plugin -- Get Shit Done for Claude Code   [title]
"Based on" + "Plugin version" + one-paragraph tagline

## What GSD Plugin provides                     [feature list — sets context]
## Session continuity + drift resilience        [feature tour]
## Installation                                  [new user path starts]
## Quick start                                   [how to use]
## Updating                                      [new user path ends]
## Maintenance scripts                           [dev tools — secondary]

---  [visual separator]

## For users of upstream GSD                     [umbrella for ex-upstream]
  ### What changed from upstream GSD             [comparison table]
  ### Automatic migration on install             [what happens automatically]
  ### Manual migration steps                     [4 numbered steps]
  ### Testing the plugin without affecting your current install
                                                  [CLAUDE_PLUGIN_ROOT isolation]
  ### Rolling back
  ### Migration audit
  ### Verifying migration

## Versioning                                    [meta — demoted from top]
## Credits
## License
```

## Key moves

1. **Demote the `### Versioning` subsection** out of the top and into a bottom `## Versioning` section. Tagline stays; detailed scheme moves.
2. **Consolidate upstream-user sections** under a single `## For users of upstream GSD` umbrella. The current "Testing without affecting your current GSD install" section and the "Migrating from legacy install" section overlap (both describe moving `~/.claude/get-shit-done/` out of the way) — unify them without losing content.
3. **Move `What changed from upstream GSD`** into the upstream-user umbrella (it's contextual for someone who knows upstream; a new user doesn't need it to get started).
4. **Put a horizontal rule** (`---`) before the upstream-user umbrella so the visual break is clear when scanning.

## What stays the same

- Every piece of information currently in the README is preserved — this is pure reorganization, no content deletions.
- Installation steps, Quick Start commands, all maintenance-script descriptions, migration details, CLAUDE_PLUGIN_ROOT usage — all identical text, just moved.
- Current commit/tag flow unchanged. Plugin version remains 2.38.3.

## Out of scope

- No new features described. No version bump. No code changes.
- Not touching the commit history or any `.planning/` files.

## Verification

- `diff` between old and new README should show only section reorderings + one horizontal-rule addition, no prose deletions (spot-check by word count: new word count should be within ±50 of old, accounting for minor linking tweaks).
- Markdown renders cleanly: `grep -c "^## " README.md` returns 10 (was 11; merges reduced one top-level heading by folding "What changed from upstream" under "For users of upstream GSD").
- New-user path is readable top-to-bottom without hitting upstream-user content.
