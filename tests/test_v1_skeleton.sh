#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)
source "$(dirname "$0")/lib/test_helpers.sh"

# Wave-0 plugin-skeleton smoke test: the manifest exists, is valid JSON, and
# carries the canonical name / version / author for the reverse-engineer plugin.

MANIFEST="$REPO_ROOT/.claude-plugin/plugin.json"

assert_file_exists "$MANIFEST" "plugin.json must exist"

if ! command -v jq >/dev/null 2>&1; then echo "SKIP: jq not installed"; test_summary; exit 0; fi

# Valid JSON (parses via jq)
assert_exit_code 0 jq -e . "$MANIFEST"

# Canonical manifest fields
assert_eq "$(jq -r .name "$MANIFEST")" "reverse-engineer" ".name must be reverse-engineer"
assert_eq "$(jq -r .version "$MANIFEST")" "1.1.2" ".version must be 1.1.2"
assert_eq "$(jq -r .author.email "$MANIFEST")" "alex@alexfordlabs.com" ".author.email must be alex@alexfordlabs.com"

test_summary
