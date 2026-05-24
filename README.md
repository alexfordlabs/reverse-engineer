<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

<div align="center">

# reverse-engineer

**An orchestrator skill that recovers a design from a project you didn't build — inside Claude Code.**

Point it at a foreign or brownfield project — arbitrary source, a half-finished folder tree, scattered notes — and it reconstructs the inventory, dependency map, inferred requirements, current-version tech landscape, and a reviewable, human-validated design. Then it hands that design to [`project-architect`](https://github.com/alexfordlabs/project-architect) so you can keep building.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/alexfordlabs/reverse-engineer?include_prereleases&label=release)](https://github.com/alexfordlabs/reverse-engineer/releases)
[![Stars](https://img.shields.io/github/stars/alexfordlabs/reverse-engineer?style=social)](https://github.com/alexfordlabs/reverse-engineer)
[![Last commit](https://img.shields.io/github/last-commit/alexfordlabs/reverse-engineer)](https://github.com/alexfordlabs/reverse-engineer/commits/main)
[![Plugin validate](https://img.shields.io/badge/plugin%20validate-✓%20passing-success)](.claude-plugin/plugin.json)
[![Tests](https://img.shields.io/badge/tests-passing-success)](tests/)

</div>

---

`reverse-engineer` is a [Claude Code](https://claude.com/claude-code) plugin that turns *"here is a codebase nobody briefed me on"* into a reviewable, evidence-backed design on disk. You invoke one skill. It walks **6 phases**, dispatches **6 specialist subagents** to read the code, map the dependencies, research the real current state of every framework it actually uses, and infer the requirements — then synthesizes a `RECOVERED_DESIGN.md` you triage decision-by-decision before anything is written. The result is a standalone deliverable *and* a clean hand-off into `project-architect`'s forward engine.

It is built on one premise: **the code is ground truth.** Docs drift; the model's training knowledge of a dependency is, by default, stale; only the source tells you what the project actually is. So every recovered claim cites a `file:line` or a tool's output, every dependency's version and status is researched against **live** sources at recovery time, and a human validates the recovered design before it's trusted.

## What it is — the gap it fills

`project-architect` handles two project origins today:

- **Greenfield** — its 11-phase forward bootstrap (interview → docs → lock → scaffold).
- **`project-architect`-produced** — `/upgrade-project` (bring an old-format project forward) and `/re-architect` (recover a design from its *own* docs, ADRs, and state ledger).

The **missing origin** is the one in between: a **foreign / brownfield** project `project-architect` never touched — arbitrary source code, a README, scattered design notes, or just a folder tree with a half-built implementation and **no architect state**. `/re-architect` and the `design-recovery` agent assume architect-shaped inputs; they can't ingest a project they didn't create.

`reverse-engineer` fills that gap. It reconstructs a design *from the artifacts that exist* — code first, docs treated as claims to verify against the code — and feeds the result into `project-architect`'s forward engine through a shared, versioned contract. Together the two plugins cover every project origin: greenfield, architect-produced, and **foreign**.

## Install

`reverse-engineer` ships from the shared **`alexfordlabs`** Claude Code marketplace — the same one-marketplace, two-plugin setup as its companion `project-architect`.

```bash
# 1. Add the shared marketplace (the alexfordlabs/skills collection)
claude plugin marketplace add alexfordlabs/skills

# 2. Install reverse-engineer from it
claude plugin install reverse-engineer@alexfordlabs

# 3. (Optional) Verify the install
claude plugin validate
```

The same marketplace also installs `project-architect` (`claude plugin install project-architect@alexfordlabs`). Installing both unlocks the seamless hand-off described under [Interoperates with project-architect](#interoperates-with-project-architect) — but `reverse-engineer` runs **fully standalone**: `project-architect` is optional, never a hard dependency.

## The pipeline

You invoke the skill on a target directory; it orchestrates six phases, recording progress in a resumable state ledger at each boundary so an interrupted run picks up where it left off.

```
P0  Detect & scope     →  P1  Understand  →  P2  Recover design
P3  Triage & validate  →  P4  Emit        →  P5  Handoff
```

- **P0 — Detect & scope.** Confirm there's a foreign project to recover (source / manifests / docs / a non-trivial tree) and that it isn't already a `project-architect` project. If architect state is present, it **defers** cleanly to `project-architect`'s own flows. Otherwise it fixes the scope — whole-repo by default, with a per-run override to a subpath.
- **P1 — Understand** *(code is ground truth)*. Four analysis passes, dispatched in dependency order: `code-inventory` first, then `dependency-mapper` + `requirements-extractor` in parallel, then `landscape-researcher`. A fifth pass, `characterization-tester`, is **opt-in and consent-gated** because it executes the target's code. Each agent's output is threaded into the agents downstream.
- **P2 — Recover design.** `design-recoverer` synthesizes all four evidence streams into a reviewable `RECOVERED_DESIGN.md` and a flat decisions keyspace — every row a *value · confidence · evidence* triple. It never invents: a decision with no evidence is omitted or recorded low-confidence with the gap stated.
- **P3 — Triage & validate** *(the human gate)*. The recovered design is presented for review, **lowest-confidence rows first**. For each decision you **keep**, **correct**, or **fill**. Recovery is *validated, not trusted* — nothing is committed before you've seen it.
- **P4 — Emit.** Writes the complete artifact set under `docs/` plus the shared schema-3.1 state, and ingests your triaged decisions. This is the **standalone deliverable** — usable even if `project-architect` isn't installed. Everything is written under the recovery's own `docs/`; the analyzed project's code is never touched.
- **P5 — Handoff.** The shared contract is on disk. If `project-architect` is installed, it offers to invoke the forward flow directly — seeded from the recovered, triaged decisions — to generate the full design-doc set, ADRs, `CLAUDE.md`, and `.claude/` tooling. If not, it prints how to install it and notes the contract is ready.

## The 6-agent suite

All six are **LLM subagents** (not CLIs), each dispatched at `model: opus`, maximum effort, with an explicit runtime budget — mirroring `project-architect`'s dispatch discipline. They leverage installed analysis tools where available and reason in-prompt where no tool fits, always recording which path produced each finding.

| Agent | What it does |
|---|---|
| **`code-inventory`** | The first pass. Walks the tree read-only, classifies files / languages / components / entry points, finds the data model first (schemas are more stable and truthful than procedural code), and produces a RepoMap-style ranked symbol map. Every claim cites `file:line`. |
| **`dependency-mapper`** | Builds the internal import graph, inventories external dependencies from every manifest, clusters cohesive modules into candidate components, detects cycles and Arcan-style architectural smells, and infers the implicit layer/boundary contracts the code already follows. Leaves a slot where `landscape-researcher` attaches each dependency's researched version + status. |
| **`landscape-researcher`** | The suite's differentiator. For every detected framework, library, runtime, and build tool, it runs the [current-version cascade](#the-differentiator--research-augmented-detection) against live sources and returns ground truth — current version, status, CVEs, EOL. **Never** from stale model knowledge. |
| **`requirements-extractor`** | Mines the business rules and requirements the system enforces, reading rule-bearing code and docs through a three-lens method (calculations / validations + eligibility / state + lifecycle), expressing each as Given/When/Then with the concrete literal values found in the code, and keeping a strict line between language-independent rules and implementation artifacts. |
| **`characterization-tester`** *(opt-in, consent-gated)* | The only agent that **executes** the foreign code. It writes golden-master tests pinning current observable behavior — bugs included, because the code is the oracle — so a later rebuild can be proven equivalent. It runs only after an explicit, unambiguous opt-in (and its own pre-flight confirmation), sandboxed; absent consent it emits a plan and runs nothing. |
| **`design-recoverer`** | The synthesis keystone. Consumes every upstream analyst and produces `RECOVERED_DESIGN.md` + the flat decisions keyspace. It recovers via the reflexion model (hypothesize an architecture → map the source onto it → report convergence / divergence / absence), grades structural health, applies an architecture-critic's skeptical lens, and routes every low-confidence row to triage. Shape-compatible with `project-architect`'s own recovery output. |

## The differentiator — research-augmented detection

Most code-understanding tools describe a dependency from whatever the model remembers. That's almost always wrong: detected tech routinely post-dates the model's training cutoff, so a *remembered* version, status, or API is stale by default. `reverse-engineer` **never trusts stale training knowledge.** Every version, status, CVE, and current-API claim carries a **live source** (the tool or API that produced it this run) and a **confidence**; an unreachable source is reported as such, never backfilled from memory.

`landscape-researcher` runs a live **current-version cascade** per detected dependency and runtime:

1. **Inventory** — `syft` → a CycloneDX SBOM (ecosystem-agnostic), falling back to the dependency-mapper's manifest inventory or direct lockfile parsing.
2. **Current stable + versions-behind** — **deps.dev** (Google's Open Source Insights): the `isDefault` version is the current stable, and the gap from the pinned version is the headline risk number. Cross-checked against npm / PyPI / crates.io registries.
3. **Vulnerabilities** — `grype` over the SBOM and/or **OSV** + deps.dev advisories on the concrete pinned version → CVEs with their fixed-version.
4. **End-of-life** — **endoflife.date** → past-EOL / nearing-EOL flags for runtimes, frameworks, databases, and OSes. This is what turns "Node 16" into "Node 16 — past EOL; upgrade to an active LTS."
5. **Doc confirmation** — for the few headline frameworks the design reasons about in detail, **context7** and the vendor's `llms.txt` confirm the current major's real API shape, so no hallucinated API reaches the recovered design.

Every source is best-effort and probed before use (`command -v` / MCP availability), with graceful degradation down the chain to the next live source — and if every source is unreachable, the cell reads *"could not verify against current sources,"* never a guess. The result is a dependency table that's correct **today**, with the provenance to audit each row.

## Interoperates with project-architect

`reverse-engineer` and `project-architect` are companions pointed in opposite directions, coupled by exactly one thing: a shared, versioned **file format** on disk. Neither imports, vendors, or calls into the other's internals — so each ships, versions, and installs independently. The contract is three artifacts:

| Surface | What it is | What the other side does with it |
|---|---|---|
| `docs/_architect_state.json` | The architect **schema-3.1** state (`origin: "reverse-engineered"` + a recovery-provenance block + a resumable sub-ledger) | `project-architect` reads it natively via its own ledger (`detect` / `migrate` / `import-decisions`). |
| `docs/RECOVERED_DESIGN.md` | The reviewable recovered design | `project-architect`'s `/re-architect` triage consumes it **identically** to its own `design-recovery` output. |
| The flat decisions keyspace | `{canonical.key: value}` pairs inside the state | Ingested by `project-architect`'s `import-decisions`, the exact counterpart of this plugin's own ledger merge. |

Schema 3.1 is **purely additive** over `project-architect`'s 3.0 (three optional fields), so the two evolve together without breaking. The interoperation runs **both ways** — and **neither direction is a hard dependency**:

- **`project-architect` → `reverse-engineer`.** When `project-architect`'s Preflight is pointed at a project that has code/docs but **no** architect state, it can route you here to recover the design first, then resume its forward flow over the recovered contract.
- **`reverse-engineer` → `project-architect`.** This plugin's P5 offers the reciprocal hand-off: recover → triage → and feed the validated design into `project-architect`'s forward engine, seeded so you continue bootstrapping with the recovered design already in hand.

And P0 defers the other way: if `reverse-engineer` finds architect state already present, it stops cleanly and points you at `project-architect`'s own `/re-architect` and `/upgrade-project` — it never re-recovers a project `project-architect` already owns.

## Research-grounded tooling

The plugin **stands on existing tools where they're strong and reasons in-prompt where no tool fits** — always probing for availability first (`command -v` / MCP reachability), degrading gracefully, and recording which path produced each finding. Tool availability is host-specific, so nothing is ever assumed.

- **Inventory & structure** — `scc` (census + complexity), the Semgrep MCP (AST, route/handler detection), `ctags` / LSP (symbol defs/refs), with a Glob + Grep fallback.
- **Dependency graphs** — language-native first: `jdeps` (Java), `cargo tree` (Rust), `go mod graph` (Go), `madge` / `dependency-cruiser` (JS), `pydeps` / `import-linter` (Python), with a Semgrep-AST / grep fallback.
- **Supply-chain & security** — `syft` → SBOM, `grype` / `trivy`, `deps.dev` / `OSV` / `endoflife.date`, plus `/security-review` + Semgrep for the security dimension of the recovered design.
- **Doc grounding** — `context7`, vendor `llms.txt`-first discovery, and web search/fetch for current-major API confirmation.

Where no CLI does the job well for arbitrary stacks — reflexion-model architecture recovery, RepoMap ranking, business-rule extraction, clustering and smell-grading — the agents emulate the technique in-prompt. **Scope is source-level recovery only**; binary reverse-engineering (Ghidra, radare2, IDA, and the rest of the binary-RE set) is explicitly out of scope, since it adds nothing when source is present.

## Project types it handles

Any **source-level** project, regardless of stack — `reverse-engineer` is ecosystem-agnostic by design:

- Web apps, APIs and services, CLI tools, libraries and SDKs
- Mobile, desktop, browser extensions
- Data pipelines, AI/ML codebases, infrastructure tooling
- Monorepos and multi-language repositories
- Half-finished implementations, abandoned spikes, and folder trees of notes + partial code

The recovery scales the same way whether the target is a single package or a sprawling monorepo: `code-inventory` censuses it, the scope can be narrowed to a subtree, and every downstream pass reasons over the inventory rather than re-walking the tree.

## Output artifacts

A completed recovery leaves a self-contained set under the project's `docs/` — written only there, never into the analyzed code:

```text
<project>/docs/
├── reverse-engineer/
│   ├── INVENTORY.md              ← structure, components, data model, ranked symbol map  (code-inventory)
│   ├── DEPENDENCIES.md           ← internal graph + external deps annotated with researched
│   │                                versions / status / CVEs / EOL  (dependency-mapper + landscape-researcher, merged)
│   ├── REQUIREMENTS.md           ← inferred business rules as Given/When/Then  (requirements-extractor)
│   ├── SUMMARY.md                ← the recovery report: what was found, confidence, gaps, triage targets
│   └── characterization-tests/   ← (opt-in) behavior-pinning golden-master tests  (characterization-tester)
├── RECOVERED_DESIGN.md           ← the synthesized, reviewable design + flat decisions keyspace  (design-recoverer)
└── _architect_state.json         ← schema-3.1 state, origin: "reverse-engineered" — the shared contract
```

`SUMMARY.md` is the executive summary of the recovery; `RECOVERED_DESIGN.md` and `_architect_state.json` are the hand-off surface `project-architect` consumes. The set is always complete and re-runnable — re-emitting refreshes the documents while preserving the in-flight state ledger.

## Companion plugins

| Plugin | Relationship |
|---|---|
| [`project-architect`](https://github.com/alexfordlabs/project-architect) | The forward engine. `reverse-engineer` recovers a design from a foreign project; `project-architect` takes that recovered design forward into docs, ADRs, `CLAUDE.md`, and `.claude/` tooling. Installed from the same `alexfordlabs` marketplace; optional, never required. |

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow; for substantial changes, open an issue first to discuss the direction.

The plugin is developed test-first. The full suite is pure Bash, asserts against the actual plugin files, and needs no external test framework:

```bash
bash tests/run_all.sh
```

Host tooling: `bash >= 4`, `jq`, `python3 >= 3.10`, `shellcheck`, `gh`, `git`, `curl`.

## License

[MIT](LICENSE) — © 2026 Alexander Ford / Alex Ford Labs.

## Attribution

When you use `reverse-engineer`, the recovered docs end with:

> *★ Skillfully made with [reverse-engineer](https://github.com/alexfordlabs/reverse-engineer).*

This is a social-norm attribution, not a legal one — keeping it visible in `SUMMARY.md`, `RECOVERED_DESIGN.md`, and other top-level docs helps others discover the tool. The MIT license doesn't require it, but it's a polite norm and costs you nothing.

If you fork or build on the skill itself, the source-file attribution comments must remain per the MIT terms, and the `LICENSE` file must be included in any redistribution.

> **Publisher.** `reverse-engineer` is published by **Alex Ford Labs**, the companion plugin to `project-architect`.

---

*★ Skillfully made with [reverse-engineer](https://github.com/alexfordlabs/reverse-engineer).*
