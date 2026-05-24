<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# The interop contract (reverse-engineer ⇄ project-architect)

> The shared, versioned **file format** that `reverse-engineer` and `project-architect` (PA) both speak (spec §6). It is the ONLY coupling between the two plugins: they exchange **files on disk**, not code. Neither imports, vendors, or calls into the other's internals — each reads and writes the same versioned artifacts, so either can ship, version, and be installed independently. A recovery produced by this plugin is consumable by PA's forward engine; a project bootstrapped by PA is recognizable by this plugin (and politely deferred to PA's own flows).

This reference is the canonical description of that contract. `references/artifacts.md` describes the full P4 artifact *set* this plugin emits; THIS file describes the *subset* that is the interop surface and the *bidirectional invocation* the format enables.

## The three contract surfaces

The contract is exactly three on-disk artifacts. Both plugins agree on their shape and versioning.

| Surface | Path (under `<out>`) | Owner of the shape | What the other side does with it |
|---|---|---|---|
| **`_architect_state.json`** | `docs/_architect_state.json` | PA's architect **schema 3.1** (PA's `references/state-schema.md`) | PA reads it natively (`architect-ledger detect` / `migrate` / `import-decisions`); this plugin writes it ONLY via `bin/re-ledger`. |
| **`RECOVERED_DESIGN.md`** | `docs/RECOVERED_DESIGN.md` | PA's `references/templates/RECOVERED_DESIGN.md` (this plugin matches it) | PA's `/re-architect` triage consumes it **identically to its own** `design-recovery` agent's output. |
| **the flat decisions keyspace** | inside `_architect_state.json` → `.decisions` | the `decisions_schema_version "1.0"` flat-key convention | ingested by `architect-ledger import-decisions` (PA) and produced/ingested by `re-ledger import-decisions` (this plugin). |

### 1. `docs/_architect_state.json` — architect schema 3.1

This plugin authors the recovered state **directly at `schema_version "3.1"`** with `origin: "reverse-engineered"`. Schema 3.1 is **purely additive over 3.0** — `3.1 = 3.0 + three optional fields` — so a 3.0-only reader simply ignores the new keys, and PA's `migrate` never downgrades or renumbers a 3.1 state. The three interop fields (see PA's `state-schema.md` §"3.0 → 3.1"):

- **`origin`** — enum `greenfield | upgraded | rearchitected | reverse-engineered`; records how the state came to be. This plugin sets `"reverse-engineered"`. Default (PA-native, absent) is `"greenfield"`.
- **`recovery`** — `{ recovered_by, recovered_at, source_summary, confidence_summary }`; the recovery provenance. `recovered_at` is a real UTC ISO8601 stamp from `re-ledger`'s `now` (never back-fillable). `null` on a normal PA project.
- **`reverse_engineer_progress`** — a per-phase sub-ledger for this plugin's run resumability. It **mirrors PA's `rearchitect_progress` / `iterate_progress` shape**: each entry carries `.complete` + `.completed_at`, which PA's `architect-ledger detect` reads (its `interrupted_flow` / `resumable` signals) so PA's situation-router can recognize a half-finished recovery and route the user back in.

Beyond these three, the recovered state carries **every baseline field a valid PA 3.0/3.1 state has** (`plugin_version`, `started_at`, `last_updated_at`, `locked`/`version`/`locked_at`, `phase`, `phase_progress`, `documents_*`, `adrs_filed`/`next_adr_id`, `decisions_dir`, `project_layout`, `last_audit`, `research_findings`, `recommended_plugins`, `snapshots`, `memory_pointer`) — so PA's `detect` / `import-decisions` consume it with no missing-field surprises. `bin/re-ledger init` writes exactly this complete baseline (see `bin/re-ledger -h`).

> **One writer, one shape.** The state shape is the interop linchpin: a near-miss (a missing baseline field, a nested dotted key, a fabricated timestamp) silently breaks PA's `detect` / `import-decisions`. So there is exactly **one** writer of the shape on this side — `bin/re-ledger` — and `re-emit` delegates state creation to it rather than hand-rolling JSON. PA likewise has exactly one writer (`architect-ledger`). The two writers are kept behavior-identical on the fields they share (verified by `tests/test_v1_statewriter.sh` + `tests/test_v1_import_decisions.sh` against PA's `tests/test_v7_set_decision.sh`).

### 2. `docs/RECOVERED_DESIGN.md` — the shared design artifact

The synthesis `design-recoverer` produces is **shape-compatible with PA's `RECOVERED_DESIGN.md`** (this plugin's `references/templates/RECOVERED_DESIGN.md` matches PA's template of the same name). That is deliberate: PA's `/re-architect` flow has a triage step (its Step 3) that reads a `RECOVERED_DESIGN.md` produced by *its own* `design-recovery` agent. Because this plugin emits the **same** document shape, PA's triage consumes a reverse-engineered `RECOVERED_DESIGN.md` with no special-casing — the recovery "looks like" one PA produced itself.

It carries the reflexion recovery (hypothesis + convergence / divergence / absence), the recovered stack (grounded on `landscape-researcher`'s current-version findings, never stale training data), component boundaries, a structural-health grade, the architecture-critic's read, interface fragments (OpenAPI + a mermaid `erDiagram`), the recovered-decisions table, and — inline — the flat decisions keyspace (surface 3).

### 3. The flat decisions keyspace — `{canonical.key: scalar}`

The machine-readable half of the recovery: a **flat** JSON object of `{canonical-key: value}` pairs, stored at `.decisions` in the state with `decisions_schema_version "1.0"`. The convention both plugins enforce:

- **Keys are canonical** — the same canonical decision keys PA's forward engine uses (e.g. `database.engine`, `project.name`, `auth.provider`, `platforms`), so a key set on one side is the key the other side reads. Where no canonical PA key applies, a project-scoped slug key is used.
- **Dotted keys are LITERAL and FLAT, never nested.** `database.engine` is the string key `"database.engine"` — *not* a nested object `.decisions.database.engine`. Both `import-decisions` implementations store it flat; a reader on either side looks it up as `.decisions["database.engine"]`.
- **Values are raw JSON** — a string stays a string, a number a number, a bool a bool, an array an array. Nothing is stringified on ingest.
- **Nothing is invented.** Every recovered row is `value · confidence · evidence`; a decision with no evidence is omitted or recorded `Low` with the gap stated (it never becomes a confident fact). Triage (P3) is the human gate before any of it is written.

Both ledgers' `import-decisions` merge a flat `{key:value}` file into `.decisions` with **identical** semantics — merge-on-top (existing non-clashing keys survive), raw values, literal dotted keys, `decisions_schema_version` filled only when absent, fully idempotent. The same keyspace file therefore round-trips **byte-identically** through `re-ledger import-decisions` and `architect-ledger import-decisions`:

```bash
# this plugin, into a recovered schema-3.1 state:
${CLAUDE_PLUGIN_ROOT}/bin/re-ledger --state "$OUT/docs/_architect_state.json" import-decisions triaged-keyspace.json

# project-architect, into its own state — same file, same resulting .decisions:
architect-ledger --state "$PROJ/docs/_architect_state.json" import-decisions triaged-keyspace.json
```

## Bidirectional invocation (the hand-offs the format enables)

The shared format makes the two plugins interoperate **both ways**. Crucially, **neither direction is a hard dependency** — each plugin runs fully standalone; the other being installed only unlocks a seamless hand-off across the file format.

### project-architect → reverse-engineer

PA's Preflight can detect that the project it has been pointed at is a **foreign / brownfield** project — real source and/or docs, but **no** `docs/_architect_state.json` (PA never bootstrapped it). Rather than treat such a project as greenfield (which would ignore the existing code), PA can route the user to `reverse-engineer` to **recover** the design first, then resume its forward flow over the recovered, triaged contract. The hand-off surface is this contract: reverse-engineer emits `RECOVERED_DESIGN.md` + the schema-3.1 state + the flat keyspace, which PA then reads.

> PA invokes reverse-engineer over the *absence* of architect state on a project that nonetheless has code/docs. reverse-engineer does the recovery; control returns to PA's forward engine seeded by the contract.

### reverse-engineer → project-architect

This plugin's **P5 (Handoff)** is the reciprocal direction. The recovery's value is reachable two ways:

- **Standalone** — the artifact set (`docs/reverse-engineer/` + `RECOVERED_DESIGN.md` + `SUMMARY.md` + the schema-3.1 state) stands on its own even if PA is **not** installed.
- **Carried forward** — if `project-architect` **is** installed, P5 offers to invoke PA's forward flow directly, **seeded via this contract**: PA reads the schema-3.1 state, ingests the flat triaged keyspace via its own `import-decisions`, and its `/re-architect` triage consumes `RECOVERED_DESIGN.md` identically to its own `design-recovery` output — producing the full design-doc set / ADRs / `CLAUDE.md` / `.claude/` tooling + a scaffold-gap analysis from the recovered decisions. If PA is **not** installed, P5 prints install guidance (`claude plugin marketplace add alexfordlabs/…` → `claude plugin install project-architect`) and notes the contract is ready on disk for whenever PA is added.

And reciprocally, this plugin's **P0 (Detect)** *defers* to PA: if `bin/re-detect` finds a `docs/_architect_state.json` already present, the project is a PA project (not a foreign one), so reverse-engineer stops cleanly and points the user at PA's own flows (`/re-architect`, `/upgrade-project`) — it never re-recovers a project PA already owns.

```
                         shared file format (this contract)
                ┌──────────────────────────────────────────────────┐
                │  docs/_architect_state.json  (schema 3.1)          │
                │  docs/RECOVERED_DESIGN.md                          │
                │  .decisions  (flat {canonical.key: scalar})        │
                └──────────────────────────────────────────────────┘
        ▲  PA Preflight: foreign project (no state)          ▲  reverse-engineer P5: hand forward
        │  → invoke reverse-engineer to recover              │  → invoke PA's forward flow (seeded)
        │                                                    │
   project-architect  ◀───────────────────────────────▶  reverse-engineer
        │  reverse-engineer P0: state present →              │
        │  defer to PA (/re-architect, /upgrade-project)     │
        ▼                                                    ▼
   (each runs fully standalone; the other unlocks a seamless hand-off, never a hard dependency)
```

## Versioning the contract

- The state's `schema_version` (`"3.1"`) versions surface 1; `decisions_schema_version` (`"1.0"`) versions surface 3. PA owns both numbers (its `state-schema.md` is canonical); this plugin tracks them.
- A future bump is **additive + migratable** by convention (PA's `state-schema.md` "migration table"): new optional fields with safe defaults, `schema_version` bump-if-below rather than renumber, every step idempotent. Because the coupling is the file format (not code), either plugin can adopt a new contract version on its own release cadence as long as it stays back-compatible per that convention.

## When to consult what

| Question | Source |
|---|---|
| The full P4 artifact set (every file, its source agent, required headings) | [`artifacts.md`](artifacts.md) |
| The `RECOVERED_DESIGN.md` section shape (PA-compatible) | [`templates/RECOVERED_DESIGN.md`](templates/RECOVERED_DESIGN.md) |
| The state writer subcommands (`init` / `set-decision` / `import-decisions` / `set-substep` / `set-recovery`) | `bin/re-ledger -h` |
| PA's canonical schema-3.1 definition + the migration table | project-architect's `references/state-schema.md` §"3.0 → 3.1" |
| PA's matching ledger semantics (the round-trip counterpart) | project-architect's `bin/architect-ledger` (`import-decisions`) |

---

*★ Skillfully made with [reverse-engineer](https://github.com/alexfordlabs/reverse-engineer).*
