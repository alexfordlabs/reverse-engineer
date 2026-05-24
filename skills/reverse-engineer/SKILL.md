---
name: reverse-engineer
description: Use when the user wants to reverse-engineer, understand, or analyze an unfamiliar source codebase they didn't write — a foreign/brownfield project, a half-built implementation, or a folder of code and notes with no docs. Triggers on "reverse engineer this," "what does this project do and how is it built," "someone handed me this repo," recovering architecture/requirements/design from existing source, or auditing a foreign project's real dependency versions, CVEs, and EOL/runtime status from live sources rather than model memory. Produces a read-only inventory, dependency map, inferred requirements, and a reviewable recovered design. Do NOT use for projects already set up by project-architect (they carry architect state — use re-architect or upgrade-project instead), or for binary/compiled reverse-engineering such as decompiling APKs or executables and extracting bytecode/smali — this handles readable source only.
---

<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# Reverse Engineer

You orchestrate a 6-phase recovery of a **foreign / brownfield** project — one project-architect (PA) never produced — and feed the result into PA's forward engine. You do **not** do the heavy reading yourself: you dispatch 6 specialised analysis agents, **thread each one's output into the agents downstream**, drive three `bin/` helpers, and synthesize. The phases are **P0 Detect → P1 Understand → P2 Recover design → P3 Triage → P4 Emit → P5 Handoff**. Load references on-demand.

**The premise that shapes everything:** the foreign project's **code is ground truth**; its docs may have drifted; its tech almost certainly post-dates your training cutoff. So the recovery is evidence-based (every claim cites `file:line` or a tool output), **research-augmented** (current versions/EOL/CVEs from LIVE sources, never memory — `landscape-researcher`), and **validated, not trusted** (a human triages it before it's committed — P3).

**Output style:** surface clean informational progress per [`../../references/output-style.md`](../../references/output-style.md). **Open the run with the `re-ui` banner, and lead every phase boundary (P0 → P5) with the advancing progress bar (the per-phase ladder in `output-style.md` §1) + `✓`/`→`/`✗` step lines — rendered INLINE in your reply as markdown** (the banner + bar are your curated narration; put them in a fenced block in the reply, never left only in a tool-result block). Capture *mechanical* output (the `re-detect` verdict JSON, each agent's return, `re-emit`'s write log, the agents' tool stdout) and never dump it raw. On a BLOCKER, run the §3 R2 self-heal protocol (informational error → `AskUserQuestion`: report-and-stop or self-heal-and-continue).

**Dispatch discipline:** every agent is dispatched **`model: opus`, maximum effort**, prepending the **Shared dispatch header** from [`../../references/dispatch-prompts.md`](../../references/dispatch-prompts.md) (the model directive + the read-only-over-target rule + the identity-hygiene HARD RULE + the post-return scrub) and then the per-agent `[INPUTS]` (the threaded upstream content) + `[TASK]` from that same file. See [§ Dispatch discipline](#dispatch-discipline).

## Phase order

```
P0. Detect & scope     — bin/re-detect verdict; defer to project-architect if architect state present;
                         else confirm a foreign project + scope (default whole-repo, per-run override)
P1. Understand         — code-inventory (FIRST) → dependency-mapper + requirements-extractor →
                         landscape-researcher; characterization-tester is OPT-IN + consent-gated
P2. Recover design     — design-recoverer (consumes ALL upstream) → RECOVERED_DESIGN + flat keyspace
P3. Triage & validate  — present the recovered design for keep / correct / fill; low-confidence FIRST
P4. Emit               — bin/re-emit writes the artifact set + the schema-3.1 state;
                         ingest the triaged keyspace via re-ledger import-decisions
P5. Handoff            — emit the shared contract; offer to invoke project-architect's forward flow
```

`${CLAUDE_PLUGIN_ROOT}` is the plugin root; the helpers are `${CLAUDE_PLUGIN_ROOT}/bin/re-detect`, `…/bin/re-emit`, `…/bin/re-ledger`. The output project (the recovered project's root, where artifacts are written) is `<out>` — by default the target itself, unless the user directs the recovery elsewhere.

## State & resumability

The recovery's state lives at `<out>/docs/_architect_state.json` — PA's **schema 3.1**, written ONLY by `bin/re-ledger` (never hand-rolled). It carries `origin: "reverse-engineered"`, the `recovery` provenance block, the flat `decisions` keyspace, and the **`reverse_engineer_progress`** sub-ledger.

**Record progress at every phase boundary** via `re-ledger set-substep <phase> <substep>` so an interrupted run **resumes** — and so PA's situation-router can detect a half-finished recovery (the sub-ledger mirrors PA's `rearchitect_progress`; its entries carry `.complete` + `.completed_at`, which PA's `detect` reads):

```bash
${CLAUDE_PLUGIN_ROOT}/bin/re-ledger --state "$OUT/docs/_architect_state.json" set-substep P1 "dependency-mapper dispatched"
```

**On startup**, if `<out>/docs/_architect_state.json` already exists with `origin: "reverse-engineered"`, read `reverse_engineer_progress`, print a one-line resume summary, and **jump to the first phase that is not `complete`** — do NOT re-run finished passes (reuse their recorded sub-ledger + the already-emitted artifacts; see output-style §2). The state is `init`'d lazily by `re-emit` at P4 (or you may `re-ledger init` earlier if you want the sub-ledger from P0); either way `re-ledger` is the only writer.

## Input-threading (the spine — read this before dispatching anything)

The recovery is a **pipeline**: each agent builds on the agents before it, so you MUST pass each agent's **returned content** as the input to the downstream agents that consume it. The agents' own `## Inputs you receive` sections specify exactly what each expects; the canonical chain is:

```
                          ┌──────────────────────┐
code-inventory ──────────▶│ dependency-mapper     │──┐
   (FIRST; no upstream)   │ requirements-extractor │  │  (both consume code-inventory)
                          └──────────────────────┘  │
                                     │               │
              dependency-mapper's external-dep table │
                                     ▼               │
                          landscape-researcher ──────┤  (annotates dependency-mapper's table;
                          (+ code-inventory detections)  also fed code-inventory's detections)
                                                     │
        (opt-in, consent-gated)                      │
        characterization-tester ◀── inventory + requirements + landscape
                                                     │
                                                     ▼
                          design-recoverer ◀── ALL upstream (inventory + dependency_map
                                               + requirements + landscape)
```

| Agent | Threaded INPUT (the upstream content you pass it) | Produces (threaded onward) |
|---|---|---|
| `code-inventory` | — (dispatched first; only `re-detect`'s verdict + scope) | the **inventory** (census, entry points, data model, components, ranked symbols) |
| `dependency-mapper` | **inventory** | the **dependency_map** + the external-dep inventory table (version/status/CVE slots empty) |
| `requirements-extractor` | **inventory** (+ any docs surfaced in P0) | the **requirements** (RULE-NNN G/W/T rules + entity catalog) |
| `landscape-researcher` | code-inventory's **detections** + dependency-mapper's **external-dep table** | the **landscape** (current_stable/versions_behind/status/CVEs filled — annotates the table) |
| `characterization-tester` *(opt-in)* | **inventory** + **requirements** + **landscape** | golden-master tests + a behavior report (or a PLAN if no consent) |
| `design-recoverer` | **inventory** + **dependency_map** (annotated) + **requirements** + **landscape** | `RECOVERED_DESIGN` + the **flat decisions keyspace** |

Pass the upstream output **as the agent returned it** (the full produced content, not a paraphrase) so every downstream agent reasons over real evidence. The `[INPUTS]` blocks in `references/dispatch-prompts.md` have a `{{...}}` slot for each threaded input; fill it from the upstream agent's return. **A dropped thread is the worst failure here** — `design-recoverer` with no `landscape` describes stale conventions; `requirements-extractor` with no `inventory` re-censuses files it shouldn't. Never dispatch a downstream agent before its upstream input is in hand.

---

## P0 — Detect & scope

**Goal:** confirm there is a foreign project to recover (and that it isn't already a PA project), then fix the scope. The target is **readable source** (code, docs, notes) — this is not binary/compiled reverse-engineering (decompiling APKs/executables, extracting bytecode); `re-detect`'s material probe is source-file based, so a binary-only target surfaces as `nothing-to-do`.

1. **Run the detection helper** (capture, don't dump — output-style §1):
   ```bash
   VERDICT="$(${CLAUDE_PLUGIN_ROOT}/bin/re-detect "$TARGET")"
   ```
   Parse `.action` from the verdict JSON:
   - **`action: "defer-to-project-architect"`** (a `docs/_architect_state.json` is present) → this is a PA project, not a foreign one. **DEFER**: tell the user this project already has project-architect state, and that PA's own flows own it — `/re-architect` (recover from its own docs/ADRs) or `/upgrade-project` (bring an old-version project forward). Do NOT run the recovery pipeline. Stop cleanly.
   - **`action: "nothing-to-do"`** (no project material — vendored/build/cache dirs are excluded by `re-detect`) → tell the user there's no first-party source/docs/structure to recover under the target, and stop.
   - **`action: "reverse-engineer"`** (`is_foreign: true`) → proceed.
2. **Surface the material** as one informational line from `verdict.material` (`source_file_count`, top `languages`, `manifests`, `has_docs`) and note the `verdict.tools_available` probe (which analysis tools are installed — passed to every agent for graceful degradation):
   `✓ P0: foreign project — {{N}} source files [{{top langs}}], manifests {{…}}, docs {{present|none}}`.
3. **Confirm scope.** The opinionated default is **whole-repo** (`verdict.scope_default`). Offer the user a per-run override to a subpath (e.g. "just `packages/api/`"). Record the chosen `scope`.
4. **Record progress:**
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/bin/re-ledger --state "$OUT/docs/_architect_state.json" set-substep P0 "detected foreign; scope={{scope}}"
   ```
   (If the state doesn't exist yet, `re-ledger init --recovered-by reverse-engineer --source-summary "{{material summary}}"` first, or let `re-emit` init it at P4 — `re-ledger` is the only writer either way.)

> **Surface any docs found** (READMEs, `docs/*.md`, design notes from `verdict.material.docs`) so you can pass them to `requirements-extractor` + `design-recoverer` as `docs_findings` — they treat docs as a *claim to verify against code*, never as ground truth.

---

## P1 — Understand (code is ground truth)

**Goal:** recover the structure, relationships, technology ground-truth, and inferred requirements. Four analysis passes (+ one opt-in), dispatched in dependency order with the threading above.

**Dispatch order (this order is load-bearing — it IS the threading):**

1. **`code-inventory` FIRST** — it has no upstream agent input; everything else builds on it.
   - Dispatch `reverse-engineer:code-inventory` (`model: opus`, max effort) with the **Shared dispatch header** + the **P1 — code-inventory** body from `references/dispatch-prompts.md`. Fill `target_root` / `scope` / `tools_available` from `re-detect`'s verdict.
   - `set-substep P1 "code-inventory dispatched"` → on return, capture its **inventory** content; `✓ P1: inventory — {{components}} components, {{entities}} data entities, ranked symbols`.
2. **`dependency-mapper` + `requirements-extractor` next, in PARALLEL** — both consume ONLY `code-inventory`'s output, share no state, and have no ordering dependency between them. Dispatch them **in a single message with two tool calls** (output-style §2):
   - `reverse-engineer:dependency-mapper` — header + the **P1 — dependency-mapper** body; thread `inventory` into its `{{...}}` slot.
   - `reverse-engineer:requirements-extractor` — header + the **P1 — requirements-extractor** body; thread `inventory` (+ `docs_findings` from P0) into its slots.
   - On return: capture the **dependency_map** (with its external-dep inventory table) and the **requirements** (RULE-NNN rules). `set-substep P1 "dependency-mapper + requirements-extractor complete"`.
3. **`landscape-researcher` after `dependency-mapper`** — it annotates dependency-mapper's external-dependency table, so it needs that table (plus code-inventory's tech detections) as input.
   - Dispatch `reverse-engineer:landscape-researcher` (`model: opus`) with the header + the **P1 — landscape-researcher** body; thread code-inventory's **detections** + dependency-mapper's **external-dep table** into the `detections.{{...}}` slots, **and thread `cascade_reference_path: ${CLAUDE_PLUGIN_ROOT}/references/current-version-cascade.md`** — the **absolute** path to the cascade reference. (A dispatched subagent has no plugin base directory, so it cannot resolve a plugin-relative reference path from its own cwd; the orchestrator, whose loaded skill knows `${CLAUDE_PLUGIN_ROOT}`, provides the absolute path.) Pass `offline` if the session has no network (it degrades honestly — **never** falls back to training data).
   - On return: capture the **landscape** (the merged table with `current_stable`/`versions_behind`/`status`/`CVEs`/`source`/`confidence` filled). **Merge** its findings back into the dependency_map's table — the two reconcile into one annotated supply surface for `design-recoverer` and for `DEPENDENCIES.md`. `✓ P1: landscape — {{EOL/stale/CVE headline}}` (e.g. `Node 16 PAST-EOL; express 2 majors behind; 1 high CVE`).
4. **`characterization-tester` — OPT-IN + CONSENT-GATED (it EXECUTES the foreign code).** Do **not** run it by default.
   - **Ask the user explicitly** whether to pin current observable behavior with characterization (golden-master) tests, stating plainly that **this runs the target's code** (sandboxed, no prod creds, no network unless allowed). Only on an unambiguous **yes** do you dispatch it with `consent_granted: true`.
   - Dispatch `reverse-engineer:characterization-tester` (`model: opus`) with the header + the **P1 (opt-in) — characterization-tester** body; thread `inventory` + `requirements` + `landscape`. The agent itself enforces a second pre-flight summarize-then-yes before executing anything; honor any tighter scope the user grants ("pure functions only").
   - **If the user declines** (or doesn't unambiguously consent): skip execution. (The agent, if dispatched without consent, returns a PLAN only — nothing runs. Default: don't dispatch it at all.)
   - `set-substep P1 "characterization {{ran|declined}}"`.

`✓ P1: Understand complete — inventory + deps + landscape + requirements{{ + characterization}}`. Surface each agent's ≤20-line return as one rolled-up line per pass, never the raw tool dumps inside them.

---

## P2 — Recover design

**Goal:** synthesize the four evidence streams into a reviewable design + the machine-readable decisions keyspace.

1. Dispatch the synthesis keystone `reverse-engineer:design-recoverer` (`model: opus`, max effort) with the **Shared dispatch header** + the **P2 — design-recoverer** body from `references/dispatch-prompts.md`. **Thread ALL upstream content** into its `{{...}}` slots: `inventory` + the **annotated** `dependency_map` (with landscape-researcher's findings merged in) + `requirements` + `landscape` (+ `docs_findings`). Pass `semgrep_mcp_available` / `security_review_available` so it can INVOKE the security dimension (`/security-review` + Semgrep), else EMULATE. **Also thread `recovered_design_template_path: ${CLAUDE_PLUGIN_ROOT}/references/templates/RECOVERED_DESIGN.md`** — the **absolute** path to the output template the subagent matches (same reason as above: a dispatched subagent cannot resolve a plugin-relative reference path itself, so the orchestrator provides the absolute path).
2. On return, capture **both** outputs:
   - the **`RECOVERED_DESIGN` content** — the reflexion recovery (hypothesis + convergence / divergence / absence), recovered stack (grounded on landscape-researcher's current findings), component boundaries, structural-health grade, the architecture-critic's read, interface fragments (OpenAPI + mermaid `erDiagram`), and the decisions table. Shape-compatible with PA's `RECOVERED_DESIGN.md` (matches `references/templates/RECOVERED_DESIGN.md`).
   - the **flat decisions keyspace** — `{canonical-PA-key-or-project-slug: value}`, where every row is **value · confidence · evidence** and **nothing is invented** (no evidence → omitted or recorded `Low` with the gap stated). This is the half P4 ingests.
3. `set-substep P2 "design recovered"` → `✓ P2: design recovered — {{N}} decisions ({{low}} low-confidence); structural-health {{band}}`.

> **Low-confidence is a SUCCESS, not a failure** — it routes the human's attention in triage (P3). `design-recoverer` never silently resolves a conflict between inputs; it surfaces it as a `Low` row. Carry that forward unchanged.

---

## P3 — Triage & validate (the human gate — recovery is *validated, not trusted*)

**Goal:** a human keeps / corrects / fills the recovered decisions **before** anything is emitted or carried forward. This mirrors project-architect's `/re-architect` triage (its Step 3) — the same discipline that makes a recovery trustworthy enough to feed a forward engine.

1. **Present the recovered design for review, low-confidence rows FIRST.** Recovery reconstructs; the human decides. Order the decisions table so the **lowest-confidence rows (`Low`, then `Med`) come first** — those are the ones that need scrutiny; the `High`-confidence, directly-evidenced rows need a glance, not a debate. For each row show its `value`, `confidence`, and `evidence` (the `file:line` or tool output) so the human can judge it.
2. **Offer three actions per decision** (the triage verbs):
   - **keep** — accept the recovered `value` as-is (the default for a `High`-confidence, well-evidenced row).
   - **correct** — the recovered `value` is wrong → the user supplies the right one (common for a `Med`/`Low` `appears` row, or a doc-vs-code conflict the recovery surfaced).
   - **fill** — the recovery found the *shape* of a decision but not its value (a `Low` row, or a gap noted in `SUMMARY.md`) → the user supplies the missing value.
   Also surface the **open-questions / SME questions** `requirements-extractor` and `design-recoverer` raised, and any `characterization-tester` spec-discrepancies — those are decisions the human owes an answer on.
3. **The gate gates:** triage happens **before** P4 writes the decisions into the state. Apply the user's keep/correct/fill edits to the flat keyspace, producing the **triaged keyspace** — the validated set that P4 ingests. Do NOT emit decisions the user hasn't seen.
4. `set-substep P3 "triaged"` → `✓ P3: {{K}} kept, {{C}} corrected, {{F}} filled — design validated`.

> This is also where the recovery stays **honest**: a value the user couldn't confirm stays flagged (e.g. recorded `Low`) rather than being promoted to a confident fact. The triaged keyspace is the human-validated truth; everything downstream builds on it.

---

## P4 — Emit (the standalone deliverable)

**Goal:** write the complete recovery artifact set + the schema-3.1 state, and ingest the triaged decisions. Usable standalone — even if project-architect is not installed.

1. **Write the artifact set** via the emit helper, passing each agent's produced content as a file (write each captured agent return to a temp file, then pass its path). Capture `re-emit`'s write log (don't dump it):
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/bin/re-emit --out "$OUT" \
     --recovered-by "reverse-engineer" \
     --source-summary "{{material summary from P0}}" \
     --inventory "$INVENTORY_MD" \
     --dependencies "$DEPENDENCIES_MD" \
     --requirements "$REQUIREMENTS_MD" \
     --summary "$SUMMARY_MD" \
     --recovered-design "$RECOVERED_DESIGN_MD" \
     ${CHAR_DIR:+--characterization-dir "$CHAR_DIR"} >/dev/null
   ```
   - `DEPENDENCIES.md` is the **merged** dependency-mapper + landscape-researcher table (you reconciled them in P1).
   - `SUMMARY.md` is the recovery report YOU compose (what was found, overall confidence, the gaps + low-confidence triage targets, which passes ran with tool provenance) — the standalone deliverable's executive summary.
   - `--characterization-dir` only if characterization ran (opt-in).
   - `re-emit` writes ONLY under `<out>/docs/` (never the analyzed target's code), writes a skeleton placeholder for any artifact you didn't provide (so the set is always complete), and **ensures the schema-3.1 state** by delegating to `re-ledger init` (only if absent — an existing state is preserved). See [`../../references/artifacts.md`](../../references/artifacts.md) for the full artifact-set contract.
2. **Ingest the triaged keyspace** into `.decisions` in ONE bulk merge via `re-ledger import-decisions`. Write the triaged flat keyspace (the P3 output) to a temp JSON file `{canonical.key: scalar}`, then:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/bin/re-ledger --state "$OUT/docs/_architect_state.json" import-decisions "$TRIAGED_KEYSPACE_JSON"
   ```
   `import-decisions` merges the flat object into `.decisions` (raw values; LITERAL dotted keys kept flat; merge-on-top so nothing pre-existing is clobbered; idempotent) and stamps `decisions_schema_version`. It **mirrors PA's `architect-ledger import-decisions` exactly**, so the keyspace lands in the schema-3.1 `.decisions` that PA's own `import-decisions` consumes identically — see [`../../references/interop-contract.md`](../../references/interop-contract.md).
3. `set-substep P4 "emitted"` → `✓ P4: artifact set written → docs/reverse-engineer/ + RECOVERED_DESIGN + schema-3.1 state ({{N}} decisions)`.

---

## P5 — Handoff (feed project-architect)

**Goal:** make the recovery's value reachable — standalone, and (if PA is installed) carried forward seamlessly.

1. **The shared contract is already on disk** (P4): `<out>/docs/RECOVERED_DESIGN.md` + `<out>/docs/_architect_state.json` (schema 3.1, `origin: "reverse-engineered"`, the flat triaged `decisions` keyspace). This is the standalone deliverable AND the hand-off surface — the three artifacts both plugins speak, defined in [`../../references/interop-contract.md`](../../references/interop-contract.md). Update `recovery.confidence_summary` if useful via `re-ledger set-recovery confidence_summary "{{…}}"`.
2. **Offer to invoke project-architect's forward flow** — if `project-architect` is installed (the `project-architect` skill is available):
   - Offer to hand the recovered, triaged design to PA's forward engine to generate the full design-doc set / ADRs / `CLAUDE.md` / `.claude/` tooling + a scaffold-gap analysis, **seeded from the recovered decisions**. The seam is the contract, not code: PA reads the schema-3.1 state, ingests the flat keyspace via its own `import-decisions` (the exact counterpart of P4's `re-ledger import-decisions` — same keyspace, identical merge), and its `/re-architect` triage consumes `RECOVERED_DESIGN.md` identically to its own `design-recovery` output.
   - **On an unambiguous yes, invoke PA's forward flow directly** — point it at `<out>` so PA reads the on-disk schema-3.1 contract (the recovered state + `RECOVERED_DESIGN.md` + the flat `decisions`). Because the recovery already wrote PA's native state, no conversion step is needed; PA picks up where the recovery left off. Per [`../../references/interop-contract.md` § reverse-engineer → project-architect](../../references/interop-contract.md), this hand-off is **not** a hard dependency — it is offered only when PA is present.
3. **If project-architect is NOT installed:** print how to install it (`claude plugin marketplace add alexfordlabs/…` then `claude plugin install project-architect`) and state that the recovery contract (`RECOVERED_DESIGN.md` + the schema-3.1 state + the flat decisions keyspace ingestible by PA's `import-decisions`) is ready for it. The standalone artifacts (`docs/reverse-engineer/` + `SUMMARY.md`) stand on their own regardless.
4. `set-substep P5 "handoff offered"` → `✓ P5: handoff ready — recovery complete`.

---

## Dispatch discipline

Every agent dispatch in P1–P2 follows the same shape (this is the family discipline mirrored from project-architect):

- **`model: opus`, maximum effort, extended thinking** — always. Never select a smaller/faster model for any agent in this pipeline, even a mechanical-seeming one. (Per the workspace's durable subagent-model rule.)
- **Prepend the Shared dispatch header** from `references/dispatch-prompts.md` verbatim — it carries the model directive, the **read-only-over-target** rule, the **identity-hygiene HARD RULE** (*never echo a secret value* — report type + location + nothing more), and the **post-return scrub**. Then append the per-agent `[INPUTS]` (the threaded upstream content) + `[TASK]` from that file.
- **Thread the inputs** per [§ Input-threading](#input-threading) — fill each `{{...}}` slot with the upstream agent's returned content. A downstream agent is never dispatched before its upstream input is in hand.
- **Identity hygiene is non-negotiable.** A foreign codebase may contain secrets (API keys, `.env` values, private keys) and a real person's PII. No agent ever echoes a secret value — it reports type + location only. After each agent returns, the **post-return scrub** in the header has the agent confirm nothing it returns contains a secret value or a forbidden identity term; if the orchestrator itself surfaces an agent's finding, it carries the same redaction (type + location, never the value).
- **Consent gate for `characterization-tester`** — it is the ONLY agent that executes the foreign code; it runs ONLY after explicit user opt-in (and its own pre-flight summarize-then-yes), sandboxed.
- **Capture, don't dump** — each agent returns a tight summary + its produced content; surface ONE rolled-up step line per pass; never paste the agent's internal `[STEP N/M]` lines or the raw tool stdout (SBOMs, graph dumps) into the transcript (output-style §1).

## Errors — informational + self-healing

On any BLOCKER (an agent returns an informational-error state, a helper exits non-zero, a required output is missing, a narrowed scope yields nothing), run the **R2 self-heal protocol** in [`../../references/output-style.md` §3](../../references/output-style.md): (1) surface a concise **informational error state** — what failed / what's known so far (from the sub-ledger + the agents' returns) / what's at risk — never a raw trace; (2) call **`AskUserQuestion`** offering exactly two paths — **write a report and stop** (clean halt, nothing half-applied) or **self-heal and continue** (the orchestrator proposes concrete remediations *derived from the gathered information*, applies them **only after the user approves**, and resumes from where it stopped). Never silently fail; never paste a stack trace. Success stays terse; failure surfaces its detail.

## When to consult what

| Question | Source |
|---|---|
| The narration + error convention | [`../../references/output-style.md`](../../references/output-style.md) |
| The Shared dispatch header + each agent's `[INPUTS]`/`[TASK]` body | [`../../references/dispatch-prompts.md`](../../references/dispatch-prompts.md) |
| The P4 artifact-set contract (each file, its source agent, the state) | [`../../references/artifacts.md`](../../references/artifacts.md) |
| The shared interop contract with project-architect (schema 3.1, the flat keyspace, both invocation directions) | [`../../references/interop-contract.md`](../../references/interop-contract.md) |
| The current-version cascade (landscape-researcher's procedure) | [`../../references/current-version-cascade.md`](../../references/current-version-cascade.md) |
| The `RECOVERED_DESIGN.md` shape (PA-compatible) | [`../../references/templates/RECOVERED_DESIGN.md`](../../references/templates/RECOVERED_DESIGN.md) |
| What each agent expects + produces | the agent's own `agents/<agent>.md` (its `## Inputs` + `## Output structure`) |
| The detection verdict shape | `bin/re-detect -h` |
| The emit mechanics + flags | `bin/re-emit -h` |
| The state writer subcommands (`init`/`set-decision`/`import-decisions`/`set-substep`/`set-recovery`) | `bin/re-ledger -h` |

---

*★ Skillfully made with [reverse-engineer](https://github.com/alexfordlabs/reverse-engineer).*
