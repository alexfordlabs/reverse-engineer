#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Presence + content test for agents/design-recoverer.md — the SYNTHESIS keystone
# of the reverse-engineer suite (the LAST analysis agent). It synthesizes the
# upstream analysts' outputs (code-inventory's structure + data model;
# dependency-mapper's graph + Arcan smells + external deps; requirements-extractor's
# business rules; landscape-researcher's current-version/EOL/CVE findings) into
# (a) a reviewable RECOVERED_DESIGN.md and (b) a FLAT decisions keyspace that
# project-architect's forward engine consumes via `import-decisions`.
#
# design-recoverer is a PROMPT (instructions to a subagent), not executable code.
# The skill's emit phase (authored later) writes the agent's produced content to
# docs/reverse-engineer/RECOVERED_DESIGN.md; the agent itself only PRODUCES it.
#
# INTEROP IS THE LINCHPIN: the recovered decisions keyspace MUST use project-architect's
# CANONICAL flat keys where a decision maps (e.g. database.engine, backend.api_style,
# platforms, frontend.framework), with a project-specific ALIAS otherwise — so PA's
# Phase-4 catalog selection + template slicing + import-decisions all resolve. This
# test pins those keys + the rest of the §4/§4b.1 method so a future prose edit can't
# silently break the cross-plugin contract or drop a technique.
#
# It asserts the file exists and (via assert_contains) carries each non-negotiable element:
#   • frontmatter: name: design-recoverer + model: opus + runtime_budget (mirrors PA's schema)
#   • the reflexion-model recovery method (hypothesize → map → convergence/divergence/absence)
#   • structural-health grade (using dependency-mapper's Arcan smell catalog)
#   • the FLAT decisions keyspace — value · confidence · evidence (file:line / tool output)
#   • CANONICAL PA keys where they map + a concrete canonical-key example + ALIAS otherwise
#   • RECOVERED_DESIGN.md — the emitted reviewable artifact (shape-compatible w/ PA's)
#   • architecture-critic's skeptical lens (real seams vs résumé-driven; simplest design)
#   • accidental vs essential complexity
#   • OpenAPI / mermaid erDiagram interface + data-model fragments
#   • never-invent / low-confidence-is-a-routing-signal (not a failure)
#   • INVOKE → EMULATE: architecture recovery EMULATED; security-review + Semgrep INVOKED
#   • "command -v"/probe — probe-then-degrade (INVOKE→EMULATE cascade)
#   • "provenance" — each finding records which path produced it
#   • family discipline: file:line citation + is/appears split
#   • consume ALL upstream agents (code-inventory / dependency-mapper /
#     requirements-extractor / landscape-researcher) as inputs
#   • "read-only" over the target (family discipline)
#   • secret hygiene + never echo a secret value
#   • attribution header + footer
source "$(dirname "$0")/lib/test_helpers.sh"

AGENT="$REPO_ROOT/agents/design-recoverer.md"

assert_file_exists "$AGENT" "agents/design-recoverer.md must exist"

# Read the whole agent file once; all content assertions match against it.
BODY="$(cat "$AGENT" 2>/dev/null || true)"

# ── frontmatter (mirrors project-architect's agent schema) ──────────────────────
assert_contains "$BODY" "name: design-recoverer" "frontmatter: name is design-recoverer"
assert_contains "$BODY" "model: opus" "frontmatter: model is opus"
assert_contains "$BODY" "description:" "frontmatter: has a description (orchestrator dispatch trigger)"
assert_contains "$BODY" "runtime_budget:" "frontmatter: runtime_budget present"

# ── attribution (the .md convention) ────────────────────────────────────────────
assert_contains "$BODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "attribution: author header present"
assert_contains "$BODY" "https://github.com/alexfordlabs/reverse-engineer" "attribution: repository URL present"
assert_contains "$BODY" "Skillfully made with [reverse-engineer]" "attribution: footer present"

# ════════════════════════════════════════════════════════════════════════════════
# §4 technique #1: REFLEXION-MODEL recovery (the core method).
# Propose a hypothesized architecture → map the source onto it → report convergence
# (source confirms) / divergence (source contradicts) / absence (hypothesized thing
# not found). Falsifiable + iterative, never a one-shot guess.
# ════════════════════════════════════════════════════════════════════════════════
assert_contains "$BODY" "reflexion" "method: the reflexion-model recovery is named"
assert_contains "$BODY" "hypothes" "method: propose a HYPOTHESIZED architecture (hypothesize/hypothesis)"
assert_contains "$BODY" "convergence" "reflexion: convergence — the source confirms the hypothesis"
assert_contains "$BODY" "divergence" "reflexion: divergence — the source contradicts the hypothesis"
assert_contains "$BODY" "absence" "reflexion: absence — a hypothesized thing is not found"
assert_contains "$BODY" "falsifiable" "reflexion: recovery is falsifiable + reviewable, not a guess"

# ── §4 technique #2: structural-health grade (Arcan smell catalog) ───────────────
assert_contains "$BODY" "structural health" "technique: grade structural health"
assert_contains "$BODY" "hub" "structural health: hub-like smell (from dependency-mapper)"
assert_contains "$BODY" "cyclic" "structural health: cyclic-dependency smell"
assert_contains "$BODY" "god-component" "structural health: god-component smell"

# ════════════════════════════════════════════════════════════════════════════════
# §4 technique #3 + INTEROP LINCHPIN: the FLAT decisions keyspace.
# Every row = value · confidence(High/Med/Low) · evidence(file:line or tool output).
# CANONICAL project-architect keys where they map; a project-specific ALIAS otherwise.
# This is what `re-ledger set-decision` stores + PA's `import-decisions` ingests.
# ════════════════════════════════════════════════════════════════════════════════
assert_contains "$BODY" "keyspace" "interop: emit the FLAT decisions keyspace"
assert_contains "$BODY" "decisions" "interop: a recovered decisions set (the forward engine consumes it)"
assert_contains "$BODY" "confidence" "keyspace: every row carries a confidence (High/Med/Low)"
assert_contains "$BODY" "High" "keyspace: confidence level High"
assert_contains "$BODY" "evidence" "keyspace: every row carries evidence (file:line / tool output)"
assert_contains "$BODY" "file:line" "keyspace: evidence cites file:line (family discipline)"
# Canonical key contract (must match PA's document-catalog.md spellings).
assert_contains "$BODY" "canonical" "interop: use CANONICAL project-architect keys where they map"
assert_contains "$BODY" "key" "interop: the flat key per recovered decision"
assert_contains "$BODY" "alias" "interop: a project-specific ALIAS when no canonical key maps"
# A concrete canonical-key example proving the spellings are PA-recognized.
assert_contains "$BODY" "database.engine" "interop: concrete canonical-key example database.engine"
assert_contains "$BODY" "platforms" "interop: concrete canonical-key example platforms"
assert_contains "$BODY" "backend.api_style" "interop: concrete canonical-key example backend.api_style"
# The forward consumer is named so the contract is unmissable.
assert_contains "$BODY" "import-decisions" "interop: PA's forward engine ingests via import-decisions"
assert_contains "$BODY" "project-architect" "interop: the keyspace feeds project-architect (PA)"

# ── §4 technique #4: emit the RECOVERED_DESIGN.md artifact (PA-shape-compatible) ─
assert_contains "$BODY" "RECOVERED_DESIGN.md" "artifact: emit RECOVERED_DESIGN.md (the reviewable synthesis)"
assert_contains "$BODY" "component boundaries" "artifact: recovered component boundaries"

# ════════════════════════════════════════════════════════════════════════════════
# §4 technique #5: architecture-critic's SKEPTICAL lens.
# "Real domain seams or microservices-for-the-résumé?"; "is this the simplest design
# that fits the evidence?"; separate accidental from essential complexity.
# ════════════════════════════════════════════════════════════════════════════════
assert_contains "$BODY" "architecture-critic" "lens: the architecture-critic skeptical lens"
assert_contains "$BODY" "skeptical" "lens: a skeptical reading of the recovered design"
assert_contains "$BODY" "simplest design" "lens: is this the simplest design that fits the evidence?"
assert_contains "$BODY" "résumé" "lens: real seams vs microservices-for-the-résumé"
assert_contains "$BODY" "accidental" "lens: separate accidental complexity ..."
assert_contains "$BODY" "essential" "lens: ... from essential complexity"

# ── §4 technique #6: OpenAPI / mermaid erDiagram interface + data-model fragments ─
assert_contains "$BODY" "OpenAPI" "fragments: OpenAPI fragment for recovered interfaces"
assert_contains "$BODY" "erDiagram" "fragments: mermaid erDiagram for the recovered data model"

# ── never-invents: low-confidence is a routing signal for triage, not a failure ──
assert_contains "$BODY" "never invent" "discipline: NEVER invents — every row traces to evidence"
assert_contains "$BODY" "low-confidence" "discipline: low-confidence is a routing signal, not a failure"

# ════════════════════════════════════════════════════════════════════════════════
# INVOKE → EMULATE: architecture recovery is EMULATED (no CLI does arbitrary-stack
# recovery — it's reasoning); the SECURITY dimension INVOKES /security-review + Semgrep.
# ════════════════════════════════════════════════════════════════════════════════
assert_contains "$BODY" "EMULATE" "cascade: architecture recovery is EMULATED (reasoning, no CLI)"
assert_contains "$BODY" "INVOKE" "cascade: INVOKE the real tool where one exists (security)"
assert_contains "$BODY" "security-review" "INVOKE: /security-review for the SECURITY dimension"
assert_contains "$BODY" "Semgrep" "INVOKE: Semgrep for the SECURITY dimension"
assert_contains "$BODY" "command -v" "cascade: probe before INVOKE (graceful degradation)"

# ── provenance: each finding records which path produced it ──────────────────────
assert_contains "$BODY" "provenance" "provenance: each finding records its source (EMULATED reasoning vs Semgrep/security-review)"

# ── family discipline: file:line citation + is/appears split ─────────────────────
assert_contains "$BODY" "appears" "discipline: separate 'is' (verified) from 'appears' (inferred)"

# ── consume ALL upstream agents (this is the SYNTHESIS step) ──────────────────────
assert_contains "$BODY" "code-inventory" "input: consume code-inventory's structure + data model"
assert_contains "$BODY" "dependency-mapper" "input: consume dependency-mapper's graph + smells + external deps"
assert_contains "$BODY" "requirements-extractor" "input: consume requirements-extractor's business rules"
assert_contains "$BODY" "landscape-researcher" "input: consume landscape-researcher's current-version/EOL/CVE findings"

# ── read-only over the target (workspace + family discipline) ────────────────────
assert_contains "$BODY" "read-only" "discipline: read-only over the target"

# ── secret hygiene (workspace HARD RULE) ─────────────────────────────────────────
assert_contains "$BODY" "secret" "hygiene: never echo a secret value (type + location only)"

test_summary
