# Project Research Summary

**Project:** Claude Code + GSD Integration Feasibility Study
**Domain:** CLI workflow orchestration integration (embedding an external orchestration layer into an actively maintained AI coding agent)
**Researched:** 2026-03-31
**Confidence:** MEDIUM-HIGH

## Executive Summary

This project asks whether GSD's workflow orchestration should move from an external layer (skills, CLAUDE.md, AgentTool) into a tighter integration with Claude Code's internals, and if so, how. All four research streams converge on the same answer: do not fork Claude Code. The maintenance burden of a fork -- driven by monthly upstream releases, a Bun-specific build system, no upstream test suite, and 5,000+ line monolithic files -- is unsustainable for a solo maintainer. The research is unanimous and confident on this point.

The recommended path is a layered integration strategy that maximizes Claude Code's existing extension points before considering any source-level changes. The highest-value next step is building a GSD MCP server that exposes workflow operations as structured tools, combined with optimizing existing skill prompts to use fork-mode execution and proper agent definitions. This approach reduces token overhead by an estimated 10x for non-GSD queries, preserves GSD's multi-CLI compatibility, and requires zero modifications to Claude Code's source. The MCP server stack is straightforward: TypeScript, the official `@modelcontextprotocol/sdk`, Zod for schema validation, and Node.js 20 LTS as the runtime.

The primary risk is token budget cannibalization -- GSD's orchestration prompts competing with Claude Code's own context for the same token budget, potentially triggering compaction that destroys workflow state. The secondary risk is building on internal APIs that shift between releases. Both risks are mitigated by the MCP+skills approach, which operates entirely through Claude Code's stable, public extension surfaces. The biggest gap in this research is the lack of actual measurements: token overhead estimates, agent spawning latency, and MCP vs. BashTool performance comparisons are all analytical projections, not empirical data. Quantifying these should be the first phase of any roadmap.

## Key Findings

### Recommended Stack

The integration should be built as a separate MCP server process, not embedded in Claude Code. GSD already has a working external-layer architecture (skills + CLAUDE.md + gsd-tools.cjs). The MCP server adds structured, token-efficient tool access on top of this foundation without replacing what works.

**Core technologies:**
- **TypeScript 5.x + `@modelcontextprotocol/sdk`**: GSD MCP server implementation -- official protocol SDK, handles JSON-RPC and stdio transport, type-safe
- **Zod 3.23+**: Tool input schema validation -- already used throughout Claude Code, ensures schema compatibility
- **Node.js 20 LTS**: MCP server runtime -- more stable than Bun for long-running servers, better MCP SDK testing coverage
- **tsup/esbuild**: Production bundling -- fast, produces single-file bundles, avoids Bun bundler complexity
- **Markdown files (PROJECT.md, ROADMAP.md)**: State storage -- human-readable, git-trackable, no database needed, already works

**What NOT to use:** Bun (for GSD server), oclif, Express/Fastify, SQLite/Postgres, React/Ink (for GSD itself). See STACK.md for rationale on each exclusion.

### Expected Features

**Must have (table stakes):**
- Project state management -- persistent workflow state across sessions via filesystem
- Slash command registration -- `/gsd:*` entry points via skills system
- Subagent orchestration -- parallel research/coding/verification via AgentTool
- Context injection -- project state included in system prompts via CLAUDE.md
- Phase/milestone tracking -- multi-phase lifecycle tracking via markdown files
- Token cost awareness -- orchestration must not consume excessive context budget
- Session continuity -- resume interrupted workflows across sessions

**Should have (differentiators -- things integration unlocks that external layer cannot):**
- Native token budget integration -- orchestration context participates in compaction pipeline
- Tool restriction per phase -- enforce read-only tools during verification phases via deny rules
- Memory system integration -- persist decisions to Claude Code's memdir for cross-session recall
- Hooks integration -- lifecycle hooks around phase transitions via post-sampling hooks
- Progress UI -- real-time workflow status in terminal (integration-only capability)

**Defer (v2+ or wait for upstream):**
- WorkflowTool registration -- blocked by `WORKFLOW_SCRIPTS` feature gate, wait for public release
- Coordinator mode integration -- blocked by `COORDINATOR_MODE` feature gate, wait for public release
- Custom Ink UI components -- requires fork, low value relative to cost
- Direct AppState access -- requires fork, useful but not essential
- System prompt pipeline modification -- breaks prompt caching, use CLAUDE.md instead

### Architecture Approach

Claude Code offers six integration seams at increasing depths: (1) Skills System, (2) Plugin System, (3) Command Registry, (4) Tool Registry, (5) Coordinator Mode, and (6) Context Injection. The recommended approach uses only seams 1-3 plus MCP, which are all accessible without forking. The architecture follows a layered model where each layer provides incremental benefit: optimized skills (immediate), custom agent definitions (low effort), plugin packaging (medium effort), and native tools (only if fork ever becomes justified). The filesystem remains the source of truth for workflow state -- never AppState.

**Major components:**
1. **GSD MCP Server** -- exposes workflow operations (init, plan, execute, read-state, transition, verify) as structured tools callable by the model; eliminates prompt-injection overhead for state operations
2. **GSD Skills (optimized)** -- slash command entry points using `context: 'fork'` for isolated execution, `allowed-tools` for phase-appropriate restrictions, `files` for reference docs without prompt embedding
3. **GSD Agent Definitions** -- `.claude/agents/gsd-planner.md`, `gsd-researcher.md`, `gsd-executor.md`, `gsd-verifier.md` with proper frontmatter (tools, model, skills, hooks, maxTurns) replacing inline role descriptions
4. **GSD CLI Tools (existing)** -- `gsd-tools.cjs` for file I/O and state management, continues to work for non-MCP operations
5. **State Files** -- `.planning/` directory with PROJECT.md, ROADMAP.md, REQUIREMENTS.md as persistent, git-trackable workflow state

### Critical Pitfalls

1. **Merge Debt Avalanche** -- forking Claude Code creates superlinear maintenance burden (8-16 hours/month minimum, growing over time). Prevention: never fork; use MCP + skills + plugins exclusively.
2. **Phantom API Surfaces** -- treating Claude Code's internal module boundaries as stable APIs leads to breakage on every upstream update. Prevention: limit integration to documented public surfaces (CLAUDE.md, skills, MCP, slash commands); create an adapter layer if any internal imports are unavoidable.
3. **Token Budget Cannibalization** -- GSD's orchestration prompts competing with Claude Code's context triggers compaction that destroys workflow state. Prevention: move orchestration logic into MCP tools (structured schemas, not prose); use fork-mode skills to isolate context; measure actual overhead before and after.
4. **State Model Collision** -- GSD's file-based state and Claude Code's AppState/session storage coexisting without corruption. Prevention: keep GSD state entirely external to AppState; mark orchestration messages as ephemeral; never store workflow state in Zustand.
5. **"Just One More Hook" Escalation** -- integration surface area grows until every upstream release causes breakage. Prevention: set hard limits (max 5 modified upstream files, max 20 lines per file); every proposed hook must prove it cannot be achieved without modifying upstream.

## Implications for Roadmap

Based on research, the project naturally decomposes into 5 phases. The ordering follows dependency chains discovered in the architecture and features analysis: measurement must precede optimization decisions, skill optimization must precede MCP server work (to establish baselines), and the MCP server must be functional before plugin packaging makes sense.

### Phase 1: Overhead Quantification
**Rationale:** Every downstream decision depends on knowing the actual cost of GSD's current approach. The research identified token overhead estimates (10x reduction possible) but flagged these as LOW confidence analytical projections. Without measurements, integration work is speculative.
**Delivers:** Concrete measurements of (a) token overhead per GSD command, (b) agent spawning latency, (c) context pollution after N interactions, (d) compaction trigger frequency during GSD workflows.
**Addresses:** Token cost awareness (table stake), the core feasibility question from PROJECT.md.
**Avoids:** Building integration based on assumptions rather than data (Pitfall 6: Token Budget Cannibalization).

### Phase 2: Skill & Agent Definition Optimization
**Rationale:** The lowest-effort, highest-impact changes identified across all research streams. Fork-mode skills and proper agent definitions are purely external changes that reduce token overhead immediately with zero Claude Code modifications.
**Delivers:** (a) Refactored GSD skills using `context: 'fork'`, `allowed-tools`, `files`, and `effort` frontmatter; (b) dedicated agent definitions in `.claude/agents/` replacing inline role prompts; (c) re-measurement to quantify improvement.
**Addresses:** Context injection optimization, subagent orchestration improvement, tool restriction per phase (via skill frontmatter).
**Avoids:** Monolithic prompt injection anti-pattern, agent definition in prompts anti-pattern.

### Phase 3: GSD MCP Server
**Rationale:** The MCP server is the centerpiece of the integration strategy. It replaces prompt-injected orchestration instructions with structured tool schemas and replaces BashTool-to-gsd-tools.cjs roundtrips with direct MCP calls. This is the phase that delivers the largest token savings.
**Delivers:** (a) Working MCP server with tools for init, plan, execute, read-state, transition, verify; (b) MCP resources for project state, roadmap, requirements; (c) hybrid command pattern (slash command triggers MCP tool); (d) re-measurement comparing MCP approach to baseline.
**Uses:** TypeScript 5.x, `@modelcontextprotocol/sdk`, Zod, Node.js 20, tsup.
**Implements:** GSD MCP Server component from architecture.
**Avoids:** State via BashTool anti-pattern, Phantom API Surfaces pitfall.

### Phase 4: Plugin Packaging
**Rationale:** Once skills, agent definitions, and MCP server are working individually, packaging them as a Claude Code plugin provides clean distribution, lifecycle hooks, and a single installation mechanism. This is deferred until the individual components are proven because plugin packaging adds abstraction without adding functionality.
**Delivers:** (a) `plugin.json` manifest bundling skills, agents, hooks, and MCP server config; (b) lifecycle hooks for session start (load workflow state) and post-compact (preserve workflow context); (c) memory system integration via memdir for cross-session persistence.
**Addresses:** Memory system integration, hooks integration, session continuity.
**Avoids:** Command Registration Fragility pitfall (plugin registration is more robust than raw settings).

### Phase 5: Integration Assessment & Decision
**Rationale:** After phases 1-4, the project has both measurements and a working non-fork integration. This phase compares the achieved improvements against the original pain points and makes the final recommendation: is the integration sufficient, or does a fork (Layer 4: native tools) become justified?
**Delivers:** (a) Final feasibility report with empirical data; (b) clear go/no-go on fork; (c) maintenance cost projections based on actual experience with the plugin approach; (d) updated PROJECT.md with final decision.
**Addresses:** The core project requirement: "Produce a clear recommendation: integrate or don't bother."

### Phase Ordering Rationale

- Phase 1 before everything else because all optimization decisions require baseline measurements. Without knowing actual token overhead, agent latency, and compaction behavior, integration work is guesswork.
- Phase 2 before Phase 3 because skill optimization is zero-risk and provides an immediate baseline improvement. It also validates whether simple external changes are sufficient, potentially reducing the scope needed from the MCP server.
- Phase 3 is the core deliverable because the MCP server addresses the highest-value differentiator (token budget integration) through the most architecturally appropriate mechanism (official extension point).
- Phase 4 after Phase 3 because plugin packaging is distribution infrastructure, not functionality. It only makes sense once the components being packaged are working.
- Phase 5 last because the final recommendation requires evidence from all prior phases.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Overhead Quantification):** Needs research into Claude Code's `cost-tracker.ts`, `tokenBudget.ts`, and compaction trigger logic to determine measurement methodology. Also needs to establish what "acceptable" overhead looks like.
- **Phase 3 (MCP Server):** Needs research into current MCP SDK API surface, transport options, and any changes since May 2025. The research flagged that MCP SDK details should be verified against current documentation.
- **Phase 4 (Plugin Packaging):** Needs research into Claude Code's plugin manifest format, hook registration lifecycle, and memdir integration API. Plugin system stability was rated MEDIUM in the research.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Skill & Agent Optimization):** Well-documented in Claude Code's skill frontmatter spec and agent definition schema. The architecture research mapped these precisely.
- **Phase 5 (Assessment):** Decision-making phase, no technical research needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Recommendations grounded in direct codebase analysis. MCP as the extension mechanism is the clear consensus across all research streams. Only gap: MCP SDK version details need verification against current docs. |
| Features | MEDIUM | Table stakes and differentiators well-identified from codebase analysis. Competitive landscape analysis limited by lack of web search -- could not validate against current state of Cursor, Devin, etc. |
| Architecture | HIGH | Six integration seams mapped directly from Claude Code source with file references. Layered integration recommendation is strongly supported by dependency analysis. |
| Pitfalls | HIGH | Pitfalls grounded in specific codebase observations (file sizes, update cadence, security infrastructure). Maintenance burden estimates are analytical but consistent with established fork maintenance patterns. |

**Overall confidence:** MEDIUM-HIGH. The strategic recommendation (do not fork, use MCP + skills + plugins) is HIGH confidence. The quantitative projections (10x token reduction, maintenance hour estimates) are LOW confidence and require empirical validation in Phase 1.

### Gaps to Address

- **No empirical measurements exist:** Token overhead, agent latency, MCP performance -- all analytical estimates. Phase 1 must produce real numbers before committing to phases 3-4.
- **MCP SDK currency:** Research was conducted without web search. The `@modelcontextprotocol/sdk` API may have changed since May 2025. Verify before Phase 3 implementation.
- **Plugin system maturity:** Claude Code's plugin system stability was rated MEDIUM. It may evolve between research and implementation. Check current state before Phase 4.
- **Coordinator mode timeline:** Feature-gated coordinator mode could become public at any time, potentially obsoleting parts of GSD's orchestration approach. Monitor upstream releases.
- **Multi-CLI compatibility testing:** The research identified preserving multi-CLI compatibility as critical, but no testing plan exists for ensuring the MCP server approach works with non-Claude-Code CLIs.
- **Compaction interaction with GSD context:** The research identified that compaction may destroy workflow-critical context, but the exact behavior depends on CLAUDE.md content priority during compaction, which was not fully mapped.

## Sources

### Primary (HIGH confidence)
- Direct Claude Code codebase analysis (read-only, 2026-03-31): `tools.ts`, `commands.ts`, `Tool.ts`, `context.ts`, `skills/loadSkillsDir.ts`, `tools/AgentTool/`, `coordinator/coordinatorMode.ts`, `state/AppStateStore.ts`, `utils/plugins/`, `services/compact/`, `utils/bash/bashSecurity.ts`
- GSD codebase analysis: current architecture of skills, CLAUDE.md injection, gsd-tools.cjs, agent spawning patterns
- `.planning/codebase/ARCHITECTURE.md`, `CONCERNS.md`, `CONVENTIONS.md`, `STRUCTURE.md`, `INTEGRATIONS.md`, `STACK.md`

### Secondary (MEDIUM confidence)
- Established patterns for fork maintenance (Linux distro kernel forks, IDE fork projects)
- MCP protocol specification and SDK (training data, pre-May 2025 -- may need updating)
- Claude Code update cadence and release patterns (stated in PROJECT.md, not independently verified)

### Tertiary (LOW confidence)
- Token overhead reduction estimates (10x for non-GSD queries) -- analytical projection, not measured
- Maintenance burden hours per approach -- based on typical patterns, not measured for this project
- Competitive landscape (Cursor, Devin, SWE-Agent) -- training data only, no live research

---
*Research completed: 2026-03-31*
*Ready for roadmap: yes*
