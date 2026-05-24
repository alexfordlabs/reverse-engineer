#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Presence + content test for agents/requirements-extractor.md — the business-rule
# mining agent of the reverse-engineer suite (the direct descendant of
# code-modernization's business-rules-extractor).
#
# requirements-extractor is a PROMPT (instructions to a subagent), not executable
# code. The skill's emit phase (authored later) writes the agent's produced content
# to docs/reverse-engineer/REQUIREMENTS.md; the agent itself only PRODUCES that
# content. It infers WHAT the system does + the rules/requirements/policies it
# enforces from code + docs, separating "what it requires" (language-independent
# business rules) from "how it happens to be implemented" (technology artifacts).
#
# This test pins the load-bearing elements of the prompt so a future prose edit
# can't silently drop a §4b.1 technique. It asserts the file exists and (via
# assert_contains) carries each non-negotiable element:
#   • frontmatter: name: requirements-extractor + model: opus (mirrors PA's schema)
#   • the 3 parallel lenses — Calculations / Validations+Eligibility / State+Lifecycle
#   • "Given/When/Then" (G/W/T) with CONCRETE LITERAL values
#   • "confidence" — per-rule High/Med/Low
#   • SME / "the question" — the exact SME question when confidence < High
#   • "magic number"/"hardcoded"/"candidate config" — params as candidate config
#   • "business rule" + "technology"/"artifact" — the strict boundary
#   • entity/data-object catalog — the rules' vocabulary (reconciled w/ code-inventory)
#   • "semgrep" — INVOKE semgrep_scan_with_custom_rule to LOCATE rule-bearing code
#   • "command -v"/probe — probe-then-degrade (INVOKE→EMULATE cascade)
#   • "provenance" — each finding records which path produced it
#   • "file:line" — every rule cites file:line
#   • "appears" — the is-vs-appears-to-be (verified vs inferred) split
#   • code-inventory — consume the upstream inventory + data model as input
#   • "read-only" — read-only over the target (family discipline)
#   • attribution header + footer
source "$(dirname "$0")/lib/test_helpers.sh"

AGENT="$REPO_ROOT/agents/requirements-extractor.md"

assert_file_exists "$AGENT" "agents/requirements-extractor.md must exist"

# Read the whole agent file once; all content assertions match against it.
BODY="$(cat "$AGENT" 2>/dev/null || true)"

# ── frontmatter (mirrors project-architect's agent schema) ──────────────────────
assert_contains "$BODY" "name: requirements-extractor" "frontmatter: name is requirements-extractor"
assert_contains "$BODY" "model: opus" "frontmatter: model is opus"
assert_contains "$BODY" "description:" "frontmatter: has a description (orchestrator dispatch trigger)"

# ── attribution (the .md convention) ────────────────────────────────────────────
assert_contains "$BODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "attribution: author header present"
assert_contains "$BODY" "https://github.com/alexfordlabs/reverse-engineer" "attribution: repository URL present"
assert_contains "$BODY" "Skillfully made with [reverse-engineer]" "attribution: footer present"

# ── §4b.1 technique #1: the 3-parallel-lens method (from code-modernization) ─────
# Three lenses, each finding a distinct class of business rule.
assert_contains "$BODY" "Calculation" "lens 1: Calculations (formulas/pricing/scoring/derived)"
assert_contains "$BODY" "Validation" "lens 2: Validations (guards/input constraints)"
assert_contains "$BODY" "Eligibility" "lens 2: Eligibility (who-can-do-what / allow-deny)"
assert_contains "$BODY" "State" "lens 3: State (state machines / status)"
assert_contains "$BODY" "Lifecycle" "lens 3: Lifecycle (transitions / workflow steps)"
assert_contains "$BODY" "lens" "method: the three-lens framing is named"

# ── §4b.1 technique #2: Given/When/Then with concrete literal values ─────────────
assert_contains "$BODY" "Given/When/Then" "technique: express rules as Given/When/Then"
assert_contains "$BODY" "G/W/T" "technique: the G/W/T shorthand"
assert_contains "$BODY" "literal" "technique: CONCRETE LITERAL values from the code (not paraphrase)"

# ── §4b.1 technique #3: hardcoded params / magic numbers as candidate config ─────
assert_contains "$BODY" "magic number" "technique: flag magic numbers"
assert_contains "$BODY" "hardcoded" "technique: extract hardcoded params"
assert_contains "$BODY" "candidate config" "technique: surface tunable literals as candidate configuration"

# ── §4b.1 technique #4: per-rule confidence + the exact SME question when < High ─
assert_contains "$BODY" "confidence" "technique: per-rule confidence (High/Med/Low)"
assert_contains "$BODY" "High" "technique: confidence level High"
assert_contains "$BODY" "SME" "technique: the exact SME question when confidence < High"
assert_contains "$BODY" "subject-matter" "technique: subject-matter expert resolves the < High rules"
assert_contains "$BODY" "the question" "technique: state the precise question for the SME"

# ── §4b.1 technique #5: companion data-object / entity catalog ───────────────────
# The domain entities the rules operate on — the rules' vocabulary. Reconciled
# with code-inventory's data model (reference, don't duplicate).
assert_contains "$BODY" "entity catalog" "technique: companion entity catalog (the rules' vocabulary)"
assert_contains "$BODY" "data-object" "technique: data-object / entity companion catalog"

# ── §4b.1 technique #6: strict business-rule vs technology-artifact boundary ─────
assert_contains "$BODY" "business rule" "boundary: language-independent business rules (what it requires)"
assert_contains "$BODY" "technology" "boundary: technology artifacts (how, not what)"
assert_contains "$BODY" "artifact" "boundary: technology-ARTIFACT side of the boundary"

# ── §4b.1 INVOKE: semgrep_scan_with_custom_rule to LOCATE rule-bearing code ──────
assert_contains "$BODY" "semgrep" "INVOKE: semgrep custom rule to LOCATE rule-bearing code"
assert_contains "$BODY" "semgrep_scan_with_custom_rule" "INVOKE: the exact Semgrep MCP tool name"

# ── §4b.1 EMULATE + probe-then-degrade (INVOKE→EMULATE cascade) ──────────────────
assert_contains "$BODY" "command -v" "cascade: probe before INVOKE (graceful degradation)"
assert_contains "$BODY" "EMULATE" "cascade: EMULATE fallback (targeted Grep + in-prompt G/W/T)"

# ── provenance: each finding records which path produced it ──────────────────────
assert_contains "$BODY" "provenance" "provenance: each finding records its source (via Semgrep / hand-grep)"

# ── family discipline: file:line citation + is/appears split ─────────────────────
assert_contains "$BODY" "file:line" "discipline: cite file:line for every rule"
assert_contains "$BODY" "appears" "discipline: separate 'is' (verified) from 'appears' (inferred)"

# ── consume the upstream code-inventory output (build ON it, don't re-derive) ────
assert_contains "$BODY" "code-inventory" "input: consume code-inventory's inventory + data model"

# ── read-only over the target (workspace + family discipline) ────────────────────
assert_contains "$BODY" "read-only" "discipline: read-only over the target"

test_summary
