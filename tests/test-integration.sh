#!/usr/bin/env bash
#
# Integration tests for autonomous loop system
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../hooks/lib/loop-helpers.sh"

TESTS_RUN=0
TESTS_PASSED=0

# Helper to create test repo
create_test_repo() {
    local dir=$(mktemp -d)
    git -C "$dir" init -q
    git -C "$dir" config user.email "test@test.com"
    git -C "$dir" config user.name "Test"
    echo "test" > "$dir/file.txt"
    git -C "$dir" add file.txt
    git -C "$dir" commit -q -m "initial"
    echo "$dir"
}

# Helper to run hook
run_hook() {
    local project_dir="$1"
    local input="${2:-{}}"
    printf '%s' "$input" | CLAUDE_PROJECT_DIR="$project_dir" "$SCRIPT_DIR/../hooks/stop.sh"
}

# Helpers to tolerate approve paths with empty stdout.
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

# --- Integration Tests ---

test_full_loop_lifecycle() {
    echo "Testing full loop lifecycle..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)
    local all_steps_passed=true

    # Create implementation plan with incomplete task
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Task 1
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize loop
    initialize_loop_state "$test_dir" "Complete the test plan" 10

    # Step 1: Loop should block incomplete work
    local exit_code=0
    local output=$(run_hook "$test_dir" 2>/dev/null) || exit_code=$?
    local decision=$(json_field "$output" '.decision // ""')
    if [[ $exit_code -eq 0 && "$decision" == "block" ]]; then
        echo "  Step 1: Loop blocks incomplete work ✓"
    else
        echo "  Step 1: Loop should block (exit $exit_code, decision=$decision) ✗"
        all_steps_passed=false
    fi

    # Step 2: Verify iteration was incremented
    local state=$(read_state_file "$test_dir")
    local iteration=$(echo "$state" | jq -r '.iteration')
    if [[ "$iteration" == "1" ]]; then
        echo "  Step 2: Iteration incremented ✓"
    else
        echo "  Step 2: Expected iteration 1, got $iteration ✗"
        all_steps_passed=false
    fi

    # Step 3: Mark task complete
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [x] Task 1
**Status: COMPLETE**
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "complete plan"

    # Step 4: Loop should allow exit when complete
    local output_complete=$(run_hook "$test_dir" 2>/dev/null)
    local decision_complete=$(json_field "$output_complete" '.decision // ""')
    local output_complete_empty=false
    if is_empty_output "$output_complete"; then
        output_complete_empty=true
    fi
    if [[ "$decision_complete" == "approve" || $output_complete_empty == true ]]; then
        echo "  Step 3: Loop allows exit when complete ✓"
    else
        echo "  Step 3: Loop should allow exit ✗"
        all_steps_passed=false
    fi

    # Step 5: State file should be cleaned up after completion
    if ! is_loop_active "$test_dir"; then
        echo "  Step 4: State file cleaned up ✓"
    else
        echo "  Step 4: State file should be cleaned up ✗"
        all_steps_passed=false
    fi

    if $all_steps_passed; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    rm -rf "$test_dir"
}

test_max_iterations_pause() {
    echo "Testing max iterations pause..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create incomplete plan to keep loop going
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Incomplete task
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize with max_iterations=2
    initialize_loop_state "$test_dir" "Test goal" 2

    # Run hook twice to hit max
    run_hook "$test_dir" > /dev/null 2>&1 || true  # iteration 1
    # Prevent verification trigger
    update_state_field "$test_dir" ".last_verified_iteration" "1"
    local output=$(run_hook "$test_dir" 2>/dev/null || true)  # iteration 2 (max)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')

    # Check paused flag
    local state=$(read_state_file "$test_dir")
    local paused=$(echo "$state" | jq -r '.paused')

    if [[ "$paused" == "true" && "$decision" == "block" && "$reason" == *"Max Iterations Reached"* ]]; then
        echo "  ✓ Loop paused at max iterations"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected paused=true, got $paused"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_quality_gates_integration() {
    echo "Testing quality gates integration..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create quality gates file with passing command
    echo "true" > "$test_dir/.claude-quality-gates"
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add passing gates"

    # Should allow exit (clean git + passing gates)
    local output=$(run_hook "$test_dir" 2>/dev/null)
    local decision=$(json_field "$output" '.decision // ""')
    local output_empty=false
    if is_empty_output "$output"; then
        output_empty=true
    fi

    if [[ "$decision" == "approve" || $output_empty == true ]]; then
        echo "  ✓ Passing quality gates allow exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Passing quality gates should allow exit (decision=$decision)"
    fi

    rm -rf "$test_dir"
}

test_hook_chain_integration() {
    echo "Testing hook chain integration..."
    TESTS_RUN=$((TESTS_RUN + 1))

    # Verify all hooks exist and are executable
    local hooks_ok=true
    for hook in pre-compact.sh session-start.sh user-prompt-submit.sh stop.sh; do
        if [[ ! -x "$SCRIPT_DIR/../hooks/$hook" ]]; then
            echo "  Missing or not executable: $hook"
            hooks_ok=false
        fi
    done

    # Verify lib files exist
    for lib in loop-helpers.sh cheatsheet.md; do
        if [[ ! -f "$SCRIPT_DIR/../lib/$lib" ]]; then
            echo "  Missing lib file: $lib"
            hooks_ok=false
        fi
    done

    if $hooks_ok; then
        echo "  ✓ All hooks and lib files present"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Hook chain incomplete"
    fi
}

test_continuation_prompt_format() {
    echo "Testing continuation prompt format..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)
    echo "uncommitted" > "$test_dir/dirty.txt"  # Make dirty

    # Initialize loop
    initialize_loop_state "$test_dir" "Test goal" 100

    # Capture output
    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')
    local system_msg=$(json_field "$output" '.systemMessage // ""')

    local checks_passed=true

    # Check decision is block (work incomplete due to dirty git)
    if [[ "$decision" == "block" ]]; then
        echo "  Decision is block ✓"
    else
        echo "  Decision is block ✗"
        checks_passed=false
    fi

    # Check reason includes the continuation prompt + goal
    if [[ "$reason" == *"AUTONOMOUS BUILD MODE ACTIVE"* && "$reason" == *"Goal: Test goal"* ]]; then
        echo "  Reason includes continuation prompt ✓"
    else
        echo "  Reason includes continuation prompt ✗ (got: $reason)"
        checks_passed=false
    fi

    # Check systemMessage contains iteration info
    if [[ "$system_msg" == *"Iteration"* ]]; then
        echo "  SystemMessage has iteration ✓"
    else
        echo "  SystemMessage has iteration ✗"
        checks_passed=false
    fi

    if $checks_passed; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_verification_triggered_at_iteration_3() {
    echo "Testing verification triggers at iteration 3..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create incomplete plan
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Incomplete task
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize at iteration 2, last_verified at 0
    initialize_loop_state "$test_dir" "Test goal" 100
    update_state_field "$test_dir" ".iteration" "2"
    update_state_field "$test_dir" ".last_verified_iteration" "0"

    # Run hook (will increment to 3)
    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')

    local state=$(read_state_file "$test_dir")
    local pending=$(echo "$state" | jq -r '.verification_pending')
    local code=$(echo "$state" | jq -r '.expected_verification_code // ""')

    if [[ "$decision" == "block" && "$reason" == *"Protocol Re-Read Required"* && "$pending" == "true" && -n "$code" ]]; then
        echo "  ✓ Verification requested at iteration 3"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Unexpected verification behavior"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

# --- Run all tests ---
echo "=== Integration Tests ==="
echo ""

test_full_loop_lifecycle
test_max_iterations_pause
test_quality_gates_integration
test_hook_chain_integration
test_continuation_prompt_format
test_verification_triggered_at_iteration_3

# Summary
echo ""
echo "=== Results ==="
echo "Integration Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
