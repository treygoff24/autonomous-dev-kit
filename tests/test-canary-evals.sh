#!/usr/bin/env bash
#
# Tests for canary eval harness
#

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANARY_RUNNER="$TEST_DIR/../evals/canary/run.sh"
CANARY_CASES="$TEST_DIR/../evals/canary/cases.json"

TESTS_RUN=0
TESTS_PASSED=0

echo "=== Canary Eval Tests ==="
echo ""

echo "Testing canary files exist..."
TESTS_RUN=$((TESTS_RUN + 1))
if [[ -x "$CANARY_RUNNER" && -f "$CANARY_CASES" ]]; then
    echo "  ✓ Canary runner and cases file exist"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  ✗ Canary runner and cases file should exist"
fi

echo "Testing canary runner emits JSON report..."
TESTS_RUN=$((TESTS_RUN + 1))
if [[ -x "$CANARY_RUNNER" ]]; then
    temp_report_dir=$(mktemp -d)
    report_path=$(CANARY_REPORT_DIR="$temp_report_dir" "$CANARY_RUNNER" 2>/dev/null || true)
    if [[ -n "$report_path" && -f "$report_path" ]] && jq -e '.summary.pass_rate' "$report_path" >/dev/null 2>&1; then
        echo "  ✓ Canary runner writes report with pass_rate"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Canary runner should output report path with summary.pass_rate"
    fi
    rm -rf "$temp_report_dir"
else
    echo "  ✗ Canary runner missing or not executable"
fi

echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
