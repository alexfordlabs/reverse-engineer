<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# Output style — fast, quiet, honest

How the `reverse-engineer` orchestrator (`skills/reverse-engineer/SKILL.md`) narrates a run. The pipeline runs a lot of mechanical machinery: `bin/re-detect`'s JSON verdict, six analysis-agent dispatches that each return ≤20-line summaries, `bin/re-emit`'s artifact-write provenance, `bin/re-ledger` echoes, and the analysis tools the agents shell out to (`scc`, `syft`, `grype`, `madge`, the dependency-graph dumps, the SBOM JSON). Left unattended that machinery floods the user's transcript with raw chatter. **This convention turns that plumbing into clean, advancing, informational progress** — the user should see *what the recovery is doing*, not *how the tools say it* — and specifies the **self-healing error path** for when a phase hits a BLOCKER.

Mirrors project-architect's `references/output-style.md` (the family discipline); adapted to this plugin's P0–P5 pipeline. Two rules, in priority order: **capture, don't dump** (§1) · **be fast** (§2) — then the **error protocol** (§3).

---

## 1. Output discipline — capture, don't dump

The orchestrator runs mechanical scripts + agent dispatches; the user reads a curated narrative. These never both happen at once.

- **Capture, then summarize.** Run a mechanical step with its stdout **captured** — assign to a variable (`VERDICT="$(bin/re-detect "$TARGET")"`) or redirect (`>/dev/null`) — then parse it and emit ONE concise informational line per meaningful step. Examples of the line you emit (NOT the raw output you captured):
  - `✓ P0: foreign project detected — 142 source files (TS/Go), 2 manifests, README present`
  - `→ P1: dispatching code-inventory…`
  - `✓ P1: inventory recovered — 6 components, 9 data entities, top-50 ranked symbols`
  - `✓ P1: dependency map — 318 edges, 2 cycles, 1 god-component; 24 external deps`
  - `✓ P1: landscape — Node 16 PAST-EOL, express 2 majors behind, 1 high-severity CVE`
  - `✓ P2: design recovered — 28 decisions (5 low-confidence); structural-health B`
  - `✓ P4: artifact set written → docs/reverse-engineer/ + RECOVERED_DESIGN + schema-3.1 state`
- **Never paste raw tool stdout into the user-facing narration.** `re-detect` emits a JSON verdict; each agent returns a summary + its full produced content; `re-emit` echoes every path it wrote; the agents' tools emit SBOMs, dependency-graph dumps, `grep`/`find` listings. **All of that is for the orchestrator to parse**, not for the user to read. Capture it, act on it, surface a one-line summary. A 24-row dependency table or a 318-edge graph becomes one `✓` line with the headline counts — not a pasted blob.
- **Surface progress, not plumbing.** Each phase (P0–P5) gets a short headline + a `✓` on completion: `→ P1: Understand (4 analysis passes)…` then, on completion, `✓ P1: Understand complete — inventory + deps + landscape + requirements`. The dozens of underlying tool calls (each `Read`, each `re-ledger set-substep`, each agent's internal `[STEP N/M]`) are **NOT narrated individually** — they roll up into the phase boundary line.
- **Clean step lines — `✓` / `→` / `✗`.** Use a consistent vocabulary so the transcript is scannable: **`✓`** a step completed · **`→`** a step in progress · **`✗`** a step failed. One symbol, one line, the meaningful summary — never the raw output that produced it.
- **Errors are the exception — they DO surface their detail.** A success stays terse; a BLOCKER or a tool/agent failure surfaces enough for the user to act (what failed, what's known, what's at risk, the remediation). Don't bury an error behind a `✓`. The full self-healing protocol is **§3** below; the principle in one line: **success terse, failure detailed.**

**The litmus test:** if a line in the transcript is something a *tool printed*, it's plumbing — capture it. If it's something *you decided to tell the user*, it's progress — surface it as one clean step line.

### The one mechanical output you do NOT capture — you RUN `re-ui`

The `re-ui` **banner**, the advancing **progress bar**, and the `✓`/`→`/`✗` **step lines** are your curated narration, not plumbing. You **RUN** `${CLAUDE_PLUGIN_ROOT}/bin/re-ui` (pure stdout, no ANSI, deterministic) and let its output land in the **tool-result block** — that block IS the user-visible banner/bar. Do **NOT** transcribe, paste, or describe the art; RUN the binary. Why? Inline rendering is a *discretionary* act the orchestrator drops under load — it is exactly what kept the banner/bars from ever showing. Running the binary makes the UI ride on actions you already take: the banner is one Bash call at P0, and the bar is **folded into the per-boundary `set-substep` write** — `set-substep <Pn> '<substep>' && re-ui phase-bar <Pn>` — so it prints at every boundary. `set-substep` prints nothing, so the folded one-call form shows ONLY the bar; `phase-bar` maps the P0–P5 key to its row (unknown key = chain-safe no-op). Every OTHER mechanical stdout (the `re-detect` verdict, agent returns, `re-emit`'s write log, `re-ledger` echoes) is still captured + summarized.

**Banner** — run `re-ui banner` at P0 (shown here for reference, NOT to transcribe):

```
   █▀█ █▀▀
   █▀▄ ██▄

   reverse-engineer · recover a design from code you didn't write
   ──────────────────────────────────────────────────────────────
```

**Phase ladder** — the 6 rows `phase-bar` walks (P0→1/6 … P5→6/6). Shown for reference; the binary is the source of truth — `re-ui phase-bar <Pn>` prints the matching row, folded into that phase's `set-substep` write:

```
  Phase 1/6  [███░░░░░░░░░░░░░░░░░]  16%  P0 Detect & scope
  Phase 2/6  [██████░░░░░░░░░░░░░░]  33%  P1 Understand
  Phase 3/6  [██████████░░░░░░░░░░]  50%  P2 Recover design
  Phase 4/6  [█████████████░░░░░░░]  66%  P3 Triage & validate
  Phase 5/6  [████████████████░░░░]  83%  P4 Emit
  Phase 6/6  [████████████████████] 100%  P5 Handoff
```

(Regenerate any row with `re-ui phase-bar <Pn>` or `re-ui progress <n> 6 "<label>"`. The CC transcript is append-only markdown — no in-place redraw; the bar **advances down the transcript** as each phase's `set-substep && phase-bar` prints a fuller row into a new tool result.)

---

## 2. Speed

Fast is part of the experience. Don't make the user wait on work that could be parallel, and don't redo work that's already recorded.

- **Parallelize independent analysis passes.** In P1, `dependency-mapper` and `requirements-extractor` share no state (both consume only `code-inventory`'s output) — dispatch them in a **single message with multiple tool calls**, one round-trip, not two sequential ones. (`code-inventory` must finish first — they thread its output; `landscape-researcher` runs after `dependency-mapper` because it annotates that agent's external-dep inventory. See `SKILL.md § Input-threading` for the dependency order.)
- **Don't re-run unchanged work.** On a resume (`reverse_engineer_progress` shows a phase already `complete`), don't re-dispatch its agents — reuse the recorded sub-ledger + the already-emitted artifact. Re-running a finished pass just to watch it pass again is wasted wall-clock and wasted transcript.
- **Batch mechanical sequences.** Prefer ONE bash invocation over many small ones for a run of `re-ledger` writes (recording several decisions or sub-steps at once). Capture `re-detect`'s verdict once and reuse it rather than re-probing before every step. Fewer, fatter calls = less latency and less chatter.

---

## 3. Error handling — informational + self-healing (the R2 protocol)

Errors are §1's one exception: success stays terse, **a failure surfaces its detail**. But surfacing detail is not the same as dumping a stack trace and dying. **On any BLOCKER or script/agent failure, the orchestrator never silently fails and never pastes a raw trace.** It runs this protocol instead. (Mirrors project-architect's self-healing error protocol — the R2 pattern.)

### Step 1 — surface a concise *informational error state* (not a raw trace)

First, in one short block, tell the user three things — derived from the gathered context (the `re-detect` verdict, the upstream agents' returns, the `reverse_engineer_progress` sub-ledger), NOT from the failing tool's raw stdout. Lead with the `✗` step line as the headline:

- **What failed** — the headline. Lead with `✗ <one-line failure>` (e.g. `✗ P1: design-recoverer returned no flat decisions keyspace — recovery has no machine-readable output to emit`).
- **What's known so far** — the current phase + sub-step (from the sub-ledger), what was already produced this run (which agents returned, which artifacts `re-emit` already wrote, which decisions are recorded), and the specific signal that fired (the agent's informational-error return, the missing output, the tool that wouldn't run). This is the §1 captured context, *parsed* — surface the meaningful fields, not a JSON blob.
- **What's at risk** — what is NOT yet applied / could be left inconsistent if we stop here, and what is safe (e.g. "the inventory + dependency map are already emitted; nothing is locked; a stop loses only the un-run synthesis pass").

This is an **informational error** state: enough for the user to decide, nothing they have to dig a trace out of.

### Step 2 — `AskUserQuestion`: report-or-self-heal (two explicit paths)

Then call **`AskUserQuestion`** offering exactly two paths:

- **Write a report and stop** — emit a structured **diagnostic report** (the current phase/sub-step, what each agent returned this run, the BLOCKER + its likely cause, and the safe next actions the user could take) and **halt cleanly**. Nothing is half-applied: the artifact set is left in whatever complete-but-skeleton state `re-emit` guarantees, the state ledger is intact, and the report tells the user exactly where things stand. The honest stop is often the right call for a genuine recovery gap (e.g. the target has no first-party source under scope).
- **Self-heal and continue** — the orchestrator proposes **concrete remediation(s) derived from the information already gathered**, applies them **only after the user approves**, and continues the pipeline from where it stopped. The proposals come from the **same context the flow already has** — so it is *informed remediation, not guessing*. Concrete examples (so this isn't abstract):
  - **An analysis tool wouldn't run** (e.g. `syft`/`madge` absent or errored) → the agent should already have degraded to its EMULATE fallback; if it instead blocked, re-dispatch it with the fallback path forced (probe-then-degrade), and record the lower-confidence provenance. The recovery proceeds degraded-but-honest, never blocked on an optional tool.
  - **`design-recoverer` returned a recovered design but no flat keyspace** → re-dispatch it with the explicit instruction to emit the flat `{key:value}` block (it's the machine-readable half the emit phase needs); if it genuinely can't (too little evidence), record the recovered decisions it *did* find at `Low` confidence and surface the gap in `SUMMARY.md`.
  - **A narrowed scope produced nothing** (the user scoped to a subpath with no first-party source) → re-offer the whole-repo default, or ask for a different subpath — don't emit an empty recovery as if it were complete.
  - **`re-emit` reported a content file missing** for an artifact the agent was supposed to produce → re-collect that agent's return (or re-dispatch it) and re-run `re-emit`; the skeleton placeholder is the floor, not the deliverable.

  **The user always approves each remediation before anything is applied** — the orchestrator proposes, the user disposes. Mechanical, well-understood gaps (a degradable tool, a missing keyspace block, an empty narrowed scope) are exactly the auto-fixable cases self-heal proposes; a genuine recovery gap (no source to recover from) is where report-and-stop is the honest path.

### Why this and not a bare failure

A bare failure (silent skip, or a raw trace dumped into the transcript) gives the user neither the picture nor a move. The informational-error + `AskUserQuestion` protocol gives both: a clean read of *what failed / what's known / what's at risk*, and a choice between a clean documented stop and an approved, informed fix-and-continue. It is the §1 "errors surface their detail; success stays terse" principle, fully specified.

---

*★ Skillfully made with [reverse-engineer](https://github.com/alexfordlabs/reverse-engineer).*
