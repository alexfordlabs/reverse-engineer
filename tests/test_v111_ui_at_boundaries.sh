#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# v1.1.1 — the inline-UI directive is wired into the MECHANISM, not just the preamble.
# v1.1.0 added a strong preamble directive (open with the re-ui banner, lead every
# phase boundary P0→P5 with the bar, inline) + embedded the exact art — but the
# per-boundary heartbeat (the "Record progress at every phase boundary" rule, which
# performs the `re-ledger set-substep` write) had NO UI-emission step. An orchestrator
# following that rule step-by-step would write the ledger but never emit the bar; only
# the easily-under-weighted preamble asked for it (mirrors project-architect's v7.1.1
# fix). This pins the reinforcement:
#   • the boundary rule gains a NARRATE (UI) directive — as each phase begins, OPEN the
#     reply with that phase's progress-ladder row + ✓/→/✗ step lines, inline, never left
#     only in a tool-result block. Emitting the bar is now part of the boundary act
#     itself (alongside the set-substep write), not a preamble afterthought.
#   • P0 (the run's first reply) reminds to OPEN with the re-ui banner.
#
# Backtick + UTF-8 needles below are intentional content assertions.
# shellcheck disable=SC2016,SC1091
source "$(dirname "$0")/lib/test_helpers.sh"

SKILL="$REPO_ROOT/skills/reverse-engineer/SKILL.md"
assert_file_exists "$SKILL" "SKILL.md exists"

# Slice the per-boundary rule block (from the boundary heading → the next ## section).
BOUNDARY="$(awk '/Record progress at every phase boundary/{f=1} f&&/^## /{exit} f{print}' "$SKILL")"
assert_contains "$BOUNDARY" "set-substep" "sliced the real per-boundary rule block"

# ── the UI is now part of the boundary act, not preamble-only ─────────────────────
assert_contains "$BOUNDARY" "NARRATE" \
  "boundary rule has a NARRATE (UI) directive"
assert_contains "$BOUNDARY" "progress-ladder row" \
  "NARRATE directive emits the matching progress-ladder row at the boundary"
assert_contains "$BOUNDARY" "inline" \
  "NARRATE directive renders the bar/step-lines inline in the reply"
assert_contains "$BOUNDARY" "tool-result" \
  "NARRATE directive: never left only in a tool-result block"

# ── the banner is reinforced at the run's first reply (P0), not preamble-only ─────
P0="$(awk '/^## P0/{f=1} f&&/^## P[1-9]/{exit} f{print}' "$SKILL")"
assert_contains "$P0" "Detect & scope" "sliced the P0 section"
assert_contains "$P0" "banner" \
  "P0 (first reply of the run) reminds to OPEN with the re-ui banner"

test_summary
