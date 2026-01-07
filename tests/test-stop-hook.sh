#!/usr/bin/env bash
#
# Tests for stop.sh hook
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/../hooks/stop.sh"

# Source helpers for test setup
source "$SCRIPT_DIR/../lib/loop-helpers.sh"

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
    echo '{}' | CLAUDE_PROJECT_DIR="$project_dir" "$HOOK_PATH"
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

# --- Tests ---

test_safety_net_allows_clean_git() {
    echo "Testing safety net allows clean git state..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    local err_file=$(mktemp)
    local exit_code=0
    local output=$(run_hook "$test_dir" 2>"$err_file") || exit_code=$?
    local decision=$(json_field "$output" '.decision // ""')
    local output_empty=false
    if is_empty_output "$output"; then
        output_empty=true
    fi

    if [[ $exit_code -eq 0 && ( "$decision" == "approve" || $output_empty == true ) ]]; then
        echo "  ✓ Clean git state allows exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected approve decision (exit $exit_code, decision=$decision)"
    fi

    rm -f "$err_file"
    rm -rf "$test_dir"
}

test_safety_net_blocks_dirty_git() {
    echo "Testing safety net blocks dirty git state..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)
    echo "modified" > "$test_dir/file.txt"  # Uncommitted change

    local err_file=$(mktemp)
    local exit_code=0
    local output=$(run_hook "$test_dir" 2>"$err_file") || exit_code=$?
    local decision=$(json_field "$output" '.decision // ""')
    local output_empty=false
    if is_empty_output "$output"; then
        output_empty=true
    fi
    local warnings=$(cat "$err_file")

    if [[ $exit_code -eq 0 && ( "$decision" == "approve" || $output_empty == true ) && "$warnings" == *"Uncommitted changes in git"* ]]; then
        echo "  ✓ Dirty git state warns but does not block"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected advisory warning with approve decision (exit $exit_code, decision=$decision)"
    fi

    rm -f "$err_file"
    rm -rf "$test_dir"
}

test_safety_net_skips_quality_gates_if_missing() {
    echo "Testing safety net skips quality gates if file missing..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    local err_file=$(mktemp)
    local exit_code=0
    local output=$(run_hook "$test_dir" 2>"$err_file") || exit_code=$?
    local decision=$(json_field "$output" '.decision // ""')
    local output_empty=false
    if is_empty_output "$output"; then
        output_empty=true
    fi

    if [[ $exit_code -eq 0 && ( "$decision" == "approve" || $output_empty == true ) ]]; then
        echo "  ✓ No quality gates file = skip checks"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ No quality gates file = skip checks (exit $exit_code, decision=$decision)"
    fi

    rm -f "$err_file"
    rm -rf "$test_dir"
}

test_safety_net_runs_quality_gates_if_present() {
    echo "Testing safety net runs quality gates if file present..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create quality gates file with failing command
    echo "false" > "$test_dir/.claude-quality-gates"
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add gates"

    local err_file=$(mktemp)
    local exit_code=0
    local output=$(run_hook "$test_dir" 2>"$err_file") || exit_code=$?
    local decision=$(json_field "$output" '.decision // ""')
    local output_empty=false
    if is_empty_output "$output"; then
        output_empty=true
    fi
    local warnings=$(cat "$err_file")

    if [[ $exit_code -eq 0 && ( "$decision" == "approve" || $output_empty == true ) && "$warnings" == *"Quality gate failed"* ]]; then
        echo "  ✓ Quality gates failure warns (advisory mode)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected advisory warning with approve decision (exit $exit_code, decision=$decision)"
    fi

    rm -f "$err_file"
    rm -rf "$test_dir"
}

test_loop_mode_blocks_when_incomplete() {
    echo "Testing loop mode blocks when work incomplete..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create incomplete plan
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Incomplete task
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize loop state
    initialize_loop_state "$test_dir" "Test goal" 100

    local exit_code=0
    local output=$(run_hook "$test_dir" 2>/dev/null) || exit_code=$?
    local decision=$(json_field "$output" '.decision // ""')

    if [[ $exit_code -eq 0 && "$decision" == "block" ]]; then
        echo "  ✓ Loop mode blocks incomplete work"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected block decision (exit $exit_code, decision=$decision)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_loop_mode_allows_when_complete() {
    echo "Testing loop mode allows exit when complete..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create complete plan
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [x] Task 1
- [x] Task 2
**Status: COMPLETE**
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "complete plan"

    # Initialize loop state
    initialize_loop_state "$test_dir" "Test goal" 100

    # Run hook - should allow exit (work complete)
    local output=$(run_hook "$test_dir" 2>/dev/null)
    local decision=$(json_field "$output" '.decision // ""')
    local output_empty=false
    if is_empty_output "$output"; then
        output_empty=true
    fi

    if [[ "$decision" == "approve" || $output_empty == true ]]; then
        echo "  ✓ Loop mode allows exit when complete"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Loop mode should allow exit when complete (decision=$decision)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_loop_increments_iteration() {
    echo "Testing loop increments iteration counter..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create incomplete plan to keep loop going
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Incomplete task
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize with iteration 5
    initialize_loop_state "$test_dir" "Test goal" 100
    update_state_field "$test_dir" ".iteration" "5"

    # Run hook
    run_hook "$test_dir" > /dev/null 2>&1 || true

    # Check iteration was incremented
    local state=$(read_state_file "$test_dir")
    local iteration=$(echo "$state" | jq -r '.iteration')

    if [[ "$iteration" == "6" ]]; then
        echo "  ✓ Iteration incremented to 6"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected iteration 6, got $iteration"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_max_iterations_pauses() {
    echo "Testing max iterations pauses loop..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create incomplete plan to prevent completion
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Incomplete task
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize with iteration at max - 1
    initialize_loop_state "$test_dir" "Test goal" 10
    update_state_field "$test_dir" ".iteration" "9"
    update_state_field "$test_dir" ".last_verified_iteration" "9"  # Prevent verification trigger

    # Run hook - should hit max and pause
    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')

    # Check paused flag
    local state=$(read_state_file "$test_dir")
    local paused=$(echo "$state" | jq -r '.paused')

    if [[ "$paused" == "true" && "$decision" == "block" && "$reason" == *"Max Iterations Reached"* ]]; then
        echo "  ✓ Loop paused at max iterations"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected pause with block decision (paused=$paused, decision=$decision)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_verification_disabled_at_iteration_3() {
    echo "Testing iteration 3 does not trigger verification..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create incomplete plan to prevent completion
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Incomplete task
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize with iteration 2 (next will be 3)
    initialize_loop_state "$test_dir" "Test goal" 100
    update_state_field "$test_dir" ".iteration" "2"
    update_state_field "$test_dir" ".last_verified_iteration" "0"

    # Capture output
    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')

    if [[ "$decision" == "block" && "$reason" == *"Test goal"* && "$reason" != *"Protocol Re-Read Required"* ]]; then
        echo "  ✓ Iteration 3 behaves like normal loop block"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Unexpected verification behavior (decision=$decision, reason=$reason)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_cheatsheet_injected() {
    echo "Testing cheatsheet is injected in continuation..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)
    echo "uncommitted" > "$test_dir/dirty.txt"  # Make it dirty

    # Initialize loop
    initialize_loop_state "$test_dir" "Test goal" 100

    # Capture output
    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')

    if [[ "$decision" == "block" && "$reason" == *"AUTONOMOUS BUILD MODE ACTIVE"* ]]; then
        echo "  ✓ Cheatsheet header present"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Cheatsheet header missing"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_no_git_repo() {
    echo "Testing works in non-git directory..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(mktemp -d)
    echo "test" > "$test_dir/file.txt"

    local output=$(run_hook "$test_dir" 2>/dev/null)
    local decision=$(json_field "$output" '.decision // ""')
    local output_empty=false
    if is_empty_output "$output"; then
        output_empty=true
    fi

    if [[ "$decision" == "approve" || $output_empty == true ]]; then
        echo "  ✓ Non-git directory allows exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Non-git directory should allow exit (decision=$decision)"
    fi

    rm -rf "$test_dir"
}

# Run tests
echo "=== Stop Hook Tests ==="
echo ""
test_safety_net_allows_clean_git
test_safety_net_blocks_dirty_git
test_safety_net_skips_quality_gates_if_missing
test_safety_net_runs_quality_gates_if_present
test_loop_mode_blocks_when_incomplete
test_loop_mode_allows_when_complete
test_loop_increments_iteration
test_max_iterations_pauses
test_verification_disabled_at_iteration_3
test_cheatsheet_injected
test_no_git_repo

# Summary
echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
