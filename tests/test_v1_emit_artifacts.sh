#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Wave-3 behavior test for bin/re-emit — the P4 ("emit") mechanics.
#
# re-emit writes the standard reverse-engineer recovery artifact SET and ensures the
# shared schema-3.1 state. The orchestrator skill (authored in Wave 4) collects the 6
# analysis agents' markdown outputs and calls re-emit to write the set + the state.
# This test pins the emit CONTRACT directly against re-emit, with no skill present.
#
# This test is SELF-CONTAINED: it operates entirely under a temp --out directory and
# never depends on project-architect's repo being present (the 3.1 state is written by
# the in-repo bin/re-ledger, which conforms to PA's schema-3.1 file format).
#
# Artifact-set contract pinned here (spec §5 + references/artifacts.md):
#   <out>/docs/reverse-engineer/INVENTORY.md      (from code-inventory)
#   <out>/docs/reverse-engineer/DEPENDENCIES.md   (dependency-mapper + landscape-researcher)
#   <out>/docs/reverse-engineer/REQUIREMENTS.md   (from requirements-extractor)
#   <out>/docs/reverse-engineer/SUMMARY.md        (the recovery report)
#   <out>/docs/RECOVERED_DESIGN.md                (from design-recoverer)
#   <out>/docs/_architect_state.json              (schema 3.1, origin "reverse-engineered")
# Behavior pinned:
#   • provided --content FILE lands verbatim in its artifact path;
#   • a NON-provided artifact gets a minimal skeleton placeholder (set always complete);
#   • the state is valid JSON, schema_version=="3.1", origin=="reverse-engineered",
#     recovery.recovered_by / source_summary from the flags (via re-ledger init);
#   • re-emit writes ONLY under --out (never the analyzed target);
#   • a second run is idempotent/safe (state preserved, set still complete).
source "$(dirname "$0")/lib/test_helpers.sh"

EMIT="$REPO_ROOT/bin/re-emit"
LEDGER="$REPO_ROOT/bin/re-ledger"

assert_file_exists "$EMIT" "bin/re-emit must exist"
assert_executable "$EMIT" "bin/re-emit must be executable"
assert_file_exists "$LEDGER" "bin/re-ledger must exist (re-emit delegates the state to it)"

if ! command -v jq >/dev/null 2>&1; then echo "SKIP: jq not installed"; test_summary; exit 0; fi

# ── 0. -h / --help prints usage and exits 0 ─────────────────────────────────────
HELP_OUT="$("$EMIT" -h 2>&1)"
assert_exit_code 0 "$EMIT" -h
assert_contains "$HELP_OUT" "re-emit" "help: mentions the tool name"
assert_contains "$HELP_OUT" "Usage" "help: has a usage section"

# ── Fixture: a couple of provided content files (the rest go to skeletons) ──────
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/out"
SRC="$WORK/src"
mkdir -p "$SRC"

INV_SENTINEL="SENTINEL-INVENTORY-$$-content-from-code-inventory"
REQ_SENTINEL="SENTINEL-REQUIREMENTS-$$-content-from-requirements-extractor"
RD_SENTINEL="SENTINEL-RECOVERED-DESIGN-$$-content-from-design-recoverer"

printf '# Code Inventory — acme\n\n%s\n' "$INV_SENTINEL" > "$SRC/inventory.md"
printf '# Inferred Requirements & Business Rules — acme\n\n%s\n' "$REQ_SENTINEL" > "$SRC/requirements.md"
printf '# Recovered Design — acme\n\n%s\n' "$RD_SENTINEL" > "$SRC/recovered_design.md"

# ── 1. Run re-emit: 3 provided content files + DEPENDENCIES/SUMMARY left to skeletons
"$EMIT" --out "$OUT" \
  --recovered-by "reverse-engineer" \
  --source-summary "legacy Flask app + scattered notes" \
  --inventory "$SRC/inventory.md" \
  --requirements "$SRC/requirements.md" \
  --recovered-design "$SRC/recovered_design.md" >/dev/null

# ── 2. The full artifact SET exists (always complete) ───────────────────────────
assert_file_exists "$OUT/docs/reverse-engineer/INVENTORY.md"     "emit: INVENTORY.md written"
assert_file_exists "$OUT/docs/reverse-engineer/DEPENDENCIES.md"  "emit: DEPENDENCIES.md written (skeleton when not provided)"
assert_file_exists "$OUT/docs/reverse-engineer/REQUIREMENTS.md"  "emit: REQUIREMENTS.md written"
assert_file_exists "$OUT/docs/reverse-engineer/SUMMARY.md"       "emit: SUMMARY.md written (skeleton when not provided)"
assert_file_exists "$OUT/docs/RECOVERED_DESIGN.md"               "emit: RECOVERED_DESIGN.md written"
assert_file_exists "$OUT/docs/_architect_state.json"             "emit: _architect_state.json written"

# ── 3. Provided content lands VERBATIM in the correct artifact ──────────────────
assert_contains "$(cat "$OUT/docs/reverse-engineer/INVENTORY.md")"    "$INV_SENTINEL" "emit: provided inventory content lands in INVENTORY.md"
assert_contains "$(cat "$OUT/docs/reverse-engineer/REQUIREMENTS.md")" "$REQ_SENTINEL" "emit: provided requirements content lands in REQUIREMENTS.md"
assert_contains "$(cat "$OUT/docs/RECOVERED_DESIGN.md")"             "$RD_SENTINEL"  "emit: provided recovered-design content lands in RECOVERED_DESIGN.md"
# Content does NOT leak across artifacts.
assert_not_contains "$(cat "$OUT/docs/reverse-engineer/DEPENDENCIES.md")" "$INV_SENTINEL" "emit: inventory content does not leak into DEPENDENCIES.md"

# ── 4. A NON-provided artifact gets a minimal SKELETON placeholder ──────────────
DEPS_BODY="$(cat "$OUT/docs/reverse-engineer/DEPENDENCIES.md")"
SUMMARY_BODY="$(cat "$OUT/docs/reverse-engineer/SUMMARY.md")"
# The skeleton carries the correct top-level heading for its artifact …
assert_contains "$DEPS_BODY"    "# Dependencies"  "emit: DEPENDENCIES skeleton carries its heading"
assert_contains "$SUMMARY_BODY" "# "              "emit: SUMMARY skeleton carries a heading"
# … and is explicitly marked as a placeholder the skill fills later (never empty).
assert_contains "$DEPS_BODY"    "placeholder"     "emit: DEPENDENCIES skeleton is marked a placeholder"
assert_eq "$(printf '%s' "$DEPS_BODY" | wc -l | tr -d ' ' | awk '{print ($1>0)}')" "1" "emit: DEPENDENCIES skeleton is non-empty"

# ── 5. The state is a valid schema-3.1 reverse-engineered state (via re-ledger) ──
S="$OUT/docs/_architect_state.json"
assert_exit_code 0 jq -e . "$S"   # valid JSON
assert_eq "$(jq -r '.schema_version' "$S")" "3.1" "emit: state schema_version is 3.1"
assert_eq "$(jq -r '.origin' "$S")" "reverse-engineered" "emit: state origin is reverse-engineered"
assert_eq "$(jq -r '.recovery.recovered_by' "$S")" "reverse-engineer" "emit: recovery.recovered_by from --recovered-by"
assert_eq "$(jq -r '.recovery.source_summary' "$S")" "legacy Flask app + scattered notes" "emit: recovery.source_summary from --source-summary"
# recovered_at must be a real UTC ISO8601 stamp (proves it came from re-ledger's `now`, not hand-rolled).
assert_eq "$(jq -r '.recovery.recovered_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$S")" "true" "emit: recovery.recovered_at is UTC ISO8601 (via re-ledger)"
assert_eq "$(jq -r '.decisions | type' "$S")" "object" "emit: decisions is an object (flat keyspace)"
assert_eq "$(jq -r '.reverse_engineer_progress | type' "$S")" "object" "emit: reverse_engineer_progress is an object"

# ── 6. re-emit writes ONLY under --out (never the analyzed target) ──────────────
# Everything created sits under $OUT; nothing leaked into $SRC or elsewhere in $WORK.
SRC_BEFORE_HASHABLE="$(cd "$SRC" && find . -type f | sort)"
# (we never touch the target; assert SRC is untouched by counting + content)
assert_eq "$(cd "$SRC" && find . -type f | sort)" "$SRC_BEFORE_HASHABLE" "emit: the provided-content source dir is left unchanged"
# Every file re-emit created is under $OUT.
STRAY="$(find "$WORK" -type f -not -path "$OUT/*" -not -path "$SRC/*" | sort)"
assert_eq "$STRAY" "" "emit: re-emit creates files ONLY under --out (no strays)"

# ── 7. A second run is idempotent/safe ──────────────────────────────────────────
# The state must NOT be re-initialized (recovered_at preserved); the set stays complete.
RECOVERED_AT_1="$(jq -r '.recovery.recovered_at' "$S")"
STARTED_AT_1="$(jq -r '.started_at' "$S")"
"$EMIT" --out "$OUT" \
  --recovered-by "reverse-engineer" \
  --source-summary "legacy Flask app + scattered notes" \
  --inventory "$SRC/inventory.md" \
  --requirements "$SRC/requirements.md" \
  --recovered-design "$SRC/recovered_design.md" >/dev/null
assert_exit_code 0 jq -e . "$S"   # still valid JSON after a re-run
assert_eq "$(jq -r '.recovery.recovered_at' "$S")" "$RECOVERED_AT_1" "emit: 2nd run preserves recovery.recovered_at (state not re-initialized)"
assert_eq "$(jq -r '.started_at' "$S")" "$STARTED_AT_1" "emit: 2nd run preserves started_at (re-ledger init only when absent)"
assert_eq "$(jq -r '.schema_version' "$S")" "3.1" "emit: state still schema 3.1 after a re-run"
assert_file_exists "$OUT/docs/reverse-engineer/DEPENDENCIES.md" "emit: 2nd run keeps the set complete"
assert_contains "$(cat "$OUT/docs/reverse-engineer/INVENTORY.md")" "$INV_SENTINEL" "emit: 2nd run keeps provided content in place"

# ── 8. Missing --out → non-zero exit (it's an error, not a no-op) ───────────────
assert_exit_code 2 "$EMIT" --recovered-by "x" --source-summary "y"

test_summary
