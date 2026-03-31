# Technology Stack: CLI Extension & Fork Strategies

**Project:** Claude Code + GSD Integration Feasibility
**Researched:** 2026-03-31
**Mode:** Ecosystem / Feasibility hybrid
**Overall confidence:** MEDIUM (training data, verified against codebase analysis)

## Executive Summary

There are four viable approaches for integrating GSD into Claude Code, ranging from zero-code-change to full fork. Each trades off maintenance burden against integration depth. The analysis below draws on Claude Code's actual architecture (Commander.js CLI, React/Ink UI, Zustand state, modular tool system, MCP plugin layer) and established patterns for extending/forking large TypeScript CLI tools.

The recommendation is a **layered strategy**: maximize what can be done through Claude Code's existing extension points (MCP servers, custom slash commands, CLAUDE.md injection) before considering any fork. If a fork is ever justified, use a thin-shim approach rather than deep modification.

---

## Approach 1: External Orchestration (Current GSD Architecture)

**What it is:** GSD runs outside Claude Code, using its public interfaces -- slash commands, CLAUDE.md injection, Agent tool spawning, and external Node.js tools.

**Confidence:** HIGH (this is what GSD already does)

### How It Works

| Integration Point | Mechanism | What GSD Does |
|-------------------|-----------|---------------|
| Slash commands | `~/.claude/settings.json` custom commands | Registers `/gsd:*` commands that invoke skills |
| Context injection | `CLAUDE.md` files at project/user level | Injects orchestration prompts, role definitions |
| Agent spawning | `Agent` tool (built into Claude Code) | Spawns sub-agents for parallel phase execution |
| State management | External `gsd-tools.cjs` Node CLI | Reads/writes PROJECT.md, ROADMAP.md, etc. |
| Tool access | Via MCP servers (optional) | Custom tools for search, file ops, etc. |

### Why This Exists

Claude Code was designed with this exact extension model. The architecture analysis confirms:
- Commands layer has ~100 commands with feature-gated registration
- MCP client/server management is a first-class service
- CLAUDE.md aggregation is built into the context pipeline
- The Agent tool is a core tool type alongside Bash and FileEdit

### Strengths

- **Zero maintenance burden on Claude Code updates.** GSD operates at the API boundary. When Claude Code updates monthly, GSD is unaffected unless Anthropic changes slash command registration or CLAUDE.md loading (extremely unlikely -- these are documented user-facing contracts).
- **No build system complexity.** No Bun bundler, no TSX compilation, no dead-code elimination to manage.
- **Cross-CLI compatibility preserved.** GSD can work with other AI CLIs, not locked to Claude Code.

### Weaknesses

- **Token overhead.** Every GSD orchestration prompt consumes context window tokens. Role definitions, workflow instructions, and state management prompts all eat into the budget.
- **Latency from agent spawning.** Each Agent tool call starts a new Claude session with full context initialization.
- **No access to internal state.** Cannot read Claude Code's AppState (model selection, message history, compaction state, permission mode). Must reconstruct or ignore this information.
- **Indirect communication.** GSD communicates with Claude Code through prompt injection, not programmatic APIs. This is inherently lossy.

### Verdict

This is the correct baseline. The question is whether the token/latency overhead justifies moving to a deeper integration level.

---

## Approach 2: MCP Server Integration (Recommended First Step)

**What it is:** Build a dedicated GSD MCP server that exposes GSD's workflow operations as tools directly accessible to Claude Code's model.

**Confidence:** HIGH (MCP is Claude Code's official extension mechanism)

### How It Works

Claude Code has a full MCP client (`services/mcp/client.ts`) that discovers and invokes tools from MCP servers. An MCP server is a separate process communicating over stdio or HTTP.

```
Claude Code  <-->  MCP Client  <-->  GSD MCP Server (separate process)
                                      |
                                      +-- gsd_create_project tool
                                      +-- gsd_plan_phase tool
                                      +-- gsd_execute_milestone tool
                                      +-- gsd_read_roadmap tool
                                      +-- gsd_transition_phase tool
                                      +-- gsd_get_state tool (resources)
```

### Technology Stack for MCP Server

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| TypeScript | 5.x | Server implementation | Matches Claude Code ecosystem, type safety |
| `@modelcontextprotocol/sdk` | latest | MCP protocol implementation | Official SDK, handles protocol details |
| `zod` | 3.x | Tool input validation | Already used throughout Claude Code, schema-compatible |
| Node.js | 20+ | Runtime | MCP servers are standard Node processes |
| `tsx` or `ts-node` | latest | TypeScript execution | For development; can bundle for production |

### What to Build

**Tools (callable by the model):**

| Tool Name | Purpose | Reduces Token Overhead? |
|-----------|---------|------------------------|
| `gsd_init_project` | Create PROJECT.md, initial structure | YES -- replaces large prompt template |
| `gsd_plan_milestone` | Generate/update ROADMAP.md phases | YES -- structured output vs prompt |
| `gsd_execute_phase` | Orchestrate phase execution | PARTIALLY -- still needs agent spawning |
| `gsd_read_state` | Return current project state | YES -- structured data vs prompt parsing |
| `gsd_transition` | Handle phase transitions | YES -- logic in server, not in prompt |
| `gsd_verify` | Run verification checklist | YES -- structured checks vs prompt |

**Resources (context the model can read):**

| Resource | Purpose |
|----------|---------|
| `gsd://project/state` | Current PROJECT.md parsed as structured data |
| `gsd://project/roadmap` | Current ROADMAP.md parsed as structured data |
| `gsd://project/requirements` | Current REQUIREMENTS.md parsed |

**Prompts (reusable prompt templates):**

| Prompt | Purpose |
|--------|---------|
| `gsd_orchestrate` | Main orchestration prompt, injected only when needed |
| `gsd_research` | Research agent role prompt |
| `gsd_implement` | Implementation agent role prompt |

### Why This Over a Fork

1. **Official extension point.** Anthropic built MCP into Claude Code specifically for this use case. Fighting the architecture is always more expensive than using it.
2. **Process isolation.** GSD MCP server crashes cannot crash Claude Code. Updates to either are independent.
3. **Token reduction.** MCP tools have structured schemas -- the model knows what parameters they accept without a long natural-language prompt explaining the workflow. A tool call like `gsd_init_project({name: "foo", type: "CLI"})` replaces a 2000-token prompt injection.
4. **Maintained by Anthropic.** The MCP client in Claude Code is actively maintained. Protocol improvements benefit GSD for free.

### What This Cannot Do

- **Cannot modify Claude Code's UI.** No custom Ink components, no progress bars, no custom renderers.
- **Cannot access AppState directly.** The MCP server is a separate process; it cannot read Claude Code's in-memory state.
- **Cannot intercept the query pipeline.** Cannot add middleware to the QueryEngine, cannot modify system prompts programmatically (only via CLAUDE.md).
- **Cannot reduce agent spawning latency.** Agent tool calls still go through Claude Code's standard Agent tool flow.

---

## Approach 3: Custom Build / Wrapper Binary

**What it is:** Build a wrapper that starts Claude Code as a subprocess, adds custom commands and UI, and mediates interaction.

**Confidence:** LOW (fragile pattern, not recommended)

### How It Would Work

```
gsd-cli (custom binary)
  |
  +-- Starts Claude Code as subprocess (claude --no-interactive or similar)
  +-- Intercepts stdin/stdout
  +-- Adds GSD commands
  +-- Manages state alongside
```

### Why NOT to Do This

1. **Claude Code is a full React/Ink TUI.** It manages its own terminal state, cursor positioning, color output, and interactive dialogs. Wrapping its stdout is not piping text -- it is intercepting a terminal UI framebuffer. This breaks constantly.
2. **No stable subprocess API.** Claude Code does not expose a machine-readable subprocess interface. The `--print` flag exists for single-shot queries, but it does not support multi-turn conversation, tool execution, or state management.
3. **Version coupling without type safety.** Any stdout parsing breaks on UI changes. No TypeScript types to catch regressions at compile time.
4. **Anthropic actively discourages this.** The official extension path is MCP + CLAUDE.md + custom commands.

### Verdict

Do not pursue. Every hour spent here is wasted compared to MCP server integration.

---

## Approach 4: Fork & Maintain

**What it is:** Fork Claude Code's repository, modify its internals to add GSD functionality, rebase on upstream releases.

**Confidence:** MEDIUM (well-established pattern, but high cost for this specific codebase)

### Fork Maintenance Strategies (General Patterns)

There are two established patterns for maintaining forks of actively developed projects:

#### Strategy A: Rebase Fork

Maintain a branch with GSD patches on top of upstream. Periodically rebase onto new upstream releases.

```
upstream/main:  A -- B -- C -- D -- E (monthly releases)
                          \
gsd/main:                  C' -- gsd1 -- gsd2 -- gsd3
                                                    \
after rebase:              E' -- gsd1' -- gsd2' -- gsd3'
```

**Pros:** Clean history, patches are explicit and reviewable.
**Cons:** Rebase conflicts on every upstream update. If GSD touches files that Anthropic also changes (which is likely given the pace of development), conflicts are frequent and painful.

#### Strategy B: Merge Fork

Maintain a separate branch, periodically merge upstream.

```
upstream/main:  A -- B -- C -- D -- E
                          \         \
gsd/main:                 +-- gsd1 -- merge(E) -- gsd2
```

**Pros:** Git handles most merge conflicts automatically. History shows when upstream was integrated.
**Cons:** Messy history. Merge conflicts in heavily-modified areas still require manual resolution.

#### Strategy C: Thin Shim (Recommended if forking)

Minimize diff against upstream. Instead of modifying existing files, add new files and use entry-point hooks.

```
claude-code/
  src/
    tools/          # upstream, untouched
    commands/       # upstream, untouched
    gsd/            # NEW directory, all GSD code lives here
      index.ts      # GSD initialization
      tools/        # GSD-specific tools
      commands/     # GSD-specific commands
      state/        # GSD state management
    main.tsx        # MINIMAL CHANGE: import and call gsd/index.ts init
```

**Pros:** Upstream files rarely touched, so merge conflicts are rare. GSD code is isolated. Easy to see what is GSD vs upstream.
**Cons:** Still requires understanding Claude Code's internal APIs (which are not stable or documented). Still need to track Bun build system changes. Still need a fork.

### Claude Code-Specific Fork Challenges

Based on the architecture analysis, here is why forking Claude Code is particularly expensive:

| Challenge | Details | Severity |
|-----------|---------|----------|
| **Bun bundler** | Build system uses `bun:bundle` imports and compile-time `feature()` flags for dead code elimination. Not standard tooling -- must maintain Bun compatibility. | HIGH |
| **Feature flags** | Compile-time flags (`COORDINATOR_MODE`, `KAIROS`, `HISTORY_SNIP`) gate entire code paths. A fork must understand which flags to enable/disable. | MEDIUM |
| **OAuth/Auth system** | Authentication involves keychain integration, MDM settings, remote managed config, OAuth flows. A fork inherits all of this or must disable it. | HIGH |
| **Analytics/GrowthBook** | Feature flag evaluation talks to GrowthBook servers. A fork either piggybacks on Anthropic's GrowthBook or disables feature flags entirely. | MEDIUM |
| **Monthly release cadence** | Claude Code updates roughly monthly with significant changes. Each merge/rebase is a non-trivial event. | HIGH |
| **No test suite detected** | The codebase analysis found no Jest/Vitest/Mocha configuration. Without tests, you cannot verify that your fork patches survive upstream merges. | CRITICAL |
| **331 utility files** | The `utils/` directory alone has 331 files. Internal APIs shift frequently in large codebases like this. | HIGH |
| **Dead code elimination** | The `feature()` function enables dead-code elimination at build time. Fork modifications must be compatible with this system or bypass it. | MEDIUM |

### What Forking Would Enable

Things that ONLY a fork can do:

| Capability | Value to GSD | Justifies fork? |
|------------|--------------|-----------------|
| Custom Ink UI components | Show GSD progress in Claude Code's terminal UI | LOW -- MCP tools already show progress |
| Direct AppState access | Read/write model selection, message history, permissions | MEDIUM -- useful but not essential |
| QueryEngine middleware | Intercept and modify queries before they reach Claude | LOW -- CLAUDE.md already modifies context |
| Custom tool types | Add GSD-native tools alongside Bash/FileEdit/Agent | MEDIUM -- MCP tools already achieve this |
| Compaction pipeline hooks | Optimize how GSD prompts are compacted | LOW -- compaction already handles large contexts |
| System prompt injection | Programmatic (not CLAUDE.md-based) prompt control | LOW -- CLAUDE.md is equivalent |

### Verdict

The capabilities that only a fork enables do not justify the maintenance burden, especially for a solo developer. The monthly update cadence, lack of test suite, and Bun build complexity make this the most expensive option by far.

---

## Recommended Stack

### Integration Architecture

| Layer | Technology | Purpose | Why |
|-------|-----------|---------|-----|
| **GSD MCP Server** | TypeScript + `@modelcontextprotocol/sdk` | Expose GSD operations as tools | Official extension mechanism, token-efficient |
| **GSD CLI Tools** | Node.js + `gsd-tools.cjs` (existing) | File I/O, state management | Already built, works well |
| **Context Injection** | CLAUDE.md files | Role definitions, workflow context | Built-in Claude Code feature, minimal tokens |
| **Command Registration** | `~/.claude/settings.json` slash commands | User-facing `/gsd:*` commands | Official mechanism, survives updates |
| **State Storage** | Markdown files (PROJECT.md, ROADMAP.md) | Persistent workflow state | Human-readable, git-trackable, no database needed |

### MCP Server Stack

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| TypeScript | 5.x | Implementation language | Type safety, matches ecosystem |
| `@modelcontextprotocol/sdk` | latest stable | Protocol handling | Official SDK, handles JSON-RPC, stdio transport |
| `zod` | 3.23+ | Schema validation | Claude Code uses it, ensures compatible schemas |
| Node.js | 20 LTS | Runtime | Stable, long-term support, MCP SDK targets it |
| `tsx` | latest | Dev-time TS execution | Zero-config TypeScript runner for development |
| `esbuild` or `tsup` | latest | Production bundling | Fast, produces single-file bundles for distribution |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `fast-glob` | 3.x | File discovery | Finding project files (ROADMAP.md, etc.) |
| `gray-matter` | 4.x | Frontmatter parsing | If structured metadata added to markdown files |
| `marked` | latest | Markdown parsing | Already used by Claude Code, parse project files |
| `chalk` | 5.x | Terminal output | For GSD CLI tool output (already in ecosystem) |
| `p-map` | 6.x | Concurrent operations | Parallel file operations (already in ecosystem) |

### What NOT to Use

| Technology | Why Not |
|------------|---------|
| Bun (for GSD server) | Claude Code uses Bun, but GSD's MCP server should use Node.js for stability and broader compatibility. Bun's MCP support is less tested. |
| oclif | Over-engineered for an MCP server. oclif is for building complex multi-command CLIs, not protocol servers. |
| Express/Fastify | MCP uses stdio transport by default, not HTTP. HTTP transport is optional and adds complexity. |
| SQLite/Postgres | Markdown files are the right state format -- human-readable, git-trackable, no migration burden. |
| Prisma/Drizzle | No database, no ORM needed. |
| React/Ink (for GSD) | GSD does not render its own terminal UI. It operates through Claude Code's UI. |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| Extension mechanism | MCP Server | Fork & modify | 10x maintenance burden, monthly merge conflicts, no test suite to verify |
| Extension mechanism | MCP Server | Wrapper binary | Fragile stdout parsing, breaks on UI changes, not a supported pattern |
| MCP transport | stdio | HTTP/SSE | stdio is simpler, same-machine communication, no port management |
| State storage | Markdown files | SQLite | Markdown is human-readable, git-trackable, already works, no schema migrations |
| Runtime | Node.js 20 LTS | Bun | Node.js is more stable for long-running servers, better MCP SDK testing |
| Schema validation | Zod | JSON Schema | Zod is already in the ecosystem, provides TypeScript type inference |
| Build tool | tsup/esbuild | Bun bundler | Simpler, well-documented, no `feature()` dead-code-elimination complexity |

---

## Fork Decision Matrix

Use this to decide if/when forking becomes justified:

| Condition | Current State | Fork Justified? |
|-----------|---------------|-----------------|
| MCP cannot expose needed operations | MCP covers all GSD operations | NO |
| CLAUDE.md context injection insufficient | Works for current needs | NO |
| Agent spawning latency is the bottleneck | Needs measurement | MAYBE -- but fork does not necessarily fix this |
| Claude Code removes MCP support | Extremely unlikely | Would justify fork |
| Claude Code removes CLAUDE.md support | Extremely unlikely | Would justify fork |
| Token overhead exceeds 30% of context window | Needs measurement | MAYBE -- MCP tools reduce this first |
| Anthropic makes Claude Code source unavailable | Unknown future risk | Fork would be necessary but frozen |

**Bottom line:** Fork only if MCP + CLAUDE.md + slash commands are proven insufficient after optimization. This has not been demonstrated yet.

---

## Command Registration Patterns

### Pattern 1: Slash Commands via Settings (Current, Keep)

```json
// ~/.claude/settings.json
{
  "customSlashCommands": [
    {
      "name": "gsd:new-project",
      "description": "Initialize a new GSD project",
      "command": "Read and execute the skill at ~/.claude/get-shit-done/skills/new-project.md"
    }
  ]
}
```

**Why keep:** Zero-cost, user-facing, survives all updates.
**Limitation:** Commands are prompt-injected, consuming tokens.

### Pattern 2: MCP Tools (Recommended Addition)

```typescript
// gsd-mcp-server/src/tools/init-project.ts
import { z } from "zod";

export const initProjectTool = {
  name: "gsd_init_project",
  description: "Initialize a new GSD project with PROJECT.md and directory structure",
  inputSchema: z.object({
    name: z.string().describe("Project name"),
    description: z.string().describe("One-line project description"),
    type: z.enum(["greenfield", "integration", "migration"]).describe("Project type"),
  }),
  handler: async (input: { name: string; description: string; type: string }) => {
    // Structured logic, no prompt overhead
    // Returns structured result, not natural language
  },
};
```

**Why add:** Structured tool calls replace long prompt injections. Model gets schema, not prose.

### Pattern 3: Hybrid (Recommended Final State)

```
User types /gsd:new-project
  -> Slash command skill fires
  -> Skill instructs model to call gsd_init_project MCP tool
  -> MCP tool does the actual work
  -> Skill provides orchestration context (minimal tokens)
  -> MCP tool returns structured result
```

This combines the user-facing convenience of slash commands with the token efficiency of MCP tools.

---

## Plugin System Analysis (Claude Code's Extensibility)

Based on the architecture analysis, Claude Code has four extension surfaces:

| Surface | Stability | Power | Token Cost | Recommended Use |
|---------|-----------|-------|------------|-----------------|
| CLAUDE.md files | Very stable | Medium | High (injected every turn) | Role definitions, project context |
| Custom slash commands | Very stable | Low | Medium (per invocation) | User-facing entry points |
| MCP servers | Stable | High | Low (structured tool calls) | Core GSD operations |
| Agent tool spawning | Stable | High | Very high (new session) | Parallel execution only |

### Key Insight: Token Budget Allocation

The biggest opportunity is reducing CLAUDE.md injection size. Currently, GSD injects its full orchestration context into CLAUDE.md, which is loaded on every query. Most of this context is only relevant during specific GSD operations.

**Current flow (expensive):**
```
Every Claude Code query:
  1. Load CLAUDE.md (includes full GSD orchestration context)  -- ~3000-5000 tokens
  2. User asks unrelated question
  3. GSD context wasted
```

**Optimized flow (MCP + minimal CLAUDE.md):**
```
Every Claude Code query:
  1. Load CLAUDE.md (minimal: "GSD available via /gsd: commands")  -- ~100 tokens
  2. User asks unrelated question
  3. No GSD overhead

GSD-specific query:
  1. User types /gsd:execute
  2. Slash command fires, instructs model to use GSD MCP tools
  3. Model calls gsd_read_state tool  -- structured, ~200 tokens
  4. Model calls gsd_execute_phase tool  -- structured, ~300 tokens
  5. Total GSD overhead: ~500 tokens vs ~5000 tokens
```

This is a **10x reduction** in token overhead for non-GSD queries and a **significant reduction** even for GSD queries.

---

## Installation & Setup

```bash
# GSD MCP Server (new component)
mkdir gsd-mcp-server && cd gsd-mcp-server
npm init -y
npm install @modelcontextprotocol/sdk zod
npm install -D typescript tsx tsup @types/node

# tsconfig.json
cat > tsconfig.json << 'TSCONFIG'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "strict": true,
    "outDir": "dist",
    "declaration": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
TSCONFIG

# Register MCP server with Claude Code
# In ~/.claude/settings.json:
# {
#   "mcpServers": {
#     "gsd": {
#       "command": "node",
#       "args": ["path/to/gsd-mcp-server/dist/index.js"],
#       "env": {}
#     }
#   }
# }
```

---

## Sources & Confidence

| Claim | Source | Confidence |
|-------|--------|------------|
| Claude Code uses Commander.js, React/Ink, Zustand | Codebase analysis (ARCHITECTURE.md, STACK.md) | HIGH |
| MCP is Claude Code's official extension mechanism | Codebase analysis (services/mcp/) | HIGH |
| CLAUDE.md loaded on every query | Codebase analysis (context.ts, context/ directory) | HIGH |
| No test suite in Claude Code | Codebase analysis ("Not detected") | MEDIUM (may exist but not found) |
| Monthly update cadence | PROJECT.md states this | MEDIUM (stated, not verified against release history) |
| MCP SDK for TypeScript exists and is stable | Training data (pre-May 2025) | MEDIUM (version may have changed) |
| Bun bundler complexity for forks | Codebase analysis (bun:bundle imports, feature() system) | HIGH |
| Token overhead estimates (10x reduction) | Analytical estimate based on architecture | LOW (needs measurement) |
| Fork rebase/merge patterns | Established git patterns, training data | HIGH |
| oclif not recommended | Training data (well-established opinion) | HIGH |

**Note:** WebSearch was unavailable during this research. MCP SDK version and API details should be verified against current documentation before implementation. The core architectural analysis and strategic recommendations are derived from the codebase analysis files, which are primary sources.

---

*Stack research: 2026-03-31*
