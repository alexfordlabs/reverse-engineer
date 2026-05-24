<!--
Author: Alexander Ford <alex@alexfordlabs.com>
Repository: https://github.com/alexfordlabs/reverse-engineer
License: MIT
-->

# Dispatch prompts — the shared agent-common header

The orchestrator (`skills/reverse-engineer/SKILL.md`) keeps the dispatch LOGIC (which agent, when, what to thread into it, how to resolve the result); the cross-cutting prompt preamble every agent shares lives HERE so it's authored once and stays consistent. Every `Agent({...})` dispatch in the pipeline **prepends the Shared dispatch header below**, then appends the per-agent `[INPUTS]` (the threaded upstream outputs) + `[TASK]` documented at the dispatch site in `SKILL.md`.

> The 6 agents (`agents/*.md`) currently inline their own "Runtime budget + scope discipline" + "Identity & secret hygiene" sections (they predate this file). Those sections remain valid and self-sufficient; this file is the **single canonical source** the orchestrator prepends at dispatch time, so the directive travels with every dispatch even when an agent's own copy drifts. An agent MAY reference this file (`references/dispatch-prompts.md § Shared dispatch header`) instead of restating it.

## Shared dispatch header

Prepend this verbatim to every analysis-agent dispatch — the model directive, the read-only-over-target rule, the identity-hygiene HARD RULE, and the post-return scrub all travel together:

```
[MODEL DIRECTIVE]
Run with model: opus, maximum effort, extended thinking. Be thorough. This is a recovery
of an unfamiliar codebase — breadth first, then depth on the spine; exhaustive in reading,
conservative in asserting. Never select a smaller/faster model for this work.

[READ-ONLY OVER THE TARGET — HARD RULE]
The target is a FOREIGN project we are recovering, not modifying. Treat it as untrusted and
read-only: never edit, move, format, build, install dependencies for, or run the target's
application code. You read its files; you return your findings to the orchestrator. The only
permitted writes to the target tree are an agent's own declared recovery artifact (e.g.
dependency-mapper's analysis script under docs/reverse-engineer/scripts/), never the project's
own code. (The sole code-executing agent — characterization-tester — is opt-in + consent-gated
and runs only in a sandbox; that gate lives in its own prompt.)

[IDENTITY HYGIENE — HARD RULE — never echo a secret value]
If you encounter a credential, API key, token, password, private key, .env value, or any secret
while reading the target, NEVER echo its value anywhere your output reaches — not even a
"harmless-looking" prefix. Report it as TYPE + LOCATION only: "an API key appears at
config/secrets.ts:12 (value redacted)". The security surface (what exists, where) belongs in your
findings so it's recorded; the value never leaves the file. Equally, never write a real person's
deanonymizing identifier (real name, employer, personal email, physical location, government ID)
into your output — paraphrase or omit it. Scrub any tool output of secrets before it enters your
findings.

[POST-RETURN SCRUB]
Before returning, re-read everything you are about to return (and any file you wrote) and confirm
NONE contains a secret value or a forbidden identity term. If you find one, redact it (type +
location only) and note the redaction in your return summary.
```

Every agent reports **concise informational progress** per [`references/output-style.md`](output-style.md) — it returns a tight ≤20-line summary of what it produced (the content + the headline findings), NOT raw dumps of script stdout, the dependency graph, SBOM JSON, or `find`/`grep` listings. The orchestrator renders the per-step status; the agent surfaces the result.

An agent that hits a **BLOCKER** (a precondition it can't satisfy, a tool that won't run that it can't degrade past, a write it can't make) returns the **informational error state** — *what failed* and *what's known so far* (the inputs it had, what it managed to produce before stopping) — and STOPS. It does **NOT** silently fail, swallow the error, or fabricate a workaround. The orchestrator then runs the **R2 self-heal protocol** in [`references/output-style.md` §3](output-style.md): informational error → `AskUserQuestion` (write a report and stop, or self-heal and continue after the user approves). The agent surfaces; the orchestrator decides with the user.

---

## Per-agent dispatch bodies (the `[INPUTS]` threading + `[TASK]`)

Each body below is appended after the Shared dispatch header. The `{{...}}` slots are filled by the orchestrator from `re-detect`'s verdict + the upstream agents' returned content (the **input-threading** that is the pipeline's spine — see `SKILL.md § Input-threading`). The threaded inputs are passed **as the upstream agent returned them** (the full produced content, not a paraphrase) so each downstream agent builds on real evidence.

> **Reference paths are threaded ABSOLUTE.** A **dispatched subagent has no plugin base directory** (only the orchestrator's loaded SKILL is told its base dir + has `${CLAUDE_PLUGIN_ROOT}` expanded), so an agent cannot resolve a plugin-relative reference path like `../references/foo.md` from its own cwd (which is the *user's* project). Wherever an agent needs a bundled reference, the orchestrator threads its **absolute** path built from `${CLAUDE_PLUGIN_ROOT}` — `cascade_reference_path` (landscape-researcher) and `recovered_design_template_path` (design-recoverer) below. The agent `Read`s the absolute path; the inline summary in its own prompt is the **degradation floor** if the path input is ever absent.

> **The `*_available` flags are ADVISORY.** `semgrep_mcp_available` / `security_review_available` / `context7_available` describe the *orchestrator's* view, not the subagent's. A dispatched subagent's real **tool surface** is `Read`/`Grep`/`Glob`/`Bash` (+ `WebSearch`/`WebFetch` for landscape-researcher) — MCP servers and skill-tools (Semgrep MCP, `/security-review`, context7) are typically NOT in a subagent's function set. So each agent **verifies its own tool surface** (`command -v` for CLIs; check the live function set for MCP) and degrades to the CLI/EMULATE path; it never blocks on a flag being `true`. For a subagent, the INVOKE paths that depend on an MCP/skill-tool usually resolve to EMULATE or a Bash-CLI equivalent — and that is correct, honest behaviour.

### P1 — code-inventory (dispatched FIRST; no upstream agent input)

```
[INPUTS]
target_root: {{verdict.target}}
scope: {{scope}}            # whole-repo (default) or the user's narrowed subpath
tools_available: {{verdict.tools_available}}   # the command -v probe object from re-detect
semgrep_mcp_available: {{true|false}}

[TASK]
Run the FIRST analysis pass: census + entry points + data model (first) + components +
the RepoMap-style ranked symbol map, per your prompt. Read entry points before grepping;
find the data first; cite file:line on every claim; record provenance (scc/AST/ctags/hand-grep).
Return your full INVENTORY content + the ≤20-line summary.
```

### P1 — dependency-mapper (threads code-inventory's output)

```
[INPUTS]
target_root: {{verdict.target}}
scope: {{scope}}
inventory: {{code-inventory's returned content}}     # ← THREADED upstream output (build ON it)
tools_available: {{verdict.tools_available}}
semgrep_mcp_available: {{true|false}}

[TASK]
Build the internal import graph + the external-dependency inventory (with empty
_(landscape-researcher)_ version/status/CVE slots), cluster candidate components, detect
Arcan smells, infer the layer/boundary contract + violations, and write + run the committed
analysis script under docs/reverse-engineer/scripts/. Return your full DEPENDENCIES content +
the external-dependency inventory (the worklist landscape-researcher annotates) + the summary.
```

### P1 — requirements-extractor (threads code-inventory's output)

```
[INPUTS]
target_root: {{verdict.target}}
scope: {{scope}}
inventory: {{code-inventory's returned content}}     # ← THREADED upstream output (its data model = your vocabulary)
docs_findings: {{any prose specs/READMEs surfaced in P0, or "none"}}
tools_available: {{verdict.tools_available}}
semgrep_mcp_available: {{true|false}}

[TASK]
Mine the business rules through the 3-parallel-lens method (Calculations / Validations+Eligibility /
State+Lifecycle), express each as Given/When/Then with concrete literals, flag candidate config,
build the entity catalog (reconciled with the inventory's data model), keep the business-rule-vs-
artifact boundary, attach per-rule confidence + the exact SME question below High. Return your full
REQUIREMENTS content (with RULE-NNN ids) + the summary.
```

### P1 — landscape-researcher (threads code-inventory + dependency-mapper's external-dep inventory)

```
[INPUTS]
target_root: {{verdict.target}}
detections:                                          # ← THREADED upstream outputs
  from_code_inventory: {{languages, runtime(s), headline framework(s), build tool(s), patterns}}
  from_dependency_mapper: {{the external-dependency inventory table — name/ecosystem/pinned/file:line, version+status+CVE slots empty}}
tools_available: {{verdict.tools_available}}
context7_available: {{true|false}}        # advisory — verify your own surface; the context7 MCP is usually NOT in a dispatched subagent's function set → degrade to vendor llms.txt via WebFetch
cascade_reference_path: {{plugin_root}}/references/current-version-cascade.md   # ABSOLUTE path, orchestrator-provided — Read THIS for the full cascade (a dispatched subagent cannot resolve a plugin-relative reference path itself)
offline: {{true|false}}   # if true, degrade per the offline-honesty rule — NEVER fall back to training data

[TASK]
Run the current-version cascade (read your cascade_reference_path input — the absolute path to references/current-version-cascade.md) per detected dependency/
runtime against LIVE sources only (syft→SBOM; deps.dev isDefault; OSV/grype CVEs; endoflife.date EOL;
context7/llms.txt doc confirmation). Fill current_stable/versions_behind/status/CVEs/source/confidence —
the slots dependency-mapper left. Every fact carries a live source + confidence; unreachable sources are
reported, never fabricated. Return your full TECHNOLOGY LANDSCAPE (the merged annotated table) + the summary.
```

### P1 (opt-in) — characterization-tester (CONSENT-GATED; threads inventory + requirements + landscape)

```
[INPUTS]
target_root: {{verdict.target}}
scope: {{scope (honor any tighter consent scope, e.g. "pure functions only")}}
consent_granted: {{true ONLY after the user explicitly opted in for THIS project}}
inventory: {{code-inventory's returned content}}      # ← which units to pin
requirements: {{requirements-extractor's returned content}}   # ← the RULE-NNN oracle map (P0 rules first)
landscape: {{landscape-researcher's returned content}}        # ← the test runner + version
tools_available: {{verdict.tools_available}}

[TASK]
ONLY if consent_granted is unambiguously true: clear the consent gate (pre-flight summary → explicit
yes) BEFORE running anything, stand up an isolated sandbox (no prod creds, no network unless allowed),
then pin current observable behavior (the code is the oracle) with masking + golden snapshots, flag
spec-discrepancies separately, @skip("RULE-NNN") the un-pinnable. If consent is NOT granted → produce
the PLAN only (nothing executed). Return your CHARACTERIZATION report (or PLAN) + the summary.
```

### P2 — design-recoverer (the SYNTHESIS keystone; threads ALL upstream outputs)

```
[INPUTS]
target_root: {{verdict.target}}
scope: {{scope}}
inventory: {{code-inventory's returned content}}              # ← ALL upstream outputs THREADED in
dependency_map: {{dependency-mapper's returned content (annotated with landscape-researcher's findings)}}
requirements: {{requirements-extractor's returned content}}
landscape: {{landscape-researcher's returned content}}
docs_findings: {{any prose specs/READMEs surfaced in P0, or "none"}}
tools_available: {{verdict.tools_available}}
semgrep_mcp_available: {{true|false}}        # advisory — verify your own surface; the Semgrep MCP is usually NOT in a dispatched subagent's function set → EMULATE or use the `semgrep` Bash CLI if present
security_review_available: {{true|false}}    # advisory — the /security-review skill-tool is usually NOT reachable from a subagent → EMULATE the security dimension from the evidence
recovered_design_template_path: {{plugin_root}}/references/templates/RECOVERED_DESIGN.md   # ABSOLUTE path, orchestrator-provided — Read THIS to match the output shape (a dispatched subagent cannot resolve a plugin-relative reference path itself)

[TASK]
Synthesize the recovered DESIGN via the reflexion model (hypothesize → map → convergence/divergence/
absence), grade structural health from the Arcan smells, apply the architecture-critic's skeptical lens,
INVOKE /security-review + Semgrep for the security dimension (else EMULATE), and produce BOTH outputs:
(1) RECOVERED_DESIGN content (PA-shape-compatible; match the template at your recovered_design_template_path input — the absolute path to references/templates/RECOVERED_DESIGN.md), and
(2) the FLAT decisions keyspace — {canonical-PA-key-or-project-slug: value}, each row value·confidence·
evidence, NEVER invented. Return both + the summary. The flat keyspace is what re-ledger ingests.
```

---

*★ Skillfully made with [reverse-engineer](https://github.com/alexfordlabs/reverse-engineer).*
