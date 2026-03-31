# Domain Pitfalls: CLI Fork/Integration

**Domain:** Embedding workflow orchestration into an actively maintained CLI tool (Claude Code + GSD integration)
**Researched:** 2026-03-31
**Confidence:** HIGH (grounded in codebase analysis and established fork/integration failure patterns)

## Critical Pitfalls

Mistakes that cause rewrites, abandonment, or unsustainable maintenance burden.

---

### Pitfall 1: Merge Debt Avalanche (The Fork Tax)

**What goes wrong:** Forking Claude Code creates a maintenance obligation that grows superlinearly with each upstream release. Claude Code updates roughly monthly. Each release touches the monolithic files at the core of the system (5,000+ line files like `cli/print.ts`, `utils/messages.ts`, `screens/REPL.tsx`). Within 2-3 upstream releases, merge conflicts accumulate faster than a solo maintainer can resolve them, and the fork falls permanently behind.

**Why it happens:** Fork maintainers underestimate the compounding nature of merge debt. The first merge takes 2 hours. The second takes 4. By the fifth, you are resolving conflicts against code you no longer recognize because intermediate refactors changed assumptions your patches relied on. Claude Code's architecture amplifies this: the 5,594-line `cli/print.ts` handles the main ask() loop, message handling, and file state -- any integration touching the conversation pipeline will conflict with nearly every upstream change to this file.

**Consequences:**
- Fork falls behind on security patches (bash security validation is 2,592+ lines and actively maintained via HackerOne reports)
- Fork misses new features (coordinator mode, compaction improvements, new tool types)
- Eventually the fork is so far behind that "catching up" requires a rewrite of all custom patches
- Estimated maintenance: 8-16 hours per upstream release for conflict resolution alone, growing over time

**Warning signs:**
- First upstream merge takes longer than expected
- You start skipping upstream releases ("we'll catch up next time")
- Merge conflicts appear in files you did not modify (transitive conflicts from refactors)
- You find yourself reading upstream commit history to understand why a function signature changed

**Prevention:**
- Never modify files in the hot path unless absolutely unavoidable (`cli/print.ts`, `query.ts`, `QueryEngine.ts`, `utils/messages.ts`)
- If forking, use a strict "patch layer" approach: all modifications live in new files, connected via minimal surgical hooks in existing files (ideally < 10 lines changed per existing file)
- Establish a merge cadence: merge upstream within 48 hours of each release, never skip
- Automate conflict detection: script that checks which of your modified files were touched in the upstream release
- Prefer the plugin/extension approach over forking entirely

**Detection:** Track a "merge health" metric: (time to merge upstream release) / (time of previous merge). If this ratio exceeds 1.5, the fork is accumulating unsustainable debt.

**Which analysis phase should address it:** Architecture Comparison phase -- must quantify which files each integration approach touches and compute expected conflict surface area per upstream release.

---

### Pitfall 2: Phantom API Surfaces (Building on Internals That Aren't APIs)

**What goes wrong:** The integration treats Claude Code's internal module boundaries as stable APIs. They are not. Internal functions change signatures, move files, get renamed, or disappear entirely between releases. Your integration breaks silently or loudly on every update.

**Why it happens:** Claude Code has no public internal API contract. The codebase uses `import ... from 'src/...'` paths extensively -- these are convenience references, not stability guarantees. The Bun bundler's `feature()` function for dead-code elimination means entire code paths can appear or disappear based on build flags. Feature-gated modules (`assistant/`, `coordinator/`, `bridge/`, `buddy/`) demonstrate that Anthropic regularly adds and restructures major subsystems.

**Specific fragile surfaces in this codebase:**
- `QueryEngine.ts` query orchestration interface -- the streaming API, tool invocation pipeline, and compaction triggers are all internal
- `state/AppStateStore.ts` Zustand store shape -- fields are added/removed as features ship
- `Tool.ts` tool registry and `buildTool()` builder -- the tool type system evolves with new tool capabilities
- `commands.ts` command dispatcher -- command registration mechanism could change
- `services/tools/StreamingToolExecutor.ts` -- parallel tool execution internals

**Consequences:**
- Integration breaks on every upstream update even when there are no merge conflicts (API shape changes)
- Runtime errors instead of compile-time errors when internal types change
- Must reverse-engineer each upstream release to understand what moved

**Warning signs:**
- You import from more than 5 internal modules
- You use `as any` casts to work around type mismatches after an upstream update
- You reference internal constants or configuration values by name

**Prevention:**
- Identify the narrowest possible integration surface. For GSD, the actual touchpoints are: (1) injecting context into the system prompt, (2) registering commands, (3) spawning subagents. All three have semi-stable mechanisms (CLAUDE.md, slash commands, AgentTool).
- Create an adapter layer: a single file that imports from Claude Code internals and exposes a stable interface to GSD code. When upstream changes, only this file needs updating.
- Write integration tests that exercise each import from Claude Code internals. Run these against each upstream release before attempting a merge.
- Prefer composition over inheritance: wrap Claude Code functionality rather than extending it.

**Detection:** Count the number of `import ... from 'src/...'` statements in your integration code. If this number exceeds 10, your coupling is dangerously high.

**Which analysis phase should address it:** Integration Points Analysis phase -- must catalog every internal module the integration would touch and classify each as stable/unstable based on upstream change frequency.

---

### Pitfall 3: The Bun Build System Lock-In

**What goes wrong:** Claude Code uses Bun as its runtime and bundler with compile-time feature flags (`import { feature } from 'bun:bundle'`). A fork must replicate this entire build pipeline. Bun-specific APIs, the `feature()` dead-code elimination system, and the bundling configuration are undocumented internal details. Your fork's build breaks when Bun updates or when Claude Code changes its build configuration.

**Why it happens:** Bun's bundler API and `bun:bundle` feature system are not part of Node.js or any standard. They are Bun-specific. Claude Code's codebase is deeply coupled to this: feature flags control which code paths exist in the final bundle (e.g., `COORDINATOR_MODE`, `KAIROS`, `PROACTIVE`). If you fork and cannot replicate the build, you either ship dead code or break feature-gated functionality.

**Consequences:**
- Cannot build the fork without matching exact Bun version and configuration
- Feature flags may evaluate differently, enabling/disabling code paths unexpectedly
- Native modules (`native-ts/file-index`, `native-ts/color-diff`, `native-ts/yoga-layout`) may fail to compile
- Build times increase as you layer additional bundling on top

**Warning signs:**
- Build succeeds locally but fails in CI
- Feature-gated code behaves differently in your fork vs. upstream
- You cannot run a production build without copying upstream's exact build scripts
- Native module compilation errors on different platforms

**Prevention:**
- If forking, document the exact Bun version and build flags required. Pin these in your fork's configuration.
- Do not add a second build system on top. Integrate into the existing build pipeline.
- For the plugin/extension approach, avoid depending on the build system entirely -- GSD's current approach of living in `~/.claude/` as external scripts is immune to this.
- Test builds on all target platforms (macOS, Linux) after each upstream merge.

**Detection:** Can a fresh checkout build successfully in under 5 minutes with documented instructions? If not, build system coupling is too tight.

**Which analysis phase should address it:** Stack/Tooling Analysis phase -- must verify build system compatibility and document exact build requirements.

---

### Pitfall 4: State Model Collision

**What goes wrong:** GSD has its own state model (PROJECT.md, ROADMAP.md, REQUIREMENTS.md, phase tracking). Claude Code has its own state model (AppState Zustand store, session storage, message history, task state machines). When you embed GSD into Claude Code, these two state models must coexist without corrupting each other. In practice, they collide: GSD's phase transitions conflict with Claude Code's session restoration, GSD's parallel agent spawning conflicts with Claude Code's single-threaded ask() loop, and GSD's file-based state (markdown files) conflicts with Claude Code's in-memory state management.

**Why it happens:** Both systems were designed as the "owner" of their respective state. Neither was designed to be a guest in the other's state model. Claude Code's AppState is a Zustand store with reactive subscriptions -- injecting GSD state into it means GSD state changes trigger Claude Code's re-render cycle. Claude Code's session persistence (`utils/sessionStorage.ts`, 5,105 lines) saves and restores the full conversation -- but GSD's orchestration prompts are ephemeral and should not be persisted.

**Consequences:**
- GSD state corrupts Claude Code sessions (orchestration prompts pollute session history)
- Session restoration loads stale GSD state, causing phase confusion
- AppState grows unbounded as GSD adds its own fields
- Race conditions between GSD's parallel agents and Claude Code's sequential ask() loop (documented in CONCERNS.md: "Cannot parallelize independent tool calls within a single agent turn")

**Warning signs:**
- Session restore produces unexpected behavior
- GSD orchestration context appears in session transcripts
- AppState grows larger than expected
- Parallel agent operations produce inconsistent results

**Prevention:**
- Keep GSD state entirely external to Claude Code's state model. GSD's current file-based approach (PROJECT.md, etc.) is actually correct -- do not move this into AppState.
- If integrating, use a separate state namespace: GSD state lives in its own Zustand slice or separate storage, never mixed into Claude Code's core state.
- Mark GSD messages as ephemeral so session persistence excludes them.
- For agent spawning, respect Claude Code's sequential model -- queue rather than parallelize within a single session.

**Detection:** After a session with GSD, check: (1) Does session size grow faster than expected? (2) Does session restore produce clean state? (3) Can you use Claude Code normally after GSD finishes?

**Which analysis phase should address it:** Architecture Design phase -- must design state isolation boundary before any implementation.

---

### Pitfall 5: Security Surface Expansion

**What goes wrong:** Claude Code has a sophisticated security model: bash command parsing (4,436-line parser), permission validation chains, eval-equivalent detection, HackerOne-audited bypass prevention. Any integration that modifies the tool execution pipeline, adds new tools, or changes how commands are dispatched risks creating security bypasses. A fork that falls behind on security patches is actively dangerous.

**Why it happens:** Security validation in Claude Code is not a simple check -- it is a multi-layer system involving AST-based bash parsing, permission classifiers (feature-gated), filesystem restrictions, and deny tracking. The system is under active adversarial pressure (HackerOne bug bounty). A fork that modifies any file in `tools/BashTool/` or `utils/permissions/` must maintain security parity with upstream, which means tracking every security-related commit.

**Specific risks from the codebase:**
- `bashSecurity.ts` (2,592 lines) and `bashPermissions.ts` (2,621 lines) are actively patched for discovered bypasses
- `bashParser.ts` (4,436 lines) implements a recursive descent parser -- any modification risks parsing regressions
- Permission mode system (`utils/permissions/PermissionMode.ts`) gates all tool execution
- The SDK status code propagation issue (CONCERNS.md) means error handling in `withRetry.ts` uses fragile string pattern matching -- a fork that changes retry logic could mask security-relevant errors

**Consequences:**
- Fork ships with known security vulnerabilities because it missed upstream patches
- Integration accidentally bypasses permission checks by routing around the standard tool pipeline
- New tools added by GSD lack the security validation that built-in tools receive
- Users run the fork with less security than vanilla Claude Code without knowing it

**Warning signs:**
- Your fork is more than one release behind upstream on security-related files
- You modify any file in `tools/BashTool/` or `utils/permissions/`
- New tools you add do not go through `canUseTool()` validation
- You suppress permission prompts for convenience during development

**Prevention:**
- Never modify security-related files. Treat `tools/BashTool/`, `utils/bash/`, `utils/permissions/` as read-only.
- Any new tools must use `buildTool()` and go through the standard permission pipeline.
- Subscribe to Claude Code release notes specifically for security patches.
- If forking, create automated alerts when upstream modifies security files -- these must be merged immediately, not on a schedule.
- Prefer approaches that add tools via MCP (which goes through existing permission validation) rather than direct tool registration.

**Detection:** Diff your fork's security files against upstream after each release. Any delta is a risk.

**Which analysis phase should address it:** Risk Assessment phase -- must catalog all security-sensitive files and establish merge priority for security patches.

---

## Moderate Pitfalls

Mistakes that cause significant rework or ongoing friction.

---

### Pitfall 6: Token Budget Cannibalization

**What goes wrong:** GSD's orchestration prompts consume significant context window. An integration that embeds GSD's system prompts into Claude Code's context injection pipeline (`context.ts`, CLAUDE.md aggregation in `utils/claudemd.ts`) competes with Claude Code's own system prompt, git status context, and user's CLAUDE.md instructions for the same token budget. The combined context exceeds optimal size, triggering Claude Code's compaction system, which then snips GSD's orchestration instructions -- breaking GSD's workflow.

**Why it happens:** Claude Code already has a multi-layer context system: system prompt + git status + CLAUDE.md files + tool schemas + conversation history. The `query/tokenBudget.ts` module tracks token budgets. The compaction system (`services/compact/`) aggressively trims when budgets are exceeded. GSD adds substantial orchestration context (role definitions, workflow instructions, phase context). These systems were not designed to coexist.

**Consequences:**
- GSD instructions get compacted away mid-workflow
- Token costs increase because the combined context is larger
- Compaction triggers more frequently, degrading conversation quality
- The user pays for orchestration tokens that could be used for actual work

**Warning signs:**
- Compaction triggers during GSD workflows when it did not before
- GSD agents lose context about their role or the current phase
- Token costs increase after integration
- Responses become less accurate during long orchestration sequences

**Prevention:**
- Measure the actual token overhead of GSD orchestration before integrating. This is one of the project's stated goals.
- If integrating, use Claude Code's existing context tiers: put GSD context in a lower-priority tier that gets compacted last.
- Implement context-aware prompt compression: GSD's verbose role descriptions can often be reduced to structured references that expand only when needed.
- Consider moving orchestration logic out of the context window entirely: use tool calls and structured state rather than prompt-injected instructions.

**Detection:** Compare token usage per query with and without GSD active. If GSD adds more than 15% overhead, the integration is not achieving its goal.

**Which analysis phase should address it:** Overhead Quantification phase -- this is literally the core question of the feasibility study.

---

### Pitfall 7: Agent Spawning Model Mismatch

**What goes wrong:** GSD spawns parallel subagents (gsd-planner, gsd-executor, gsd-researcher) via Claude Code's AgentTool. Inside Claude Code, the AgentTool creates new conversation sessions with their own context, tools, and state. The integration assumes these subagents share state or can communicate, but they cannot -- each agent is an isolated session. Orchestration that depends on agents seeing each other's work requires explicit state passing through files, which is slow and fragile.

**Why it happens:** Claude Code's agent model is hierarchical, not collaborative. The `tools/AgentTool/` spawns agents as independent tasks (`tasks/LocalAgentTask/`). Each agent gets a fresh context window. There is no shared memory or message bus between agents. GSD works around this by using the filesystem as shared state (PROJECT.md, etc.), but this introduces race conditions and stale reads.

**Specific codebase constraints:**
- `AgentTool` creates a new `QueryEngine` instance per agent -- no shared state
- The coordinator mode (`coordinator/coordinatorMode.ts`) is feature-gated and implements multi-agent orchestration differently than GSD, suggesting even Anthropic finds this hard
- `tasks/InProcessTeammateTask/` exists as a newer pattern but is also feature-gated
- The sequential ask() loop means only one agent runs at a time within a session

**Consequences:**
- Agents duplicate work because they cannot see each other's progress
- File-based state passing adds latency (write file, agent reads file, processes, writes result)
- Race conditions when multiple agents modify the same files
- Integration gains nothing over the current external approach if agents still communicate via files

**Warning signs:**
- Agents produce conflicting changes to the same files
- Orchestration latency does not improve after integration
- You find yourself building a custom IPC mechanism between agents

**Prevention:**
- Accept the single-agent-per-session limitation. Design GSD's orchestration to be sequential within a session, parallel across sessions.
- If using parallel agents, implement file-level locking (Claude Code already uses `proper-lockfile`) to prevent race conditions.
- Investigate whether coordinator mode's teammate model could replace GSD's custom orchestration -- this would align with upstream rather than fighting it.
- Measure actual latency: if agent spawning overhead is the bottleneck, the fix might be optimizing spawn time rather than redesigning orchestration.

**Detection:** Time each phase of agent orchestration: spawn time, context loading, actual work, result collection. If spawn + context > 30% of total time, the architecture needs rethinking.

**Which analysis phase should address it:** Agent Architecture Analysis phase -- must understand coordinator mode and teammate model as potential alternatives to GSD's current approach.

---

### Pitfall 8: Command Registration Fragility

**What goes wrong:** GSD registers custom slash commands into Claude Code's command system. The `commands.ts` file is a centralized dispatcher that imports all subcommands. The registration mechanism (via settings/configuration) is a convenience layer, not a plugin API. If Claude Code changes how commands are registered, discovered, or dispatched, all GSD commands break simultaneously with no fallback.

**Why it happens:** Claude Code's command system is designed for first-party commands. Third-party commands via settings is an escape hatch, not a supported extension point. The `commands.ts` file uses feature flags and conditional requires for command registration -- suggesting the registration mechanism is still evolving. A skills system (`skills/bundled/`) exists but its relationship to the command system is unclear and likely unstable.

**Consequences:**
- All GSD commands break on a single upstream change
- No error message -- commands simply stop appearing or stop working
- Users cannot distinguish between "command not registered" and "command broken"
- Must reverse-engineer command registration changes from each upstream release

**Warning signs:**
- Commands work in one version and silently disappear in the next
- The `commands.ts` file is restructured in an upstream release
- A new "official" plugin/extension mechanism replaces the current approach

**Prevention:**
- Use the most stable registration mechanism available. Currently, CLAUDE.md injection + slash command configuration in settings is the most stable because it does not depend on internal module structure.
- Implement a health check: at startup, verify that all GSD commands are registered and accessible. Log warnings if any are missing.
- Keep command implementations thin: the slash command should do minimal work itself, delegating to GSD's own (external) logic. This means if registration breaks, fixing it is a one-line change rather than a rewrite.
- Watch for Anthropic shipping an official extension/plugin API -- this would be the right integration point and would supersede any current approach.

**Detection:** After each upstream update, run a smoke test: invoke each GSD command and verify it produces expected output.

**Which analysis phase should address it:** Integration Points Analysis phase -- must assess stability of each command registration mechanism.

---

### Pitfall 9: The "Just One More Hook" Escalation

**What goes wrong:** The integration starts minimal -- "just hook into the system prompt." Then requirements grow: "we also need to intercept tool results," "we need to modify the compaction behavior," "we need to inject state into AppState." Each hook is small, but collectively they create a deeply entangled integration that is impossible to maintain or debug. Within months, GSD is not a layer on top of Claude Code -- it is woven throughout.

**Why it happens:** Workflow orchestration inherently wants to control the full lifecycle: prompt construction, tool execution, result processing, state management, error recovery. Each phase of GSD's workflow needs slightly different control, and the "clean" integration point is always just one hook away. The codebase's monolithic files make it tempting to add just one more modification to `cli/print.ts` or `query.ts` because "everything is already there."

**Consequences:**
- Integration surface area grows until merge conflicts are guaranteed on every upstream release
- Debugging requires understanding both Claude Code's internals and GSD's logic simultaneously
- Cannot upgrade Claude Code without extensive testing of every hook
- Eventually reaches a point where removing the integration is harder than starting over

**Warning signs:**
- The number of files modified from upstream exceeds 10
- You are modifying the same upstream file for different GSD features
- New GSD features require touching upstream code rather than just GSD code
- You spend more time on integration maintenance than on GSD feature development

**Prevention:**
- Set a hard limit on integration surface area before starting: maximum N files modified from upstream, maximum M lines changed per file. For a solo maintainer, N = 5 and M = 20 is aggressive but sustainable.
- Every proposed hook must answer: "Can this be achieved without modifying upstream?" If yes, do it the other way, even if it is less elegant.
- Review integration surface area monthly. If it has grown, refactor to reduce it before adding more.
- Use the strangler pattern: new functionality wraps existing behavior rather than modifying it.

**Detection:** `git diff --stat upstream/main..integration/main` -- the number of files and lines changed is your integration health metric.

**Which analysis phase should address it:** Every phase -- this is a meta-pitfall that should be checked at every milestone.

---

## Minor Pitfalls

Mistakes that cause friction or wasted effort but are recoverable.

---

### Pitfall 10: Misreading Feature Gates as Dead Code

**What goes wrong:** The codebase uses `feature('FLAG_NAME')` from `bun:bundle` for dead-code elimination. Code behind a disabled feature flag does not exist in the production build. A fork maintainer sees feature-gated code (coordinator mode, Kairos, agent swarms) and either (a) ignores it because "it's not in production" or (b) enables it without understanding the implications. Both are mistakes.

**Prevention:** Catalog all feature gates. Understand which are enabled in production. Feature-gated code often represents Anthropic's future direction -- it may become the standard before your integration is complete, making your custom approach redundant.

---

### Pitfall 11: CLAUDE.md Injection Order Sensitivity

**What goes wrong:** GSD injects instructions via CLAUDE.md files. Claude Code aggregates CLAUDE.md files from multiple locations (global, project, local) via `utils/claudemd.ts`. The order of aggregation affects which instructions take precedence. GSD assumes its instructions are authoritative, but a user's project-level CLAUDE.md may contradict them.

**Prevention:** Document the CLAUDE.md precedence order. Design GSD instructions to be additive (adding capabilities) rather than overriding (changing behavior). Test with conflicting CLAUDE.md files present.

---

### Pitfall 12: Session History Bloat from Orchestration

**What goes wrong:** GSD orchestration generates many messages (role assignment, phase transitions, verification loops). These accumulate in Claude Code's session history, which keeps the full transcript in memory (`history.ts` line 281). Long GSD sessions can trigger OOM or excessive disk usage in session storage.

**Prevention:** Implement orchestration message pruning. Mark GSD's internal messages as purgeable. Use Claude Code's compaction system intentionally rather than fighting it.

---

### Pitfall 13: Assuming MCP Is the Silver Bullet

**What goes wrong:** MCP (Model Context Protocol) looks like the perfect integration mechanism -- it provides tools, resources, and a clean client/server boundary. The integration team decides to expose all GSD functionality via MCP servers. But MCP adds latency (process spawn, stdio/SSE transport, JSON-RPC overhead), MCP tools lack the rich UI integration that built-in tools have (no JSX rendering, no progress streaming in the same format), and MCP connection management has known bugs (OAuth token race condition documented in CONCERNS.md).

**Prevention:** Use MCP for what it does well (resource exposure, simple tool calls) but not as the sole integration mechanism. Benchmark MCP tool call latency vs. built-in tool latency. If GSD's orchestration requires sub-second responsiveness, MCP may not be fast enough.

---

### Pitfall 14: Ignoring the GSD Multi-CLI Constraint

**What goes wrong:** The project context states "GSD also works with other AI CLIs (not just Claude Code)." An integration that deeply couples GSD to Claude Code's internals makes GSD Claude Code-exclusive. This is a strategic mistake if GSD's value depends on being CLI-agnostic.

**Prevention:** Any integration must preserve GSD's ability to work with other CLIs. This strongly favors the "adapter layer" approach over the "deep fork" approach. Design the integration as a Claude Code adapter that implements a GSD-defined interface, not as GSD embedded in Claude Code.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Overhead Quantification | Measuring token cost in isolation without accounting for compaction interactions | Measure tokens across full workflows, not individual prompts; include compaction trigger frequency |
| Integration Point Mapping | Treating internal modules as stable APIs | Classify each touchpoint as stable/unstable; compute expected churn per release cycle |
| Fork vs. Plugin Comparison | Underestimating fork maintenance while overestimating plugin limitations | Quantify merge debt: hours per upstream release times releases per year; factor in security patch urgency |
| Architecture Design | State model collision between GSD and Claude Code | Design state isolation boundary before writing any code; prototype with intentionally corrupted state |
| Agent Orchestration | Building custom IPC when upstream is building the same thing (coordinator mode) | Investigate feature-gated code thoroughly; Anthropic may ship what you are building |
| Implementation (if recommended) | "Just one more hook" escalation | Set hard surface area limits; enforce them via automated diff counting |
| Security Review | Missing upstream security patches | Automate monitoring of changes to `tools/BashTool/` and `utils/permissions/`; merge security patches within 24 hours |
| Maintenance Planning | Assuming current maintainer bandwidth is permanent | Plan for zero-maintenance periods; the integration must survive 3 months without attention |

## Maintenance Burden Estimates

| Approach | Monthly Hours (estimated) | Scales With |
|----------|--------------------------|-------------|
| External layer (current GSD) | 1-2 | GSD feature development only |
| MCP-based integration | 2-4 | MCP protocol changes + GSD features |
| Plugin/extension hook | 4-8 | Upstream release cycle + GSD features |
| Shallow fork (< 5 files modified) | 8-16 | Upstream release cycle, growing over time |
| Deep fork (> 20 files modified) | 20-40+ | Upstream release cycle, exponentially growing |

For a solo maintainer, anything above 8 monthly hours of maintenance is likely unsustainable alongside actual feature development.

## Sources

- Codebase analysis: `.planning/codebase/ARCHITECTURE.md`, `CONCERNS.md`, `CONVENTIONS.md`, `STRUCTURE.md`, `INTEGRATIONS.md`, `STACK.md`, `TESTING.md`
- Project context: `.planning/PROJECT.md`
- Established patterns from open-source fork maintenance (Linux distro kernel forks, IDE fork projects, CLI wrapper tools)
- Confidence: HIGH for codebase-specific pitfalls (directly verified against code); MEDIUM for maintenance hour estimates (based on typical open-source fork maintenance patterns, not measured for this specific project)

---

*Pitfalls analysis: 2026-03-31*
