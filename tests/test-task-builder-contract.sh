#!/usr/bin/env bash
#
# Contract tests for task-builder coordination guarantees
#

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_FILE="$TEST_DIR/../agents/task-builder.md"
SKILL_FILE="$TEST_DIR/../skills/task-builder/SKILL.md"

TESTS_RUN=0
TESTS_PASSED=0

assert_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"

    TESTS_RUN=$((TESTS_RUN + 1))
    if rg -q "$pattern" "$file"; then
        echo "  ✓ $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ $message"
    fi
}

echo "=== Task Builder Contract Tests ==="
echo ""

echo "Testing ownership claim protocol in agent instructions..."
assert_contains "$AGENT_FILE" "owner" "Agent docs mention owner-based claim"
assert_contains "$AGENT_FILE" "verify ownership" "Agent docs require ownership verification before work"

echo "Testing ownership claim protocol in skill instructions..."
assert_contains "$SKILL_FILE" "owner" "Skill docs mention owner-based claim"
assert_contains "$SKILL_FILE" "verify ownership" "Skill docs require ownership verification before in_progress"

echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1

