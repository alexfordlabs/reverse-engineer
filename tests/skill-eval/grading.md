<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# reverse-engineer — functional grading (skill-creator grader lens)

Graded the [Part-1 functional eval cases](eval.md) of running `SKILL.md` inline
against `tests/fixtures/e2e-foreign-node/` on 2026-05-24, using the skill-creator
grader's standard: PASS requires *genuine substance* (real evidence), not surface
compliance. Every step below used real tooling — `bin/re-detect`, a LIVE
syft/deps.dev/OSV/grype/endoflife.date cascade, and real `bin/re-emit`/`bin/re-ledger`.

## Grades

| # | Expectation | Verdict | Evidence |
|---|---|---|---|
| Triggered? | the skill fires on recovery intent | **PASS** | A nested `claude -p` on "i inherited this node repo, reverse-engineer it…" invoked the `Skill` tool on the reverse-engineer command (observed `tool_use name=Skill`). |
| Detect foreign? | P0 classifies foreign, not PA, not empty | **PASS** | `re-detect` → `{"action":"reverse-engineer","is_foreign":true,"has_architect_state":false}`; material = 3 JS files, `package.json`, README; `tools_available` probe returned (syft/grype/trivy/semgrep/scc present). |
| Flag stale dep? | express flagged behind + CVEs, from LIVE sources | **PASS** | deps.dev **and** npm registry agree current stable = **5.2.1** (pinned 4.16.0 = 1 major behind). OSV **and** grype agree on 2 CVEs: GHSA-rv95-896h-c2vc (CVE-2024-29041, fixed 4.19.2) + GHSA-qw6h-vgh9-j6wx (CVE-2024-43796, fixed 4.20.0). Two agreeing live sources each → `confidence: high`. |
| Flag EOL runtime? | Node 16 past-EOL, from a live source | **PASS** | endoflife.date `nodejs`: Node 16 `isEol: true` (last release 16.20.2). |
| Emit artifacts + 3.1 state? | full set + schema-3.1 `origin: reverse-engineered` | **PASS** | `re-emit` wrote `RECOVERED_DESIGN.md` + `docs/reverse-engineer/{INVENTORY,DEPENDENCIES,REQUIREMENTS,SUMMARY}.md` + `_architect_state.json`. State: `schema_version:3.1`, `origin:reverse-engineered`, `recovery.recovered_by:reverse-engineer` with a real `recovered_at` stamp, 8 flat decisions, `decisions_schema_version:1.0`, `reverse_engineer_progress.P4` recorded. |
| Decisions keyspace correct? | flat, dotted keys LITERAL (PA interop) | **PASS** | `import-decisions` merged 8 keys; `backend.framework` stored as a **flat literal** key (not nested under `backend`); idempotent on re-run (count stayed 8). This is the exact keyspace PA's own `import-decisions` consumes. |
| Coherent orchestration? | P0→P5 order; threading; read-only target | **PASS** | Phases ran in order; landscape findings merged into the dependency table before design synthesis; **the fixture was never modified** (git status clean; no state leaked into the target) — the read-only-over-target rule held. |
| Low-confidence surfaced? | not silently resolved | **PASS** | `auth` recorded `Low` (absence across routes); `data.persistence` recorded `Med` (in-memory) — carried forward as triage targets, not invented. P3 (human gate) precedes P4 (emit). |
| Negative case | greenfield does NOT trigger | **PASS (by design + description)** | "starting a brand-new Rust CLI from scratch" is project-architect's job; P0 would find nothing to recover, and the optimized description now scopes the skill to existing/foreign code. |

**Aggregate: 9/9 PASS.**

## Grader critique of the evals themselves

- The functional cases are *discriminating*: they'd fail for a skill that hallucinated versions from memory (the live cascade is what makes "is it up to date?" pass), and the read-only assertion catches a skill that wrote into the target.
- The cascade findings are **cross-validated** (two agreeing live sources per claim), which is stronger than a single-source check — it directly exercises the `confidence: high` path.
- **Gap acknowledged:** the P1/P2 agent *reasoning* (code-inventory ranking, design-recoverer reflexion) was followed inline by the orchestrator rather than dispatched as 6 separate `model: opus` subagents (can't spawn sub-subagents from this context). The artifact *shapes* and the bin/-helper *mechanics* are real; the multi-agent dispatch fidelity is **deferred to the W7 installed-plugin live eval**, where the skill runs as an installed plugin and dispatches real subagents.
