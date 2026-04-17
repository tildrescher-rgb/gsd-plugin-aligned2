# GSD-2 Feature Analysis: What to Borrow

**Date:** 2026-04-17
**Context:** GSD-2 (github.com/gsd-build/gsd-2) is a TypeScript CLI on Pi SDK that rebuilds the GSD prompt framework as a disciplined state machine. It is not production-ready. This analysis evaluates its feature set against the gsd-plugin's architecture and identifies patterns worth adapting.

## Executive Summary

GSD-2 reimagines the GSD workflow as a standalone TypeScript CLI with SQLite-backed state, formal task isolation, and infrastructure-grade features like cost tracking, stuck detection, and headless CI execution. While the ambition is impressive, the project is immature -- many features are architectural stubs or carry significant operational complexity. The gsd-plugin takes a different approach: it wraps the GSD prompt framework as a Claude Code plugin with MCP-backed state, achieving ~92% token reduction through compiled command routing. The plugin's tight integration with Claude Code's runtime (hooks, model negotiation, tool permissions) gives it advantages GSD-2 cannot replicate. Three ideas from GSD-2 are worth adapting: cost awareness, stuck detection heuristics, and crash recovery patterns. Most other features either already exist in the plugin or introduce complexity that does not pay for itself.

## Feature-by-Feature Analysis

| # | Feature | GSD-Plugin Equivalent | Feasibility | Priority | Notes |
|---|---------|----------------------|-------------|----------|-------|
| 1 | Hierarchical Work Structure (Milestone > Slice > Task) | Phase > Plan > Task (via .planning/ files) | Already exists | Skip | Plugin already has a 3-level hierarchy. GSD-2's naming is different but the structure is equivalent. The plugin's file-based approach is simpler and debuggable. |
| 2 | Fresh Context Per Task (pre-inlined, 65% token reduction) | Compiled command routing (~92% token reduction) | Already exceeded | Skip | The plugin achieves better token reduction through its compiled routing system. GSD-2's "pre-inlined context" is essentially what the plugin does when spawning executor agents with relevant files. |
| 3 | Cost Tracking (per-unit token/cost ledger) | None | Medium | **High** | The plugin has no cost visibility. Claude Code tracks costs internally but does not expose them to plugins. A lightweight approach: track model selections and estimate costs from known pricing. Does not need GSD-2's full ledger -- a per-session running total with budget warnings would cover 80% of the value. |
| 4 | Stuck Detection (sliding-window pattern matching) | None | Medium | **High** | The plugin has no stuck detection. Agents can loop on failing commands or repeat the same edit. GSD-2's approach (pattern-match over recent turns for repetition signals) is sound. The plugin could implement this in a PostToolUse hook: track recent tool calls, flag when the same tool+args repeat 3+ times, inject a "you appear stuck" message. Modest code, high impact. |
| 5 | Headless Mode (CI/CD execution, structured exit codes) | None | Low-Medium | **Medium** | The plugin runs inside Claude Code which is already a CLI tool, but it lacks non-interactive batch execution with clean exit codes. Useful for CI pipelines that run GSD tasks on PRs. Feasibility is constrained by Claude Code's own interactive assumptions. Worth tracking but blocked until Claude Code supports better non-interactive modes. |
| 6 | Extension API (.gsd/extensions/ with lifecycle hooks) | Hooks system (SessionStart, PreToolUse, PostToolUse, PreCompact) | Already exists (different form) | Skip | The plugin's hooks are simpler but cover the same lifecycle points. GSD-2's formal extension API adds discoverability but also adds complexity (versioning, compatibility). The plugin's approach of shipping hooks in-tree is sufficient for a single-maintainer project. |
| 7 | Knowledge Graph (queryable learnings/decisions/patterns) | Learnings system + decisions in PROJECT.md | Partial equivalent | **Low** | The plugin already extracts learnings and records decisions. GSD-2's graph makes them queryable, which is nice but rarely needed -- learnings are typically injected at plan time, not queried ad-hoc. The existing system works. |
| 8 | Dynamic Model Routing (20+ providers, complexity-based) | Model profiles (quality/balanced/budget/adaptive) with alias resolution | Equivalent in practice | Skip | The plugin's profile system already routes models by agent type and user preference. GSD-2 supports more providers, but the plugin delegates provider selection to Claude Code's own model routing. Adding 20 providers adds maintenance burden with marginal benefit. |
| 9 | Unified Orchestration Kernel (compile gates, audit envelopes, turn-level git) | Compiled command router + worktree isolation | Partial overlap | **Low** | The UOK is GSD-2's most ambitious and most over-engineered feature. Compile gates map roughly to the plugin's plan verification. Audit envelopes are interesting for compliance but not needed for an open-source dev tool. Turn-level git transactions (commit per tool call) would generate enormous git noise. Skip the abstraction, consider the specific patterns case by case. |
| 10 | Parallel Workers (multi-worker, file-based IPC) | None (sequential execution) | Low | Skip | Claude Code does not support spawning parallel agent processes from a plugin. The plugin's sequential plan execution is a feature, not a bug -- it keeps state simple and avoids merge conflicts. Parallel execution would need Claude Code runtime changes. |
| 11 | Auto-recovery (crash recovery, TOCTOU-hardened locks) | Session continuity hooks (Phase 04 work) | Partial -- in progress | **Medium** | Phase 04's SessionStart hook already detects HANDOFF.json and resumes interrupted sessions. GSD-2's approach adds TOCTOU-hardened file locks and surviving-session-file scanning. The plugin should borrow the idea of a recovery manifest (what was in progress, what completed) without the lock complexity. The HANDOFF.json approach is simpler and sufficient for single-agent execution. |
| 12 | Reassessment Gates (auto roadmap updates after slices) | Manual ROADMAP.md updates via gsd-tools | Medium | **Low** | The plugin already updates ROADMAP.md after plan execution via `roadmap update-plan-progress`. GSD-2 automates this with an LLM call after each slice. Automating would cost tokens and risk hallucinated progress. The current semi-automated approach (tools update counts, human reviews) is more reliable. |

## Top 3 Recommendations

### 1. Add Lightweight Cost Tracking (Priority: High)

**What to borrow:** The idea of tracking model usage and projecting costs, not GSD-2's full ledger implementation.

**Concrete approach:**
- Add a `cost-tracker.cjs` module that maintains a per-session JSON file in `.gsd/`
- On each model resolution (in `resolveModelInternal`), log the model ID, timestamp, and agent type
- Use known pricing tables to estimate cost per call (input/output tokens are available in Claude Code's response metadata)
- Surface a running total in the session summary and warn when approaching a configurable budget ceiling
- No database needed -- a simple append-only JSON log file per session

**Why it matters:** Users have no visibility into what GSD workflows cost. A single planning + execution cycle can involve dozens of API calls across opus/sonnet/haiku. Even rough estimates help users choose between quality and budget profiles.

### 2. Add Stuck Detection in PostToolUse Hook (Priority: High)

**What to borrow:** The pattern-matching heuristic for detecting repetitive tool calls, adapted to the plugin's hook system.

**Concrete approach:**
- In the PostToolUse hook, maintain a sliding window of the last 5 tool calls (tool name + first 200 chars of input)
- If 3+ consecutive calls match the same pattern (same tool, similar input), inject a system message: "You appear to be repeating the same action. Consider a different approach."
- If 5+ consecutive matches, escalate: suggest the agent stop and report the blocker
- Store the window in the hook's session state (already available via hook context)
- No new dependencies needed

**Why it matters:** Stuck loops are the single biggest waste of tokens and time in agentic coding. A simple heuristic catches the common case (retrying a failing command, re-editing the same line) without needing GSD-2's full sliding-window infrastructure.

### 3. Enhance Recovery Manifest (Priority: Medium)

**What to borrow:** The concept of a structured recovery manifest that survives crashes, extending the existing HANDOFF.json approach.

**Concrete approach:**
- Extend HANDOFF.json to include: current task index, list of completed task commit hashes, files modified, and a "dirty state" flag
- In the PreCompact hook, update the manifest before compaction (already partially done)
- In SessionStart, use the manifest to provide richer context to the resume directive -- not just "continue from plan X" but "continue from task 3 of plan X, tasks 1-2 committed at abc123/def456"
- Phase 04 already laid the groundwork; this is incremental enhancement

**Why it matters:** The gap between "session died" and "session resumed with full context" is where work gets lost. A richer manifest reduces re-discovery time when sessions restart.

## Not Worth Borrowing

### Hierarchical Work Structure (Feature 1)
The plugin's Phase > Plan > Task hierarchy is functionally identical. Renaming to Milestone > Slice > Task would break existing .planning/ artifacts and documentation for zero functional benefit.

### Fresh Context Per Task (Feature 2)
The plugin already achieves better token reduction (92% vs 65%) through compiled command routing. GSD-2's approach of pre-inlining entire files into each task context is actually less efficient than the plugin's selective injection.

### Extension API (Feature 6)
A formal extension API makes sense for a platform with third-party developers. The gsd-plugin is a single-project tool. The hooks system covers the same lifecycle events with less abstraction. If third-party extensions become relevant, add the API then -- not speculatively.

### Dynamic Model Routing (Feature 8)
The plugin's profile system (quality/balanced/budget/adaptive) already covers the practical use cases. GSD-2's 20+ provider support is a maintenance burden. Claude Code handles provider routing; the plugin just needs to set the right model ID for the right task.

### Parallel Workers (Feature 10)
Claude Code does not support plugin-spawned parallel agents. Implementing this would require either forking Claude Code processes (unsupported, fragile) or building a separate orchestration layer outside Claude Code. The complexity is not justified by the benefit, and sequential execution avoids the merge-conflict and state-corruption risks that parallel execution introduces.

### UOK / Audit Envelopes (Feature 9)
The Unified Orchestration Kernel is a solution looking for a problem in the plugin's context. Compile gates already exist (plan verification). Audit envelopes add compliance overhead that no current user needs. Turn-level git commits would create hundreds of commits per session. The specific useful patterns (verification gates, structured logging) are already implemented more simply.

### Reassessment Gates (Feature 12)
Automated LLM-driven roadmap updates after each slice would cost tokens and risk introducing hallucinated progress claims. The current approach -- tools update numeric counts, humans review narrative -- is more reliable and cheaper.
