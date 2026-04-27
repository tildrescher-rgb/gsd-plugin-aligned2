---
name: gsd:legion-pilot
description: Erzeugt einen GSD-Plan fuer eine Pilot-Komponente (K6/K7/K8/K10/K1/K4) aus .ruflo/aligned/02_mapping.md mit Acceptance-Kriterien aus 04_synergies.md.
argument-hint: "<komponente>"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - Task
  - AskUserQuestion
---
<objective>
Erzeugt eine vollstaendige GSD-Phase fuer die Pilot-Implementierung einer
Legion-Komponente (K6, K7, K8, K10, K1 oder K4) aus dem Mapping-Plan.
Nicht-Pilot-Komponenten (K2/K3/K5/K9/K14/...) und A5-blockierte Komponenten
(K15, K22, K23, K24) werden mit klarer Fehlermeldung zurueckgewiesen.

**Erstellt:**
- `.planning/phases/legion-pilot-<slug>/CONTEXT.md` — Komponenten-Kontext
- `.planning/phases/legion-pilot-<slug>/RESEARCH.md` — heutige Implementierung
- `.planning/phases/legion-pilot-<slug>/1-PLAN.md` — atomare Tasks (XML)
- `.planning/phases/legion-pilot-<slug>/UAT.md` — User-Acceptance-Test
</objective>

<execution_context>
@${CLAUDE_PLUGIN_ROOT}/workflows/legion-pilot.md
@${CLAUDE_PLUGIN_ROOT}/references/aligned-brand-voice.md
@${CLAUDE_PLUGIN_ROOT}/references/planning-config.md
@${CLAUDE_PLUGIN_ROOT}/templates/spec.md
</execution_context>

<context>
**Argument:** `<komponente>` — eine der: K1, K4, K6, K7, K8, K10.

**A5-Whitelist (sofort startbar):** K6, K7, K8, K10, K1, K4 — alle ohne
cowork-memory-Schreibzugriff.

**A5-BLOCKED (rejected):** K15 (Coach-Webhook), K22 (Coach Phase-Import),
K23 (Coach Workout-Materialization), K24 (Memory-Artifact Read/Write).

**Andere K-Nummern:** keine Pilot-Komponenten, rejected mit Hinweis auf
02_mapping.md-Markierung.
</context>

<process>
Execute the legion-pilot workflow from @${CLAUDE_PLUGIN_ROOT}/workflows/legion-pilot.md end-to-end.
Bei A5-Block: Fehler werfen, KEINE Datei schreiben.
Acceptance-Kriterien aus 04_synergies.md §4 (30/60/90-Tage-Metriken).
</process>
