---
name: gsd:legion-test
description: Acceptance-Test eines Legion-Workers gegen heutige Sonnet-Baseline (Default 50 Test-Samples). Liefert Genauigkeits-Vergleich + Cost-Differenz + Latenz-Vergleich.
argument-hint: "<komponente> [--samples=N] [--baseline=feature_name]"
allowed-tools:
  - Read
  - Bash
  - Task
---
<objective>
Fuehrt einen Acceptance-Test fuer einen Legion-Pilot-Worker aus:

1. Laed N Test-Samples (Default 50) — entweder aus Test-Fixtures oder aus
   Production-Snapshots (Mails, Tasks, Plan-Inputs).
2. Fuehrt sowohl den neuen Legion-Worker als auch die heutige Baseline aus.
3. Vergleicht Outputs — Genauigkeit (Match-Rate), Cost (Token x Modell-Preis),
   Latenz (ms pro Sample).
4. Stop-Loss-Check: bei <95% Genauigkeit oder >200% Cost werden Warnung
   und Abbruch-Empfehlung ausgegeben.
</objective>

<execution_context>
@${CLAUDE_PLUGIN_ROOT}/workflows/legion-test.md
@${CLAUDE_PLUGIN_ROOT}/references/aligned-brand-voice.md
</execution_context>

<context>
**Argumente:**
- `<komponente>` (Pflicht) — K6, K7, K8, K10, K1 oder K4
- `--samples=N` (optional, Default 50)
- `--baseline=feature_name` (optional, Default abgeleitet aus Komponente —
  z.B. K6 → `mail_scanner_classify`)

**Test-Sample-Quellen pro Komponente:**
- K6/K7 (Mail-Klassifikation): letzte 50 Mails aus Gmail mit Label
  `claude-rated` als Ground-Truth
- K8 (Telegram-Intent): hardcoded 50 Test-Strings im Sample-File
  `tests/fixtures/legion/intent-samples.json`
- K10 (Reply-Draft): letzte 20 angenommene Drafts aus
  `pc_customer_emails` (direction='out')
- K1 (Briefing): 7 Briefings (vergangene Woche) als JSON-Snapshot
- K4 (Day-Architect): 14 vergangene Plaene als Snapshot
</context>

<process>
Execute the legion-test workflow from @${CLAUDE_PLUGIN_ROOT}/workflows/legion-test.md end-to-end.
Bei Stop-Loss-Verletzung: klare Empfehlung Worker zu pausieren
(`pc_settings.legion_<role>_enabled = false`).
</process>
