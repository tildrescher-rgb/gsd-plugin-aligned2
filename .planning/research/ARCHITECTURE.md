# Architecture Patterns: GSD Integration into Claude Code

**Domain:** CLI workflow orchestration integration
**Researched:** 2026-03-31
**Confidence:** HIGH (based on direct codebase analysis of both systems)

## Executive Summary

Claude Code provides five distinct architectural seams through which GSD could integrate, each at a different depth. The current GSD integration uses the shallowest approach (skills + CLAUDE.md injection + AgentTool spawning). Deeper integration is architecturally feasible through the skills/bundled-skills system, the plugin system, the tool registry, the command registry, and the coordinator mode infrastructure. The right integration depth depends on which bottleneck GSD is trying to eliminate: context overhead, agent spawning latency, state persistence, or orchestration control flow.

## Current GSD Architecture (External Layer)

GSD currently integrates via Claude Code's user-facing extension points:

```
User Input ("/gsd:new-project")
    |
    v
[Claude Code REPL] -- slash command dispatch
    |
    v
[Skills System] -- loads .claude/skills/*.md files
    |                  GSD skills are markdown prompts with frontmatter
    v
[SkillTool] -- injects skill content into conversation
    |
    v
[Claude Model] -- interprets GSD orchestration prompt
    |
    v
[AgentTool] -- spawns subagents (gsd-planner, gsd-executor, etc.)
    |
    v
[BashTool] -- runs gsd-tools.cjs for state management
    |
    v
[FileWriteTool/FileEditTool] -- writes .planning/ files
```

**Key pain points in this architecture:**
1. Every GSD skill prompt consumes context tokens (orchestration instructions re-sent each turn)
2. Agent spawning via AgentTool creates new model sessions (startup latency per agent)
3. State management via gsd-tools.cjs requires BashTool invocations (tool call overhead)
4. No persistent workflow state -- each slash command is a fresh conversation

## Claude Code's Integration Seams

### Seam 1: Skills System (Current -- Shallowest)

**Location:** `skills/loadSkillsDir.ts`, `skills/bundledSkills.ts`, `tools/SkillTool/SkillTool.ts`
**What it provides:** Markdown-based prompt injection via slash commands
**How GSD uses it now:** `.claude/skills/*.md` files define GSD commands like `/gsd:new-project`

**Architecture detail:** Skills are `Command` objects with `type: 'prompt'`. When invoked, `SkillTool.ts` calls `getPromptForCommand()` which returns `ContentBlockParam[]` injected into the conversation. Skills support:
- `context: 'fork'` -- run in a sub-agent with separate context (reduces main context pollution)
- `allowedTools` -- restrict which tools the skill can use
- `model` -- override model for the skill
- `hooks` -- lifecycle hooks (pre/post execution shell commands)
- `effort` -- control reasoning effort level
- `agent` -- specify agent type for forked execution

**Integration potential:**
- **Bundled skills** (`skills/bundledSkills.ts`) are compiled into the CLI binary via `registerBundledSkill()`. GSD could register its skills this way instead of relying on filesystem discovery, eliminating the disk I/O latency.
- **Fork context** (`context: 'fork'`) already provides sub-agent isolation. GSD skills could use this to avoid polluting the main conversation context.
- Skills can have `files` property -- reference files extracted to disk on first invocation, giving the skill access to supporting documentation without embedding it in the prompt.

**Data flow:** User types `/gsd:plan` -> `processUserInput()` finds command -> `SkillTool.call()` invoked -> prompt content injected -> model responds using the injected instructions.

**Limitations:** Skills are stateless. Each invocation is independent. No workflow state machine. No cross-skill coordination.

---

### Seam 2: Plugin System (Medium Depth)

**Location:** `plugins/builtinPlugins.ts`, `utils/plugins/loadPluginCommands.ts`, `services/plugins/`
**What it provides:** Full plugin lifecycle with skills, commands, agents, hooks, MCP servers, and output styles

**Architecture detail:** Plugins are Git repositories with a manifest (`plugin.json`) defining:
- Skills (markdown prompts) in `skills/` directory
- Commands in `commands/` directory
- Agent definitions
- Hooks (lifecycle callbacks)
- MCP server configurations
- Output style overrides

Plugins are loaded via `loadAllPluginsCacheOnly()` at startup and their commands merged into `getCommands()`. Plugin skills are loaded separately via `getPluginSkills()`.

**Integration potential:**
- GSD could be packaged as a Claude Code plugin, giving it access to the full plugin infrastructure
- Plugin hooks provide lifecycle integration (pre/post compact, session start, etc.)
- Plugin agent definitions would let GSD define specialized agents (planner, executor, researcher) as first-class agent types
- Plugin MCP servers could provide GSD state management as an MCP service instead of via BashTool

**Data flow:** Plugin installed -> manifest parsed -> skills/commands/agents registered -> available in `getCommands()` and `getSkills()` -> model can invoke via SkillTool or slash commands.

**Limitations:** Plugins are still external packages loaded at startup. No deeper access to AppState, QueryEngine, or tool execution internals. Plugin API surface is designed for extension, not deep integration.

---

### Seam 3: Command Registry (Medium-Deep)

**Location:** `commands.ts`, `types/command.ts`
**What it provides:** Slash command implementation with full access to `ToolUseContext` and `LocalJSXCommandContext`

**Architecture detail:** Commands come in three types:
1. `type: 'prompt'` -- Inject prompt content (what skills use)
2. `type: 'local'` -- Execute locally, return text result
3. `type: 'local-jsx'` -- Execute locally, render React/Ink JSX to terminal

`local` and `local-jsx` commands receive full `ToolUseContext` which includes:
- `getAppState()` / `setAppState()` -- read/write global application state
- `readFileState` -- cached file content
- `messages` -- full conversation history
- `options.tools` -- current tool registry
- `options.commands` -- current command registry
- `options.mcpClients` -- MCP connections
- `options.agentDefinitions` -- available agent types

**Integration potential:**
- GSD workflow commands could be implemented as `local-jsx` commands with direct AppState access
- Workflow state could be persisted in AppState (via custom fields) rather than external files
- Commands can trigger model queries via `shouldQuery: true` in their `onDone` callback
- Commands can inject `metaMessages` -- model-visible but UI-hidden messages for state context
- JSX commands can render rich terminal UI (progress bars, status panels, interactive menus)

**Data flow:** User types `/gsd:status` -> `processUserInput()` finds command -> command `load()` called -> `call(onDone, context, args)` executed -> command reads/writes AppState, renders UI -> calls `onDone()` with result -> optionally triggers model query.

**Key file paths:**
- `types/command.ts` -- Command type definitions (lines 175-206)
- `commands.ts` -- Command registry and getCommands() (lines 258-517)
- `utils/processUserInput/processUserInput.ts` -- Slash command dispatch

**Limitations:** Requires forking Claude Code to add new commands to the built-in registry. Commands registered via skills/plugins have narrower type (`prompt` only unless using plugin commands).

---

### Seam 4: Tool Registry (Deep)

**Location:** `tools.ts`, `Tool.ts`, `services/tools/StreamingToolExecutor.ts`, `services/tools/toolOrchestration.ts`
**What it provides:** Define tools the model can invoke directly, with full streaming, permissions, and progress tracking

**Architecture detail:** Tools are built via `buildTool()` which produces a `ToolDef` with:
- Zod input schema (model sees this for parameter validation)
- `call()` function receiving `ToolUseContext`
- Permission checking via `canUseTool` hook
- Progress streaming via `setToolJSX()` and `ToolCallProgress` callbacks
- JSX rendering for tool output in terminal
- Concurrency control (whether tool can run in parallel with others)

Tools are registered in `getAllBaseTools()` (`tools.ts` lines 193-251) and filtered by feature flags, environment variables, and permission deny rules.

**Integration potential:**
- A `GSDWorkflowTool` could let the model directly manage workflow state without going through BashTool
- A `GSDStateTool` could replace gsd-tools.cjs for state reads/writes
- Tools get streaming progress updates -- workflow progress could be shown in real-time
- Tools participate in the permission system -- workflow actions could require approval
- The existing `WorkflowTool` (feature-gated behind `WORKFLOW_SCRIPTS`) shows that Claude Code already has infrastructure for workflow execution

**Data flow:** Model decides to use tool -> `StreamingToolExecutor` extracts tool call from message -> `findToolByName()` resolves tool -> permission check -> Zod input validation -> `tool.call()` invoked with `ToolUseContext` -> result returned to model -> model continues reasoning.

**Key file paths:**
- `Tool.ts` -- Tool type definitions and ToolUseContext (158-300)
- `tools.ts` -- Tool registry, getAllBaseTools() (193-251)
- `services/tools/StreamingToolExecutor.ts` -- Parallel tool execution
- `services/tools/toolOrchestration.ts` -- Tool invocation pipeline

**Limitations:** Requires fork to register tools in `getAllBaseTools()`. Tools are model-initiated (the model decides when to use them), not user-initiated (unlike commands).

---

### Seam 5: Coordinator Mode / Agent Orchestration (Deepest)

**Location:** `coordinator/coordinatorMode.ts`, `tools/AgentTool/AgentTool.tsx`, `tools/AgentTool/runAgent.ts`, `tasks/LocalAgentTask/`
**What it provides:** Multi-agent orchestration with named agents, team management, message passing, and task tracking

**Architecture detail:** Coordinator mode (feature-gated behind `COORDINATOR_MODE`) transforms Claude Code into a multi-agent orchestrator:
- Spawns named worker agents via `AgentTool` with `name` parameter
- Workers communicate via `SendMessageTool`
- Teams managed via `TeamCreateTool` / `TeamDeleteTool`
- Workers can run in background with progress tracking
- Workers can use isolation modes (`worktree` for git isolation, `remote` for cloud)
- Agent definitions can specify: tools, model, effort, permission mode, MCP servers, hooks, max turns, skills, initial prompt, memory scope

**Integration potential:**
- GSD's parallel agent spawning pattern (research, planning, execution) maps directly to coordinator mode's team management
- Custom agent definitions (`.claude/agents/*.md` or `.claude/agents/*.json`) could define GSD-specific agent types
- Background agent execution with progress tracking matches GSD's verify-execute-verify loop
- The `AgentDefinition` type already supports everything GSD needs: tools, model overrides, skills, hooks, memory

**Data flow:** Coordinator spawns agent -> `AgentTool.call()` creates subagent context via `createSubagentContext()` -> `runAgent()` runs query loop with isolated ToolUseContext -> agent results returned to coordinator -> coordinator decides next action.

**Key file paths:**
- `coordinator/coordinatorMode.ts` -- Coordinator setup and worker tool filtering
- `tools/AgentTool/AgentTool.tsx` -- Agent spawning logic (1-120 for schema/setup)
- `tools/AgentTool/runAgent.ts` -- Agent query loop execution
- `tools/AgentTool/loadAgentsDir.ts` -- Agent definition loading from .claude/agents/
- `utils/forkedAgent.ts` -- Subagent context creation, cache-safe parameters

**Limitations:** Coordinator mode is feature-gated and not available in external builds. Agent-to-agent communication is via message passing, not shared state. Each agent runs its own query loop consuming separate API calls.

---

### Seam 6: Context Injection (Cross-cutting)

**Location:** `context.ts`, `utils/claudemd.ts`, `utils/messages/systemInit.ts`
**What it provides:** System prompt and user context injection into every model query

**Architecture detail:** Every query includes:
1. System prompt (git status, date, instructions)
2. User context from CLAUDE.md files (hierarchical: managed > user > project > local)
3. System context (environment details, coordinator context)
4. Memory files and attachments

CLAUDE.md files are loaded from multiple directories with priority ordering. The `@include` directive allows composing context from multiple files.

**Integration potential:**
- GSD currently uses CLAUDE.md for persistent context injection -- this is the correct approach
- Project-level `.claude/CLAUDE.md` with `@include` directives could compose GSD context modularly
- Memory files (`memdir/`) could store workflow state that persists across sessions
- The `getCoordinatorUserContext()` pattern shows how to conditionally inject workflow-specific context

**Data flow:** Query starts -> `getUserContext()` loads CLAUDE.md chain -> `getSystemContext()` adds environment -> context merged into system prompt -> sent with every API call.

**Limitations:** Context is re-injected on every turn, consuming tokens. CLAUDE.md content is static (loaded at session start, memoized). No dynamic context that responds to workflow state changes mid-conversation.

---

## Recommended Architecture: Layered Integration

Based on the seam analysis, GSD integration should follow a layered approach, with each layer providing incremental benefit:

### Layer 1: Optimized Skills (Low effort, High impact)

**What:** Restructure existing GSD skills to use `context: 'fork'` execution and add `files` property for reference documentation.

**Why:** This is the lowest-effort change that addresses the biggest pain point (context pollution). Forked skills run in sub-agents with separate token budgets, preventing GSD orchestration prompts from consuming the main conversation's context.

**Integration points:**
- `skills/loadSkillsDir.ts` -- skills loaded from `.claude/skills/`
- `tools/SkillTool/SkillTool.ts` -- skill execution with fork support
- Skill frontmatter: `context: fork`, `agent: general-purpose`, `files: {...}`

### Layer 2: Custom Agent Definitions (Low effort, Medium impact)

**What:** Define GSD agent types (planner, researcher, executor, verifier) as `.claude/agents/*.md` files with proper frontmatter.

**Why:** Replaces the current approach of embedding agent role descriptions in skill prompts. Agent definitions support tools, model overrides, skills, hooks, memory scoping, and permission modes. This gives each GSD agent a proper identity the model understands.

**Integration points:**
- `tools/AgentTool/loadAgentsDir.ts` -- agent definition loading
- `.claude/agents/gsd-planner.md`, `.claude/agents/gsd-researcher.md`, etc.
- Agent frontmatter: `tools`, `model`, `skills`, `hooks`, `memory`, `maxTurns`

### Layer 3: Plugin Package (Medium effort, High impact)

**What:** Package GSD as a Claude Code plugin with skills, agent definitions, hooks, and potentially an MCP server for state management.

**Why:** Plugins provide the full extension surface without forking. A GSD plugin could:
- Register all skills and agent definitions in one package
- Add lifecycle hooks (session start hook to load workflow state, post-compact hook to preserve workflow context)
- Include an MCP server that provides workflow state as resources (no more BashTool calls to gsd-tools.cjs)
- Define output styles for GSD-specific formatting

**Integration points:**
- `utils/plugins/loadPluginCommands.ts` -- plugin skill/command loading
- `utils/plugins/loadPluginAgents.ts` -- plugin agent definition loading
- `utils/plugins/loadPluginHooks.ts` -- plugin hook registration
- Plugin manifest `plugin.json` with skills, agents, hooks, mcp-servers

### Layer 4: Native Tools (High effort, Highest impact -- Requires Fork)

**What:** Add GSD-specific tools to Claude Code's tool registry: `GSDStateTool` (read/write workflow state), `GSDTransitionTool` (phase transitions), `GSDSpawnTool` (spawn typed GSD agents).

**Why:** Native tools eliminate the BashTool-as-intermediary overhead and give the model direct, schema-validated access to GSD operations. The model sees tool descriptions in its tool list and can use them without prompt injection.

**Integration points:**
- `tools.ts` -- `getAllBaseTools()` registration
- New directories: `tools/GSDStateTool/`, `tools/GSDTransitionTool/`
- `Tool.ts` -- ToolUseContext provides full AppState access

## Component Interaction Diagram

```
                    User Input
                        |
                        v
              +-------------------+
              | processUserInput  |  <-- Slash command dispatch
              +-------------------+
                   |          |
          /gsd:*  |          | free text
                   v          v
        +------------+  +-----------+
        | GSD Skill  |  | QueryEngine|
        | (forked)   |  |           |
        +------------+  +-----------+
              |               |
              v               v
        +-----------+   +-----------+
        | runAgent  |   | Model API |
        +-----------+   +-----------+
              |               |
              v               v
     +----------------+  +----------+
     | GSD Agent Def  |  | Tools    |
     | (.claude/agents)|  |          |
     +----------------+  +----------+
              |               |
              v               v
     +----------------+  +-----------+
     | Sub-query loop |  | GSD Tools |  <-- Layer 4: native tools
     | with GSD tools |  | (state,   |
     +----------------+  | transition)|
                          +-----------+
                               |
                               v
                      +------------------+
                      | .planning/ files |  <-- Workflow state
                      | (PROJECT.md,     |
                      |  ROADMAP.md, etc)|
                      +------------------+
```

## Data Flow Changes by Integration Layer

### Current (External Layer)
```
User -> Skill (prompt injection, ~2K tokens) -> Model -> AgentTool -> Model (new session, re-sends prompts) -> BashTool -> gsd-tools.cjs -> filesystem -> result text -> Model
```
Token cost: HIGH (orchestration prompt * number of agents + state read/write overhead)
Latency: HIGH (agent startup + BashTool subprocess + gsd-tools.cjs execution)

### Layer 1+2 (Optimized Skills + Agent Definitions)
```
User -> Skill (forked, isolated context) -> runAgent (typed GSD agent) -> Model -> BashTool -> gsd-tools.cjs -> filesystem -> result text -> Model
```
Token cost: MEDIUM (fork isolates context, agent definitions reduce prompt size)
Latency: MEDIUM (still subprocess overhead for state management)

### Layer 3 (Plugin with MCP State Server)
```
User -> Plugin Skill (forked) -> runAgent (typed GSD agent) -> Model -> MCP Resource Read -> GSD State Server -> result -> Model
```
Token cost: LOW (MCP resources are lean, no prompt overhead for state operations)
Latency: LOW-MEDIUM (MCP is in-process, no subprocess spawning)

### Layer 4 (Native Tools -- Fork Required)
```
User -> Skill (forked) -> runAgent (typed GSD agent) -> Model -> GSDStateTool -> direct filesystem -> typed result -> Model
```
Token cost: LOWEST (tool schemas in tool list, no prompt injection for state ops)
Latency: LOWEST (direct in-process execution, no subprocess or MCP overhead)

## Suggested Analysis Order (Dependencies)

Integration analysis should proceed in this order because each layer depends on understanding the previous:

1. **Skills System** (independent) -- Understand how skills are loaded, invoked, and how fork mode works. This is the foundation everything builds on.
   - Key files: `skills/loadSkillsDir.ts`, `tools/SkillTool/SkillTool.ts`
   - Question: How much context does fork mode actually save? What's the startup cost of a forked sub-agent?

2. **Agent Definitions** (depends on 1) -- Understand how agents are defined, loaded, and how their capabilities differ from skills.
   - Key files: `tools/AgentTool/loadAgentsDir.ts`, `tools/AgentTool/runAgent.ts`
   - Question: Can agent definitions specify skills? (Yes -- `skills` field.) Do agent-specified skills get their prompts injected automatically?

3. **Plugin System** (depends on 1, 2) -- Understand plugin lifecycle, manifest structure, and what extension points plugins get.
   - Key files: `utils/plugins/loadPluginCommands.ts`, `utils/plugins/loadPluginAgents.ts`, `plugins/builtinPlugins.ts`
   - Question: Can plugins register MCP servers? What hooks are available?

4. **Tool Registration** (depends on 1, 2, 3) -- Understand how tools are registered, how buildTool() works, and what ToolUseContext provides.
   - Key files: `tools.ts`, `Tool.ts`, `services/tools/toolOrchestration.ts`
   - Question: What's the actual overhead of BashTool vs a native tool? Can tools be dynamically registered without modifying tools.ts?

5. **Coordinator Mode** (depends on all above) -- Understand multi-agent orchestration, message passing, and task management.
   - Key files: `coordinator/coordinatorMode.ts`, `tasks/LocalAgentTask/LocalAgentTask.ts`
   - Question: Is coordinator mode the right model for GSD's orchestration, or is sequential sub-agent spawning sufficient?

6. **State Management** (cross-cutting, analyze last) -- Understand how AppState works, what can be persisted, and where workflow state should live.
   - Key files: `state/AppStateStore.ts`, `utils/sessionStorage.ts`, `memdir/`
   - Question: Can workflow state survive session boundaries? Is memdir the right persistence mechanism?

## Anti-Patterns to Avoid

### Anti-Pattern 1: Monolithic Prompt Injection
**What:** Single large skill prompt containing all GSD orchestration logic
**Why bad:** Consumes context on every turn, cannot be compacted, scales linearly with feature additions
**Instead:** Decompose into focused skills with `context: 'fork'`, use agent definitions for role specification

### Anti-Pattern 2: State via BashTool
**What:** Running `gsd-tools.cjs` via BashTool for every state read/write
**Why bad:** Each invocation is a subprocess spawn (~200ms), model must parse text output, no schema validation
**Instead:** MCP resource server (Layer 3) or native tool (Layer 4) for typed state access

### Anti-Pattern 3: Agent Definition in Prompts
**What:** Embedding agent role descriptions (researcher prompt, executor prompt) inside skill markdown
**Why bad:** Duplicates content across skills, cannot be shared, no schema validation of agent capabilities
**Instead:** `.claude/agents/*.md` files with frontmatter defining tools, model, permissions, skills

### Anti-Pattern 4: Forking Claude Code for Extension
**What:** Maintaining a fork of Claude Code with GSD modifications in core files
**Why bad:** Monthly update cadence means constant merge conflicts, deep coupling to internal APIs
**Instead:** Use plugin system (Layer 3) which provides a stable extension API designed for third-party use

### Anti-Pattern 5: Shared Mutable State Between Agents
**What:** Multiple GSD agents writing to the same files simultaneously
**Why bad:** Race conditions, lost updates, inconsistent state
**Instead:** Use `isolation: 'worktree'` for parallel agents, or serialize through a state management tool/MCP server

## Scalability Considerations

| Concern | Single Agent | 3 Parallel Agents | 10+ Agents |
|---------|-------------|-------------------|------------|
| Context overhead | Fork mode sufficient | Fork mode essential | Fork + agent defs essential |
| State management | BashTool acceptable | MCP server preferred | Native tool required |
| Token cost | Moderate | 3x base (unavoidable) | Need model selection per agent |
| Latency | Low | Medium (parallel) | Need background mode |
| Git conflicts | N/A | Use worktrees | Worktrees + merge strategy |

## Key Metrics for Integration Decision

To decide which integration depth is worthwhile, measure:

1. **Token overhead per GSD command:** How many tokens does the orchestration prompt consume? (Measure via `cost-tracker.ts`)
2. **Agent startup latency:** Time from AgentTool invocation to first model response (measure via `LocalAgentTask` progress events)
3. **State access overhead:** Time for BashTool -> gsd-tools.cjs round-trip vs MCP resource read vs native tool call
4. **Context pollution:** How much of the main conversation's context window is consumed by GSD prompts after N interactions?

## Sources

- Direct codebase analysis of Claude Code internals (read-only, 2026-03-31)
- `tools.ts` -- Tool registry architecture (lines 193-300)
- `commands.ts` -- Command registry and loading (lines 258-517)
- `skills/loadSkillsDir.ts` -- Skills loading and frontmatter parsing
- `skills/bundledSkills.ts` -- Bundled skill registration pattern
- `Tool.ts` -- ToolUseContext definition (lines 158-300)
- `types/command.ts` -- Command type system (lines 25-217)
- `tools/AgentTool/loadAgentsDir.ts` -- Agent definition schema (lines 73-99)
- `tools/AgentTool/AgentTool.tsx` -- Agent spawning with isolation modes
- `tools/AgentTool/runAgent.ts` -- Agent query loop execution
- `coordinator/coordinatorMode.ts` -- Multi-agent orchestration
- `utils/forkedAgent.ts` -- Subagent context creation
- `utils/claudemd.ts` -- CLAUDE.md context injection chain
- `context.ts` -- System and user context building
- `state/AppStateStore.ts` -- AppState definition
- `utils/plugins/loadPluginCommands.ts` -- Plugin command/skill loading

---

*Architecture analysis: 2026-03-31*
