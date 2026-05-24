---
template_name: RECOVERED_DESIGN
generate_when: "reverse_engineer_synthesis"
emitted_by: design-recoverer
consumed_by: ["re-ledger import-decisions", "project-architect /re-architect triage"]
---

<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# Recovered Design — {{target_name}}

> **The synthesis artifact of `/reverse-engineer`.** The `design-recoverer` agent synthesized it from the four upstream analysts — code-inventory (structure + data model), dependency-mapper (graph + Arcan smells + external deps), requirements-extractor (business rules), and landscape-researcher (current versions / EOL / CVEs / conventions) — into one reviewable recovery + a flat decisions keyspace.
>
> **It is shape-compatible with project-architect's `RECOVERED_DESIGN.md`** so PA's `/re-architect` **triage** (its Step 3) consumes this output identically: same canonical decision keys, same `value · confidence · evidence` rows, same `alias` convention. The **Flat decisions keyspace** block at the bottom is what `re-ledger import-decisions` stores and what PA's `import-decisions` ingests.
>
> **The recovery NEVER invents.** Every decision row traces to evidence (a `file:line` or a named tool output). A **low-confidence** row is a SUCCESS — it routes a reviewer's attention to exactly what needs scrutiny, and PA's triage surfaces low-confidence rows FIRST.
>
> Synthesized: `{{recovered_summary}}` (e.g. `RECOVERED 28 decisions (5 low-confidence) across 5 areas; reflexion: 9 convergence / 3 divergence / 2 absence; structural-health B`).

## How to read this document

The architecture is recovered via the **reflexion model** — a hypothesis tested against the evidence — so you can see *how well the evidence supports it*, not just an authoritative-sounding conclusion. The **decisions table** is the machine-readable heart; its columns:

| field | meaning |
|---|---|
| `key` | the **canonical project-architect flat key** when the decision maps to one (`database.engine`, `backend.api_style`, `platforms`, `frontend.framework`, `auth.enabled`, …), else a descriptive project-specific slug. The canonical key is what PA's Phase-4 catalog selection + each template's `required_decisions` slicing key off. |
| `alias` | the project's OWN term for this concept when it differs from the canonical key (so the row is traceable to the project's language AND resolves against PA's keyspace). `—` when the project uses the canonical concept directly or the key is already project-specific. |
| `value` | the recovered choice, as the evidence shows it — the concrete value, never a paraphrase. |
| `confidence` | `High` (direct evidence — manifest/schema/literal/tool resolution), `Med` (inferred — `appears`), or `Low` (ambiguous, conflicting across inputs, or a shape without confirmed semantics). **Low/Med rows are the triage targets — surfaced first.** |
| `evidence` | the citation that makes the row trustworthy: a `file:line`, or a named tool output (`(via dependency-mapper)`, `(via landscape-researcher)`, `(via Semgrep findings)`, `(via /security-review)`). **No row without evidence — that is the never-invent rule made concrete.** |

> **The recovery reconstructs; the human (in triage) decides.** If a `value` is wrong, correct it. If a row is `confidence: Low`, scrutinize its `evidence` before trusting it. When this design is carried forward into project-architect, its triage step lets a human keep/revise/drop/add each decision before anything is re-derived.

---

## Provenance & tooling

- Synthesized from: code-inventory `{{✓/✗}}` · dependency-mapper `{{✓/✗}}` · requirements-extractor `{{✓/✗}}` · landscape-researcher `{{✓/✗}}`
- Security dimension: `{{/security-review ✓ | Semgrep ✓ | EMULATED — no security tool reachable}}`
- The **architecture recovery is EMULATED reasoning** over the analysts' cited evidence (no CLI does arbitrary-stack recovery); **security findings carry a tool source**. Read-only over the target — nothing was executed (behavior-pinning is `characterization-tester`'s opt-in job).
- Scope: `{{whole-repo | subpath}}` · vendored/build/cache excluded

## Recovered architecture (reflexion model)

> Hypothesize a high-level architecture → map the source onto it → report where the source **confirms** (convergence), **contradicts** (divergence), or is **silent** (absence). The recovered architecture is the hypothesis that survives the mapping — reported *with* its divergences, not laundered into settled fact.

- **Hypothesis**: `{{the high-level architecture proposed — e.g. "a layered HTTP service: handlers → services → repositories over Postgres, plus a background worker"}}`

### Convergence — the source confirms the hypothesis
- `{{hypothesized element}}` — confirmed by `{{evidence}}` `{{file:line / (via …)}}`

### Divergence — the source contradicts the hypothesis (high-value findings)
- `{{hypothesized element}}` — the evidence shows `{{what instead}}` at `{{file:line}}` `{{(via dependency-mapper)}}`

### Absence — a hypothesized element is not found
- `{{hypothesized element}}` — expected because `{{why}}`; not present because `{{what the evidence shows}}`

**Recovered architecture (the surviving hypothesis):** `{{statement, carrying forward its key divergences/absences — never presented as settled when the mapping diverged}}`

## Recovered stack (grounded on landscape-researcher's current findings)

| Layer | Tech @ detected version | Current stable | Status | Source |
|---|---|---|---|---|
| `{{layer}}` | `{{tech @ version}}` | `{{current_stable}}` | `{{current/deprecated/superseded/EOL}}` | `{{(via landscape-researcher)}}` |

> Every version/status here came from landscape-researcher's LIVE sources (deps.dev / OSV / endoflife.date / context7), never model training knowledge. Stale/superseded/EOL pins are the rebuild's first upgrade targets.

## Component boundaries

> The recovered component boundaries — each component, its responsibility, its members, and whether its complexity is essential or accidental.

| Component | Responsibility (`is`/`appears`) | Members (`file:line`) | Complexity verdict |
|---|---|---|---|
| `{{component}}` | `{{responsibility}}` | `{{file:line…}}` | `{{essential | accidental — why}}` |

## Structural-health grade (from dependency-mapper's Arcan smell catalog)

> The structural health of the recovered design — a grade derived from the Arcan smells (cyclic / hub-like / unstable / god-component), with the evidence behind it.

- **Grade**: `{{band — e.g. A–F or 1–5}}`
- **Evidence**: cyclic `{{N}}` · hub-like `{{H}}` · unstable `{{U}}` · god-component `{{G}}` — `{{file:line…}}` `{{(via dependency-mapper)}}`
- **Read**: `{{1-3 lines — what the grade means for an incremental rebuild; which smells are load-bearing risks vs cosmetic}}`

## Architecture-critic's read (skeptical lens — essential vs accidental complexity)

> Not stenography — a senior reviewer's skeptical read. Be fair, not cynical: state the evidence, let the reader judge.

- **Real domain seams vs microservices-for-the-résumé**: `{{judgment + evidence — are the boundaries genuine business capabilities with their own data, or paper splits sharing a schema/transaction?}}`
- **Is this the simplest design that fits the evidence?**: `{{where the design exceeds the need — a plugin system with one plugin, a layer that only forwards calls — with evidence}}`
- **Accidental vs essential complexity (what to keep / what to shed)**: `{{the scalpel — essential = inherent to the domain; accidental = self-inflicted}}`

## Recovered decisions (key · value · confidence · evidence)

> The interop linchpin. Use the **canonical project-architect key** whenever a decision maps to one (confirm spellings against PA's `document-catalog.md`); record the project's own term as `alias` when it differs; keep a descriptive slug + no `alias` for purely project-specific decisions. Every row cites evidence — **never invented**. Group by area; add or remove area sections to match the project.

### Area: Project / Vision

| key | alias | value | confidence | evidence |
|---|---|---|---|---|
| `{{project.type}}` | `{{—}}` | `{{value}}` | `{{High/Med/Low}}` | `{{file:line / (via …)}}` |

### Area: Tech Stack

| key | alias | value | confidence | evidence |
|---|---|---|---|---|
| `{{database.engine}}` | `{{store}}` | `{{PostgreSQL}}` | `{{High}}` | `{{docker-compose.yml:14}}` |
| `{{backend.api_style}}` | `{{—}}` | `{{REST}}` | `{{Med (appears)}}` | `{{src/router.ts:8}}` |

### Area: Architecture

| key | alias | value | confidence | evidence |
|---|---|---|---|---|
| `{{key}}` | `{{alias}}` | `{{value}}` | `{{confidence}}` | `{{evidence}}` |

### Area: Security

| key | alias | value | confidence | evidence |
|---|---|---|---|---|
| `{{auth.enabled}}` | `{{—}}` | `{{value}}` | `{{confidence}}` | `{{(via /security-review)}}` |

### Area: Ops

| key | alias | value | confidence | evidence |
|---|---|---|---|---|
| `{{devops.cicd}}` | `{{—}}` | `{{value}}` | `{{confidence}}` | `{{.github/workflows/ci.yml:1}}` |

> Every material decision the project evidently made MUST appear as at least one row, each with resolving `evidence`. A decision with no canonical PA key keeps a descriptive project-specific slug (e.g. `{{pricing.rounding_policy}}` · `—` · `{{half-up to cents}}` · `High` · `{{pricing.ts:42}}`).

## Recovered interfaces — OpenAPI fragment

> Recovered from the routes/handlers code-inventory found — a *recovered* contract (each path traces to a handler `file:line`; inferred fields marked `appears`), not an authored specification. If the project exposes no HTTP API, that is an **absence** (noted above) and this section is omitted.

```yaml
openapi: 3.1.0
info:
  title: {{recovered service name}}
  version: {{recovered or "unknown — appears"}}
paths:
  {{/path}}:
    {{method}}:
      summary: {{recovered from handler}}  # {{file:line}}
      # request/response shapes recovered from the handler + data model; {{appears}} where inferred
```

## Recovered data model — mermaid erDiagram

> Rendered from code-inventory's data-entity list (entities → key fields → relationships); each entity traces to its schema/model `file:line`.

```mermaid
erDiagram
  {{ENTITY_A}} ||--o{ {{ENTITY_B}} : "{{relationship}}"
  {{ENTITY_A}} {
    {{type}} {{field}}  "{{note / source file:line}}"
  }
```

## Open questions / low-confidence (the triage targets)

> The `Low`/`Med`-confidence rows + any input conflicts, gathered here for the reviewer. In project-architect's `/re-architect`, these are surfaced FIRST — they are where validation is most needed.

- `{{decision / conflict}}` — what's verified (`is`) vs inferred (`appears`); what a human must resolve before this is carried forward; what evidence would resolve it.

---

## Flat decisions keyspace (machine-readable — for `re-ledger import-decisions` → project-architect)

> The machine-readable subset of the decisions table: a flat `{key: value}` object keyed by the canonical project-architect keys (project-specific slugs kept as-is). The skill pipes this to `re-ledger import-decisions`, which stores it `decisions_schema_version "1.0"` — column-compatible with PA's `import-decisions`. Every table row with a resolvable key appears here; keep the two consistent.

```json
{
  "project.type": "{{value}}",
  "database.engine": "{{value}}",
  "backend.api_style": "{{value}}",
  "platforms": ["{{...}}"],
  "{{pricing.rounding_policy}}": "{{value}}"
}
```

---

*★ Skillfully made with [reverse-engineer](https://github.com/alexfordlabs/reverse-engineer).*
