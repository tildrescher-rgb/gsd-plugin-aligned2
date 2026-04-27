# Workflow: legion-pilot

Erzeugt eine GSD-Phase fuer eine Legion-Pilot-Komponente.

## Schritte

### 1. Argument validieren
Lies `<komponente>` aus den Args. Erlaubte Werte: K1, K4, K6, K7, K8, K10.

**A5-BLOCKED rejection** (sofortiges Abbrechen mit Hinweis):
- K15 → "Coach-Webhook ist A5-blockiert. Coach + Chef muss zuerst stabilisiert sein."
- K22 → "Coach Phase-Import ist A5-blockiert."
- K23 → "Coach Workout-Materialization ist A5-blockiert."
- K24 → "Memory-Artifact Read/Write ist A5-blockiert."

**Andere K-Nummern** → "Komponente <X> ist kein Pilot-Kandidat. Siehe
.ruflo/aligned/02_mapping.md §3 fuer Markierung und Reihenfolge."

### 2. Komponenten-Context laden
Lies aus `.ruflo/aligned/02_mapping.md`:
- Zeile fuer `<komponente>` aus der Mapping-Tabelle (Komponenten-Name, heutige
  Implementierung, Ruflo-Capability, Erwartete Verbesserung, Risiko, Markierung)

Lies aus `.ruflo/aligned/04_synergies.md`:
- Zugehoerige Synergie (S1-S7), die durch diese Komponente erschlossen wird
- 30-Tage-Metrik-Ziel
- Stop-Loss-Kriterium

Lies aus `.ruflo/aligned/05_plan.md`:
- Atomares Arbeitspaket aus Track C (AP13-AP18)
- Test-Definition + Rollback-Mechanismus

### 3. Code-Recherche
Glob + Grep im Working-Repo nach:
- Heutiger Implementierung der Komponente (z.B. `lib/spam-filter.ts` fuer K7,
  `lib/agent.ts:classifyIntent` fuer K8)
- Bestehender Test-Files
- Aufruf-Sites der heutigen Funktion

### 4. CONTEXT.md schreiben
Pfad: `.planning/phases/legion-pilot-<slug>/CONTEXT.md`

Inhalt (deutsch, Brand-Voice-konform):
- Welche Komponente, welcher Worker-Role-Name
- Heutige Implementierung (Datei + Funktion)
- Ziel-Architektur (Worker mit `callAnthropic`, Pattern-Lookup-First, Modell-Routing)
- Acceptance-Kriterien aus 04_synergies.md
- Stop-Loss-Schwelle
- Rollback-Pfad (`pc_settings.legion_<role>_enabled = false`)

### 5. RESEARCH.md schreiben
Pfad: `.planning/phases/legion-pilot-<slug>/RESEARCH.md`

Inhalt:
- Heutiger Code-Pfad (Aufruf-Sites, Datenfluss, Cost-Snapshot)
- Pattern-Library-Bedarf (welche `legion_pattern.pattern_type` braucht der Worker)
- Embedding-Bedarf (ja/nein, fuer welchen Subject-Typ)
- Test-Sample-Quelle (Mail-Snapshots, Inbox-Mails, Test-Fixtures)

### 6. 1-PLAN.md schreiben
Pfad: `.planning/phases/legion-pilot-<slug>/1-PLAN.md`

XML-Tasks im GSD-Format:
```xml
<task type="auto">
  <name>Worker-Skeleton anlegen</name>
  <files>lib/legion/workers/<role>.ts (neu)</files>
  <action>callAnthropic-basierter Worker mit Pattern-Lookup-First, Modell aus model-profile</action>
  <verify>tsc --noEmit + Worker-Run gegen 1 Test-Sample</verify>
  <done>Worker-File existiert, Test-Run liefert valide JSON-Klassifikation</done>
</task>

<task type="auto">
  <name>pc_settings-Toggle eintragen</name>
  <files>supabase/migrations/<datum>_legion_<role>_toggle.sql (neu)</files>
  <action>INSERT INTO pc_settings (key, value, category) VALUES ('legion_<role>_enabled', 'true', 'legion_workflow')</action>
  <verify>SELECT-Query liefert die Row</verify>
  <done>Toggle ist DB-seitig vorhanden</done>
</task>

<task type="auto">
  <name>Test-Suite anlegen</name>
  <files>tests/legion/workers/<role>.test.ts (neu)</files>
  <action>50-Sample-Vergleichstest gegen heutige Sonnet-Baseline</action>
  <verify>npm test passes mit >=95% Genauigkeit</verify>
  <done>Test-Run liefert Genauigkeit + Cost-Differenz</done>
</task>

<task type="auto">
  <name>Cron/Webhook-Integration mit Toggle-Check</name>
  <files>app/api/.../route.ts (anpassen)</files>
  <action>If toggle on: Worker statt heutige Funktion; sonst Fallback</action>
  <verify>Cron-Run mit Toggle on + off funktioniert</verify>
  <done>Beide Pfade laufen ohne Fehler</done>
</task>
```

### 7. UAT.md schreiben
Pfad: `.planning/phases/legion-pilot-<slug>/UAT.md`

User-Acceptance-Punkte:
- [ ] Worker liefert valide Klassifikation auf 50 Test-Samples
- [ ] Genauigkeit >=95% vs. heutige Sonnet-Baseline
- [ ] Cost-Reduktion sichtbar in `pc_api_usage` (gegen Vergleichswoche)
- [ ] Toggle-Off rollt sauber zurueck (heutige Funktion uebernimmt)
- [ ] Telegram-Push bei Worker-Fehler funktioniert (Stop-Loss)

### 8. Output an User
Strukturierte Zusammenfassung in deutscher Sprache:
- Welche Komponente jetzt geplant
- Welche 4 Tasks erzeugt wurden
- Naechster Schritt: `/gsd:execute-phase legion-pilot-<slug>` oder `/gsd:legion-test <komponente>` nach Implementierung

## Konstraints

- A5-Block strikt durchsetzen — keine Datei wird geschrieben bei rejected
  Komponenten.
- Alle Outputs deutsch, Brand-Voice-konform.
- Test-Sample-Anzahl: Default 50 (in UAT-Doku referenzieren).
- Modell-Routing: Klassifikations-Worker auf Haiku, Synthese-Worker (K1, K4)
  auf Sonnet (Pinning aus 02_mapping.md §5).
