# Workflow: legion-test

Acceptance-Test eines Legion-Workers gegen heutige Baseline.

## Schritte

### 1. Argumente parsen
- `<komponente>` (Pflicht): K6, K7, K8, K10, K1, K4
- `--samples=N` (Default 50)
- `--baseline=feature_name` (Default aus Komponente abgeleitet)

### 2. Worker-Existenz-Check
Pruefen ob `lib/legion/workers/<role>.ts` existiert. Wenn nicht:
"Worker fuer <komponente> existiert noch nicht. Erst /gsd:legion-worker
ausfuehren oder /gsd:legion-pilot fuer vollen Plan."

### 3. Test-Samples laden
Je nach Komponente:
- **K6/K7:** Gmail-Query via `lib/gmail.ts` — letzte 50 Mails mit Label
  `claude-rated`. Header inkl. Sender, Subject. Body anonymisiert (200 Zeichen).
  Ground-Truth = bestehender `claude-rated`-Score (1-5).
- **K8:** Read `tests/fixtures/legion/intent-samples.json`. Format:
  `[{"input": "...", "expected_intent": "task_add"}, ...]`. Wenn File nicht
  existiert: anlegen mit 10 Beispielen + Hinweis "bitte ergaenzen, dann erneut
  testen".
- **K10:** Supabase-Query auf `pc_customer_emails WHERE direction='out' AND
  imported_at > now() - interval '90 days' LIMIT 20`.
- **K1:** Read `.planning/legion-test-samples/briefings-7d.json` (manuell
  erstellt aus letzten 7 Tagen).
- **K4:** Read `.planning/legion-test-samples/day-plans-14d.json`.

### 4. Baseline-Output erzeugen
Fuehre die heutige Funktion auf alle Samples aus:
- K6 → `rateMail()` aus `app/api/mail-scanner/route.ts`
- K7 → `classifySpamCandidate()` aus `lib/spam-filter.ts`
- K8 → `classifyIntent()` aus `lib/agent.ts`
- K10 → `generateReply()` aus `lib/agent.ts`
- K1 → `generateBriefing()` aus `lib/agent.ts`
- K4 → `generatePlan()` aus `lib/day-architect.ts`

Pro Sample: Output speichern, Token-Verbrauch aus `pc_api_usage`-Snapshot
zur Baseline-Run-Zeit lesen.

### 5. Worker-Output erzeugen
Fuehre `lib/legion/workers/<role>.ts` auf identische Samples aus.
Token-Verbrauch + Latenz pro Sample tracken.

### 6. Vergleichs-Metrik berechnen
- **Genauigkeits-Score:** Anteil Matches gegen Baseline (bei
  Klassifikationen: identische Score/Category; bei Drafts: heuristisch
  via Embedding-Cosine >=0.85)
- **Cost-Differenz:** `(worker_cost - baseline_cost) / baseline_cost * 100`
- **Latenz-Vergleich:** Median + p95 der Worker- vs. Baseline-Durations

### 7. Stop-Loss-Pruefung
- Genauigkeit <95% → Warnung "Stop-Loss-Schwelle gerissen. Worker NICHT
  produktiv setzen."
- Cost >200% Baseline ohne Funktionszuwachs → Warnung "Cost-Stop-Loss
  gerissen. Modell-Routing pruefen."
- Latenz p95 >2x Baseline → Hinweis (kein hartes Stop-Loss)

### 8. Output-Report rendern
Deutsch, kompakt:

```
LEGION-TEST — <komponente> — <ISO-Datum>

Samples: N
Genauigkeit: X% (Stop-Loss: 95%)        [OK / WARNUNG]
Cost vs. Baseline: -Y% (Stop-Loss: +200%)  [OK / WARNUNG]
Latenz median: A ms (Baseline: B ms)
Latenz p95: C ms (Baseline: D ms)

Empfehlung:
- [OK]      Worker kann produktiv gesetzt werden. pc_settings.legion_<role>_enabled = true.
- [WARNUNG] Worker NICHT produktiv setzen. <Begruendung>. Vorschlag: <Massnahme>.
```

### 9. Persistenz (optional)
Wenn `--save`-Flag: Test-Resultat als Row in eigener Tabelle
`legion_test_runs` (muss separat per Migration angelegt werden).
Default: nur Console-Output.

## Konstraints

- KEINE produktive Aenderung — Worker-Toggle wird NICHT automatisch
  gesetzt, nur Empfehlung im Output.
- Test-Samples muessen reproduzierbar sein (Snapshot-Files unter
  `.planning/legion-test-samples/` ablegen wenn von Production geladen).
- Cost-Vergleich nutzt aktuelle Modell-Preistabelle aus
  `lib/usage-tracking.ts`.
- Output deutsch, ohne Berater-Phrasen, mit klaren OK/WARNUNG-Markierungen.
