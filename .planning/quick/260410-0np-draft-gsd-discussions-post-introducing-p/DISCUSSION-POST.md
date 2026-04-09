# Sharing claude-code-gsd: a Claude Code plugin packaging of GSD — would upstream integration be useful?

Hi all — first, thanks to Lex (TACHES) for GSD. I've been using it daily inside Claude Code and started poking at whether the per-turn overhead could come down without breaking anything. What I ended up with is a Claude Code-specific plugin packaging built on GSD 1.32.0 that uses Claude Code's public extension points to cut per-turn token cost and agent spawn latency. Tom suggested I post here first to see whether this resonates before I write it up as a Feature Request — so this is a discussion, not a pitch.

## Why I built it

- Running GSD inside Claude Code was paying the full `CLAUDE.md` block as per-turn token overhead on every turn. Long sessions added up fast.
- I looked at forking Claude Code to optimize the integration. Research came back at roughly 8-16+ hours/month for a solo dev, plus a security surface I didn't want to own. Not sustainable.
- Whatever I built had to be additive. GSD's multi-CLI compatibility is a core property, and I didn't want to do anything that made upstream GSD harder to use outside Claude Code.
- I found six integration seams in Claude Code's public extension points — enough to do most of what a fork would do, without touching source.

## What it does

- Single-step install: `claude plugin install gsd`
- Bundles 60 skills, 21 agents, an MCP server, and hooks into one plugin
- `CLAUDE.md` reduced from ~2,338 words to ~174 words (~92% reduction) — the rest loads on demand via skills, so sessions that don't need a given piece of context don't pay for it
- The MCP server exposes project state as 6 queryable MCP resources and 10 workflow mutation tools, replacing a lot of prompt-injected context with structured tool calls
- Phase outcomes and key decisions persist via Claude Code's memdir and are auto-recalled across sessions

## What it is NOT

- **Not a fork** of Claude Code or of GSD. It sits on top of GSD 1.32.0 and uses Claude Code's public extension points only — no source modification, no upstream coupling.
- **Not a replacement** for GSD's multi-CLI support. Upstream GSD still works everywhere it did before; this is purely a Claude Code-specific packaging on top.
- **Not a feature request** yet. Per Tom's guidance, I'm posting here first to gauge community interest.

## The open question

Would something like this be useful upstream? Specifically:

- Does "Claude Code-specific optimized packaging" feel like it belongs in GSD core (perhaps as an optional install target), or is it better off as a separate downstream project?
- If it did belong upstream, which parts feel most valuable — the token reduction via skills, the MCP state surface, or the memdir persistence?
- Is there appetite for similar optimized packagings for other AI CLIs over time, or would that fragment things more than it helps?

Happy to share implementation details, the six integration seams, measurement notes, or walk through the repo if there's interest. Mostly I want to know whether this is a conversation worth having upstream, or whether it's better kept as a downstream plugin people can grab if they want it.

## Links

- [claude-code-gsd on GitHub](https://github.com/jnuyens/gsd-plugin) <!-- confirm this URL before posting -->
- Based on [GSD 1.32.0](https://github.com/gsd-build/get-shit-done) by Lex Christopherson (TACHES).

Thanks for reading — curious what people think.
