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

# --- Tests ---

test_safety_net_allows_clean_git() {
    echo "Testing safety net allows clean git state..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Run hook - should allow exit (code 0)
    if run_hook "$test_dir" > /dev/null 2>&1; then
        echo "  ✓ Clean git state allows exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Clean git state allows exit"
    fi

    rm -rf "$test_dir"
}

test_safety_net_blocks_dirty_git() {
    echo "Testing safety net blocks dirty git state..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)
    echo "modified" > "$test_dir/file.txt"  # Uncommitted change

    # Run hook - should block exit (code 2)
    local exit_code=0
    run_hook "$test_dir" > /dev/null 2>&1 || exit_code=$?

    if [[ $exit_code -eq 2 ]]; then
        echo "  ✓ Dirty git state blocks exit with code 2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected exit code 2, got $exit_code"
    fi

    rm -rf "$test_dir"
}

test_safety_net_skips_quality_gates_if_missing() {
    echo "Testing safety net skips quality gates if file missing..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # No .claude-quality-gates file - should allow exit
    if run_hook "$test_dir" > /dev/null 2>&1; then
        echo "  ✓ No quality gates file = skip checks"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ No quality gates file = skip checks"
    fi

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

    # Should block exit
    local exit_code=0
    run_hook "$test_dir" > /dev/null 2>&1 || exit_code=$?

    if [[ $exit_code -eq 2 ]]; then
        echo "  ✓ Quality gates failure blocks exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected exit code 2, got $exit_code"
    fi

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

    # Run hook - should block (loop active, work not complete)
    local exit_code=0
    run_hook "$test_dir" > /dev/null 2>&1 || exit_code=$?

    if [[ $exit_code -eq 2 ]]; then
        echo "  ✓ Loop mode blocks incomplete work"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected exit code 2, got $exit_code"
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
    if run_hook "$test_dir" > /dev/null 2>&1; then
        echo "  ✓ Loop mode allows exit when complete"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Loop mode should allow exit when complete"
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
    update_state_field "$test_dir" ".last_protocol_reread" "9"  # Prevent verification trigger

    # Run hook - should hit max and pause
    run_hook "$test_dir" > /dev/null 2>&1 || true

    # Check paused flag
    local state=$(read_state_file "$test_dir")
    local paused=$(echo "$state" | jq -r '.paused')

    if [[ "$paused" == "true" ]]; then
        echo "  ✓ Loop paused at max iterations"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected paused=true, got $paused"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_verification_required_every_3() {
    echo "Testing verification required every 3 iterations..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create incomplete plan to prevent completion
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Incomplete task
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize with iteration 2 (next will be 3, triggering verification)
    initialize_loop_state "$test_dir" "Test goal" 100
    update_state_field "$test_dir" ".iteration" "2"
    update_state_field "$test_dir" ".last_protocol_reread" "0"

    # Capture output
    local output=$(run_hook "$test_dir" 2>&1 || true)

    if [[ "$output" == *"Protocol Re-Read Required"* ]]; then
        echo "  ✓ Verification triggered at iteration 3"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Verification not triggered"
        echo "    Output: $output"
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
    local output=$(run_hook "$test_dir" 2>&1 || true)

    if [[ "$output" == *"AUTONOMOUS BUILD MODE ACTIVE"* ]]; then
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

    # Should allow exit (no git = skip git check)
    if run_hook "$test_dir" > /dev/null 2>&1; then
        echo "  ✓ Non-git directory allows exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Non-git directory should allow exit"
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
test_verification_required_every_3
test_cheatsheet_injected
test_no_git_repo

# Summary
echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
