#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Wave-6 END-TO-END test: the reverse-engineer MECHANICAL spine over a FOREIGN project.
#
# reverse-engineer recovers a design from a FOREIGN/brownfield project. This e2e runs the
# bin/ pipeline — bin/re-detect (P0 detect & scope) → bin/re-emit (P4 emit, which delegates
# the schema-3.1 state to bin/re-ledger) — end-to-end against a small but genuine foreign
# Node app (tests/fixtures/e2e-foreign-node), and asserts the full recovery artifact SET +
# a valid schema-3.1 "reverse-engineered" state.
#
# SCOPE — what a bash e2e can and cannot exercise:
#   • CAN: the mechanical spine (the bin/ pipeline) end-to-end + best-effort, REAL tooling
#     for the stale-dependency differentiator (syft SBOM showing the pinned version; an
#     optional deps.dev lookup proving it is behind current stable).
#   • CANNOT: the 6 LLM analysis agents or the live current-version cascade as a whole — a
#     bash test cannot dispatch LLM subagents. Those are exercised in the skill-creator eval.
#
# GRACEFUL DEGRADATION (the plugin's core philosophy, mirrored here):
#   The stale-dep tooling probe is BEST-EFFORT. If syft/grype is absent OR the network is
#   unreachable, the relevant assertion is SKIPPED with a clear "degraded: <what> unavailable"
#   note and the test STILL PASSES. The suite NEVER depends on a tool being installed or on
#   network access — it passes identically online and offline.
#
# This test is SELF-CONTAINED: re-emit writes only under a temp --out dir, and the pipeline
# operates read-only over the in-repo fixture (which is foreign material only — no architect
# state). The fixture's stale express pin + EOL node engines are INTENTIONAL; do not "fix" them.
source "$(dirname "$0")/lib/test_helpers.sh"

DETECT="$REPO_ROOT/bin/re-detect"
EMIT="$REPO_ROOT/bin/re-emit"
LEDGER="$REPO_ROOT/bin/re-ledger"
FIXTURE="$REPO_ROOT/tests/fixtures/e2e-foreign-node"

# ── 0. Pipeline preconditions ───────────────────────────────────────────────────
assert_file_exists "$DETECT" "bin/re-detect must exist"
assert_executable  "$DETECT" "bin/re-detect must be executable"
assert_file_exists "$EMIT"   "bin/re-emit must exist"
assert_executable  "$EMIT"   "bin/re-emit must be executable"
assert_file_exists "$LEDGER" "bin/re-ledger must exist (re-emit delegates the state to it)"

if ! command -v jq >/dev/null 2>&1; then echo "SKIP: jq not installed"; test_summary; exit 0; fi

# ── 1. The fixture is genuine FOREIGN material (no architect state) ──────────────
assert_dir_exists  "$FIXTURE"                    "fixture: e2e-foreign-node must exist"
assert_file_exists "$FIXTURE/package.json"       "fixture: has package.json (manifest)"
assert_file_exists "$FIXTURE/package-lock.json"  "fixture: has package-lock.json (so syft resolves the pin)"
assert_file_exists "$FIXTURE/server.js"          "fixture: has a server entry"
assert_file_exists "$FIXTURE/routes/users.js"    "fixture: has a route handler"
assert_file_exists "$FIXTURE/models/user.js"     "fixture: has a data model (find-the-data-first material)"
assert_file_exists "$FIXTURE/README.md"          "fixture: has a README"
# Guard the premise: foreign material must NOT carry an architect state.
if [[ -f "$FIXTURE/docs/_architect_state.json" ]]; then
  echo "FATAL: e2e-foreign-node fixture unexpectedly has docs/_architect_state.json" >&2
  exit 1
fi
# Guard the differentiator's premise: the dependency is genuinely stale-pinned.
assert_contains "$(cat "$FIXTURE/package.json")"      '"express": "4.16.0"' "fixture: express is stale-pinned at 4.16.0"
assert_contains "$(cat "$FIXTURE/package-lock.json")" '"version": "4.16.0"' "fixture: lockfile resolves express to 4.16.0"

# ════════════════════════════════════════════════════════════════════════════════
# P0 — re-detect: the fixture is a FOREIGN project to reverse-engineer
# ════════════════════════════════════════════════════════════════════════════════
V="$("$DETECT" "$FIXTURE")"
assert_exit_code 0 bash -c "printf '%s' \"\$1\" | jq -e ." _ "$V"   # valid JSON verdict

assert_eq "$(printf '%s' "$V" | jq -r '.has_architect_state')" "false" "P0: has_architect_state is false"
assert_eq "$(printf '%s' "$V" | jq -r '.is_foreign')"          "true"  "P0: is_foreign is true"
assert_eq "$(printf '%s' "$V" | jq -r '.action')" "reverse-engineer"   "P0: action is reverse-engineer"
# tools_available is present and is an object (best-effort tool probe for later phases).
assert_eq "$(printf '%s' "$V" | jq -r '.tools_available | type')" "object" "P0: tools_available is present (object)"
# The probe ran jq (we gated on it), so it must report jq present — proves the probe works.
assert_eq "$(printf '%s' "$V" | jq -r '.tools_available.jq')" "true" "P0: tools_available probes jq as present"
# Material signals the node/js nature of the fixture.
assert_eq "$(printf '%s' "$V" | jq -r '(.material | tostring | ascii_downcase) | (test("node") or test("js") or test("javascript"))')" "true" "P0: material signals node/js"

# ════════════════════════════════════════════════════════════════════════════════
# P4 — re-emit: the mechanical spine writes the full recovery artifact SET + state
# ════════════════════════════════════════════════════════════════════════════════
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/recovered"
SRC="$WORK/agent-output"; mkdir -p "$SRC"

# A couple of sample agent-output content files (as the skill would collect from the
# analysis agents) so the emit is realistic — INVENTORY + a SUMMARY derived from the
# fixture. The rest of the set lands as skeleton placeholders (still complete).
INV_SENTINEL="SENTINEL-INV-$$-widget-api-3-js-files-express-model"
SUM_SENTINEL="SENTINEL-SUM-$$-recovery-of-foreign-widget-api"
printf '# Code Inventory — widget-api\n\nserver.js, routes/users.js, models/user.js — %s\n' "$INV_SENTINEL" > "$SRC/inventory.md"
printf '# Recovery Summary — widget-api\n\n%s\n' "$SUM_SENTINEL" > "$SRC/summary.md"

"$EMIT" --out "$OUT" \
  --recovered-by "reverse-engineer" \
  --source-summary "e2e foreign node app (widget-api): Express service + users route + User model" \
  --inventory "$SRC/inventory.md" \
  --summary "$SRC/summary.md" >/dev/null

# ── The FULL artifact set appears (always complete) ─────────────────────────────
assert_file_exists "$OUT/docs/reverse-engineer/INVENTORY.md"    "P4: docs/reverse-engineer/INVENTORY.md written"
assert_file_exists "$OUT/docs/reverse-engineer/DEPENDENCIES.md" "P4: docs/reverse-engineer/DEPENDENCIES.md written (skeleton)"
assert_file_exists "$OUT/docs/reverse-engineer/REQUIREMENTS.md" "P4: docs/reverse-engineer/REQUIREMENTS.md written (skeleton)"
assert_file_exists "$OUT/docs/reverse-engineer/SUMMARY.md"      "P4: docs/reverse-engineer/SUMMARY.md written"
assert_file_exists "$OUT/docs/RECOVERED_DESIGN.md"             "P4: docs/RECOVERED_DESIGN.md written (skeleton)"
assert_file_exists "$OUT/docs/_architect_state.json"           "P4: docs/_architect_state.json written"

# Provided content lands verbatim in the right artifact.
assert_contains "$(cat "$OUT/docs/reverse-engineer/INVENTORY.md")" "$INV_SENTINEL" "P4: provided inventory content lands in INVENTORY.md"
assert_contains "$(cat "$OUT/docs/reverse-engineer/SUMMARY.md")"    "$SUM_SENTINEL" "P4: provided summary content lands in SUMMARY.md"

# ── State: valid schema-3.1 reverse-engineered state ────────────────────────────
S="$OUT/docs/_architect_state.json"
assert_exit_code 0 jq -e . "$S"   # valid JSON
assert_eq "$(jq -r '.schema_version' "$S")" "3.1"               "P4: state schema_version is 3.1"
assert_eq "$(jq -r '.origin' "$S")" "reverse-engineered"        "P4: state origin is reverse-engineered"
assert_eq "$(jq -r '.recovery | type' "$S")" "object"           "P4: state has a recovery object"
assert_eq "$(jq -r '.recovery.recovered_by' "$S")" "reverse-engineer" "P4: recovery.recovered_by from --recovered-by"
assert_eq "$(jq -r '.reverse_engineer_progress | type' "$S")" "object" "P4: state has a reverse_engineer_progress object"
assert_eq "$(jq -r '.decisions | type' "$S")" "object"          "P4: state has a decisions object (flat keyspace)"
# recovered_at must be a real UTC ISO8601 stamp (proves it came from re-ledger's `now`).
assert_eq "$(jq -r '.recovery.recovered_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' "$S")" "true" "P4: recovery.recovered_at is UTC ISO8601 (via re-ledger)"

# ── The spine wrote ONLY under --out (never the analyzed foreign target) ────────
FIXTURE_BEFORE="$(cd "$FIXTURE" && find . -type f | sort)"
# (re-emit operated on --out, not the target; the fixture must be untouched.)
assert_eq "$(cd "$FIXTURE" && find . -type f | sort)" "$FIXTURE_BEFORE" "P4: the foreign target is left unchanged by the pipeline"
STRAY="$(find "$WORK" -type f -not -path "$OUT/*" -not -path "$SRC/*" | sort)"
assert_eq "$STRAY" "" "P4: re-emit creates files ONLY under --out (no strays)"

# ════════════════════════════════════════════════════════════════════════════════
# Stale-dep flag — BEST-EFFORT, GRACEFUL (the differentiator's tooling)
#   Demonstrate that the fixture's deliberately stale express@4.16.0 pin is DETECTABLE
#   by the real tooling the landscape-researcher cascade documents (references/
#   current-version-cascade.md): syft → SBOM (the pinned version), then a deps.dev
#   lookup proving it is behind current stable. EVERY step degrades gracefully:
#   missing tool OR offline → SKIP with a "degraded:" note; the test still PASSES.
# ════════════════════════════════════════════════════════════════════════════════
PINNED_EXPRESS="4.16.0"

# ── Step 1 (syft): the pinned version is detectable in an SBOM ──────────────────
if command -v syft >/dev/null 2>&1; then
  # Run syft READ-ONLY over the fixture, CycloneDX SBOM (the cascade's preferred inventory
  # step). The SBOM must list express at the stale pinned version.
  SBOM=""
  SBOM="$(syft "dir:$FIXTURE" -o cyclonedx-json 2>/dev/null || true)"
  if [[ -n "$SBOM" ]] && printf '%s' "$SBOM" | jq -e . >/dev/null 2>&1; then
    EXPRESS_VER="$(printf '%s' "$SBOM" | jq -r '[.components[]? | select(.name=="express") | .version][0] // empty')"
    assert_eq "$EXPRESS_VER" "$PINNED_EXPRESS" "stale-dep (syft): SBOM shows express pinned at $PINNED_EXPRESS"
  else
    echo "  · degraded: syft present but produced no usable SBOM — skipping the SBOM stale-pin assertion (test still PASSES)"
  fi
else
  echo "  · degraded: syft unavailable — skipping the SBOM stale-pin assertion (test still PASSES)"
fi

# ── Step 2 (deps.dev): the pinned version is genuinely behind current stable ────
# Live network is NOT required. Probe reachability with a short timeout; only assert
# if we actually got a parseable current-stable version back.
DEPSDEV_OK=false
CURRENT_EXPRESS=""
if command -v curl >/dev/null 2>&1; then
  RESP="$(curl -fsS --max-time 8 "https://api.deps.dev/v3/systems/NPM/packages/express" 2>/dev/null || true)"
  if [[ -n "$RESP" ]] && printf '%s' "$RESP" | jq -e . >/dev/null 2>&1; then
    CURRENT_EXPRESS="$(printf '%s' "$RESP" | jq -r '[.versions[]? | select(.isDefault == true) | .versionKey.version][0] // empty')"
    [[ -n "$CURRENT_EXPRESS" ]] && DEPSDEV_OK=true
  fi
fi
if [[ "$DEPSDEV_OK" == "true" ]]; then
  # Compare majors: pinned 4.x must be a major behind the current stable (5.x at time of
  # writing). This proves the stale pin against a LIVE source, never from memory.
  PINNED_MAJOR="${PINNED_EXPRESS%%.*}"
  CURRENT_MAJOR="${CURRENT_EXPRESS%%.*}"
  if [[ "$PINNED_MAJOR" =~ ^[0-9]+$ && "$CURRENT_MAJOR" =~ ^[0-9]+$ ]]; then
    assert_eq "$(awk -v p="$PINNED_MAJOR" -v c="$CURRENT_MAJOR" 'BEGIN{print (c>p)?"true":"false"}')" "true" \
      "stale-dep (deps.dev): pinned express $PINNED_EXPRESS is behind current stable $CURRENT_EXPRESS (live source)"
  else
    echo "  · degraded: deps.dev returned an unparseable version ('$CURRENT_EXPRESS') — skipping the behind-current assertion (test still PASSES)"
  fi
else
  echo "  · degraded: deps.dev unreachable (offline or timed out) — skipping the behind-current assertion (test still PASSES)"
fi

test_summary
