# Workflow: legion-migration

Erzeugt + validiert eine Supabase-Migrations-Datei.

## Schritte

### 1. Argument validieren
`<migration-name>` snake_case, nur a-z + _ + Ziffern.

### 2. Datum bestimmen
Heutiges Datum als YYYYMMDD (UTC). Migration-Slug = `<datum>_<name>`.
File-Pfad: `supabase/migrations/<slug>.sql`.

Wenn File schon existiert (Duplikat-Tag): Suffix `_2`, `_3` etc.

### 3. Naming-Konflikt-Check
Frage User mit AskUserQuestion: "Welche Tabellen-Operations enthaelt die
Migration?":
- CREATE TABLE — neue Tabelle
- ALTER TABLE — bestehende erweitern
- CREATE INDEX — neuer Index
- INSERT INTO pc_settings — Default-Row
- Function/Trigger — DB-Logik
- Andere

Bei CREATE TABLE: Frage nach Tabellen-Namen. Pruefen gegen Naming-
Konflikt-Liste (siehe SKILL.md Context). Bei Konflikt: Vorschlag
"<name>_v2" oder Abbruch.

### 4. pgvector-Check
Frage: "Verwendet die Migration eine VECTOR-Spalte (Embedding)?"

Wenn ja: am Anfang der Migration Block:
```sql
-- pgvector wird benoetigt fuer VECTOR-Typ
CREATE EXTENSION IF NOT EXISTS vector;
```

### 5. Migration-Skeleton schreiben
Pfad: `supabase/migrations/<slug>.sql`

Template:
```sql
-- Migration: <name>
-- Erzeugt: <heute_iso>
-- Zweck: TODO

BEGIN;

-- pgvector falls noetig
-- CREATE EXTENSION IF NOT EXISTS vector;

-- TODO: SQL-Statements

COMMIT;
```

### 6. Schema-Konsistenz-Hinweis
Wenn neue Tabelle: erinnern an
- `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` (Konvention)
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()` (mit moddatetime-Trigger
  bei Bedarf — Extension `moddatetime` ist verfuegbar)
- Indizes auf Foreign-Key-Spalten + `created_at DESC` fuer Time-Series

### 7. RLS-Hinweis
Erinnerung im Output:
- Service-Role-Key bypasst RLS — fuer Server-Side-only-Tabellen genuegt das.
- Bei User-facing Tabellen: `ENABLE ROW LEVEL SECURITY` + Policies hinzufuegen.

### 8. Output an User
Deutsch:
- File-Pfad der erzeugten Migration
- TODO-Punkte (eigentliche SQL-Logik fehlt noch)
- Naechster Schritt: Migration via MCP applizieren mit
  `mcp__supabase__apply_migration` und name=`<slug>`.

## Konstraints

- KEIN automatisches Apply — User entscheidet wann appliziert wird.
- Naming-Konflikt strikt pruefen — keine Doppel-Namen mit existierenden
  Tabellen.
- Idempotenz erzwingen (IF NOT EXISTS / ON CONFLICT).
- pgvector nur per `CREATE EXTENSION IF NOT EXISTS vector` aktivieren.
