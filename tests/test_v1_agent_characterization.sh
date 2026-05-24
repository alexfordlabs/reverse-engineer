#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Presence + content test for agents/characterization-tester.md — the OPT-IN,
# CONSENT-GATED behavior-pinning agent of the reverse-engineer suite (the only
# agent that EXECUTES the foreign target's code).
#
# characterization-tester is a PROMPT (instructions to a subagent), not executable
# code. It DESCRIBES the consent gate + golden-master/characterization technique; it
# does not itself run anything. The skill's emit phase (authored later) writes the
# agent's produced tests/plan to docs/reverse-engineer/characterization-tests/; the
# agent itself only PRODUCES that content (or, absent consent, a PLAN of it).
#
# Feathers-style characterization / ApprovalTests golden-master testing: pin the
# CURRENT observable behavior (bugs included — "the code is the oracle") so a later
# rebuild can be proven behavior-equivalent.
#
# This test pins the load-bearing elements of the prompt so a future prose edit
# can't silently weaken the SAFETY gate or drop a §4 / §4b.1 technique. It asserts
# the file exists and (via assert_contains) carries each non-negotiable element:
#   • frontmatter: name: characterization-tester + model: opus (mirrors PA's schema)
#   • "oracle"            — the code is the oracle (assert observed output as-is)
#   • "branch" + "boundar" — cover every branch + boundaries (zero/neg/max/empty/null)
#   • "non-deterministic"/"mask" — mask time/uuid/random/order or the golden is flaky
#   • "golden"/"approval"/"snapshot" — approval / golden-master capture style
#   • "@skip"/"skip"      — mark unimplemented as @skip("RULE-NNN") (traceable gap)
#   • "spec-discrepancy"/"discrepancy" — flag observed-vs-spec divergence SEPARATELY
#   • THE CONSENT GATE: "opt-in" AND "consent" AND "sandbox" (the safety property)
#   • a target test runner — "pytest"/"jest"/"cargo test" (INVOKE the runner concept)
#   • "command -v"/probe  — probe-then-degrade (INVOKE→EMULATE cascade)
#   • "EMULATE"           — minimal harness fallback (call unit + record stdout/return)
#   • "provenance"        — each finding records which path produced it
#   • "file:line"         — cite file:line over the target's SOURCE
#   • "appears"           — the is-vs-appears-to-be (verified vs inferred) split
#   • code-inventory / requirements — consume the upstream understanding as input
#   • "read-only" over the target's SOURCE (never edits the target's code)
#   • secret hygiene + never echo a secret value
#   • attribution header + footer
source "$(dirname "$0")/lib/test_helpers.sh"

AGENT="$REPO_ROOT/agents/characterization-tester.md"

assert_file_exists "$AGENT" "agents/characterization-tester.md must exist"

# Read the whole agent file once; all content assertions match against it.
BODY="$(cat "$AGENT" 2>/dev/null || true)"

# ── frontmatter (mirrors project-architect's agent schema) ──────────────────────
assert_contains "$BODY" "name: characterization-tester" "frontmatter: name is characterization-tester"
assert_contains "$BODY" "model: opus" "frontmatter: model is opus"
assert_contains "$BODY" "description:" "frontmatter: has a description (orchestrator dispatch trigger)"
assert_contains "$BODY" "runtime_budget:" "frontmatter: runtime_budget present"

# ── attribution (the .md convention) ────────────────────────────────────────────
assert_contains "$BODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "attribution: author header present"
assert_contains "$BODY" "https://github.com/alexfordlabs/reverse-engineer" "attribution: repository URL present"
assert_contains "$BODY" "Skillfully made with [reverse-engineer]" "attribution: footer present"

# ════════════════════════════════════════════════════════════════════════════════
# THE CONSENT GATE — the distinctive SAFETY property (assert it explicitly + loudly).
# This is the ONLY agent that executes foreign code; the gate must be unmissable.
# ════════════════════════════════════════════════════════════════════════════════
assert_contains "$BODY" "opt-in" "CONSENT GATE: strictly opt-in (runs only when the user opts in)"
assert_contains "$BODY" "consent" "CONSENT GATE: explicit per-project consent required BEFORE executing"
assert_contains "$BODY" "sandbox" "CONSENT GATE: sandbox-aware (isolated/ephemeral env)"
assert_contains "$BODY" "EXECUTE foreign code" "CONSENT GATE: names the risk — it EXECUTES foreign code"
# Without consent it produces a PLAN (what it WOULD pin) rather than executing.
assert_contains "$BODY" "PLAN" "CONSENT GATE: absent consent, emit a PLAN (no execution) — still useful"

# ── §4b.1 technique #1: "the code is the oracle" + spec-discrepancy SEPARATELY ───
# Assert the CURRENT observed output (bugs included), not what a spec says it should.
assert_contains "$BODY" "oracle" "technique: the code is the oracle (assert observed output as-is)"
assert_contains "$BODY" "spec-discrepancy" "technique: flag observed-vs-spec divergence as a spec-discrepancy"
assert_contains "$BODY" "discrepancy" "technique: the discrepancy is flagged SEPARATELY, never 'fixed' in the test"

# ── §4b.1 technique #2: cover every branch + boundaries ──────────────────────────
assert_contains "$BODY" "branch" "technique: cover every code path / branch"
assert_contains "$BODY" "boundar" "technique: boundaries — zero / negative / max / empty / null"

# ── §4b.1 technique #3: mask non-deterministic values (or the golden is flaky) ───
assert_contains "$BODY" "non-deterministic" "technique: mask non-deterministic values (time/uuid/random/order)"
assert_contains "$BODY" "mask" "technique: mask/freeze/stub the non-determinism (essential, not optional)"

# ── §4b.1 technique #4: approval / golden-master style ───────────────────────────
assert_contains "$BODY" "golden" "technique: golden-master capture (the snapshot IS the test)"
assert_contains "$BODY" "approval" "technique: ApprovalTests-style approval testing"
assert_contains "$BODY" "snapshot" "technique: capture output to an approved snapshot; diffs are the test"

# ── §4b.1 technique #5: mark unimplemented as @skip("RULE-NNN") (traceable gap) ──
assert_contains "$BODY" "@skip" "technique: mark unimplemented as @skip(\"RULE-NNN\") (no silent gap)"
assert_contains "$BODY" "skip" "technique: a traceable SKIPPED test referencing the rule id"
assert_contains "$BODY" "RULE-" "technique: the @skip references a requirements RULE-NNN id"

# ── §4b.1 INVOKE → EMULATE: the target-language test runner ──────────────────────
# At least the concept of the detected runner (pytest / jest / cargo test / go test).
assert_contains "$BODY" "pytest" "INVOKE: pytest (Python target runner)"
assert_contains "$BODY" "jest" "INVOKE: jest (JS/TS target runner)"
assert_contains "$BODY" "cargo test" "INVOKE: cargo test (Rust target runner)"
assert_contains "$BODY" "test runner" "INVOKE: the target-language test runner (detected from inventory)"
# Probe-then-degrade + EMULATE minimal harness.
assert_contains "$BODY" "command -v" "cascade: command -v probe before INVOKE (graceful degradation)"
assert_contains "$BODY" "EMULATE" "cascade: EMULATE — minimal harness that calls the unit + records output"

# ── provenance: each finding records which path produced it ──────────────────────
assert_contains "$BODY" "provenance" "provenance: each test/finding records its source (runner vs harness)"

# ── family discipline: file:line citation + is/appears split ─────────────────────
assert_contains "$BODY" "file:line" "discipline: cite file:line over the target's SOURCE"
assert_contains "$BODY" "appears" "discipline: separate 'is' (verified) from 'appears' (inferred)"

# ── consume the upstream understanding (build ON it, don't re-derive) ────────────
assert_contains "$BODY" "code-inventory" "input: consume code-inventory's structure (units to pin)"
assert_contains "$BODY" "requirements" "input: consume requirements-extractor's rules (RULE ids → @skip)"

# ── read-only over the target's SOURCE (never edits the target's code) ───────────
assert_contains "$BODY" "read-only" "discipline: read-only over the target's SOURCE (never edits target code)"

# ── secret hygiene (workspace HARD RULE) ─────────────────────────────────────────
assert_contains "$BODY" "run with production credentials" "safety: never run with production credentials/env"
assert_contains "$BODY" "no production credentials" "safety: minimal/fake env — no production credentials"
assert_contains "$BODY" "secret" "hygiene: never echo a secret value / never exfiltrate"

test_summary
