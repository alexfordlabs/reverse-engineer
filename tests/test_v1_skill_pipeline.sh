#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# Wave-4 test for skills/reverse-engineer/SKILL.md — the ORCHESTRATING skill.
#
# SKILL.md is a PROMPT/orchestrator doc (not executable code beyond the bin/ calls
# it instructs). It sequences the P0–P5 pipeline, dispatches the 6 analysis agents in
# the correct order, threads each agent's output into the downstream agents that need
# it, drives the bin/ helpers (re-detect / re-emit / re-ledger), records per-phase
# progress for resumability, and cites the two references it leans on (output-style +
# dispatch-prompts). This test pins those load-bearing elements so a future prose edit
# can't silently drop the pipeline's spine.
#
# It asserts the file exists and (via assert_contains) carries each non-negotiable
# element:
#   • frontmatter: name: reverse-engineer + a TRIGGER-RICH description (writing-skills)
#   • each of P0–P5 named (Detect / Understand / Recover / Triage / Emit / Handoff)
#   • all 6 agents named (code-inventory, dependency-mapper, requirements-extractor,
#     landscape-researcher, characterization-tester, design-recoverer)
#   • the input-threading ("input"/"thread") between agents
#   • the helpers: re-detect + re-emit + set-substep (resumability)
#   • cites output-style + dispatch-prompts
#   • "opus" (dispatch discipline)
#   • defer-to-project-architect (P0 deferral) + consent-gated characterization
source "$(dirname "$0")/lib/test_helpers.sh"

SKILL="$REPO_ROOT/skills/reverse-engineer/SKILL.md"

assert_file_exists "$SKILL" "skills/reverse-engineer/SKILL.md must exist"

# Read the whole skill file once; all content assertions match against it.
BODY="$(cat "$SKILL" 2>/dev/null || true)"
# Case-insensitive copy for trigger/word-presence checks that shouldn't be brittle on case.
LOWER="$(printf '%s' "$BODY" | tr '[:upper:]' '[:lower:]')"

# ── frontmatter (mirrors project-architect's skill schema) ──────────────────────
assert_contains "$BODY" "name: reverse-engineer" "frontmatter: name is reverse-engineer"
assert_contains "$BODY" "description:" "frontmatter: has a description (the activation trigger surface)"

# ── attribution (the .md convention) ────────────────────────────────────────────
assert_contains "$BODY" "Author: Alexander Ford <alex@alexfordlabs.com>" "attribution: author header present"
assert_contains "$BODY" "https://github.com/alexfordlabs/reverse-engineer" "attribution: repository URL present"
assert_contains "$BODY" "Skillfully made with [reverse-engineer]" "attribution: footer present"

# ── trigger-rich description (writing-skills discipline) ─────────────────────────
# The description must contain natural-language triggers so prompts reliably activate it.
# Extract just the frontmatter description region (between the two leading '---' fences)
# to assert the triggers live in the description, not merely elsewhere in the body.
FRONTMATTER="$(awk 'NR==1 && $0=="---"{f=1;next} f&&$0=="---"{exit} f{print}' "$SKILL")"
FM_LOWER="$(printf '%s' "$FRONTMATTER" | tr '[:upper:]' '[:lower:]')"
assert_contains "$FM_LOWER" "reverse-engineer" "description: trigger 'reverse-engineer'"
assert_contains "$FM_LOWER" "recover" "description: trigger 'recover the design'"
assert_contains "$FM_LOWER" "existing" "description: trigger 'existing code/project'"
# brownfield OR foreign — the core target framing must appear in the description.
assert_eq "$(printf '%s' "$FM_LOWER" | grep -Eqc 'brownfield|foreign' && echo yes || echo no)" "yes" "description: trigger 'brownfield/foreign project'"
assert_contains "$FM_LOWER" "understand" "description: trigger 'understand this existing code'"

# ── the P0–P5 phases (all six named) ────────────────────────────────────────────
assert_contains "$BODY" "P0" "phase P0 present"
assert_contains "$BODY" "P1" "phase P1 present"
assert_contains "$BODY" "P2" "phase P2 present"
assert_contains "$BODY" "P3" "phase P3 present"
assert_contains "$BODY" "P4" "phase P4 present"
assert_contains "$BODY" "P5" "phase P5 present"
# The phase names (spec §3) so the order is semantically pinned, not just labels.
assert_contains "$LOWER" "detect" "P0 phase name: Detect & scope"
assert_contains "$LOWER" "understand" "P1 phase name: Understand"
assert_contains "$LOWER" "recover" "P2 phase name: Recover design"
assert_contains "$LOWER" "triage" "P3 phase name: Triage & validate"
assert_contains "$LOWER" "emit" "P4 phase name: Emit"
assert_contains "$LOWER" "handoff" "P5 phase name: Handoff"

# ── all 6 agents named (the dispatch surface) ───────────────────────────────────
assert_contains "$BODY" "code-inventory" "agent: code-inventory dispatched"
assert_contains "$BODY" "dependency-mapper" "agent: dependency-mapper dispatched"
assert_contains "$BODY" "requirements-extractor" "agent: requirements-extractor dispatched"
assert_contains "$BODY" "landscape-researcher" "agent: landscape-researcher dispatched"
assert_contains "$BODY" "characterization-tester" "agent: characterization-tester dispatched"
assert_contains "$BODY" "design-recoverer" "agent: design-recoverer dispatched"

# ── input-threading (CRITICAL — each agent's output feeds the downstream agents) ─
assert_contains "$LOWER" "input" "threading: agents receive inputs from upstream agents"
assert_contains "$LOWER" "thread" "threading: outputs are threaded into downstream agents"
# code-inventory is dispatched FIRST (the others build on it) — pin the ordering claim.
assert_contains "$LOWER" "first" "threading: code-inventory runs FIRST"
# The explicit upstream→downstream chain must be stated.
assert_eq "$(printf '%s' "$BODY" | grep -Eqc 'code-inventory[^.]*(→|->|feeds|into|to) *(dependency-mapper|requirements-extractor)' && echo yes || echo no)" "yes" "threading: code-inventory feeds dependency-mapper + requirements-extractor"

# ── the bin/ helpers (mechanics) + resumability via set-substep ─────────────────
assert_contains "$BODY" "re-detect" "helper: re-detect (P0 detection verdict)"
assert_contains "$BODY" "re-emit" "helper: re-emit (P4 artifact-set writer)"
assert_contains "$BODY" "re-ledger" "helper: re-ledger (state writer)"
assert_contains "$BODY" "set-substep" "resumability: re-ledger set-substep records per-phase progress"
assert_contains "$LOWER" "resum" "resumability: an interrupted run resumes"

# ── P0 deferral to project-architect (re-detect's action verdict) ───────────────
assert_contains "$BODY" "defer-to-project-architect" "P0: defers to project-architect when architect state present"

# ── consent-gated / opt-in characterization (it executes foreign code) ───────────
assert_contains "$LOWER" "opt-in" "characterization is opt-in"
assert_contains "$LOWER" "consent" "characterization is consent-gated"

# ── cites the two references ─────────────────────────────────────────────────────
assert_contains "$BODY" "output-style" "cites references/output-style.md"
assert_contains "$BODY" "dispatch-prompts" "cites references/dispatch-prompts.md"

# ── dispatch discipline: opus ─────────────────────────────────────────────────────
assert_contains "$LOWER" "opus" "dispatch: every agent dispatched model opus"

# ── P4 references import-decisions (added in W4-interop; referenced here) ─────────
assert_contains "$BODY" "import-decisions" "P4/P5: references re-ledger import-decisions (the keyspace ingest)"

# ── the two new references exist (top-level references/, like the sibling refs) ──
assert_file_exists "$REPO_ROOT/references/output-style.md" "references/output-style.md must exist"
assert_file_exists "$REPO_ROOT/references/dispatch-prompts.md" "references/dispatch-prompts.md must exist"

test_summary
