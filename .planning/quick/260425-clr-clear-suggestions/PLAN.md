---
slug: 260425-clr-clear-suggestions
type: quick
created: 2026-04-25
status: in-progress
---

# Quick: Resurface `/clear` suggestions at end-of-flow boundaries

## Problem

The plugin has a rich `references/continuation-format.md` template (continuation blocks with `/clear` then [next-command] format), but **no skill currently `@`-includes it or otherwise references it** — verified via `grep -rln "continuation-format"` returning empty.

Only `agents/gsd-planner.md` line 1175 emits a `/clear` suggestion directly. Every other end-of-flow skill (execute-phase, complete-milestone, verify-work, quick, plan-phase, ship, next, explore) silently completes without the format.

User reports the perception is correct: `/clear` suggestions feel rare or absent in current output.

## Fix

Add an `<output_format>` block to each end-of-flow skill instructing the workflow to emit a continuation-format block (with `/clear`-then-X) when reporting completion. Plus a one-line "/clear is safe — resume-work restores position" note since v1.1's session-continuity work made the cost of an unintended `/clear` near-zero.

## Targets (6 skills)

Highest-value end-of-flow boundaries where `/clear` saves real tokens:

1. `skills/execute-phase/SKILL.md` — phase completion (highest-volume context accumulation)
2. `skills/complete-milestone/SKILL.md` — milestone shipped (already verbose terminal; ensures `/clear` note appears)
3. `skills/verify-work/SKILL.md` — verification done (pass or fail both warrant fresh-context next step)
4. `skills/quick/SKILL.md` — quick task done (long quick tasks benefit; short ones don't, but the suggestion is cheap)
5. `skills/plan-phase/SKILL.md` — plan written, before execute (planning chatter rarely informs execution)
6. `skills/ship/SKILL.md` — PR created (clean transition before next milestone)

Skills NOT touched (intentional):
- `next`, `do`, `explore`, `discuss-phase` — these route to other skills (the routed-to skill emits the `/clear` hint at its terminal)
- `new-project`, `new-milestone` — these START fresh contexts; `/clear` after kickoff would discard the just-loaded project bootstrap
- Mid-flow skills (research-phase, list-phase-assumptions, etc.) — completion isn't a phase boundary

## Approach per skill

Add a new `<output_format>` block after the existing `<process>` block (before `<critical_rules>` where present):

```xml
<output_format>
When this workflow completes, emit a Next Up continuation block following the pattern in `references/continuation-format.md`:

- Show completion status (e.g., `## ✓ Phase N Complete`, `## 🎉 Milestone v1.x Complete`)
- Emit a `## ▶ Next Up` heading with the next likely command
- Use **`` `/clear` then: ``** before the command
- Include a parenthetical: *(`/clear` is safe — `/gsd:resume-work` restores position from `HANDOFF.json` if you change your mind)*
- Add an "Also available:" section with 1-3 alternatives where relevant

Phase / plan / milestone boundaries are the highest-value places to clear context. The accumulated conversation rarely informs the next boundary, and `/clear` resets the prompt cache cleanly. Always suggest it on completion.
</output_format>
```

## Also update

`references/continuation-format.md` — add a footer note documenting the v1.1 session-continuity safety net so the "/clear is safe" parenthetical has a single source of truth.

## Out of scope

- Context-pressure-aware prompts (option B from the analysis) — needs a token-budget heuristic; v1.3-shaped.
- Modifying `next`, `do`, `explore`, `discuss-phase` (intentional — they route, don't terminate).
- Modifying `new-project`, `new-milestone` (intentional — fresh-context skills, `/clear` would defeat the kickoff).

## Verification

- After commit: each of the 6 target SKILL.md files contains an `<output_format>` block referencing `references/continuation-format.md` and the "/clear is safe" parenthetical.
- `references/continuation-format.md` has the new footer note.
- `node bin/maintenance/check-drift.cjs` umbrella stays green (no new dangling refs introduced; we point at `references/continuation-format.md` which exists in the plugin).
