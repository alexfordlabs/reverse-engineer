#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# v1.2.0 — the UI render mechanism flips from "transcribe embedded art INLINE" to
# "RUN the binary; its stdout in the tool-result block IS the user-visible surface"
# (mirrors project-architect v7.2.0). The inline approach (v1.1.0 embed + v1.1.1
# NARRATE) was discretionary and kept not showing. The fix: a new `re-ui phase-bar
# <Pn>` subcommand maps a P0–P5 key to its 6-step ladder row, and the orchestrator
# folds it into the per-boundary `set-substep` write (`set-substep Pn '<s>' && re-ui
# phase-bar Pn`) so the bar prints in the same tool result as the ledger write. The
# banner is RUN once at P0. This pins that flip across the binary, SKILL.md, output-style.
#
# Backtick + UTF-8 (block-char) needles below are intentional content assertions.
# shellcheck disable=SC2016,SC1091
source "$(dirname "$0")/lib/test_helpers.sh"

UI="$REPO_ROOT/bin/re-ui"
OUTPUT_STYLE="$REPO_ROOT/references/output-style.md"
SKILL="$REPO_ROOT/skills/reverse-engineer/SKILL.md"

# ── the re-ui binary: the three primitives still work ─────────────────────────────
assert_file_exists "$UI" "bin/re-ui exists"
assert_executable  "$UI" "bin/re-ui is executable"
assert_exit_code 0 "$UI" banner
B="$("$UI" banner)"
assert_contains "$B" "reverse-engineer" "re-ui banner carries the literal 'reverse-engineer' tagline"
assert_contains "$B" "█▀█ █▀▀" "re-ui banner renders the RE monogram (row 1)"
assert_contains "$("$UI" progress 3 6 "P2 Recover design")" "50%" "re-ui progress 3/6 → 50%"
assert_eq "$("$UI" step "✓" "done")" "✓ done" "re-ui step renders '<symbol> <text>' verbatim"

# ── phase-bar <Pn> — the v1.2.0 mechanism. Maps a P0–P5 key → its 6-step ladder row ─
PBP2="$("$UI" phase-bar P2)"
assert_contains "$PBP2" "Phase 3/6"          "phase-bar P2 → ladder row 3/6"
assert_contains "$PBP2" "50%"                "phase-bar P2 → 50%"
assert_contains "$PBP2" "P2 Recover design"  "phase-bar P2 → 'P2 Recover design' label"
assert_contains "$("$UI" phase-bar P0)" "Phase 1/6" "phase-bar P0 → row 1/6 (first bar)"
PBP5="$("$UI" phase-bar P5)"
assert_contains "$PBP5" "Phase 6/6" "phase-bar P5 → row 6/6"
assert_contains "$PBP5" "100%"      "phase-bar P5 → 100%"
assert_not_contains "$PBP5" "░"     "phase-bar P5 → all-filled bar"
# unknown / missing key must NOT break the `&& ` chain after a successful set-substep
assert_exit_code 0 "$UI" phase-bar bogus
assert_eq "$("$UI" phase-bar bogus)" "" "phase-bar <unknown key> emits nothing (chain-safe)"
assert_eq "$("$UI" phase-bar)" "" "phase-bar with no arg emits nothing (chain-safe)"

# ── output-style.md: RUN the binary; the tool-result block IS the surface ─────────
assert_file_exists "$OUTPUT_STYLE" "output-style.md exists"
OS="$(cat "$OUTPUT_STYLE")"
assert_contains "$OS" "phase-bar"        "output-style documents the phase-bar subcommand"
assert_contains "$OS" "RUN"              "output-style says to RUN the binary (not transcribe it)"
assert_contains "$OS" "tool-result block" "output-style frames the tool-result block as the surface"
assert_contains "$OS" "set-substep"      "output-style shows the folded set-substep command"
assert_contains "$OS" "do NOT capture"   "output-style keeps the re-ui exception (stdout shown, not suppressed)"
# doc/binary SYNC: the embedded ladder row equals what phase-bar prints today
assert_contains "$OS" "Phase 3/6  [██████████░░░░░░░░░░]  50%  P2 Recover design" \
  "output-style ladder row 3 matches the binary (P2)"
assert_contains "$PBP2" "Phase 3/6  [██████████░░░░░░░░░░]  50%  P2 Recover design" \
  "the binary's phase-bar P2 equals the embedded ladder row (sync guarantee)"

# ── SKILL preamble WIRES run-the-binary ───────────────────────────────────────────
SK="$(cat "$SKILL")"
assert_contains "$SK" "re-ui banner" "SKILL preamble: OPEN the run by RUNNING re-ui banner"
assert_contains "$SK" "phase-bar"    "SKILL preamble references the phase-bar bar"

# ── the per-boundary rule folds phase-bar into the set-substep write ──────────────
BOUNDARY="$(awk '/Record progress at every phase boundary/{f=1} f&&/^## /{exit} f{print}' "$SKILL")"
assert_contains "$BOUNDARY" "set-substep" "sliced the real per-boundary rule block"
assert_contains "$BOUNDARY" "phase-bar"   "boundary rule folds re-ui phase-bar into the set-substep write"
assert_contains "$BOUNDARY" "&&"          "boundary rule shows the && fold"

# ── P0 RUNS the banner (not 'rendered inline in a fenced block') ──────────────────
P0="$(awk '/^## P0/{f=1} f&&/^## P[1-9]/{exit} f{print}' "$SKILL")"
assert_contains "$P0" "Detect & scope" "sliced the P0 section"
assert_contains "$P0" "re-ui banner"   "P0 RUNS re-ui banner (its stdout opens the run in the tool result)"

# ── at least one phase body shows the folded set-substep && re-ui phase-bar ───────
assert_contains "$SK" "&& \${CLAUDE_PLUGIN_ROOT}/bin/re-ui phase-bar P1" \
  "a phase body shows the folded command verbatim (so the model copies the right thing)"

test_summary
