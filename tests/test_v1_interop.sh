#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Wave-4 (interop) contract + wiring test.
#
# Asserts the SHARED interop contract is documented and that the orchestrator
# SKILL.md's handoff (P5) actually references it. The contract is the versioned
# file format BOTH plugins speak: architect schema 3.1 (origin/recovery + a flat
# decisions keyspace), RECOVERED_DESIGN.md, and the bidirectional invocation
# hand-offs (PA→reverse-engineer AND reverse-engineer→PA). Neither plugin
# hard-depends on the other's internals — they share the versioned format.
source "$(dirname "$0")/lib/test_helpers.sh"

CONTRACT="$REPO_ROOT/references/interop-contract.md"
SKILL="$REPO_ROOT/skills/reverse-engineer/SKILL.md"

# ── 1. references/interop-contract.md exists (top-level references/, this repo's convention) ──
assert_file_exists "$CONTRACT" "references/interop-contract.md must exist (top-level references/)"

DOC="$(cat "$CONTRACT" 2>/dev/null || true)"

# ── 2. the contract documents the shared schema version + keyspace + handoff surface ──
assert_contains "$DOC" "3.1" "interop-contract: names architect schema 3.1"
assert_contains "$DOC" "import-decisions" "interop-contract: names the import-decisions ingest verb"
assert_contains "$DOC" "RECOVERED_DESIGN" "interop-contract: names RECOVERED_DESIGN (the shared design artifact)"
assert_contains "$DOC" "canonical" "interop-contract: describes the flat canonical-key keyspace"

# ── 3. BOTH invocation directions are documented (bidirectional, no hard dependency) ──
# PA → reverse-engineer (PA Preflight detects a foreign project → invokes reverse-engineer)
assert_contains "$DOC" "project-architect → reverse-engineer" "interop-contract: documents the PA → reverse-engineer direction"
# reverse-engineer → PA (P5 offers to invoke PA's forward flow, seeded via the contract)
assert_contains "$DOC" "reverse-engineer → project-architect" "interop-contract: documents the reverse-engineer → PA direction"

# ── 4. markdown attribution header + footer (this repo's .md convention) ────────
assert_contains "$DOC" "Author: Alexander Ford <alex@alexfordlabs.com>" "interop-contract: has the markdown attribution header"
assert_contains "$DOC" "★ Skillfully made with [reverse-engineer]" "interop-contract: has the skillfully-made footer"

# ── 5. SKILL.md P5 references the contract + the import-decisions ingest ─────────
assert_file_exists "$SKILL" "skills/reverse-engineer/SKILL.md must exist"
SKILL_TXT="$(cat "$SKILL" 2>/dev/null || true)"
# Isolate the P5 (Handoff) section so the assertions are about the handoff wiring,
# not an incidental mention elsewhere. P5 runs from its heading to the next "## ".
P5="$(awk '/^## P5 — Handoff/{f=1} f&&/^## /&&!/^## P5 — Handoff/{if(seen)exit} {if(f)print; if(/^## P5 — Handoff/)seen=1}' "$SKILL")"
assert_contains "$P5" "references/interop-contract.md" "SKILL P5: references references/interop-contract.md"
# P5 hands off via the shared format; the contract names import-decisions as PA's ingest verb.
assert_contains "$SKILL_TXT" "import-decisions" "SKILL: references the import-decisions ingest verb"

test_summary
