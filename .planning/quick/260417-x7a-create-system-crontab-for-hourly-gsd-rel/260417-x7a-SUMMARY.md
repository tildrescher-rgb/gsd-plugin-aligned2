---
phase: quick
plan: 260417-x7a
subsystem: release-monitoring
tags: [cron, release-check, notification, shell]
dependency_graph:
  requires: []
  provides: [hourly-upstream-release-check]
  affects: [bin/]
tech_stack:
  added: []
  patterns: [ssh-mail-relay, gh-api-release-query]
key_files:
  created:
    - bin/check-gsd-release.sh
  modified: []
decisions:
  - Used SSH relay to m1.linuxbe.com for mail delivery instead of local mail
  - Full paths for all binaries (gh, curl, ssh) to work in cron's minimal PATH
metrics:
  duration: ~2min
  completed: 2026-04-17
  tasks_completed: 2
  tasks_total: 2
  files_changed: 1
---

# Quick Task 260417-x7a: Create System Crontab for Hourly GSD Release Check Summary

Shell script checking GitHub API for new gsd-build/get-shit-done releases hourly, sending email via SSH to m1.linuxbe.com on version change.

## What Was Done

### Task 1: Create the release check script
- Created `bin/check-gsd-release.sh` with full release detection pipeline
- Network connectivity check via `curl` to `api.github.com/zen` (silent exit on failure)
- Fetches latest release tag via `gh api` with `--jq '.tag_name'`
- First-run guard: creates `~/.gsd-last-known-version` without sending email
- Version comparison: exits silently if version unchanged
- Email notification via SSH: `echo "$BODY" | ssh m1.linuxbe.com "mail -s '...' jnuyens"`
- Version file updated only after successful mail send (prevents missed notifications)
- All binary paths are absolute for cron compatibility (`/opt/homebrew/bin/gh`, `/usr/bin/curl`, `/usr/bin/ssh`)
- Commit: c36bdb5

### Task 2: Install crontab entry and verify end-to-end
- Crontab write blocked by macOS sandbox ("Operation not permitted") -- documented manual install step below
- Successfully ran first-run dry-run: script created `~/.gsd-last-known-version` with version `1.37.0`
- Successfully ran idempotent second run: exited silently (no duplicate notification)
- All verification checks passed except crontab install (requires manual step)

## Deviations from Plan

### Blocked Issues

**1. [Rule 3 - Blocking] macOS sandbox prevents crontab writes**
- **Found during:** Task 2
- **Issue:** Claude Code's sandbox blocks `crontab -` with "Operation not permitted" (macOS TCC restriction)
- **Resolution:** Cannot be auto-fixed -- this is an OS-level security boundary. User must run the install command manually.
- **Manual step required:**
  ```bash
  (crontab -l 2>/dev/null; echo "17 * * * * /Users/jnuyens/claude-code-gsd/bin/check-gsd-release.sh") | crontab -
  ```
- **Verification:** `crontab -l | grep check-gsd-release.sh`

## Known Stubs

None -- all logic is fully wired.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | c36bdb5 | feat(260417-x7a): add hourly GSD upstream release check script |
| 2 | (no file changes) | Crontab install + verification (runtime only) |

## Self-Check: PASSED

- [x] bin/check-gsd-release.sh exists and is executable
- [x] Commit c36bdb5 exists
- [x] Script passes syntax check
- [x] Version file ~/.gsd-last-known-version created with 1.37.0
- [x] Idempotent re-run exits silently
