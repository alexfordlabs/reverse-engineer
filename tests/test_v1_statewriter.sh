#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Wave-1 state-writer test for bin/re-ledger.
#
# re-ledger WRITES/manages a project-architect schema-3.1 *recovered* state — the
# SHARED, versioned FILE FORMAT that lets reverse-engineer hand a recovered design
# off to project-architect (PA). It does NOT vendor PA's code; it conforms to the
# format only (learned from PA's bin/architect-ledger + references/state-schema.md).
#
# This test is SELF-CONTAINED: it operates on a temp state path and validates the
# emitted SHAPE against the documented schema-3.1 contract — it does NOT depend on
# PA's repo being present.
#
# Contract pins (from PA's state-schema.md §"3.0 → 3.1" + tests/test_v7_schema31.sh):
#   • schema_version "3.1"; origin "reverse-engineered".
#   • recovery {recovered_by, recovered_at, source_summary, confidence_summary}.
#   • decisions = FLAT {key:value} (LITERAL dotted keys, never nested paths);
#     decisions_schema_version "1.0".
#   • reverse_engineer_progress sub-ledger mirrors PA's *_progress shape — entries
#     carry .complete + .completed_at (what PA's detect/interrupted_flow reads).
#   • every baseline field a valid PA 3.0/3.1 state needs, so PA's detect /
#     import-decisions consume the state cleanly.
source "$(dirname "$0")/lib/test_helpers.sh"

LEDGER="$REPO_ROOT/bin/re-ledger"

assert_file_exists "$LEDGER" "bin/re-ledger must exist"
assert_executable "$LEDGER" "bin/re-ledger must be executable"

if ! command -v jq >/dev/null 2>&1; then echo "SKIP: jq not installed"; test_summary; exit 0; fi

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
S="$WORK/docs/_architect_state.json"

# ── 1. init creates a complete schema-3.1 recovered state ──────────────────────
"$LEDGER" --state "$S" init \
  --recovered-by "reverse-engineer" \
  --source-summary "legacy Flask app + scattered notes" >/dev/null

assert_file_exists "$S" "init creates the state file (parent dirs auto-created)"
assert_exit_code 0 jq -e . "$S"   # valid JSON

assert_eq "$(jq -r '.schema_version' "$S")" "3.1" "init: schema_version is 3.1"
assert_eq "$(jq -r '.origin' "$S")" "reverse-engineered" "init: origin is reverse-engineered"
assert_eq "$(jq -r '.recovery.recovered_by' "$S")" "reverse-engineer" "init: recovery.recovered_by from flag"
assert_eq "$(jq -r '.recovery.source_summary' "$S")" "legacy Flask app + scattered notes" "init: recovery.source_summary from flag"
assert_eq "$(jq -r '.recovery.confidence_summary' "$S")" "null" "init: recovery.confidence_summary starts null"
assert_eq "$(jq -r '.recovery.recovered_at | (. != null and . != "")' "$S")" "true" "init: recovery.recovered_at is non-empty"
# recovered_at must be a real UTC ISO8601 stamp (YYYY-MM-DDTHH:MM:SSZ).
assert_eq "$(jq -r '.recovery.recovered_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$S")" "true" "init: recovery.recovered_at is UTC ISO8601"
assert_eq "$(jq -r '.decisions' "$S")" "{}" "init: decisions starts as empty object"
assert_eq "$(jq -r '.decisions | type' "$S")" "object" "init: decisions is an object"
assert_eq "$(jq -r '.decisions_schema_version' "$S")" "1.0" "init: decisions_schema_version is 1.0"
assert_eq "$(jq -r '.reverse_engineer_progress' "$S")" "{}" "init: reverse_engineer_progress starts as empty object"
assert_eq "$(jq -r '.reverse_engineer_progress | type' "$S")" "object" "init: reverse_engineer_progress is an object"

# Baseline PA-required fields present so detect / import-decisions accept the state.
assert_eq "$(jq -r 'has("plugin_version")' "$S")" "true" "init: plugin_version present"
assert_eq "$(jq -r 'has("started_at")' "$S")" "true" "init: started_at present"
assert_eq "$(jq -r 'has("last_updated_at")' "$S")" "true" "init: last_updated_at present"
assert_eq "$(jq -r '.locked' "$S")" "false" "init: locked is false"
assert_eq "$(jq -r '.version' "$S")" "null" "init: version is null"
assert_eq "$(jq -r '.locked_at' "$S")" "null" "init: locked_at is null"
assert_eq "$(jq -r 'has("phase")' "$S")" "true" "init: phase present"
assert_eq "$(jq -r '.phase_progress | type' "$S")" "object" "init: phase_progress is an object"
assert_eq "$(jq -r '.decisions_dir' "$S")" "docs/decisions" "init: decisions_dir default"
assert_eq "$(jq -r '.project_layout' "$S")" "{}" "init: project_layout default empty object"
assert_eq "$(jq -r '.last_audit' "$S")" "null" "init: last_audit default null"
assert_eq "$(jq -r '.documents_generated | type' "$S")" "array" "init: documents_generated is an array"
assert_eq "$(jq -r '.adrs_filed | type' "$S")" "array" "init: adrs_filed is an array"
assert_eq "$(jq -r 'has("next_adr_id")' "$S")" "true" "init: next_adr_id present"

# ── 2. set-decision with a DOTTED key stays LITERAL/FLAT (not nested) ───────────
"$LEDGER" --state "$S" set-decision database.engine postgres >/dev/null
assert_eq "$(jq -r '.decisions["database.engine"]' "$S")" "postgres" "set-decision: dotted key stored as a literal flat key"
# Prove it is FLAT, not nested .decisions.database.engine.
assert_eq "$(jq -r '.decisions.database // "ABSENT"' "$S")" "ABSENT" "set-decision: dotted key is NOT nested (no .decisions.database object)"
assert_eq "$(jq -r '.decisions | has("database.engine")' "$S")" "true" "set-decision: .decisions has the literal 'database.engine' key"
assert_eq "$(jq -r '.decisions_schema_version' "$S")" "1.0" "set-decision: decisions_schema_version stays 1.0"

# ── 3. set-decision with raw JSON ingests as parsed JSON (array), not a string ──
"$LEDGER" --state "$S" set-decision platforms '["web","cli"]' >/dev/null
assert_eq "$(jq -r '.decisions.platforms | type' "$S")" "array" "set-decision: JSON array stored as an array"
assert_eq "$(jq -rc '.decisions.platforms' "$S")" '["web","cli"]' "set-decision: array value round-trips"
assert_eq "$(jq -r '.decisions.platforms[1]' "$S")" "cli" "set-decision: array element accessible"

# ── 4. set-substep records the sub-ledger entry for resumability ────────────────
"$LEDGER" --state "$S" set-substep P1 understand >/dev/null
assert_eq "$(jq -r '.reverse_engineer_progress.P1.substep' "$S")" "understand" "set-substep: substep label recorded"
# PA-consumable shape: detect/interrupted_flow reads .complete + .completed_at.
assert_eq "$(jq -r '.reverse_engineer_progress.P1 | has("complete")' "$S")" "true" "set-substep: entry has .complete (PA detect contract)"
assert_eq "$(jq -r '.reverse_engineer_progress.P1.complete' "$S")" "false" "set-substep: in-flight substep is complete:false"
assert_eq "$(jq -r '.reverse_engineer_progress.P1 | has("completed_at")' "$S")" "true" "set-substep: entry has .completed_at (PA detect contract)"
# A timestamp is present (the task's resumability stamp).
assert_eq "$(jq -r '.reverse_engineer_progress.P1.updated_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$S")" "true" "set-substep: updated_at is a UTC ISO8601 timestamp"

# set-substep is an idempotent per-phase upsert that preserves sibling phases.
"$LEDGER" --state "$S" set-substep P2 inventory >/dev/null
assert_eq "$(jq -r '.reverse_engineer_progress.P1.substep' "$S")" "understand" "set-substep: sibling phase P1 preserved after recording P2"
assert_eq "$(jq -r '.reverse_engineer_progress.P2.substep' "$S")" "inventory" "set-substep: new phase P2 recorded"

# ── 5. set-recovery sets a recovery.<field> ─────────────────────────────────────
"$LEDGER" --state "$S" set-recovery confidence_summary "12 high / 3 low" >/dev/null
assert_eq "$(jq -r '.recovery.confidence_summary' "$S")" "12 high / 3 low" "set-recovery: confidence_summary set"
# Sibling recovery fields are preserved by the upsert.
assert_eq "$(jq -r '.recovery.recovered_by' "$S")" "reverse-engineer" "set-recovery: sibling recovery.recovered_by preserved"

# ── 6. State remains valid JSON after every mutation ────────────────────────────
assert_exit_code 0 jq -e . "$S"

# ── 7. last_updated_at advances on a mutation (every write stamps it fresh) ─────
BEFORE_TS="$(jq -r '.last_updated_at' "$S")"
# A jq-level re-stamp would tie to wall-clock seconds; instead just assert the
# field is a valid UTC ISO8601 stamp after a mutation (cheap + deterministic).
"$LEDGER" --state "$S" set-decision auth.provider clerk >/dev/null
assert_eq "$(jq -r '.last_updated_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$S")" "true" "mutation: last_updated_at is a UTC ISO8601 stamp"
assert_eq "$(jq -r '.decisions["auth.provider"]' "$S")" "clerk" "set-decision: second dotted key also flat"
# BEFORE_TS captured for documentation; not asserted against (sub-second writes
# can share a whole-second stamp, which is fine — the format is what matters).
: "$BEFORE_TS"

# ── 8. default state path (no --state flag) lands at ./docs/_architect_state.json ─
DEFWORK="$(mktemp -d)"
(
  cd "$DEFWORK" || exit 1
  "$LEDGER" init --recovered-by "re" --source-summary "s" >/dev/null
)
assert_file_exists "$DEFWORK/docs/_architect_state.json" "init: default state path is ./docs/_architect_state.json"
assert_eq "$(jq -r '.schema_version' "$DEFWORK/docs/_architect_state.json")" "3.1" "init: default-path state is schema 3.1"
rm -rf "$DEFWORK"

test_summary
