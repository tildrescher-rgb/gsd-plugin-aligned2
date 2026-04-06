# GSD -- Get Shit Done for Claude Code

A structured workflow plugin for Claude Code that adds planning, execution, and verification commands with MCP-backed project state.

## Installation

```bash
claude plugin install gsd
```

That single command installs everything: slash commands, agent definitions, hooks, and an MCP server for project state. No manual configuration required.

## What GSD provides

- **60 slash commands** (`/gsd:*`) for project planning, execution, debugging, and verification
- **21 agent definitions** for specialized workflow roles (planner, executor, researcher, verifier, etc.)
- **MCP server** exposing project state as queryable resources and mutation tools
- **Hooks** for session-start context loading, workflow enforcement, and tool-use monitoring
- **Templates and references** for planning artifacts, summaries, and verification checklists

## Quick start

1. Install: `claude plugin install gsd`
2. Start a new project: `/gsd:new`
3. Plan your first phase: `/gsd:plan-phase`
4. Execute: `/gsd:execute-phase`
5. Verify: `/gsd:verify-work`

## Updating

Updates are managed automatically by Claude Code's plugin system. To manually trigger an update:

```bash
claude plugin install gsd
```

## Migrating from legacy install

If you previously installed GSD via `get-shit-done-cc` or manual setup, follow these steps to migrate to the plugin-based install.

### What the plugin replaces

| Legacy component | Plugin replacement |
|---|---|
| `~/.claude/get-shit-done/` directory | Plugin cache at `~/.claude/plugins/cache/` (managed automatically) |
| `get-shit-done-cc` npm package | `claude plugin install gsd` |
| `/gsd:update` command | Plugin-managed updates (command is now deprecated) |
| Manual `.mcp.json` entries pointing at `~/.claude/get-shit-done/mcp/server.cjs` | Plugin manifest declares MCP server automatically |
| Manual `~/.claude/settings.json` hook entries | Plugin-packaged `hooks/hooks.json` auto-loaded by plugin loader |

### Migration steps

#### 1. Install the plugin

```bash
claude plugin install gsd
```

#### 2. Remove legacy `~/.claude/get-shit-done/` directory

The legacy install directory is no longer needed. The plugin bundles all skills, agents, templates, references, and bin tools.

```bash
rm -rf ~/.claude/get-shit-done/
```

#### 3. Remove GSD entries from `.mcp.json`

If your project has a `.mcp.json` file with a GSD MCP server entry pointing at the legacy path, remove it. The plugin manifest now declares the MCP server.

Look for and remove entries like:

```json
{
  "mcpServers": {
    "gsd": {
      "command": "node",
      "args": ["/Users/.../.claude/get-shit-done/mcp/server.cjs"]
    }
  }
}
```

#### 4. Remove GSD hook entries from `~/.claude/settings.json`

If your `~/.claude/settings.json` contains hook entries referencing old GSD scripts (e.g., `gsd-check-update.js`, `gsd-context-monitor.js`, `gsd-prompt-guard.js`, `gsd-statusline.js` from `~/.claude/hooks/`), remove those entries. The plugin provides equivalent hooks via `hooks/hooks.json`.

#### 5. Remove legacy hook scripts

```bash
rm -f ~/.claude/hooks/gsd-check-update.js
rm -f ~/.claude/hooks/gsd-context-monitor.js
rm -f ~/.claude/hooks/gsd-prompt-guard.js
rm -f ~/.claude/hooks/gsd-statusline.js
```

#### 6. Uninstall `get-shit-done-cc` npm package (if installed)

The `get-shit-done-cc` npm package is no longer the distribution path for GSD. If you installed it globally:

```bash
npm uninstall -g get-shit-done-cc
```

#### 7. Stop using `/gsd:update`

The `/gsd:update` command is deprecated. Plugin-managed updates replace it entirely. Use `claude plugin install gsd` to update.

### Automated migration audit

GSD includes a migration helper that audits your system for legacy paths:

```bash
node bin/gsd-tools.cjs migrate
```

This prints all legacy GSD artifacts found on your system. To remove them (with confirmation):

```bash
node bin/gsd-tools.cjs migrate --clean
```

### Verifying migration

After migration, verify the plugin is active:

1. Start a new Claude Code session
2. Run `/gsd:status` -- should show project state
3. Check that MCP resources are available (the GSD MCP server should auto-start)

## License

MIT

## Author

Jasper Nuyens
