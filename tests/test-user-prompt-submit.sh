#!/usr/bin/env bash
#
# Tests for user-prompt-submit.sh hook
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/../hooks/user-prompt-submit.sh"

source "$SCRIPT_DIR/../hooks/lib/loop-helpers.sh"

TESTS_RUN=0
TESTS_PASSED=0

run_hook() {
    local project_dir="$1"
    local input="${2:-{}}"
    printf '%s' "$input" | CLAUDE_PROJECT_DIR="$project_dir" "$HOOK_PATH"
}

is_empty_output() {
    local output="$1"
    [[ -z "${output//[[:space:]]/}" ]]
}

json_field() {
    local output="$1"
    local filter="$2"
    if is_empty_output "$output"; then
        echo ""
        return 0
    fi
    echo "$output" | jq -r "$filter"
}

# --- Tests ---

test_inactive_loop_outputs_nothing() {
    echo "Testing no output when loop inactive..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(mktemp -d)
    delete_state_file "$test_dir"

    local output
    output=$(run_hook "$test_dir")

    if is_empty_output "$output"; then
        echo "  OK No output when loop inactive"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL Expected empty output when loop inactive"
    fi

    rm -rf "$test_dir"
}

test_active_loop_outputs_anchor() {
    echo "Testing protocol anchor output when loop active..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(mktemp -d)
    initialize_loop_state "$test_dir" "Test goal" 10

    local output
    output=$(run_hook "$test_dir")
    local ctx
    ctx=$(json_field "$output" '.hookSpecificOutput.additionalContext // ""')

    if [[ "$ctx" == *"Autonomous Loop Protocol Anchor"* && "$ctx" == *"AUTONOMOUS_BUILD_CLAUDE.md"* && "$ctx" == *"<verified code=\"####\"/>"* ]]; then
        echo "  OK Protocol anchor included"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL Expected protocol anchor in output"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_verification_pending_notice() {
    echo "Testing verification pending notice..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(mktemp -d)
    initialize_loop_state "$test_dir" "Test goal" 10
    update_state_field "$test_dir" ".verification_pending" "true"

    local output
    output=$(run_hook "$test_dir")
    local ctx
    ctx=$(json_field "$output" '.hookSpecificOutput.additionalContext // ""')

    if [[ "$ctx" == *"Verification pending"* ]]; then
        echo "  OK Verification pending notice included"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL Expected verification pending notice"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

# Run tests
echo "=== User Prompt Submit Hook Tests ==="
echo ""

test_inactive_loop_outputs_nothing
test_active_loop_outputs_anchor
test_verification_pending_notice

# Summary
echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
