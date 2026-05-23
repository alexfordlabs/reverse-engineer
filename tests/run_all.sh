#!/usr/bin/env bash
# Author: Alexander Ford <alex@alexfordlabs.com>
# License: MIT
# Project: reverse-engineer (https://github.com/alexfordlabs/reverse-engineer)

# Run every test_*.sh file in tests/. Exits non-zero on any failure.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_FILES=()

for t in tests/test_*.sh; do
  [[ -f "$t" ]] || continue
  echo "→ Running $t"
  if bash "$t"; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_FILES+=("$t")
  fi
done

echo ""
echo "═══════════════════════════════"
echo "Test files passed: $TOTAL_PASS"
echo "Test files failed: $TOTAL_FAIL"
if [[ "$TOTAL_FAIL" -gt 0 ]]; then
  echo "Failed:"
  for f in "${FAILED_FILES[@]}"; do
    echo "  $f"
  done
  exit 1
fi
echo "All tests passed."
