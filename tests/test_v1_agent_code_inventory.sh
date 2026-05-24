#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Presence + content test for agents/code-inventory.md — the FIRST analysis agent
# of the reverse-engineer suite.
#
# code-inventory is a PROMPT (instructions to a subagent), not executable code. The
# skill's emit phase (authored later) writes the agent's produced content to
# docs/reverse-engineer/INVENTORY.md; the agent itself only PRODUCES that content.
#
# This test pins the load-bearing elements of the prompt so a future prose edit
# can't silently drop a technique. It asserts the file exists and (via
# assert_contains) carries each non-negotiable element:
#   • frontmatter: name: code-inventory + model: opus (mirrors PA's agent schema)
#   • "entry point"      — read entry points before grepping (control flow over names)
#   • "file:line"        — every claim cites file:line
#   • "appears"          — the is-vs-appears-to-be (verified fact vs inference) split
#   • data-first         — inventory schemas/models/DDL/types before procedural code
#   • "RepoMap"/"ranked"  — token-budgeted ranked symbol map (defs↔refs by importance)
#   • "scc"              — INVOKE scc for file/line/complexity inventory
#   • "AST"/"Semgrep"     — Semgrep MCP get_abstract_syntax_tree for per-file structure
#   • "ctags"            — ctags/LSP for symbol defs↔refs
#   • "command -v"/probe  — probe-then-degrade (INVOKE→EMULATE cascade)
#   • "provenance"/evidence — each finding records which path produced it
#   • "node_modules"      — vendored/build/cache exclusion
source "$(dirname "$0")/lib/test_helpers.sh"

AGENT="$REPO_ROOT/agents/code-inventory.md"

assert_file_exists "$AGENT" "agents/code-inventory.md must exist"

# Read the whole agent file once; all content assertions match against it.
BODY="$(cat "$AGENT" 2>/dev/null || true)"

# ── frontmatter (mirrors project-architect's agent schema) ──────────────────────
assert_contains "$BODY" "name: code-inventory" "frontmatter: name is code-inventory"
assert_contains "$BODY" "model: opus" "frontmatter: model is opus"
assert_contains "$BODY" "description:" "frontmatter: has a description (orchestrator dispatch trigger)"

# ── attribution (the .md convention) ────────────────────────────────────────────
assert_contains "$BODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "attribution: author header present"
assert_contains "$BODY" "https://github.com/alexfordlabs/reverse-engineer" "attribution: repository URL present"
assert_contains "$BODY" "Skillfully made with [reverse-engineer]" "attribution: footer present"

# ── §4b.1 technique #1: read entry points before grepping ───────────────────────
assert_contains "$BODY" "entry point" "technique: read entry points (control flow over names)"

# ── §4b.1 technique #2: cite file:line for every claim ──────────────────────────
assert_contains "$BODY" "file:line" "technique: cite file:line for every claim"

# ── §4b.1 technique #3: is vs appears-to-be (verified fact vs inference) ─────────
assert_contains "$BODY" "appears" "technique: separate 'is' from 'appears-to-be'"

# ── §4b.1 technique #4: find the data first (schemas/models more truthful) ──────
# Data-first means inventorying schemas/models/types ahead of procedural code.
assert_contains "$BODY" "schema" "technique: data-first — inventory schemas"
assert_contains "$BODY" "model" "technique: data-first — inventory data models"

# ── §4b.1 technique #5: RepoMap-style ranked symbol map ─────────────────────────
assert_contains "$BODY" "RepoMap" "technique: RepoMap-style symbol map (aider recipe)"
assert_contains "$BODY" "ranked" "technique: ranked-by-importance symbol map"

# ── §4b.1 technique #6: exclude vendored/build/cache dirs ───────────────────────
assert_contains "$BODY" "node_modules" "technique: exclude vendored/build/cache dirs (node_modules)"

# ── §4b.1 INVOKE→EMULATE tool cascade ───────────────────────────────────────────
assert_contains "$BODY" "scc" "cascade: INVOKE scc (file/line inventory + complexity + COCOMO)"
# Semgrep MCP get_abstract_syntax_tree — AST or Semgrep must be present.
assert_contains "$BODY" "AST" "cascade: AST (Semgrep get_abstract_syntax_tree)"
assert_contains "$BODY" "ctags" "cascade: ctags/LSP for symbol defs↔refs"
# Probe-then-degrade: command -v presence probe + graceful fallback to Glob/Grep.
assert_contains "$BODY" "command -v" "cascade: command -v probe before INVOKE (graceful degradation)"

# ── provenance: each finding records which path produced it ─────────────────────
assert_contains "$BODY" "provenance" "provenance: each finding records its source (scc vs hand-grep)"

# ── read-only + secret hygiene (workspace HARD RULE) ────────────────────────────
assert_contains "$BODY" "read-only" "discipline: read-only over the target"

test_summary
