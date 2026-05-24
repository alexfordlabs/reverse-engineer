<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# reverse-engineer — skill-creator eval set

A tidy, durable record of the [`skill-creator`](https://github.com/anthropics/skills)
eval pass on `skills/reverse-engineer/SKILL.md`. Two parts:

1. **Functional eval cases** — does the skill *do the right thing* when triggered? (P0→P5 against a real foreign fixture.)
2. **Trigger eval queries** — does the skill *fire when it should and stay quiet when it shouldn't*? (feeds `improve_description.py`.)

The fixture under test is `tests/fixtures/e2e-foreign-node/` — a foreign Express
`widget-api` deliberately pinning `express@4.16.0` (one major behind current
stable) on `engines.node >=16 <17` (Node 16 is past end-of-life). The raw eval
transcripts / JSON from running `improve_description.py` are scratch and
gitignored (`tests/skill-eval/_runs/`); this file is the curated summary.

---

## Part 1 — Functional eval cases (the orchestration)

Each case is a realistic trigger prompt + the EXPECTATIONS a grader checks. The
"Run" column records what actually happened when the SKILL.md was followed inline
against the fixture on 2026-05-24 (real `bin/re-detect` + the live
syft/deps.dev/OSV/grype/endoflife.date cascade + real `bin/re-emit`/`re-ledger`).

### Case 1 — "reverse-engineer this project"

> **Prompt:** "reverse-engineer this project at tests/fixtures/e2e-foreign-node — I inherited it and have no idea how it's put together."

**Expectations**
- E1.1 The skill TRIGGERS (a reverse-engineer / recovery skill is the right tool).
- E1.2 P0 classifies the target **foreign** (`action: reverse-engineer`, `is_foreign: true`, no architect state).
- E1.3 The cascade flags the **stale `express`** (1 major behind 5.2.1) from a LIVE source.
- E1.4 The cascade flags **Node 16 past-EOL** from endoflife.date.
- E1.5 P4 emits the full artifact set + a **schema-3.1 `origin: reverse-engineered`** state.
- E1.6 The orchestration is coherent (P0→P5 in order; agents threaded; target read-only).

**Run:** PASS on all. `re-detect` → `action: reverse-engineer`. deps.dev + npm
registry agree express stable = 5.2.1 (1 major behind). endoflife.date → Node 16
`isEol: true`. `re-emit` wrote `RECOVERED_DESIGN.md` + 4 `docs/reverse-engineer/*.md`
+ schema-3.1 state (`origin: reverse-engineered`, 8 flat decisions, dotted keys
kept literal/flat). Fixture untouched (git clean).

### Case 2 — "what does this codebase do and is it up to date?"

> **Prompt:** "what does this codebase do, and are its dependencies and runtime up to date? it's a node service someone handed me, in tests/fixtures/e2e-foreign-node."

**Expectations**
- E2.1 The skill TRIGGERS (understand foreign code + currency check is its core).
- E2.2 It explains *what it does* from code evidence (REST user API: `/health`, `/users` list+create, `User` model + validation).
- E2.3 "Up to date?" is answered from **live** sources, not memory — express 1 major behind + 2 CVEs; Node 16 EOL.
- E2.4 Every currency claim cites a source + confidence (`high` where two sources agree).

**Run:** PASS. The currency answer is exactly the cascade's differentiator —
deps.dev/npm (stable 5.2.1), OSV/grype (CVE-2024-29041 fixed 4.19.2;
CVE-2024-43796 fixed 4.20.0), endoflife.date (Node 16 EOL). All `confidence: high`
(two agreeing live sources each). The "what it does" answer is grounded in
`models/user.js` + `routes/users.js` + `server.js` (file:line cited).

### Case 3 — "recover the design of tests/fixtures/e2e-foreign-node"

> **Prompt:** "recover the design of the project in tests/fixtures/e2e-foreign-node and write it somewhere I can review before anything is changed."

**Expectations**
- E3.1 The skill TRIGGERS (design recovery is the headline capability).
- E3.2 Produces a **RECOVERED_DESIGN** + a **flat decisions keyspace** (value · confidence · evidence).
- E3.3 Low-confidence items are surfaced for triage, NOT silently resolved (e.g. persistence-durability intent, auth absence).
- E3.4 Nothing is written into the target itself — artifacts land under `<out>/docs/`; the human triages BEFORE emit.

**Run:** PASS. `RECOVERED_DESIGN.md` carries the reflexion recovery (hypothesis /
convergence / divergence / absence), recovered stack grounded on the live
landscape, a structural-health grade, interface fragments, and the decisions
table. `auth` recorded `Low` (absence across routes) and `data.persistence`
recorded `Med` (in-memory) — both carried forward as triage targets rather than
invented. P3 (human gate) precedes P4 (emit) per the skill.

### Case 4 (negative / near-miss) — "this is MY project, set it up"

> **Prompt:** "I'm starting a brand-new Rust CLI from scratch — help me set up the project architecture and pick a stack."

**Expectation**
- E4.1 The skill does **NOT** trigger; this is greenfield → `project-architect`'s job, not reverse-engineer's. (reverse-engineer is for *foreign/existing* code; P0 itself would find nothing to recover.)

**Run:** PASS (by design + by description). The optimized description scopes the
skill to *existing / foreign / brownfield* code and recovery intent, so a
from-scratch greenfield setup routes to project-architect instead.

---

## Part 2 — Trigger eval queries (for `improve_description.py`)

20 realistic queries (≈10 should-trigger, ≈10 should-not), with the should-not set
weighted to genuine near-misses (greenfield setup, plain code review, a bug-fix, a
single-file read, a project-architect-owned re-architect). Machine-readable copy:
[`trigger-eval.json`](trigger-eval.json). These are the queries fed to the
skill-description optimizer; the run is summarized in
[`description-optimization.md`](description-optimization.md).
