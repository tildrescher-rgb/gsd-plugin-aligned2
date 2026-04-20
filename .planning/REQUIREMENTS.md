# Requirements: v1.1 Session Continuity

## Milestone Requirements

### Checkpoint Creation
- [x] **CKPT-01**: PreCompact hook saves HANDOFF.json with current phase, plan, task, and status — Phase 4
- [x] **CKPT-02**: HANDOFF.json includes uncommitted file list and in-progress task context — Phase 4
- [x] **CKPT-03**: HANDOFF.json includes recent decisions and context notes for mental model restoration — Phase 4

### Auto-Resume
- [x] **RESM-01**: SessionStart hook detects HANDOFF.json and triggers /gsd-resume-work — Phase 4
- [x] **RESM-02**: Auto-resume continues work with zero user intervention after context reset — Phase 4 (synthetic; live `/compact` UAT pending)
- [x] **RESM-03**: Resume restores full project state including phase/plan position — Phase 4

### Backup Trigger
- [ ] **BKUP-01**: CLAUDE.md contains instruction to check for HANDOFF.json at session start — Phase 5
- [ ] **BKUP-02**: Backup instruction works independently of hooks (fallback path) — Phase 5

### Checkpoint Lifecycle
- [ ] **LIFE-01**: HANDOFF.json is deleted after successful resume — Phase 5

## Future Requirements (deferred to v1.2 per 2026-04-20 audit)

### Checkpoint Lifecycle polish
- **LIFE-02**: Stale checkpoints (older than configurable threshold) are detected and handled — *deferred. Nice-to-have; current resume is always-accept.*
- **LIFE-03**: User can manually trigger checkpoint save via dedicated command — *deferred. `/gsd-pause-work` + `node bin/gsd-tools.cjs checkpoint --source manual-pause` already satisfy the manual-trigger need; a dedicated `/gsd-checkpoint` skill is polish.*

### Documentation
- **DOCS-01**: Plugin README documents session continuity feature and configuration — *deferred. One paragraph; rides the next README update pass.*
- **DOCS-02**: CHANGELOG tracks v1.1 changes relative to both plugin version and GSD base version — *deferred. Release history currently lives in git + GitHub Releases.*

### Upstream Compatibility
- **UPST-01**: HANDOFF.json format compatible with upstream `/gsd-pause-work` — *deferred. Needs re-assessment: upstream's 1.34→1.38.x evolution changed the compat target.*
- **UPST-03**: Changes packaged as isolated upstream-ready patches — *deferred pending UPST-01.*
- **UPST-04**: Patch files / PR-ready diff prepared for upstream — *deferred pending UPST-01.*

### Already satisfied (closed without phase work)
- [x] **UPST-02**: Plugin version and GSD base version distinguished in all artifacts — SATISFIED by the `plugin_major = upstream_major + 1` versioning scheme adopted in quick task 260418-r6d. Visible in README "Based on" line, package.json, PROJECT.md Context section, and GitHub release titles.

## Out of Scope

- Token count API exposure -- Claude Code doesn't provide this to plugins; PreCompact hook sidesteps the need
- Custom UI for token usage -- StatusLine already handles this internally
- PostCompact hook actions -- not needed; PreCompact captures state before compression

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CKPT-01 | Phase 4 | Satisfied |
| CKPT-02 | Phase 4 | Satisfied |
| CKPT-03 | Phase 4 | Satisfied |
| RESM-01 | Phase 4 | Satisfied |
| RESM-02 | Phase 4 | Satisfied (live UAT pending) |
| RESM-03 | Phase 4 | Satisfied |
| BKUP-01 | Phase 5 | Pending |
| BKUP-02 | Phase 5 | Pending |
| LIFE-01 | Phase 5 | Pending |
| LIFE-02 | v1.2 backlog | Deferred |
| LIFE-03 | v1.2 backlog | Deferred |
| DOCS-01 | v1.2 backlog | Deferred |
| DOCS-02 | v1.2 backlog | Deferred |
| UPST-01 | v1.2 backlog | Deferred (needs rethink) |
| UPST-02 | — | Satisfied by 260418-r6d (versioning scheme) |
| UPST-03 | v1.2 backlog | Deferred pending UPST-01 |
| UPST-04 | v1.2 backlog | Deferred pending UPST-01 |
