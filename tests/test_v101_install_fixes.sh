#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
#
# v1.0.1 install-verification fixes — pins the three corrections surfaced by the
# live post-install run of v1.0.0 on the bundled e2e-foreign-node fixture:
#
#   (a) SUBAGENT reference-path resolution. A dispatched subagent gets NO plugin
#       base directory (only the orchestrator's loaded SKILL does), so an agent's
#       plugin-relative `../references/foo.md` resolves against the agent's cwd
#       (the user's project) and fails. The robust fix mirrors project-architect:
#       the ORCHESTRATOR (which has ${CLAUDE_PLUGIN_ROOT}) threads the ABSOLUTE
#       reference path into the two dispatches that read a bundled reference —
#       landscape-researcher (the cascade) + design-recoverer (the template).
#       The agents read the threaded absolute path; their inline content stays
#       as the degradation floor.
#
#   (b) endoflife.date field shape. The v1 endpoint returns clean JSON with
#       `.result.releases[]`, each carrying `isEol` (boolean) + `eolFrom` (date)
#       — NOT the legacy `/api/{product}.json` single `eol` field. The reference
#       prose must name the v1 fields + the legacy distinction.
#
#   (c) advisory dispatch flags. semgrep_mcp_available / security_review_available
#       / context7_available are ADVISORY — a dispatched subagent's real tool
#       surface is Read/Grep/Glob/Bash (+Web for landscape), so MCP/skill tools
#       may be unavailable; the agent verifies its own tool surface and degrades.
source "$(dirname "$0")/lib/test_helpers.sh"

SKILL="$REPO_ROOT/skills/reverse-engineer/SKILL.md"
DISPATCH="$REPO_ROOT/references/dispatch-prompts.md"
CASCADE="$REPO_ROOT/references/current-version-cascade.md"
LANDSCAPE="$REPO_ROOT/agents/landscape-researcher.md"
DESIGNREC="$REPO_ROOT/agents/design-recoverer.md"

assert_file_exists "$SKILL"     "SKILL.md must exist"
assert_file_exists "$DISPATCH"  "dispatch-prompts.md must exist"
assert_file_exists "$CASCADE"   "current-version-cascade.md must exist"
assert_file_exists "$LANDSCAPE" "landscape-researcher.md must exist"
assert_file_exists "$DESIGNREC" "design-recoverer.md must exist"

SKILL_BODY="$(cat "$SKILL" 2>/dev/null || true)"
DISPATCH_BODY="$(cat "$DISPATCH" 2>/dev/null || true)"
CASCADE_BODY="$(cat "$CASCADE" 2>/dev/null || true)"
LANDSCAPE_BODY="$(cat "$LANDSCAPE" 2>/dev/null || true)"
DESIGNREC_BODY="$(cat "$DESIGNREC" 2>/dev/null || true)"

# ── (a) orchestrator threads ABSOLUTE reference paths into the two dispatches ─────
# The orchestrator (SKILL.md) builds the absolute path from ${CLAUDE_PLUGIN_ROOT}
# (harness-expanded for the loaded skill) and threads it as a named input.
assert_contains "$SKILL_BODY" "cascade_reference_path" \
  "(a) SKILL threads cascade_reference_path into the landscape-researcher dispatch"
assert_contains "$SKILL_BODY" "recovered_design_template_path" \
  "(a) SKILL threads recovered_design_template_path into the design-recoverer dispatch"
assert_contains "$SKILL_BODY" "\${CLAUDE_PLUGIN_ROOT}/references/current-version-cascade.md" \
  "(a) SKILL builds the absolute cascade path from \${CLAUDE_PLUGIN_ROOT}"
assert_contains "$SKILL_BODY" "\${CLAUDE_PLUGIN_ROOT}/references/templates/RECOVERED_DESIGN.md" \
  "(a) SKILL builds the absolute template path from \${CLAUDE_PLUGIN_ROOT}"

# dispatch-prompts.md exposes the path slots in the two [INPUTS] blocks + the rationale
assert_contains "$DISPATCH_BODY" "cascade_reference_path" \
  "(a) dispatch-prompts landscape [INPUTS] carries cascade_reference_path"
assert_contains "$DISPATCH_BODY" "recovered_design_template_path" \
  "(a) dispatch-prompts design-recoverer [INPUTS] carries recovered_design_template_path"
assert_contains "$DISPATCH_BODY" "dispatched subagent" \
  "(a) dispatch-prompts states the rationale (a dispatched subagent has no base dir)"
assert_contains "$DISPATCH_BODY" "absolute" \
  "(a) dispatch-prompts: the threaded reference path is absolute"

# the agents consume the threaded absolute input (keeping the inline summary as fallback)
assert_contains "$LANDSCAPE_BODY" "cascade_reference_path" \
  "(a) landscape-researcher reads its cascade_reference_path input (absolute)"
assert_contains "$LANDSCAPE_BODY" "current-version-cascade.md" \
  "(a) landscape-researcher still names the cascade reference (kept; inline-fallback floor)"
assert_contains "$DESIGNREC_BODY" "recovered_design_template_path" \
  "(a) design-recoverer reads its recovered_design_template_path input (absolute)"
assert_contains "$DESIGNREC_BODY" "RECOVERED_DESIGN.md" \
  "(a) design-recoverer still names the template (kept; inline-fallback floor)"

# ── (b) endoflife.date v1 field shape documented correctly ────────────────────────
assert_contains "$CASCADE_BODY" "isEol" \
  "(b) cascade reference names the v1 isEol boolean field"
assert_contains "$CASCADE_BODY" "eolFrom" \
  "(b) cascade reference names the v1 eolFrom date field"
assert_contains "$CASCADE_BODY" ".result.releases" \
  "(b) cascade reference documents the v1 .result.releases[] path"
assert_contains "$CASCADE_BODY" "legacy" \
  "(b) cascade reference notes the legacy /api/{product}.json shape distinction"

# ── (c) advisory note on the *_available dispatch flags ───────────────────────────
assert_contains "$DISPATCH_BODY" "advisory" \
  "(c) dispatch-prompts marks the *_available flags advisory"
assert_contains "$DISPATCH_BODY" "tool surface" \
  "(c) dispatch-prompts: the agent verifies its own tool surface + degrades"

test_summary
