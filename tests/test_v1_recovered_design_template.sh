#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Presence + content test for references/templates/RECOVERED_DESIGN.md — the output
# structure design-recoverer fills to produce the suite's central recovery artifact.
#
# This template is the SHAPE-COMPATIBLE analog of project-architect's
# references/templates/RECOVERED_DESIGN.md, so PA's /re-architect triage (Step 3)
# consumes reverse-engineer's output identically. Like every project-architect /
# reverse-engineer template, its {{placeholder}} markers are INTENTIONAL — they are
# filled at runtime by the agent; the auditor only scans a USER's docs/, never the
# template files, so they don't false-positive.
#
# The template is documentation (a fill-in skeleton), not executable code. This test
# pins the load-bearing sections so a future edit can't silently drop the decisions
# table (the interop linchpin), the reflexion sections, or the placeholder markers.
#
# It asserts the file exists and (via assert_contains) carries each non-negotiable element:
#   • the {{ placeholder markers (intentional — filled at runtime, like PA's templates)
#   • the DECISIONS TABLE columns — key / value / confidence / evidence (the keyspace)
#   • canonical-key + alias guidance (the cross-plugin interop contract)
#   • the reflexion sections — convergence / divergence / absence
#   • recovered stack + architecture + component boundaries
#   • structural-health grade section
#   • interface fragments — OpenAPI + mermaid erDiagram
#   • open questions / low-confidence (the triage targets)
#   • provenance
#   • attribution header + footer
source "$(dirname "$0")/lib/test_helpers.sh"

TEMPLATE="$REPO_ROOT/references/templates/RECOVERED_DESIGN.md"

assert_file_exists "$TEMPLATE" "references/templates/RECOVERED_DESIGN.md must exist"

# Read the whole template file once; all content assertions match against it.
BODY="$(cat "$TEMPLATE" 2>/dev/null || true)"

# ── attribution (the .md convention) ────────────────────────────────────────────
assert_contains "$BODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "attribution: author header present"
assert_contains "$BODY" "https://github.com/alexfordlabs/reverse-engineer" "attribution: repository URL present"
assert_contains "$BODY" "Skillfully made with [reverse-engineer]" "attribution: footer present"

# ── intentional placeholder markers (filled at runtime, like PA's templates) ─────
assert_contains "$BODY" "{{" "template: carries {{placeholder}} markers (filled at runtime)"
assert_contains "$BODY" "}}" "template: closing placeholder marker present"

# ════════════════════════════════════════════════════════════════════════════════
# THE DECISIONS TABLE — the interop linchpin. Columns: key / value / confidence /
# evidence. This is what `re-ledger set-decision` stores + PA's import-decisions ingests.
# ════════════════════════════════════════════════════════════════════════════════
assert_contains "$BODY" "key" "decisions table: 'key' column (canonical flat key)"
assert_contains "$BODY" "value" "decisions table: 'value' column (the recovered choice)"
assert_contains "$BODY" "confidence" "decisions table: 'confidence' column (High/Med/Low)"
assert_contains "$BODY" "evidence" "decisions table: 'evidence' column (file:line / tool output)"
# Canonical-key + alias guidance carried into the template (interop contract).
assert_contains "$BODY" "canonical" "decisions table: canonical project-architect key guidance"
assert_contains "$BODY" "alias" "decisions table: project-specific alias when no canonical key maps"
# A concrete canonical-key example, matching PA's recognized spellings.
assert_contains "$BODY" "database.engine" "decisions table: concrete canonical-key example"

# ── reflexion sections — convergence / divergence / absence ──────────────────────
assert_contains "$BODY" "convergence" "reflexion: convergence section"
assert_contains "$BODY" "divergence" "reflexion: divergence section"
assert_contains "$BODY" "absence" "reflexion: absence section"

# ── recovered stack + architecture + component boundaries ────────────────────────
assert_contains "$BODY" "stack" "section: recovered stack"
assert_contains "$BODY" "rchitecture" "section: recovered architecture (Architecture/architecture)"
assert_contains "$BODY" "component boundaries" "section: component boundaries"

# ── structural-health grade ──────────────────────────────────────────────────────
assert_contains "$BODY" "tructural health" "section: structural-health grade (Structural/structural)"

# ── interface fragments — OpenAPI + mermaid erDiagram ────────────────────────────
assert_contains "$BODY" "OpenAPI" "fragments: OpenAPI fragment for recovered interfaces"
assert_contains "$BODY" "erDiagram" "fragments: mermaid erDiagram for the recovered data model"

# ── open questions / low-confidence (the triage targets) ─────────────────────────
assert_contains "$BODY" "low-confidence" "section: open questions / low-confidence (triage targets)"

# ── provenance ────────────────────────────────────────────────────────────────────
assert_contains "$BODY" "rovenance" "section: provenance (Provenance/provenance)"

test_summary
