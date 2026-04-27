# Workflow: legion-status

Zeigt den Implementierungs-Stand der Legion-Komponenten gegen den Plan in
`.ruflo/aligned/02_mapping.md`.

## Schritte

### 1. Mapping-Tabelle laden
Lies `.ruflo/aligned/02_mapping.md` §3 (Mapping-Tabelle K1-K24) und §4.5
(Bestaetigte Defaults). Extrahiere pro Komponente:
- ID (K1-K24)
- Komponenten-Name
- Markierung (`replace-by-ruflo` / `wrap-with-ruflo` / `synergy-only` / `keep-as-is`)
- A5-Block-Status (`BLOCKED bis A5` ja/nein)

### 2. Worker-Existenz pruefen
Glob `lib/legion/workers/*.ts` im Working-Repo. Pro Worker-Datei: Name
extrahieren (Dateiname ohne Extension = `role`), gegen Mapping abgleichen.

### 3. pc_settings-Toggles abrufen
Falls Supabase-MCP verfuegbar: `SELECT key, value FROM pc_settings WHERE
key LIKE 'legion_%_enabled'`. Sonst: Hinweis "Toggles nicht abrufbar — bitte
Supabase MCP konfigurieren".

### 4. Cost-Snapshot (optional)
Falls Supabase-MCP verfuegbar: aktuelle 7-Tage-Cost-Summe pro Feature aus
`pc_api_usage`, gruppiert nach `feature LIKE 'legion_%'`.

### 5. Output-Tabelle rendern
Format (deutsch, Brand-Voice-konform):

```
LEGION-STATUS — <ISO-Datum>

| #   | Komponente                  | Markierung                       | Worker | Toggle | Status     |
|-----|-----------------------------|----------------------------------|--------|--------|------------|
| K1  | Daily Briefing              | replace-by-ruflo                 | nein   | aus    | offen      |
| K6  | Mail-Classifier             | replace-by-ruflo                 | ja     | an     | aktiv      |
| K22 | Coach Phase-Import          | wrap-with-ruflo (BLOCKED bis A5) | nein   | -      | A5-blocked |
...
```

Spalten:
- **#**: K-Nummer
- **Komponente**: Kurzname aus 02_mapping.md
- **Markierung**: aus Mapping-Tabelle, mit BLOCKED-Suffix wenn A5-relevant
- **Worker**: ja/nein (Datei existiert?)
- **Toggle**: an/aus/- (- bei BLOCKED)
- **Status**: aktiv / offen / pausiert / A5-blocked

Am Ende: Aggregat-Zeile "X von 24 aktiv, Y offen, Z A5-blocked, W keep-as-is".

### 6. Stop-Loss-Hinweis
Falls Cost-Snapshot abrufbar war: kompakte Liste der Top-5-Cost-Features +
Hinweis ob >200% Baseline (Stop-Loss-Trigger laut 04_synergies.md §4).

## Konstraints

- KEIN Schreiben in Repo oder DB — read-only.
- Kein LLM-Call — rein deterministisch.
- A5-Blocked-Komponenten klar markieren (K15, K22, K23, K24).
- Output deutsch, ohne Berater-Phrasen.
