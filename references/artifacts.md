<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# The recovery artifact set (the P4 "emit" contract)

> The standard set of files `/reverse-engineer` writes when its pipeline emits (spec §5). `bin/re-emit` is the mechanics that writes this set + ensures the shared state; the orchestrator skill (Wave 4) collects the analysis agents' outputs and calls `re-emit`. This reference is the **contract** both follow: each file, the agent it comes from, its required sections, and the shared schema-3.1 state.

The set is **standalone** — usable even if project-architect is not installed (P4 is the standalone deliverable). When project-architect *is* installed, the same set is the hand-off surface (P5): `RECOVERED_DESIGN.md` + the flat decisions keyspace inside `_architect_state.json` are what project-architect's `/re-architect` triage + `import-decisions` consume.

## Layout

```
<out>/docs/
├── reverse-engineer/
│   ├── INVENTORY.md          (from code-inventory)
│   ├── DEPENDENCIES.md       (dependency-mapper + landscape-researcher, merged)
│   ├── REQUIREMENTS.md       (from requirements-extractor)
│   ├── SUMMARY.md            (recovery report: what was found, confidence, gaps)
│   ├── characterization-tests/   (opt-in; only if characterization-tester ran)
│   └── scripts/              (opt-in; dependency-mapper's committed extract_topology.*)
├── RECOVERED_DESIGN.md       (from design-recoverer)
└── _architect_state.json     (schema 3.1, origin: reverse-engineered — via bin/re-ledger)
```

`<out>` is the recovered project's root (the `--out` argument to `re-emit`). **Everything is written under `<out>/docs/`** — `re-emit` writes ONLY there and NEVER touches the analyzed target project (the plugin is read-only over the foreign project; it writes only its own recovery output).

## The files

| Artifact | Path (under `<out>`) | Source agent | What it carries |
|---|---|---|---|
| **INVENTORY.md** | `docs/reverse-engineer/INVENTORY.md` | `code-inventory` | The structure + inventory map: census, entry points, the data model (inventoried first), components, and the RepoMap-style ranked symbol map. |
| **DEPENDENCIES.md** | `docs/reverse-engineer/DEPENDENCIES.md` | `dependency-mapper` + `landscape-researcher` (**merged**) | The internal import graph + candidate components + Arcan smells + the inferred layer/boundary contract (dependency-mapper), with the external-dependency table **annotated** with researched current-version / status / CVE / EOL findings (landscape-researcher). The two agents' outputs reconcile into ONE doc. |
| **REQUIREMENTS.md** | `docs/reverse-engineer/REQUIREMENTS.md` | `requirements-extractor` | The inferred requirements / business rules as Given/When/Then with concrete literals, candidate-config params, the entity catalog, doc-vs-code discrepancies, and the rules-needing-SME-confirmation list. |
| **SUMMARY.md** | `docs/reverse-engineer/SUMMARY.md` | the skill (recovery report) | The recovery report: what was found, the overall confidence, the gaps + low-confidence triage targets, and which analysis passes ran (with tool provenance). The standalone deliverable's executive summary. |
| **RECOVERED_DESIGN.md** | `docs/RECOVERED_DESIGN.md` | `design-recoverer` | The synthesis: the reflexion recovery (hypothesis + convergence/divergence/absence), recovered stack, component boundaries, structural-health grade, the architecture-critic's read, the recovered-decisions table, interface fragments (OpenAPI + mermaid `erDiagram`), and the **flat decisions keyspace**. Shape-compatible with project-architect's `RECOVERED_DESIGN.md`. Template: [`templates/RECOVERED_DESIGN.md`](templates/RECOVERED_DESIGN.md). |
| **characterization-tests/** | `docs/reverse-engineer/characterization-tests/` | `characterization-tester` (opt-in) | Behavior-pinning golden-master tests + their approved snapshots + a `CHARACTERIZATION.md` report. **Present only if** the user opted in to characterization and it ran (`re-emit --characterization-dir`). |
| **_architect_state.json** | `docs/_architect_state.json` | `bin/re-ledger` | The shared schema-3.1 state (below). The machine-readable contract with project-architect. |

### Required top-level heading per artifact

`re-emit` writes a **skeleton placeholder** for any artifact whose content wasn't provided, so the set is always complete + structurally recognizable. Each skeleton (and the real content the agent produces) carries this canonical top-level heading:

| Artifact | Top-level heading |
|---|---|
| INVENTORY.md | `# Code Inventory — {{target name}}` |
| DEPENDENCIES.md | `# Dependencies & Coupling — {{target name}}` |
| REQUIREMENTS.md | `# Inferred Requirements & Business Rules — {{target name}}` |
| SUMMARY.md | `# Recovery Summary — {{target name}}` |
| RECOVERED_DESIGN.md | `# Recovered Design — {{target name}}` |

The full per-section structure of each artifact is defined in its source agent's "Output structure" block (`agents/<agent>.md`) and, for `RECOVERED_DESIGN.md`, in `references/templates/RECOVERED_DESIGN.md`. A skeleton is a deliberately minimal stand-in (heading + a "not yet generated" note) — it is replaced by the agent's real content during emit; it is never the final deliverable.

## The shared state: `_architect_state.json` (schema 3.1, `origin: reverse-engineered`)

This file is the **shared, versioned contract** with project-architect — its architect **schema 3.1** state. `re-emit` does NOT hand-roll it; it **delegates to `bin/re-ledger init`** (only when the state is absent), because `re-ledger` is the contract-correct writer (verified compatible with project-architect's `architect-ledger import-decisions`). See `bin/re-ledger` and project-architect's `references/state-schema.md` §"3.0 → 3.1".

The recovered state carries, beyond every baseline PA field:

- `schema_version: "3.1"`
- `origin: "reverse-engineered"` — marks how the state came to be (vs. `greenfield` / `upgraded` / `rearchitected`).
- `recovery: { recovered_by, recovered_at, source_summary, confidence_summary }` — the recovery provenance (`recovered_at` is a real UTC ISO8601 stamp from `re-ledger`'s `now`, never back-fillable).
- `decisions: {}` — the **flat decisions keyspace** (`{canonical.key: value}`, LITERAL dotted keys), `decisions_schema_version: "1.0"`. design-recoverer's flat keyspace is stored here via `re-ledger set-decision`; it is what project-architect's `import-decisions` ingests.
- `reverse_engineer_progress: {}` — the per-phase sub-ledger for resumability (mirrors project-architect's `rearchitect_progress`; entries carry `.complete` + `.completed_at`, which project-architect's `detect` / interrupted-flow reads).

### Why delegate the state to `re-ledger` (not hand-roll it in `re-emit`)

The state shape is the **interop linchpin** — a near-miss (a missing baseline field, a nested dotted key, a fabricated timestamp) silently breaks project-architect's `detect` / `import-decisions`. There is exactly ONE writer of that shape (`re-ledger`), so every path that needs a state (`re-emit`, the skill, a resume) produces the identical contract-correct state. `re-emit` is idempotent here: it `init`s only when the state is **absent**; an existing state is the recovery's in-flight ledger (decisions, progress, provenance) and is **preserved** untouched.

## Idempotency + write discipline (the invariants `re-emit` guarantees)

- **Writes ONLY under `--out`.** Never the analyzed target. The plugin reads the foreign project; it writes only its own recovery output (mirrors the spec's read-only-over-target / write-only-our-output rule).
- **Always complete.** Every artifact in the set exists after a run — provided content where given, a skeleton placeholder otherwise.
- **Idempotent / re-runnable.** A second `re-emit` re-writes the artifact files (atomic temp-file + `mv`) and **preserves** the existing state (no re-init). Safe to run repeatedly as the pipeline fills in content.
- **Provenance.** `re-emit` echoes exactly what it wrote — which artifacts came from provided content, which are skeleton placeholders, and whether the state was initialized or preserved.

---

*★ Skillfully made with [reverse-engineer](https://github.com/alexfordlabs/reverse-engineer).*
