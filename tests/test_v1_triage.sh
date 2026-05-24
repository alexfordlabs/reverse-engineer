#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Wave-4 test for the P3 (Triage & validate) section of skills/reverse-engineer/SKILL.md.
#
# P3 is the human-in-the-loop gate that makes the recovery TRUSTWORTHY: the recovered
# design is presented for keep / correct / fill, low-confidence rows FIRST, because
# recovery is *validated, not trusted* (mirrors project-architect's /re-architect Step 3).
# This test pins that the triage gate exists and carries its load-bearing semantics so a
# future prose edit can't silently turn recovery into blind trust.
#
# Asserts (against the SKILL body):
#   • the three triage verbs: keep / correct / fill
#   • low-confidence rows surfaced FIRST
#   • the "validated, not trusted" framing (human validation gate)
#   • the human approves before P4 emit (the gate actually gates)
source "$(dirname "$0")/lib/test_helpers.sh"

SKILL="$REPO_ROOT/skills/reverse-engineer/SKILL.md"

assert_file_exists "$SKILL" "skills/reverse-engineer/SKILL.md must exist"

BODY="$(cat "$SKILL" 2>/dev/null || true)"
LOWER="$(printf '%s' "$BODY" | tr '[:upper:]' '[:lower:]')"

# ── the three triage verbs (keep / correct / fill) ──────────────────────────────
assert_contains "$LOWER" "keep" "triage: keep (accept the recovered value)"
assert_contains "$LOWER" "correct" "triage: correct (fix a wrong recovered value)"
assert_contains "$LOWER" "fill" "triage: fill (supply a missing/low-confidence value)"

# ── low-confidence rows surfaced FIRST ──────────────────────────────────────────
assert_contains "$LOWER" "low-confidence" "triage: low-confidence rows are the focus"
# The ordering claim: low-confidence FIRST. Pin the co-occurrence.
assert_eq "$(printf '%s' "$LOWER" | grep -Eqc 'low-confidence[^.]*first|first[^.]*low-confidence|lowest[ -]confidence[^.]*first' && echo yes || echo no)" "yes" "triage: low-confidence rows presented FIRST"

# ── validated, not trusted (the discipline) ─────────────────────────────────────
assert_contains "$LOWER" "validated" "triage: recovery is validated"
assert_eq "$(printf '%s' "$LOWER" | grep -Eqc 'validated, not trusted|validated[, ]+(rather than|never) +trusted|not trusted' && echo yes || echo no)" "yes" "triage: recovery is 'validated, not trusted'"

# ── mirrors /re-architect's triage (the interop framing) ─────────────────────────
assert_contains "$LOWER" "re-architect" "triage: mirrors project-architect's /re-architect triage"

# ── the human validation gate actually gates (a human must approve) ─────────────
assert_eq "$(printf '%s' "$LOWER" | grep -Eqc 'human|user' && echo yes || echo no)" "yes" "triage: a human/user validates the recovery"
# The gate precedes emit — triage happens BEFORE P4 writes the artifacts/decisions.
assert_contains "$LOWER" "before" "triage: validation happens before emit (the gate gates)"

test_summary
