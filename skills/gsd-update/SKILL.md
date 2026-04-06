---
name: gsd-update
description: "DEPRECATED -- Plugin-managed updates replace this command"
allowed-tools:
  - Bash
  - AskUserQuestion
---

<objective>
This command is deprecated. GSD is now distributed as a Claude Code plugin and updates are managed automatically by the plugin system.

## What replaced /gsd:update

- **Plugin-managed updates** replace the npm-based update flow
- **`claude plugin install gsd`** is the single install and update command
- **`get-shit-done-cc`** npm package is no longer the distribution path

## How to update GSD

Run:
```
claude plugin install gsd
```

Claude Code's plugin system handles versioning, caching, and updates automatically.

## Migration from legacy install

If you still have a legacy `~/.claude/get-shit-done/` installation:

1. Install the plugin: `claude plugin install gsd`
2. Remove the legacy directory: `rm -rf ~/.claude/get-shit-done/`
3. Remove GSD entries from `~/.claude/settings.json` (hook entries pointing at old scripts)
4. Remove GSD entries from project `.mcp.json` files

See `README.md` for full migration guidance.
</objective>

<success_criteria>
- [ ] User informed that /gsd:update is deprecated
- [ ] User directed to `claude plugin install gsd`
- [ ] Legacy paths documented for cleanup
</success_criteria>
