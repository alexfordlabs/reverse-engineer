#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# v1.1.0 — the inline banner + advancing progress bar (mirrors project-architect's
# bin/architect-ui wiring). v1.0.0 shipped only the plain-text ✓/→/✗ convention and
# no UI binary, so a run showed no banner or progress bar. This pins the fix:
#   • bin/re-ui exists (executable) and renders banner / progress / step (pure stdout).
#   • output-style.md EMBEDS the exact banner art + the P0–P5 progress ladder
#     (re-ui-sourced) and states the UI is rendered INLINE in the reply (the
#     exception to capture-don't-dump), never left only in a tool-result block.
#   • SKILL.md's preamble WIRES the directive: open the run with the banner, lead
#     every phase boundary (P0→P5) with the bar + step lines, inline.
#
# Backtick + UTF-8 (block-char) needles below are intentional content assertions.
# shellcheck disable=SC2016,SC1091
source "$(dirname "$0")/lib/test_helpers.sh"

UI="$REPO_ROOT/bin/re-ui"
OUTPUT_STYLE="$REPO_ROOT/references/output-style.md"
SKILL="$REPO_ROOT/skills/reverse-engineer/SKILL.md"

# ── the re-ui binary exists + renders the three primitives ────────────────────────
assert_file_exists "$UI" "bin/re-ui exists"
assert_executable  "$UI" "bin/re-ui is executable"
assert_exit_code 0 "$UI" banner
B="$("$UI" banner)"
assert_contains "$B" "reverse-engineer" "re-ui banner carries the literal 'reverse-engineer' tagline"
assert_contains "$B" "█▀█ █▀▀" "re-ui banner renders the RE monogram (row 1)"
P="$("$UI" progress 3 6 "P2 Recover design")"
assert_contains "$P" "50%" "re-ui progress 3/6 shows 50%"
assert_contains "$P" "█"   "re-ui progress 3/6 has at least one filled block"
S="$("$UI" step "✓" "done")"
assert_contains "$S" "✓ done" "re-ui step renders '<symbol> <text>' verbatim"

# ── output-style.md embeds the banner + the P0–P5 ladder (re-ui-sourced) ──────────
assert_file_exists "$OUTPUT_STYLE" "output-style.md exists"
OS="$(cat "$OUTPUT_STYLE")"
assert_contains "$OS" "█▀█ █▀▀" "output-style embeds the exact re-ui banner monogram (row 1)"
# sync: the embedded monogram equals what the binary prints today
assert_contains "$B" "█▀█ █▀▀" "the re-ui banner matches the embedded art (sync)"
assert_contains "$OS" "Phase 1/6" "output-style embeds the P0–P5 progress ladder (first phase)"
assert_contains "$OS" "Phase 6/6  [████████████████████] 100%" \
  "output-style embeds the ladder (final phase, full bar)"
assert_contains "$OS" "Phase 3/6  [██████████░░░░░░░░░░]  50%" \
  "output-style embeds a mid-run ladder row (binary-exact bar)"
assert_contains "$OS" "inline" "output-style states the UI is rendered inline"
assert_contains "$OS" "tool-result" \
  "output-style says the UI is NOT left only in a tool-result block (rendered in the reply)"

# ── SKILL.md preamble WIRES the directive (was text-only ✓/→/✗ before) ────────────
SK="$(cat "$SKILL")"
assert_contains "$SK" "re-ui" "SKILL preamble names the re-ui renderer"
assert_contains "$SK" "banner" "SKILL preamble wires: open the run with the banner"
assert_contains "$SK" "ladder" "SKILL preamble points at the per-phase progress ladder"

test_summary
