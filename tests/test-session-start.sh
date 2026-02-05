#!/usr/bin/env bash
#
# Tests for session-start.sh hook behavior
#

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$TEST_DIR/../hooks/session-start.sh"

TESTS_RUN=0
TESTS_PASSED=0

create_test_repo() {
    local dir
    dir=$(mktemp -d)
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@test.com"
    git -C "$dir" config user.name "Test"
    echo "test" > "$dir/file.txt"
    git -C "$dir" add file.txt
    git -C "$dir" commit -q -m "initial"
    echo "$dir"
}

test_missing_handoff_dir_does_not_crash() {
    echo "Testing missing handoff directory does not crash..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(create_test_repo)

    local output
    output=$(echo '{}' | CLAUDE_PROJECT_DIR="$test_dir" "$HOOK_PATH" 2>/dev/null || true)

    if [[ "$output" == *"hookSpecificOutput"* ]]; then
        echo "  ✓ Hook returns output without handoff directory"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Hook should return output without handoff directory"
    fi

    rm -rf "$test_dir"
}

test_specialized_agent_not_forced_to_orchestrator() {
    echo "Testing specialized agent context does not force orchestrator role..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(create_test_repo)
    mkdir -p "$test_dir/thoughts/handoffs"
    echo "# Handoff" > "$test_dir/thoughts/handoffs/auto-handoff-$(date +%Y%m%d-%H%M%S).md"

    local output
    output=$(echo '{"agent_type":"task-builder"}' | CLAUDE_PROJECT_DIR="$test_dir" "$HOOK_PATH" 2>/dev/null || true)
    local ctx
    ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // ""')

    if [[ "$ctx" == *"Agent Context: Plan Executor"* ]] && [[ "$ctx" != *"You are the orchestrator, not the implementer."* ]]; then
        echo "  ✓ Specialized agent receives non-orchestrator resume context"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Specialized agent context should not include orchestrator-only reminder"
    fi

    rm -rf "$test_dir"
}

echo "=== Session Start Hook Tests ==="
echo ""

test_missing_handoff_dir_does_not_crash
test_specialized_agent_not_forced_to_orchestrator

echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1

