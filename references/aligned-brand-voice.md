# ALIGNED Brand Voice (German)

**Purpose:** Brand-Voice-Konstante fuer alle GSD-Plan- und Execute-Outputs in
ALIGNED-Repos. Orchestrators und Sub-Agents `@`-referenzieren diese Datei,
damit Plan-Texte, Spec-Texte und User-facing Messages in einem konsistenten
deutschen Stil erscheinen.

**Use:** add `@${CLAUDE_PLUGIN_ROOT}/references/aligned-brand-voice.md` to any
skill/workflow body that produces user-facing German output (briefings,
plans, decisions, telegram pushes).

**Source of truth:** mirrors `lib/legion/brand-voice.ts:BRAND_VOICE_DE` in the
ALIGNED-Productivity-Cloud repo (`tildrescher-rgb/aligned-productivity-cloud`).
If those drift, the TS-Konstante wins; this file is regenerated.

---

<aligned_brand_voice>

## RECHTSCHREIBUNG
- Nutze echte deutsche Umlaute und ß: ä, ö, ü, ß. Schreibe NIE ae, oe, ue oder ss als Ersatz.
- Neue Rechtschreibung (Duden).

## INHALT — Schreibregeln
- Ausschließlich Deutsch.
- Sie-Form bei externer Kommunikation. Bei internen Briefings an Til: direkte Anrede mit "du" und Vorname.
- Pragmatisch-klar. Kurze, aktive Sätze. Subjekt-Verb-Objekt.
- Konkrete Zahlen und Beispiele statt Allgemeinplätze.
- Keine Berater-Phrasen: "holistisch", "ganzheitlich", "auf Augenhöhe", "nachhaltig" (außer Ökologie), "end-to-end", "Best Practices" als Substantiv, "wir begleiten Sie", "maßgeschneidert", "Game Changer", "digitale Transformation" als Oberbegriff.
- Keine unnötigen Anglizismen. "Termin" statt "Slot", "Angebot" statt "Proposal", "Rückmeldung" statt "Feedback".
- Keine Emojis in Business-Kommunikation.
- Zahlen deutsch: Tausenderpunkt ("4.800"), Dezimalkomma ("4,5 Tage").
- Verbindlich formulieren. "Ich schicke Ihnen den Entwurf bis Donnerstag" statt "Ich könnte versuchen...".

## KEINE ERFUNDENEN INHALTE
- Verwende niemals Platzhalter-Firmen wie "Beispiel GmbH", "Muster AG", "ACME Corp" oder erfundene Kunden-/Lead-Namen.
- Alle Firmennamen, Termine, Zahlen und Referenzen müssen direkt aus den Kontext-Daten stammen.
- Wenn ein Datenblock leer ist: die entsprechende Sektion komplett weglassen. Keine Ersatzzeile, keine Dummy-Einträge.
- Lieber kürzere ehrliche Antwort als eine vollständige mit erfundenen Inhalten.

## VERBOTS-LISTE (fuer Post-Task-Validation)
Diese Begriffe duerfen NICHT in Worker-Output erscheinen — bei Verstoss
Worker neu starten:

- holistisch
- ganzheitlich
- auf Augenhöhe
- Best Practices
- wir begleiten Sie
- maßgeschneidert
- Game Changer
- end-to-end
- Beispiel GmbH
- Muster AG
- ACME Corp

</aligned_brand_voice>

---

## Geltungsbereich

| Output-Typ | Brand-Voice anwenden? |
|---|---|
| Plan-Texte (`/gsd:plan-phase` Output) | **Ja**, Plan-Beschreibungen + Decisions deutsch |
| Spec-Templates | **Ja**, sofern user-facing |
| Code-Kommentare | Nein (technisches Englisch ist OK) |
| Commit-Messages | Empfohlen Englisch (Git-Convention), aber Description darf deutsch |
| Verifier-Reports | **Ja**, an User adressiert |
| Internal Agent-zu-Agent | Nein (Englisch fuer Konsistenz mit upstream Skills) |

## Update-Workflow

1. Aenderungen in `lib/legion/brand-voice.ts:BRAND_VOICE_DE` machen
2. Diese Datei spiegeln (manuell oder via CI-Sync — geplant in spaeterem AP)
3. PR im `gsd-plugin-aligned2`-Repo
