---
slug: 260420-rar-readme-autoresume-feature
type: quick
created: 2026-04-20
status: in-progress
---

# Quick: Add autoresume feature bullet to README

## Task

Add a bullet advertising the `/compact` → HANDOFF.json → auto-resume round-trip (delivered by Phase 4 of v1.1) to the **What GSD Plugin provides** list in `README.md`.

## Why now

Phase 4 live UAT passed today (2026-04-20). The feature is production-ready but the README still omits it — closes part of DOCS-01 scope (deferred to v1.2, but trivial to fold in).

## Change

One bullet added to the features list in `README.md`, positioned between the Hooks bullet (which mentions "checkpoint on compact" from the hook-implementation angle) and the Execution context profiles bullet. The new bullet describes the user-visible behavior — what actually happens across a `/compact`.

## Out of scope

- No change to the `What changed from upstream GSD` comparison table.
- No CHANGELOG addition (CHANGELOG.md doesn't exist yet; that's DOCS-02, deferred to v1.2).
- No changes to other docs (PROJECT.md, plugin-level marketing copy).
