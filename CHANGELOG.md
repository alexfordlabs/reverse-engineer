<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# Changelog

All notable changes to the `reverse-engineer` plugin.

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0 — 2026-05-24

**Initial release: recover a design from a project you didn't build, then hand it to project-architect.**

`reverse-engineer` reconstructs a reviewable design from a foreign or brownfield project — arbitrary source, scattered docs, a half-built implementation, or just a folder tree with no project-architect state — treating the code as ground truth and never trusting stale model knowledge about the tech it finds. It is the companion to [`project-architect`](https://github.com/alexfordlabs/project-architect): where project-architect bootstraps greenfield and recovers its own projects, `reverse-engineer` ingests projects it never produced and feeds the recovered design into project-architect's forward engine.

### Added

- **The recovery pipeline (P0–P5)** — an orchestrating skill walks six phases: **P0 Detect & scope** (confirm a foreign project; defer to project-architect when the project already has architect state), **P1 Understand** (inventory, dependency map, live tech-landscape research, inferred requirements), **P2 Recover design**, **P3 Triage & validate** (a human reviews low-confidence rows first — recovery is *validated, not trusted*), **P4 Emit**, and **P5 Handoff**. Per-phase progress is recorded in a resumable sub-ledger, so an interrupted run picks up where it stopped.
- **A six-agent analysis suite** (all opus, read-only over the target) — `code-inventory` (structure + a RepoMap-style ranked symbol map; read entry points before grepping; find the data model first), `dependency-mapper` (import graph, component clustering, cycle + architectural-smell detection, a committed re-runnable analysis script), `landscape-researcher` (the live current-version cascade — below), `requirements-extractor` (business rules as Given/When/Then with concrete literals, separating *what the system requires* from *how it happens to be implemented*), `characterization-tester` (behavior-pinning golden-master tests — **opt-in and consent-gated**, since it executes the target's code), and `design-recoverer` (reflexion-model architecture recovery → a reviewable design + a flat decisions keyspace).
- **Research-augmented detection — never stale knowledge.** For every detected language, framework, and dependency, `reverse-engineer` researches **current** sources rather than relying on the model's training cutoff: a cascade of `syft` → deps.dev → `grype`/OSV → endoflife.date → context7 / vendor `llms.txt`. Each dependency is annotated with its current stable version, how many versions the pin is behind, EOL status, and known CVEs — every fact carrying its live source and a confidence. Stale, superseded, and end-of-life pins are flagged; nothing is invented.
- **Interoperates with project-architect** — both plugins speak a shared, versioned file contract: the schema-3.1 `_architect_state.json` (with an `origin` field + recovery provenance), a `RECOVERED_DESIGN.md`, and a flat decisions keyspace under canonical keys. `reverse-engineer` writes it; project-architect reads it. Neither hard-depends on the other: when both are installed they chain (project-architect's Preflight can invoke `reverse-engineer`; `reverse-engineer`'s handoff can invoke project-architect's forward flow), and each works standalone.
- **Standalone deliverable** — even without project-architect installed, a run emits `docs/reverse-engineer/{INVENTORY,DEPENDENCIES,REQUIREMENTS,SUMMARY}.md`, a `RECOVERED_DESIGN.md`, and the schema-3.1 state file.
- **Research-grounded, source-level tooling** — leverages installed analysis tools (`scc`, Semgrep, `syft`/`grype`/`trivy`, `jdeps`/`cargo`/`go`, `ctags`, and the deps.dev / OSV / endoflife.date APIs) with `command -v` probing and graceful degradation, recording the provenance of every finding. Source-level recovery only — binary reverse-engineering is out of scope.
- **Self-healing error handling** — on a blocker, the orchestrator surfaces a concise informational error state (what failed, what's known, what's at risk) and offers two paths: write a diagnostic report and stop, or propose a fix from the information already gathered and continue after you approve.
- **Safe by construction** — read-only over the analyzed project (writes only its own output directory), never echoes a discovered secret (reports type + location only), and gates anything that executes the target's code behind explicit consent.

Ships from the shared `alexfordlabs` marketplace alongside `project-architect`. MIT licensed. Built by Alex Ford Labs.
