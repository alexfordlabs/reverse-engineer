#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Presence + content test for agents/landscape-researcher.md — the DIFFERENTIATOR
# agent of the reverse-engineer suite, and for its reference doc
# references/current-version-cascade.md.
#
# landscape-researcher is a PROMPT (instructions to a subagent), not executable
# code. It is reverse-engineer's analog of project-architect's research-scout
# (opus; llms.txt-first; current-sources-only): for each language / framework /
# library / build-tool / pattern fed from code-inventory + dependency-mapper, it
# runs the §4b.3 current-version cascade against LIVE sources and returns ground
# truth — what the tech is, its current version + status (current / deprecated /
# superseded / EOL), CVEs, and conventions. The core NEVER rule: never state a
# version / status / CVE from stale model TRAINING knowledge — every one carries a
# live SOURCE (tool/api) + a confidence; unreachable sources are reported, never
# fabricated.
#
# This test pins the load-bearing elements of the prompt + the reference so a
# future prose edit can't silently drop a cascade step or the never-stale rule.
# It asserts the files exist and (via assert_contains) carry each non-negotiable:
#   AGENT (agents/landscape-researcher.md):
#   • frontmatter: name: landscape-researcher + model: opus (mirrors research-scout)
#   • the 5-step current-version cascade (§4b.3) — each keyword present
#   • "syft" / "grype"   — SBOM inventory + vuln scan CLIs (INVOKE→EMULATE)
#   • "deps.dev"         — current-stable via the isDefault version
#   • "OSV"              — vuln query on the concrete pinned version
#   • "endoflife"        — EOL / nearing-EOL for runtimes/frameworks
#   • "context7"/llms.txt — doc-grounded confirmation of the current major
#   • "versions_behind"   — computed gap pinned → current_stable
#   • "EOL"              — the end-of-life status dimension
#   • never + (train | stale) — the core NEVER rule (no training-data versions)
#   • "confidence"       — per-row confidence (high/low)
#   • "source"           — per-row source (the tool/api that produced it)
#   • "landscape-researcher" + column hand-off to dependency-mapper
#   • "command -v"/probe  — probe-then-degrade (INVOKE→EMULATE cascade)
#   • "read-only"        — read-only over the target (family discipline)
#   • attribution header + footer
#   REFERENCE (references/current-version-cascade.md):
#   • exists + "deps.dev" + "endoflife" + "isDefault" (the documented procedure)
source "$(dirname "$0")/lib/test_helpers.sh"

AGENT="$REPO_ROOT/agents/landscape-researcher.md"
REF="$REPO_ROOT/references/current-version-cascade.md"

assert_file_exists "$AGENT" "agents/landscape-researcher.md must exist"

# Read the whole agent file once; all content assertions match against it.
BODY="$(cat "$AGENT" 2>/dev/null || true)"

# ── frontmatter (mirrors project-architect's research-scout agent schema) ────────
assert_contains "$BODY" "name: landscape-researcher" "frontmatter: name is landscape-researcher"
assert_contains "$BODY" "model: opus" "frontmatter: model is opus (current-sources research, like research-scout)"
assert_contains "$BODY" "description:" "frontmatter: has a description (orchestrator dispatch trigger)"

# ── attribution (the .md convention) ────────────────────────────────────────────
assert_contains "$BODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "attribution: author header present"
assert_contains "$BODY" "https://github.com/alexfordlabs/reverse-engineer" "attribution: repository URL present"
assert_contains "$BODY" "Skillfully made with [reverse-engineer]" "attribution: footer present"

# ── §4b.3 the current-version cascade (the differentiator) — 5 numbered steps ────
assert_contains "$BODY" "cascade" "cascade: the current-version cascade is named"
# Step 1 — Inventory (syft → CycloneDX SBOM; fallback: lockfiles/manifests).
assert_contains "$BODY" "syft" "cascade step 1: syft → CycloneDX SBOM inventory"
assert_contains "$BODY" "cyclonedx" "cascade step 1: CycloneDX SBOM format"
# Step 2 — Current stable via deps.dev isDefault + compute versions_behind.
assert_contains "$BODY" "deps.dev" "cascade step 2: deps.dev current-stable lookup"
assert_contains "$BODY" "isDefault" "cascade step 2: isDefault:true version is current stable"
assert_contains "$BODY" "versions_behind" "cascade step 2: compute versions_behind (pinned → current)"
# The deps.dev SYSTEM enum the API path requires.
assert_contains "$BODY" "SYSTEM" "cascade step 2: the deps.dev {SYSTEM} path enum"
# Step 3 — Vulns via grype and/or OSV / deps.dev advisoryKeys on the pinned version.
assert_contains "$BODY" "grype" "cascade step 3: grype vuln scan over the SBOM"
assert_contains "$BODY" "OSV" "cascade step 3: OSV vuln query on the concrete pinned version"
assert_contains "$BODY" "CVE" "cascade step 3: CVEs + fixed-version"
# Step 4 — EOL via endoflife.date.
assert_contains "$BODY" "endoflife" "cascade step 4: endoflife.date EOL lookup"
assert_contains "$BODY" "EOL" "cascade step 4: past-EOL / nearing-EOL status"
# Step 5 — Doc confirmation via context7 + vendor llms.txt (avoid hallucinated APIs).
assert_contains "$BODY" "context7" "cascade step 5: context7 doc-grounded confirmation"
assert_contains "$BODY" "llms.txt" "cascade step 5: vendor llms.txt doc confirmation"

# ── the core NEVER rule: never a version/status/CVE from stale training data ─────
assert_contains "$BODY" "never" "NEVER rule: never state a version/status/CVE present"
assert_contains "$BODY" "train" "NEVER rule: not from model TRAINING knowledge"
assert_contains "$BODY" "stale" "NEVER rule: never stale model knowledge"

# ── per-row CROSS-AGENT contract: source + confidence on every fact ──────────────
assert_contains "$BODY" "source" "per-row: every fact carries a live source (tool/api)"
assert_contains "$BODY" "confidence" "per-row: every fact carries a confidence (high/low)"
assert_contains "$BODY" "current_stable" "per-row: current_stable column (the researched ground truth)"
assert_contains "$BODY" "status" "per-row: status column (current/deprecated/superseded/EOL)"

# ── column hand-off reconciled with dependency-mapper's annotation table ─────────
assert_contains "$BODY" "dependency-mapper" "hand-off: reconcile columns with dependency-mapper's table"

# ── INVOKE→EMULATE probe-then-degrade + offline-honesty (no fabrication) ──────────
assert_contains "$BODY" "command -v" "cascade: command -v probe before INVOKE (graceful degradation)"
assert_contains "$BODY" "could not verify" "offline-honesty: report 'could not verify' rather than guessing"

# ── read-only over the target (workspace + family discipline) ────────────────────
assert_contains "$BODY" "read-only" "discipline: read-only over the target"

# ── the reference doc: documented procedure + exact endpoints ────────────────────
assert_file_exists "$REF" "references/current-version-cascade.md must exist"
REFBODY="$(cat "$REF" 2>/dev/null || true)"
assert_contains "$REFBODY" "deps.dev" "reference: documents the deps.dev endpoint"
assert_contains "$REFBODY" "endoflife" "reference: documents the endoflife.date endpoint"
assert_contains "$REFBODY" "isDefault" "reference: documents isDefault current-stable semantics"
assert_contains "$REFBODY" "OSV" "reference: documents the OSV query endpoint"
assert_contains "$REFBODY" "syft" "reference: documents syft → SBOM"
assert_contains "$REFBODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "reference: attribution header present"
assert_contains "$REFBODY" "Skillfully made with [reverse-engineer]" "reference: attribution footer present"

test_summary
