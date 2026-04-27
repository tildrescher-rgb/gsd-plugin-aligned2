---
name: gsd:legion-migration
description: Erzeugt + validiert eine Supabase-Migration mit Schema-Check gegen pgvector und bestehende pc_*/coach_*/chef_*/legion_*-Tabellen.
argument-hint: "<migration-name>"
allowed-tools:
  - Read
  - Write
  - Bash
---
<objective>
Erzeugt eine Supabase-Migrations-Datei mit:
- Korrektem Datums-Slug-Format `YYYYMMDD_<name>.sql`
- Idempotentem SQL (CREATE TABLE IF NOT EXISTS / ON CONFLICT)
- Schema-Validierung gegen Naming-Konflikte mit existierenden Tabellen
- pgvector-Aktivierung-Check, falls embedding-Spalten verwendet werden

**Apply** der Migration NICHT ueber dieses Skill — sondern via Supabase
MCP `mcp__supabase__apply_migration`. Skill schreibt nur das File.
</objective>

<execution_context>
@${CLAUDE_PLUGIN_ROOT}/workflows/legion-migration.md
@${CLAUDE_PLUGIN_ROOT}/references/aligned-brand-voice.md
</execution_context>

<context>
**Argument:** `<migration-name>` — snake_case, beschreibt was die Migration macht
(z.B. `legion_pattern_decay_function`, `legion_outbox_priority_index`).

**Naming-Konflikt-Check:** Migration darf KEINE Tabellen-Namen verwenden,
die bereits existieren in den Schemas:
- `pc_*` (Productivity-Cloud)
- `coach_*` (Coach-Bot)
- `chef_*` (Chef-Bot)
- `legion_*` (Hive-Mind)
- `v2_*`, `import_*`, `warenstamm_*` (andere Restaurant-Stack-Tabellen,
  Domain-Trennung beachten)
</context>

<process>
Execute the legion-migration workflow from @${CLAUDE_PLUGIN_ROOT}/workflows/legion-migration.md end-to-end.
</process>
