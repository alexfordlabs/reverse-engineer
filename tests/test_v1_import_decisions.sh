#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Wave-4 (interop) behavior test for `bin/re-ledger import-decisions`.
#
# re-ledger import-decisions MIRRORS project-architect's `architect-ledger
# import-decisions` EXACTLY, so the flat decisions keyspace round-trips identically
# through BOTH ledgers (the interop linchpin). Contract pins (mirrored from PA's
# tests/test_v7_set_decision.sh § import-decisions):
#   • merges a flat {key:value} JSON object into .decisions (raw values).
#   • DOTTED keys stay LITERAL/FLAT (e.g. "database.engine"), never nested.
#   • merges alongside existing decisions WITHOUT clobbering them.
#   • sets decisions_schema_version "1.0" (only when absent — preserves an existing one).
#   • idempotent: re-importing the same file adds no keys + changes no values.
#   • the state stays valid JSON throughout; last_updated_at advances.
#
# Self-contained: operates on a temp state and does NOT depend on PA's repo.
source "$(dirname "$0")/lib/test_helpers.sh"

LEDGER="$REPO_ROOT/bin/re-ledger"

assert_file_exists "$LEDGER" "bin/re-ledger must exist"
assert_executable "$LEDGER" "bin/re-ledger must be executable"

if ! command -v jq >/dev/null 2>&1; then echo "SKIP: jq not installed"; test_summary; exit 0; fi

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
S="$WORK/docs/_architect_state.json"

# ── 0. a complete schema-3.1 recovered state to merge into ──────────────────────
"$LEDGER" --state "$S" init \
  --recovered-by "reverse-engineer" \
  --source-summary "legacy Flask app" >/dev/null
assert_eq "$(jq -r '.decisions' "$S")" "{}" "precondition: decisions starts empty"

# Seed one existing decision so we can prove import MERGES (does not clobber).
"$LEDGER" --state "$S" set-decision project.name '"legacy-svc"' >/dev/null
assert_eq "$(jq -r '.decisions["project.name"]' "$S")" "legacy-svc" "precondition: an existing decision is present"

# ── 1. import-decisions merges a flat {key:value} file with mixed value types ────
# Mixed JSON value types prove raw-value ingestion (number stays number, string
# stays string, bool stays bool, array stays array) — exactly PA's behavior.
printf '%s' '{"database.engine":"postgres","budget.max":42,"feature.flag":true,"platforms":["web","cli"]}' > "$WORK/imp.json"
"$LEDGER" --state "$S" import-decisions "$WORK/imp.json" >/dev/null

# LITERAL dotted keys (flat), never nested.
assert_eq "$(jq -r '.decisions["database.engine"]' "$S")" "postgres" "import: dotted key 'database.engine' stored as a literal flat key"
assert_eq "$(jq -r '.decisions.database // "ABSENT"' "$S")" "ABSENT" "import: dotted key is NOT nested (no .decisions.database object)"
assert_eq "$(jq -r '.decisions | has("database.engine")' "$S")" "true" "import: .decisions has the literal 'database.engine' key"

# Raw values keep their JSON types.
assert_eq "$(jq -r '.decisions["budget.max"] | type' "$S")" "number" "import: JSON number kept as number"
assert_eq "$(jq -r '.decisions["budget.max"]' "$S")" "42" "import: numeric value round-trips"
assert_eq "$(jq -r '.decisions["feature.flag"] | type' "$S")" "boolean" "import: JSON bool kept as boolean"
assert_eq "$(jq -r '.decisions.platforms | type' "$S")" "array" "import: JSON array kept as array"
assert_eq "$(jq -rc '.decisions.platforms' "$S")" '["web","cli"]' "import: array value round-trips"

# ── 2. merge (not replace): the pre-existing decision survives ──────────────────
assert_eq "$(jq -r '.decisions["project.name"]' "$S")" "legacy-svc" "import: merges, does not clobber the pre-existing decision"
assert_eq "$(jq -r '.decisions_schema_version' "$S")" "1.0" "import: sets decisions_schema_version 1.0"

# ── 3. state stays valid JSON after the merge ───────────────────────────────────
assert_exit_code 0 jq -e . "$S"
assert_eq "$(jq -r '.last_updated_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$S")" "true" "import: last_updated_at is a UTC ISO8601 stamp"

# ── 4. idempotency: re-importing the SAME file adds no keys + changes no values ──
# 1 seeded (project.name) + 4 imported (database.engine, budget.max, feature.flag,
# platforms) = 5 keys; a second import of the same file must NOT add or change any.
KEYS_BEFORE="$(jq -r '.decisions | keys | length' "$S")"
assert_eq "$KEYS_BEFORE" "5" "import: 5 keys present after first import"
"$LEDGER" --state "$S" import-decisions "$WORK/imp.json" >/dev/null
assert_eq "$(jq -r '.decisions | keys | length' "$S")" "5" "import: idempotent — re-importing the same file does not duplicate keys"
assert_eq "$(jq -r '.decisions["database.engine"]' "$S")" "postgres" "import: idempotent — values unchanged on re-import"

# ── 5. decisions_schema_version is PRESERVED when already set (// fills only if absent) ──
printf '%s' '{"foo.bar":1}' > "$WORK/imp2.json"
# Re-init a fresh state, then pin a non-default dsv, then import.
S2="$WORK/two/docs/_architect_state.json"
"$LEDGER" --state "$S2" init --recovered-by "re" --source-summary "s" >/dev/null
# Hand-set a non-default dsv on the machine-managed state to assert preservation.
tmp2="$(mktemp)"; jq '.decisions_schema_version = "1.5"' "$S2" > "$tmp2" && mv "$tmp2" "$S2"
"$LEDGER" --state "$S2" import-decisions "$WORK/imp2.json" >/dev/null
assert_eq "$(jq -r '.decisions_schema_version' "$S2")" "1.5" "import: keeps an existing (non-default) decisions_schema_version"
assert_eq "$(jq -r '.decisions["foo.bar"]' "$S2")" "1" "import: still merges the key when dsv pre-exists"

# ── 6. missing state file -> non-zero exit (require_state, mirrors PA) ───────────
assert_exit_code 1 "$LEDGER" --state "$WORK/nope/docs/_architect_state.json" import-decisions "$WORK/imp.json"

# ── 7. import-decisions is documented in the -h usage ───────────────────────────
USAGE="$("$LEDGER" -h 2>&1)"
assert_contains "$USAGE" "import-decisions" "usage: import-decisions is listed"

test_summary
