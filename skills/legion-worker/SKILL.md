---
name: gsd:legion-worker
description: Bootstrappt einen neuen Legion-Worker — generiert lib/legion/workers/<role>.ts, Test-Skeleton, pc_settings-Toggle-Migration.
argument-hint: "<role>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---
<objective>
Erzeugt die drei Standard-Files fuer einen neuen Legion-Worker:

1. `lib/legion/workers/<role>.ts` — Worker-Implementierung mit
   callAnthropic-Aufruf, Pattern-Lookup-First, Modell-Routing.
2. `tests/legion/workers/<role>.test.ts` — Acceptance-Test-Skeleton mit
   Sample-Loader.
3. `supabase/migrations/<datum>_legion_<role>_toggle.sql` —
   pc_settings-Toggle-Eintrag (Default `true`).

**Worker-Pattern** (aus 04b_gsd_integration.md §6 GSD-Pattern-Pinning):
- Fresh Anthropic-Session pro Run
- Wave-based Parallelization wenn Multi-Sample
- Size-limited Output (Soft-Limit 500 Lines im result-JSONB)
- Modell aus `legion_workers.model`-Spalte oder default per Worker-Role
</objective>

<execution_context>
@${CLAUDE_PLUGIN_ROOT}/workflows/legion-worker.md
@${CLAUDE_PLUGIN_ROOT}/references/aligned-brand-voice.md
</execution_context>

<context>
**Argument:** `<role>` — snake_case Worker-Role-Name (z.B. `mail_classifier`,
`spam_classifier`, `intent_router`, `reply_drafter`).

**Worker-Typ-Klassifikation** (steuert Default-Modell):
- `*_classifier`, `*_router` → Haiku (schnell, billig, deterministisch)
- `*_synthesizer`, `*_drafter` → Sonnet (Brand-Voice-Tiefe)
- `*_queen`, `*_orchestrator` → Sonnet oder Opus (komplex)
</context>

<process>
Execute the legion-worker workflow from @${CLAUDE_PLUGIN_ROOT}/workflows/legion-worker.md end-to-end.
Verifiziert dass `lib/legion/anthropic.ts` und `lib/legion/embedding.ts`
existieren — sonst Hinweis dass AP1 erst durch sein muss.
</process>
