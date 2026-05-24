#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Presence + content test for agents/dependency-mapper.md — the SECOND analysis
# agent of the reverse-engineer suite (after code-inventory).
#
# dependency-mapper is a PROMPT (instructions to a subagent), not executable code.
# The skill's emit phase (authored later) writes the agent's produced content to
# docs/reverse-engineer/DEPENDENCIES.md; the agent itself only PRODUCES that
# content (plus a small re-runnable analysis script it generates AT RUNTIME to
# extract the graph from the target — that script is NOT shipped in this repo).
#
# This test pins the load-bearing elements of the prompt so a future prose edit
# can't silently drop a §4b.1 technique. It asserts the file exists and (via
# assert_contains) carries each non-negotiable element:
#   • frontmatter: name: dependency-mapper + model: opus (mirrors PA's agent schema)
#   • "import" + "graph"  — the internal import/require dependency graph
#   • "cluster"/"component" — cluster modules into candidate architectural components
#   • "cycle"             — cycle detection as a health signal
#   • "smell"/Arcan       — Arcan-style architectural smells (hub-like / god-component)
#   • "layer"/"boundary"  — infer the implicit layer/boundary contracts the code follows
#   • analysis-script     — committed, re-runnable, reproducible extraction script + raw output
#   • "jdeps"             — INVOKE jdeps (Java) language-native graph
#   • "cargo tree"/cargo  — INVOKE cargo tree / cargo metadata (Rust)
#   • "go mod graph"      — INVOKE go mod graph (Go)
#   • "madge"             — INVOKE madge / dependency-cruiser (JS via npx)
#   • "pydeps"            — INVOKE pydeps / import-linter (Py via pipx)
#   • "Semgrep"/AST       — EMULATE: Semgrep-AST import edges → in-prompt graph
#   • "command -v"/probe  — probe-then-degrade (INVOKE→EMULATE cascade)
#   • "provenance"        — each finding records which path produced it (via jdeps / via madge / …)
#   • "EOL"/"stale"       — the version-annotation hand-off to landscape-researcher
#   • "node_modules"/read-only — vendored/build/cache exclusion + read-only over target
source "$(dirname "$0")/lib/test_helpers.sh"

AGENT="$REPO_ROOT/agents/dependency-mapper.md"

assert_file_exists "$AGENT" "agents/dependency-mapper.md must exist"

# Read the whole agent file once; all content assertions match against it.
BODY="$(cat "$AGENT" 2>/dev/null || true)"

# ── frontmatter (mirrors project-architect's agent schema) ──────────────────────
assert_contains "$BODY" "name: dependency-mapper" "frontmatter: name is dependency-mapper"
assert_contains "$BODY" "model: opus" "frontmatter: model is opus"
assert_contains "$BODY" "description:" "frontmatter: has a description (orchestrator dispatch trigger)"

# ── attribution (the .md convention) ────────────────────────────────────────────
assert_contains "$BODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "attribution: author header present"
assert_contains "$BODY" "https://github.com/alexfordlabs/reverse-engineer" "attribution: repository URL present"
assert_contains "$BODY" "Skillfully made with [reverse-engineer]" "attribution: footer present"

# ── §4b.1 technique #1: internal import/require dependency graph ─────────────────
assert_contains "$BODY" "import" "technique: internal import/require edges"
assert_contains "$BODY" "graph" "technique: build the dependency graph"

# ── §4b.1 technique #2: cluster modules into candidate components ────────────────
assert_contains "$BODY" "cluster" "technique: cluster cohesive modules"
assert_contains "$BODY" "component" "technique: candidate architectural components"

# ── §4b.1 technique #3: cycle detection + Arcan-style architectural smells ───────
assert_contains "$BODY" "cycle" "technique: cycle detection (health signal)"
assert_contains "$BODY" "smell" "technique: Arcan-style architectural smells"
# The named smells from the spec — at least the headline ones must appear.
assert_contains "$BODY" "hub-like" "smell: hub-like dependency"
assert_contains "$BODY" "god-component" "smell: god-component"
assert_contains "$BODY" "Arcan" "smell catalog: Arcan attribution"

# ── §4b.1 technique #4: infer the implicit layer/boundary contracts ─────────────
assert_contains "$BODY" "layer" "technique: infer implicit layer contracts"
assert_contains "$BODY" "boundary" "technique: infer the boundary contracts the code follows"

# ── §4b.1 technique #5: committed, re-runnable analysis script + raw output ──────
# code-modernization's extract_topology.py pattern: GENERATE a small analysis
# script at runtime, save it with the recovery artifacts (reproducible/auditable),
# and SHOW its raw output as evidence.
assert_contains "$BODY" "analysis script" "technique: write a committed re-runnable analysis script"
assert_contains "$BODY" "re-runnable" "technique: the analysis script is re-runnable"
assert_contains "$BODY" "reproducible" "technique: reproducible + auditable extraction"

# ── §4b.1 INVOKE language-native cascade ─────────────────────────────────────────
assert_contains "$BODY" "jdeps" "cascade: INVOKE jdeps (Java)"
assert_contains "$BODY" "cargo tree" "cascade: INVOKE cargo tree / cargo metadata (Rust)"
assert_contains "$BODY" "go mod graph" "cascade: INVOKE go mod graph (Go)"
assert_contains "$BODY" "madge" "cascade: INVOKE madge / dependency-cruiser (JS via npx)"
assert_contains "$BODY" "pydeps" "cascade: INVOKE pydeps / import-linter (Py via pipx)"

# ── §4b.1 EMULATE fallback: Semgrep-AST import edges → in-prompt graph ───────────
assert_contains "$BODY" "Semgrep" "cascade: EMULATE Semgrep-AST import edges"
assert_contains "$BODY" "AST" "cascade: AST-derived import edges (fallback)"

# ── §4b.1 probe-then-degrade (INVOKE→EMULATE cascade) ────────────────────────────
assert_contains "$BODY" "command -v" "cascade: command -v probe before INVOKE (graceful degradation)"

# ── provenance: each finding records which path produced it ─────────────────────
assert_contains "$BODY" "provenance" "provenance: each finding records its source (via jdeps / via madge / via Semgrep AST / hand-grep)"

# ── version-annotation hand-off to landscape-researcher ──────────────────────────
# depmap inventories deps + leaves an explicit slot; landscape-researcher attaches
# version/status/CVE; depmap flags stale/superseded/EOL pins ONCE annotated.
assert_contains "$BODY" "landscape-researcher" "hand-off: explicit slot for landscape-researcher's version/status findings"
assert_contains "$BODY" "EOL" "hand-off: flag stale/superseded/EOL pins once annotated"

# ── read-only + vendored/build/cache exclusion (workspace + family discipline) ──
assert_contains "$BODY" "node_modules" "discipline: exclude vendored/build/cache dirs (node_modules)"
assert_contains "$BODY" "read-only" "discipline: read-only over the target"

test_summary
