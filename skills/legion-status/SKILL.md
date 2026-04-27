---
name: gsd:legion-status
description: Stand der Legion-Implementierung gegen .ruflo/aligned/02_mapping.md anzeigen — welche K-Komponenten wo (gewrapt / replaced / BLOCKED bis A5).
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---
<objective>
Liefert eine kompakte Status-Tabelle der 24 Legion-Komponenten K1-K24 aus
`.ruflo/aligned/02_mapping.md` und pruegt sie gegen den aktuellen Code- und
DB-Stand des konsumierenden Repos (`aligned-productivity-cloud`).

Pro Komponente: Markierung aus 02_mapping.md (replace/wrap/synergy/keep),
ob ein zugehoeriger Worker existiert (`lib/legion/workers/<role>.ts`), und
ob der `pc_settings`-Toggle aktiv ist (`legion_<role>_enabled`).
</objective>

<execution_context>
@${CLAUDE_PLUGIN_ROOT}/workflows/legion-status.md
@${CLAUDE_PLUGIN_ROOT}/references/aligned-brand-voice.md
</execution_context>

<context>
**Voraussetzungen:**
- Git-Repo `aligned-productivity-cloud` ist Working-Directory oder erreichbar
- `.ruflo/aligned/02_mapping.md` existiert
- `lib/legion/workers/` ggf. noch leer (in dem Fall: alle als "nicht implementiert")

**Output-Format:** Tabelle in deutscher Sprache, Brand-Voice-konform
(Sie-Form bei externer Kommunikation, kurze aktive Saetze, keine Berater-
Phrasen). Maximal 1 Zeile pro Komponente.
</context>

<process>
Execute the legion-status workflow from @${CLAUDE_PLUGIN_ROOT}/workflows/legion-status.md end-to-end.
Preserve A5-Markierungen — BLOCKED-Komponenten (K15/K22/K23/K24) muessen
sichtbar als blockiert ausgewiesen werden.
</process>
