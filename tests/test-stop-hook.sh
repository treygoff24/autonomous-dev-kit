#!/usr/bin/env bash
#
# Tests for stop.sh autonomous loop enforcement
#

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$TEST_DIR/../hooks/stop.sh"
source "$TEST_DIR/../hooks/lib/loop-helpers.sh"

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

run_hook() {
    local project_dir="$1"
    local input="${2:-{}}"
    set +e
    local output
    output=$(printf '%s' "$input" | CLAUDE_PROJECT_DIR="$project_dir" "$HOOK_PATH" 2>&1)
    local exit_code=$?
    set -e
    printf '%s\n' "$exit_code"
    printf '%s' "$output"
}

test_hook_exists_and_executable() {
    echo "Testing hook exists and is executable..."
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -x "$HOOK_PATH" ]]; then
        echo "  ✓ stop.sh exists and is executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ stop.sh missing or not executable"
    fi
}

test_inactive_loop_allows_exit() {
    echo "Testing inactive loop allows exit..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(create_test_repo)

    local result
    result=$(run_hook "$test_dir")
    local exit_code
    exit_code=$(echo "$result" | head -n1)

    if [[ "$exit_code" == "0" ]]; then
        echo "  ✓ Inactive loop allows exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected exit code 0, got $exit_code"
    fi

    rm -rf "$test_dir"
}

test_active_loop_blocks_and_increments_iteration() {
    echo "Testing active loop blocks and increments iteration..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(create_test_repo)

    initialize_loop_state "$test_dir" "Test goal" 100
    echo "dirty" >> "$test_dir/file.txt"

    local result
    result=$(run_hook "$test_dir")
    local exit_code
    exit_code=$(echo "$result" | head -n1)

    local state
    state=$(read_state_file "$test_dir")
    local iteration
    iteration=$(echo "$state" | jq -r '.iteration')

    if [[ "$exit_code" == "2" && "$iteration" == "1" ]]; then
        echo "  ✓ Active loop blocks and increments iteration"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected exit 2 and iteration 1 (got exit=$exit_code, iteration=$iteration)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_protocol_verification_triggered_every_three_iterations() {
    echo "Testing protocol verification triggers every 3 iterations..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(create_test_repo)

    initialize_loop_state "$test_dir" "Test goal" 100
    update_state_field "$test_dir" ".iteration" "2"
    update_state_field "$test_dir" ".last_verified_iteration" "0"
    echo "dirty" >> "$test_dir/file.txt"

    local result
    result=$(run_hook "$test_dir")
    local exit_code
    exit_code=$(echo "$result" | head -n1)

    local state
    state=$(read_state_file "$test_dir")
    local pending
    pending=$(echo "$state" | jq -r '.verification_pending')
    local code
    code=$(echo "$state" | jq -r '.expected_verification_code // ""')

    if [[ "$exit_code" == "2" && "$pending" == "true" && "$code" =~ ^[0-9]{4}$ ]]; then
        echo "  ✓ Verification pending and code generated at iteration 3"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected verification pending with 4-digit code (exit=$exit_code, pending=$pending, code=$code)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_max_iterations_pauses_loop() {
    echo "Testing max iterations pauses loop..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(create_test_repo)

    initialize_loop_state "$test_dir" "Test goal" 3
    update_state_field "$test_dir" ".iteration" "2"
    echo "dirty" >> "$test_dir/file.txt"

    local result
    result=$(run_hook "$test_dir")
    local exit_code
    exit_code=$(echo "$result" | head -n1)

    local state
    state=$(read_state_file "$test_dir")
    local paused
    paused=$(echo "$state" | jq -r '.paused')

    if [[ "$exit_code" == "2" && "$paused" == "true" ]]; then
        echo "  ✓ Loop pauses at max iterations"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected paused=true at max iterations (exit=$exit_code, paused=$paused)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_completion_allows_exit_and_clears_state() {
    echo "Testing completion allows exit and clears state..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(create_test_repo)

    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'EOF'
# Plan

## Phase 1
- [x] Task A
- [x] Task B
EOF
    git -C "$test_dir" add IMPLEMENTATION_PLAN.md
    git -C "$test_dir" commit -q -m "add plan"

    initialize_loop_state "$test_dir" "Test goal" 10

    local result
    result=$(run_hook "$test_dir")
    local exit_code
    exit_code=$(echo "$result" | head -n1)

    local state_file
    state_file=$(get_state_file_path "$test_dir")

    if [[ "$exit_code" == "0" && ! -f "$state_file" ]]; then
        echo "  ✓ Completion exits cleanly and clears loop state"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected exit=0 and removed state file (exit=$exit_code, state_exists=$([[ -f "$state_file" ]] && echo yes || echo no))"
    fi

    rm -rf "$test_dir"
}

echo "=== Stop Hook Loop Tests ==="
echo ""

test_hook_exists_and_executable
test_inactive_loop_allows_exit
test_active_loop_blocks_and_increments_iteration
test_protocol_verification_triggered_every_three_iterations
test_max_iterations_pauses_loop
test_completion_allows_exit_and_clears_state

echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1

