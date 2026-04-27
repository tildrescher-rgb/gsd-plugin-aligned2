# Workflow: legion-worker

Bootstrappt einen neuen Legion-Worker mit Code-Skeleton, Test und Toggle.

## Schritte

### 1. Argument validieren
`<role>` muss snake_case sein, nur a-z + _ + Ziffern. Pruefen mit Regex
`^[a-z][a-z0-9_]*$`. Bei Verstoss: Fehler "Role muss snake_case sein,
z.B. mail_classifier".

### 2. Pruegen ob Voraussetzungen erfuellt sind
- `lib/legion/anthropic.ts` existiert (AP1 durch)
- `lib/legion/brand-voice.ts` existiert
- `lib/legion/embedding.ts` existiert
- Migration `legion_memory_init` ist applied (kann ueber Supabase-MCP `list_migrations` geprueft werden)

Wenn eines fehlt: Abbruch mit "AP1 muss zuerst durch sein. Siehe
.ruflo/aligned/05_plan.md §1 Track A."

### 3. Pruegen ob Worker schon existiert
Glob `lib/legion/workers/<role>.ts`. Wenn ja: Abbruch mit "Worker <role>
existiert bereits. Loesche oder waehle anderen Role-Namen."

### 4. Worker-Typ klassifizieren
Aus `<role>`-Suffix:
- `*_classifier` oder `*_router` → `model_default = "claude-haiku-4-5"`
- `*_synthesizer` oder `*_drafter` → `model_default = "claude-sonnet-4-6"`
- `*_queen` oder `*_orchestrator` → `model_default = "claude-sonnet-4-6"` (Opus optional ueber Override)
- Sonst: `model_default = "claude-sonnet-4-6"`

### 5. Worker-File schreiben
Pfad: `lib/legion/workers/<role>.ts`

Template:
```typescript
/**
 * Legion-Worker: <role>
 *
 * Generiert via /gsd:legion-worker.
 * Ergaenze die Logik in classify() / synthesize() je nach Worker-Typ.
 */
import { callAnthropic, extractToolUse } from "@/lib/legion/anthropic";
import { getSupabase } from "@/lib/supabase";
import { embedText } from "@/lib/legion/embedding";

const WORKER_ROLE = "<role>";
const DEFAULT_MODEL = "<model_default>";
const SYSTEM_PROMPT = `TODO: Brand-Voice-Konstante aus
@${CLAUDE_PLUGIN_ROOT}/references/aligned-brand-voice.md
+ aufgaben-spezifischer Prompt einfuegen.`;

export type <RoleType>Input = {
  // TODO: Input-Schema definieren
};

export type <RoleType>Result = {
  // TODO: Output-Schema definieren
};

/**
 * Pattern-Lookup zuerst — wenn legion_patterns einen Match liefert,
 * KEIN LLM-Call. Bei Pattern-Hit: hit_count incrementen.
 */
async function lookupPattern(
  subject: string
): Promise<<RoleType>Result | null> {
  const sb = getSupabase();
  const { data } = await sb
    .from("legion_patterns")
    .select("*")
    .eq("pattern_type", "<role>")
    .contains("trigger_signature", { subject })
    .gte("confidence", 0.85)
    .order("confidence", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!data) return null;
  // hit_count + last_used_at update (fire-and-forget)
  void sb
    .from("legion_patterns")
    .update({
      hit_count: (data.hit_count as number) + 1,
      last_used_at: new Date().toISOString(),
    })
    .eq("pattern_id", data.pattern_id);
  return data.action_signature as <RoleType>Result;
}

export async function run<RoleType>(
  input: <RoleType>Input
): Promise<<RoleType>Result> {
  // 1. Pattern-Lookup-First
  // const cached = await lookupPattern(input.subject);
  // if (cached) return cached;

  // 2. LLM-Call ueber zentralen Wrapper
  const { content } = await callAnthropic({
    feature: "<feature_name>",
    model: DEFAULT_MODEL,
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: JSON.stringify(input) }],
    max_tokens: 1024,
    // tools: [...] wenn Tool-Use noetig
  });

  // 3. Output-Parsing
  // TODO: extractText oder extractToolUse + Schema-Validation
  throw new Error("<role> noch nicht implementiert");
}
```

Ersetze `<role>`, `<model_default>`, `<RoleType>` (CamelCase), `<feature_name>`
(snake_case fuer pc_api_usage.feature).

### 6. Test-File schreiben
Pfad: `tests/legion/workers/<role>.test.ts`

Template:
```typescript
import { describe, it, expect } from "vitest";
import { run<RoleType> } from "@/lib/legion/workers/<role>";

describe("<role>", () => {
  it("liefert valides Resultat fuer Standard-Input", async () => {
    // TODO: Sample-Input definieren
    // const result = await run<RoleType>({ ... });
    // expect(result).toMatchObject({ ... });
    expect.fail("Test noch nicht implementiert — siehe TODO");
  });

  it("nutzt Pattern-Cache wenn verfuegbar", async () => {
    expect.fail("Pattern-Cache-Test noch nicht implementiert");
  });
});
```

### 7. pc_settings-Toggle-Migration schreiben
Pfad: `supabase/migrations/<heute_iso>_legion_<role>_toggle.sql`

Wo `<heute_iso>` = aktueller Datum YYYYMMDD.

Inhalt:
```sql
INSERT INTO pc_settings (key, value, category, description)
VALUES (
  'legion_<role>_enabled',
  'true'::jsonb,
  'legion_workflow',
  'Toggle fuer Legion-Worker <role>. Bei false: Fallback auf alten Code-Pfad.'
)
ON CONFLICT (key) DO NOTHING;
```

Hinweis im Output: "Migration noch nicht applied. Run via Supabase MCP:
mcp__supabase__apply_migration mit name=legion_<role>_toggle und obigem
Inhalt."

### 8. Output an User
Deutsch, Brand-Voice-konform:
- Welche 3 Files erzeugt
- TODO-Punkte im Worker-File (Input/Output-Schema, Pattern-Subject-Logik,
  Output-Parsing)
- Hinweis: Migration via Supabase-MCP applizieren
- Hinweis: Test ausfuehren mit `npm test tests/legion/workers/<role>.test.ts`

## Konstraints

- KEIN Schreiben in DB direkt — Migration-File-Schreiben ist OK,
  Apply ueber MCP.
- Alle Files deutsche Kommentare wo user-facing.
- Worker-Pattern strikt: callAnthropic-Wrapper, Pattern-Lookup-First, kein
  direkter Anthropic-Client.
- Test-File MUSS expect.fail() haben — kein gruener Fake-Test.
