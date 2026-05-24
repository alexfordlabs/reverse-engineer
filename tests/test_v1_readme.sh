#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# README.md presence + content + identity-hygiene test.
#
# The README is the plugin's PUBLIC face. This test asserts it exists, that it
# covers the load-bearing sections (install, the P0–P5 pipeline, the 6-agent
# suite, the current-version-cascade differentiator, the project-architect
# interop, MIT + Alex Ford Labs attribution), and — critically — that it leaks
# ZERO legacy-identity strings (the repo is public; only the Alex Ford Labs
# brand / Alexander Ford <alex@alexfordlabs.com> may appear).
source "$(dirname "$0")/lib/test_helpers.sh"

README="$REPO_ROOT/README.md"

# ── 1. README.md exists (repo root) ──────────────────────────────────────────
assert_file_exists "$README" "README.md must exist at the repo root"

DOC="$(cat "$README" 2>/dev/null || true)"

# ── 2. Title + value prop ────────────────────────────────────────────────────
assert_contains "$DOC" "reverse-engineer" "README: names the plugin (reverse-engineer)"
assert_contains "$DOC" "Claude Code" "README: frames it as a Claude Code plugin"
# The gap it fills — recovers a design from a foreign/brownfield project.
assert_contains "$DOC" "foreign" "README: names the foreign-project premise"
assert_contains "$DOC" "brownfield" "README: names the brownfield premise"

# ── 3. Install — from the shared alexfordlabs marketplace ────────────────────
assert_contains "$DOC" "## Install" "README: has an Install section"
assert_contains "$DOC" "claude plugin marketplace add alexfordlabs/project-architect" \
  "README: documents the marketplace-add command (shared marketplace, rooted in the PA repo)"
assert_contains "$DOC" "claude plugin install reverse-engineer@alexfordlabs" \
  "README: documents the plugin-install command (reverse-engineer@alexfordlabs)"

# ── 4. The P0–P5 pipeline ────────────────────────────────────────────────────
assert_contains "$DOC" "P0" "README: documents pipeline phase P0 (detect)"
assert_contains "$DOC" "P1" "README: documents pipeline phase P1 (understand)"
assert_contains "$DOC" "P2" "README: documents pipeline phase P2 (recover design)"
assert_contains "$DOC" "P3" "README: documents pipeline phase P3 (triage)"
assert_contains "$DOC" "P4" "README: documents pipeline phase P4 (emit)"
assert_contains "$DOC" "P5" "README: documents pipeline phase P5 (handoff)"

# ── 5. The 6-agent suite (all six named) ─────────────────────────────────────
assert_contains "$DOC" "code-inventory" "README: names the code-inventory agent"
assert_contains "$DOC" "dependency-mapper" "README: names the dependency-mapper agent"
assert_contains "$DOC" "landscape-researcher" "README: names the landscape-researcher agent"
assert_contains "$DOC" "requirements-extractor" "README: names the requirements-extractor agent"
assert_contains "$DOC" "characterization-tester" "README: names the characterization-tester agent"
assert_contains "$DOC" "design-recoverer" "README: names the design-recoverer agent"
# characterization-tester is the consent-gated one (executes foreign code).
assert_contains "$DOC" "consent" "README: flags the consent gate (characterization executes foreign code)"

# ── 6. The differentiator — research-augmented current-version detection ─────
assert_contains "$DOC" "current-version" "README: names the current-version cascade (the differentiator)"
# Names the live sources in the cascade.
assert_contains "$DOC" "deps.dev" "README: names deps.dev (current-stable source)"
assert_contains "$DOC" "endoflife.date" "README: names endoflife.date (EOL source)"
# The never-stale rule.
assert_contains "$DOC" "stale" "README: states the never-trust-stale-training-knowledge rule"

# ── 7. Interop with project-architect ────────────────────────────────────────
assert_contains "$DOC" "project-architect" "README: documents the project-architect companion/interop"
assert_contains "$DOC" "schema-3.1" "README: names the shared schema-3.1 state contract"
assert_contains "$DOC" "RECOVERED_DESIGN" "README: names the RECOVERED_DESIGN shared artifact"

# ── 8. Output artifacts ──────────────────────────────────────────────────────
assert_contains "$DOC" "INVENTORY" "README: names the INVENTORY artifact"
assert_contains "$DOC" "DEPENDENCIES" "README: names the DEPENDENCIES artifact"
assert_contains "$DOC" "REQUIREMENTS" "README: names the REQUIREMENTS artifact"
assert_contains "$DOC" "SUMMARY" "README: names the SUMMARY artifact"

# ── 9. Source-level scope (binary RE out of scope) ──────────────────────────
assert_contains "$DOC" "source-level" "README: states source-level scope (binary RE out of scope)"

# ── 10. License + attribution ────────────────────────────────────────────────
assert_contains "$DOC" "MIT" "README: states the MIT license"
assert_contains "$DOC" "Alex Ford Labs" "README: attributes to Alex Ford Labs"

# ── 11. Markdown attribution header + skillfully-made footer ─────────────────
assert_contains "$DOC" "Author: Alexander Ford <alex@alexfordlabs.com>" \
  "README: has the markdown attribution header"
assert_contains "$DOC" "★ Skillfully made with [reverse-engineer]" \
  "README: has the skillfully-made footer"

# ── 12. NO legacy identity (HARD RULE — the README is public) ────────────────
# Case-insensitive scan. None of these strings may appear anywhere in the README.
LOWER="$(printf '%s' "$DOC" | tr '[:upper:]' '[:lower:]')"
assert_not_contains "$LOWER" "whoami"                  "README: NO legacy identity 'whoami'"
assert_not_contains "$LOWER" "pseudo-lang"             "README: NO legacy identity 'pseudo-lang'"
assert_not_contains "$LOWER" "pseudo-workspace"        "README: NO legacy identity 'pseudo-workspace'"
assert_not_contains "$LOWER" "vladimir"                "README: NO legacy identity 'vladimir'"
assert_not_contains "$LOWER" "alexander-ford-ventures" "README: NO legacy identity 'alexander-ford-ventures'"
assert_not_contains "$LOWER" "/users/vladimir"         "README: NO legacy filesystem path '/Users/vladimir'"
assert_not_contains "$LOWER" "silicon-youth"           "README: NO legacy identity 'silicon-youth'"

test_summary
