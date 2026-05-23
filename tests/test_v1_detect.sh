#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Wave-2 detection test for bin/re-detect — the Phase-0 ("detect & scope") helper.
#
# re-detect probes a target directory READ-ONLY and emits a JSON verdict that tells
# the orchestrator skill (authored later) whether there's a FOREIGN project to
# reverse-engineer, whether a project-architect (PA) state is already present (in
# which case reverse-engineer DEFERS to PA), or whether there's nothing to do. It
# also probes which analysis tools are installed for graceful degradation.
#
# This test is SELF-CONTAINED: it runs against the in-repo fixtures
# (tests/fixtures/foreign-node + tests/fixtures/architect-project) and never writes
# into the target dir (the helper is strictly read-only over its target).
#
# Verdict contract pinned here:
#   • has_architect_state : bool — docs/_architect_state.json present in target.
#   • is_foreign          : bool — project material present AND no architect state.
#   • material            : object/summary of what was found (manifests, languages, docs).
#   • tools_available     : object/list of analysis-tool presence (best-effort command -v).
#   • scope_default       : "whole-repo" (opinionated default; skill lets user override).
#   • action              : "reverse-engineer" | "defer-to-project-architect" | "nothing-to-do".
source "$(dirname "$0")/lib/test_helpers.sh"

DETECT="$REPO_ROOT/bin/re-detect"
FIXTURES="$REPO_ROOT/tests/fixtures"

assert_file_exists "$DETECT" "bin/re-detect must exist"
assert_executable "$DETECT" "bin/re-detect must be executable"

if ! command -v jq >/dev/null 2>&1; then echo "SKIP: jq not installed"; test_summary; exit 0; fi

# ── 1. -h / --help prints usage and exits 0 ─────────────────────────────────────
HELP_OUT="$("$DETECT" -h 2>&1)"
assert_exit_code 0 "$DETECT" -h
assert_contains "$HELP_OUT" "re-detect" "help: mentions the tool name"
assert_contains "$HELP_OUT" "Usage" "help: has a usage section"

# ── 2. foreign-node fixture → a FOREIGN project to reverse-engineer ─────────────
FOREIGN_FIX="$FIXTURES/foreign-node"
assert_dir_exists "$FOREIGN_FIX" "fixture: foreign-node must exist"
assert_file_exists "$FOREIGN_FIX/package.json" "fixture: foreign-node has package.json"
assert_file_exists "$FOREIGN_FIX/index.js" "fixture: foreign-node has index.js"
# Guard the premise: the foreign fixture must NOT carry an architect state.
if [[ -f "$FOREIGN_FIX/docs/_architect_state.json" ]]; then
  echo "FATAL: foreign-node fixture unexpectedly has docs/_architect_state.json" >&2
  exit 1
fi

V_FOREIGN="$("$DETECT" "$FOREIGN_FIX")"

# Output is valid JSON.
assert_exit_code 0 bash -c "printf '%s' '$V_FOREIGN' | jq -e ."

assert_eq "$(printf '%s' "$V_FOREIGN" | jq -r '.has_architect_state')" "false" "foreign: has_architect_state is false"
assert_eq "$(printf '%s' "$V_FOREIGN" | jq -r '.is_foreign')" "true" "foreign: is_foreign is true"
assert_eq "$(printf '%s' "$V_FOREIGN" | jq -r '.action')" "reverse-engineer" "foreign: action is reverse-engineer"
assert_eq "$(printf '%s' "$V_FOREIGN" | jq -r '.scope_default')" "whole-repo" "foreign: scope_default is whole-repo"

# tools_available is present and is a structured value (object or array).
assert_eq "$(printf '%s' "$V_FOREIGN" | jq -r '.tools_available | type | (. == "object" or . == "array")')" "true" "foreign: tools_available is present (object/list)"
# jq is definitely available in this test context (we gated on it above).
assert_eq "$(printf '%s' "$V_FOREIGN" | jq -r '.tools_available.jq')" "true" "foreign: tools_available probes jq as present"

# material mentions the node/js manifest we planted.
MATERIAL_FOREIGN="$(printf '%s' "$V_FOREIGN" | jq -r '.material | tostring')"
assert_contains "$MATERIAL_FOREIGN" "package.json" "foreign: material mentions package.json"
# Some signal of the node/javascript nature (manifest ecosystem or language).
assert_eq "$(printf '%s' "$V_FOREIGN" | jq -r '(.material | tostring | ascii_downcase) | (test("node") or test("js") or test("javascript"))')" "true" "foreign: material signals node/js"

# ── 3. architect-project fixture → DEFER to project-architect ───────────────────
PA_FIX="$FIXTURES/architect-project"
assert_dir_exists "$PA_FIX" "fixture: architect-project must exist"
assert_file_exists "$PA_FIX/docs/_architect_state.json" "fixture: architect-project has docs/_architect_state.json"

V_PA="$("$DETECT" "$PA_FIX")"

# Output is valid JSON.
assert_exit_code 0 bash -c "printf '%s' '$V_PA' | jq -e ."

assert_eq "$(printf '%s' "$V_PA" | jq -r '.has_architect_state')" "true" "architect: has_architect_state is true"
assert_eq "$(printf '%s' "$V_PA" | jq -r '.is_foreign')" "false" "architect: is_foreign is false (PA owns it)"
assert_eq "$(printf '%s' "$V_PA" | jq -r '.action')" "defer-to-project-architect" "architect: action is defer-to-project-architect"

# ── 4. empty dir → nothing-to-do ───────────────────────────────────────────────
EMPTY="$(mktemp -d)"; trap 'rm -rf "$EMPTY"' EXIT
V_EMPTY="$("$DETECT" "$EMPTY")"
assert_exit_code 0 bash -c "printf '%s' '$V_EMPTY' | jq -e ."
assert_eq "$(printf '%s' "$V_EMPTY" | jq -r '.has_architect_state')" "false" "empty: has_architect_state is false"
assert_eq "$(printf '%s' "$V_EMPTY" | jq -r '.is_foreign')" "false" "empty: is_foreign is false (no material)"
assert_eq "$(printf '%s' "$V_EMPTY" | jq -r '.action')" "nothing-to-do" "empty: action is nothing-to-do"

# ── 5. vendored/build dirs are EXCLUDED from the material assessment ─────────────
# A dir that contains ONLY node_modules/.git/etc. must read as nothing-to-do, not
# foreign — re-detect must not count vendored/build/cache trees as project material.
VENDOR_ONLY="$(mktemp -d)"
mkdir -p "$VENDOR_ONLY/node_modules/left-pad" "$VENDOR_ONLY/dist" "$VENDOR_ONLY/.git"
printf '{"name":"left-pad"}\n' > "$VENDOR_ONLY/node_modules/left-pad/package.json"
printf 'module.exports=1;\n' > "$VENDOR_ONLY/node_modules/left-pad/index.js"
printf 'console.log(1);\n' > "$VENDOR_ONLY/dist/bundle.js"
printf 'ref: refs/heads/main\n' > "$VENDOR_ONLY/.git/HEAD"
V_VENDOR="$("$DETECT" "$VENDOR_ONLY")"
assert_exit_code 0 bash -c "printf '%s' '$V_VENDOR' | jq -e ."
assert_eq "$(printf '%s' "$V_VENDOR" | jq -r '.is_foreign')" "false" "vendor-only: is_foreign is false (vendored/build dirs excluded)"
assert_eq "$(printf '%s' "$V_VENDOR" | jq -r '.action')" "nothing-to-do" "vendor-only: action is nothing-to-do"
rm -rf "$VENDOR_ONLY"

# ── 6. real source OUTSIDE vendored dirs IS counted as material ─────────────────
# Same vendored noise, but now with a real top-level source file → foreign.
MIXED="$(mktemp -d)"
mkdir -p "$MIXED/node_modules/x" "$MIXED/src"
printf '{"name":"x"}\n' > "$MIXED/node_modules/x/package.json"
printf 'def main():\n    return 1\n' > "$MIXED/src/main.py"
V_MIXED="$("$DETECT" "$MIXED")"
assert_exit_code 0 bash -c "printf '%s' '$V_MIXED' | jq -e ."
assert_eq "$(printf '%s' "$V_MIXED" | jq -r '.is_foreign')" "true" "mixed: real src/ source counts as material even alongside node_modules"
assert_eq "$(printf '%s' "$V_MIXED" | jq -r '.action')" "reverse-engineer" "mixed: action is reverse-engineer"
rm -rf "$MIXED"

# ── 7. read-only: re-detect must NOT write into the target dir ───────────────────
# Snapshot the foreign fixture's file inventory before+after a probe; it must match.
BEFORE_LS="$(cd "$FOREIGN_FIX" && find . -type f | sort)"
"$DETECT" "$FOREIGN_FIX" >/dev/null
AFTER_LS="$(cd "$FOREIGN_FIX" && find . -type f | sort)"
assert_eq "$AFTER_LS" "$BEFORE_LS" "read-only: probing the target leaves its file inventory unchanged"

# ── 8. missing target dir → non-zero exit (it's an error, not a verdict) ─────────
assert_exit_code 1 "$DETECT" "$EMPTY/does-not-exist-subdir"

test_summary
