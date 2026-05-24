#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Wave-4 test for references/output-style.md — the orchestrator's narration + error
# convention (mirrors project-architect's output-style.md).
#
# output-style.md is the convention the SKILL follows when it narrates a run: capture
# mechanical tool output instead of dumping it (clean ✓ / → / ✗ step lines), and — at a
# BLOCKER — run the R2 self-heal protocol: surface a concise informational error state,
# then offer two paths via AskUserQuestion {write a report & stop | self-heal: propose
# concrete remediations from the gathered info, apply after approval, continue}.
#
# This test pins those load-bearing elements so a future edit can't silently turn the
# error path back into a raw-trace dump or a silent failure.
#
# Asserts (against the output-style body):
#   • the informational-progress / capture-don't-dump convention (✓ / → / ✗ steps)
#   • the R2 self-heal: informational error → report-or-self-heal
#   • AskUserQuestion offering the two explicit paths
#   • markdown attribution (header + footer)
source "$(dirname "$0")/lib/test_helpers.sh"

OS="$REPO_ROOT/references/output-style.md"

assert_file_exists "$OS" "references/output-style.md must exist"

BODY="$(cat "$OS" 2>/dev/null || true)"
LOWER="$(printf '%s' "$BODY" | tr '[:upper:]' '[:lower:]')"

# ── attribution (the .md convention: header + footer) ───────────────────────────
assert_contains "$BODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "attribution: author header present"
assert_contains "$BODY" "https://github.com/alexfordlabs/reverse-engineer" "attribution: repository URL present"
assert_contains "$BODY" "Skillfully made with [reverse-engineer]" "attribution: footer present"

# ── capture-don't-dump informational progress ───────────────────────────────────
assert_eq "$(printf '%s' "$LOWER" | grep -Eqc "capture|don't dump|do not dump" && echo yes || echo no)" "yes" "convention: capture-don't-dump (no raw tool spam in the transcript)"
assert_contains "$LOWER" "progress" "convention: surface informational progress, not plumbing"
# The clean step-line vocabulary (✓ done / → in-progress / ✗ failure).
assert_contains "$BODY" "✓" "convention: ✓ done step line"
assert_contains "$BODY" "→" "convention: → in-progress step line"
assert_contains "$BODY" "✗" "convention: ✗ failure step line"

# ── R2 self-heal: informational error state at a BLOCKER ─────────────────────────
assert_contains "$LOWER" "blocker" "self-heal: triggered on a BLOCKER"
assert_eq "$(printf '%s' "$LOWER" | grep -Eqc 'informational error|error state' && echo yes || echo no)" "yes" "self-heal: surfaces a concise informational error state (not a raw trace)"
assert_eq "$(printf '%s' "$LOWER" | grep -Eqc 'self-heal|self heal' && echo yes || echo no)" "yes" "self-heal: the self-heal path is named"
assert_contains "$LOWER" "remediation" "self-heal: proposes concrete remediations from gathered info"
assert_contains "$LOWER" "approv" "self-heal: remediations applied only after the user approves"

# ── AskUserQuestion: the two explicit paths (report-or-self-heal) ───────────────
assert_contains "$BODY" "AskUserQuestion" "self-heal: routed via AskUserQuestion"
assert_eq "$(printf '%s' "$LOWER" | grep -Eqc 'report (and|&) stop|report and halt|write a report' && echo yes || echo no)" "yes" "self-heal: path 1 = write a report and stop"
assert_eq "$(printf '%s' "$LOWER" | grep -Eqc 'continue|fix-and-continue|continue the flow|resume' && echo yes || echo no)" "yes" "self-heal: path 2 = self-heal and continue"

# ── success terse, failure detailed (the §1 exception) ──────────────────────────
assert_eq "$(printf '%s' "$LOWER" | grep -Eqc 'success.*terse|terse.*success|failure.*detail|detail.*failure' && echo yes || echo no)" "yes" "convention: success terse, failure detailed"

test_summary
