#!/usr/bin/env bash
#
# Tests for stop.sh hook
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/../hooks/stop.sh"

# Source helpers for test setup
source "$SCRIPT_DIR/../lib/loop-helpers.sh"
# Source stop hook helpers (skip main execution)
STOP_HOOK_LIB_ONLY=1 source "$HOOK_PATH"

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
    printf '%s' "$input" | CLAUDE_PROJECT_DIR="$project_dir" "$HOOK_PATH"
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

test_plan_scope_module_missing_allows_exit() {
    echo "Testing module-scoped goal skips plan when section missing..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Plan does not include a medical module section
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
## Phase 1: Setup
- [ ] Task 1
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize loop with module-scoped goal
    initialize_loop_state "$test_dir" "Complete Medical Module" 100

    local output=$(run_hook "$test_dir" 2>/dev/null)
    local decision=$(json_field "$output" '.decision // ""')
    local output_empty=false
    if is_empty_output "$output"; then
        output_empty=true
    fi
    local active=false
    if is_loop_active "$test_dir"; then
        active=true
    fi

    if [[ ("$decision" == "approve" || $output_empty == true) && "$active" == "false" ]]; then
        echo "  ✓ Missing module section does not block completion"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected completion when module section missing (decision=$decision)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_plan_scope_module_hyphen_blocks_when_incomplete() {
    echo "Testing hyphenated module goal blocks when section incomplete..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
## Front-End Module
- [ ] Task 1
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    initialize_loop_state "$test_dir" "Complete front-end module" 100

    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')

    if [[ "$decision" == "block" && "$reason" == *"IMPLEMENTATION_PLAN.md has incomplete tasks"* ]]; then
        echo "  ✓ Hyphenated module scope blocks exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected block for hyphenated module (decision=$decision)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_plan_scope_phase_allows_exit() {
    echo "Testing phase-scoped goal allows exit when phase complete..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
## Phase 1: Setup
- [x] Task 1
## Phase 2: Build
- [ ] Task 2
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    initialize_loop_state "$test_dir" "Finish Phase 1" 100

    local output=$(run_hook "$test_dir" 2>/dev/null)
    local decision=$(json_field "$output" '.decision // ""')
    local output_empty=false
    if is_empty_output "$output"; then
        output_empty=true
    fi
    local active=false
    if is_loop_active "$test_dir"; then
        active=true
    fi

    if [[ ("$decision" == "approve" || $output_empty == true) && "$active" == "false" ]]; then
        echo "  ✓ Phase-complete section allows exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected completion for phase-scoped goal (decision=$decision)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_plan_scope_phase_blocks_when_incomplete() {
    echo "Testing phase-scoped goal blocks when phase incomplete..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
## Phase 1: Setup
- [ ] Task 1
## Phase 2: Build
- [ ] Task 2
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    initialize_loop_state "$test_dir" "Finish Phase 1" 100

    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')

    if [[ "$decision" == "block" && "$reason" == *"IMPLEMENTATION_PLAN.md has incomplete tasks"* ]]; then
        echo "  ✓ Phase-incomplete section blocks exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected block for incomplete phase (decision=$decision)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_stuck_detection_pauses_loop() {
    echo "Testing stuck detection pauses loop..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create incomplete plan to keep loop active
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Incomplete task
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    initialize_loop_state "$test_dir" "Test goal" 100
    update_state_field "$test_dir" ".iteration" "4"
    update_state_field "$test_dir" ".last_verified_iteration" "100"
    update_state_field "$test_dir" ".verification_pending" "false"

    local goal_hash=$(hash_string "Test goal")
    local progress_hash=$(hash_string "$(get_progress_fingerprint "$test_dir")")
    local threshold="${STUCK_THRESHOLD:-5}"

    update_state_field "$test_dir" ".last_goal_hash" "\"$goal_hash\""
    update_state_field "$test_dir" ".last_progress_hash" "\"$progress_hash\""
    update_state_field "$test_dir" ".stuck_count" "$((threshold - 1))"

    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')
    local state=$(read_state_file "$test_dir")
    local paused=$(echo "$state" | jq -r '.paused')

    if [[ "$paused" == "true" && "$decision" == "block" && "$reason" == *"Loop Paused (No Progress Detected)"* ]]; then
        echo "  ✓ Stuck loop triggers pause"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected stuck loop pause (paused=$paused, decision=$decision)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_stuck_detection_resets_on_diff_change() {
    echo "Testing stuck detection resets when diff changes..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create incomplete plan to keep loop active
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Incomplete task
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    initialize_loop_state "$test_dir" "Test goal" 100
    update_state_field "$test_dir" ".iteration" "4"
    update_state_field "$test_dir" ".last_verified_iteration" "100"
    update_state_field "$test_dir" ".verification_pending" "false"

    # First change to create baseline diff
    echo "change-1" >> "$test_dir/file.txt"

    local goal_hash=$(hash_string "Test goal")
    local progress_hash=$(hash_string "$(get_progress_fingerprint "$test_dir")")
    local threshold="${STUCK_THRESHOLD:-5}"

    update_state_field "$test_dir" ".last_goal_hash" "\"$goal_hash\""
    update_state_field "$test_dir" ".last_progress_hash" "\"$progress_hash\""
    update_state_field "$test_dir" ".stuck_count" "$((threshold - 1))"

    # Second change updates diff but keeps status the same
    echo "change-2" >> "$test_dir/file.txt"

    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local state=$(read_state_file "$test_dir")
    local paused=$(echo "$state" | jq -r '.paused')
    local stuck_count=$(echo "$state" | jq -r '.stuck_count')

    if [[ "$paused" == "false" && "$decision" == "block" && "$stuck_count" == "0" ]]; then
        echo "  ✓ Stuck counter resets on diff change"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected stuck counter reset (paused=$paused, stuck_count=$stuck_count, decision=$decision)"
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

test_verification_triggered_at_iteration_3() {
    echo "Testing verification triggers at iteration 3..."
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

    local state=$(read_state_file "$test_dir")
    local pending=$(echo "$state" | jq -r '.verification_pending')
    local code=$(echo "$state" | jq -r '.expected_verification_code // ""')

    if [[ "$decision" == "block" && "$reason" == *"Protocol Re-Read Required"* && "$pending" == "true" && -n "$code" ]]; then
        echo "  ✓ Verification requested at iteration 3"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Unexpected verification behavior (decision=$decision, pending=$pending, code=$code)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_verification_resets_stuck_count() {
    echo "Testing verification resets stuck count..."
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
    update_state_field "$test_dir" ".stuck_count" "4"

    run_hook "$test_dir" 2>/dev/null || true

    local state=$(read_state_file "$test_dir")
    local pending=$(echo "$state" | jq -r '.verification_pending')
    local stuck=$(echo "$state" | jq -r '.stuck_count')

    if [[ "$pending" == "true" && "$stuck" == "0" ]]; then
        echo "  ✓ Verification resets stuck count"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected stuck count reset when verification starts (pending=$pending, stuck=$stuck)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_verification_tag_with_code_attribute() {
    echo "Testing check_verification_tag with code attribute..."
    TESTS_RUN=$((TESTS_RUN + 1))

    if check_verification_tag '<verified code="1234"/>' "1234"; then
        echo "  ✓ Code attribute accepted"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Code attribute should be accepted"
    fi
}

test_verification_tag_with_code_body() {
    echo "Testing check_verification_tag with code body..."
    TESTS_RUN=$((TESTS_RUN + 1))

    if check_verification_tag '<verified>1234</verified>' "1234"; then
        echo "  ✓ Code body accepted"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Code body should be accepted"
    fi
}

test_verification_tag_wrong_code() {
    echo "Testing check_verification_tag with wrong code..."
    TESTS_RUN=$((TESTS_RUN + 1))

    if ! check_verification_tag '<verified code="9999"/>' "1234"; then
        echo "  ✓ Wrong code rejected"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Wrong code should be rejected"
    fi
}

test_verification_tag_prefix_code_rejected() {
    echo "Testing check_verification_tag rejects prefix match..."
    TESTS_RUN=$((TESTS_RUN + 1))

    if ! check_verification_tag '<verified code="12345"/>' "1234"; then
        echo "  ✓ Prefix code rejected"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Prefix code should be rejected"
    fi
}

test_verification_tag_with_code_attribute_and_closing_tag() {
    echo "Testing check_verification_tag with code attribute and closing tag..."
    TESTS_RUN=$((TESTS_RUN + 1))

    if check_verification_tag '<verified code="1234"></verified>' "1234"; then
        echo "  ✓ Code attribute with closing tag accepted"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Code attribute with closing tag should be accepted"
    fi
}

test_verification_tag_invalid_code_falls_back() {
    echo "Testing check_verification_tag falls back on invalid code..."
    TESTS_RUN=$((TESTS_RUN + 1))

    if check_verification_tag '<verified/>' "12345"; then
        echo "  ✓ Invalid code falls back to legacy verification"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Invalid code should fall back to legacy verification"
    fi
}

test_goal_in_reason() {
    echo "Testing reason includes continuation prompt and goal..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)
    echo "uncommitted" > "$test_dir/dirty.txt"  # Make it dirty

    # Initialize loop
    initialize_loop_state "$test_dir" "Test goal for verification" 100

    # Capture output
    local output=$(run_hook "$test_dir" 2>/dev/null || true)
    local decision=$(json_field "$output" '.decision // ""')
    local reason=$(json_field "$output" '.reason // ""')
    local system_msg=$(json_field "$output" '.systemMessage // ""')

    # Reason should include the continuation prompt and goal
    # SystemMessage should have iteration info
    if [[ "$decision" == "block" && "$reason" == *"AUTONOMOUS BUILD MODE ACTIVE"* && "$reason" == *"Goal: Test goal for verification"* && "$system_msg" == *"Iteration"* ]]; then
        echo "  ✓ Continuation prompt in reason, status in systemMessage"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Expected continuation prompt in reason and iteration in systemMessage"
        echo "    reason: $reason"
        echo "    systemMessage: $system_msg"
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
test_plan_scope_module_missing_allows_exit
test_plan_scope_module_hyphen_blocks_when_incomplete
test_plan_scope_phase_allows_exit
test_plan_scope_phase_blocks_when_incomplete
test_stuck_detection_pauses_loop
test_stuck_detection_resets_on_diff_change
test_loop_increments_iteration
test_max_iterations_pauses
test_verification_triggered_at_iteration_3
test_verification_resets_stuck_count
test_verification_tag_with_code_attribute
test_verification_tag_with_code_body
test_verification_tag_wrong_code
test_verification_tag_prefix_code_rejected
test_verification_tag_with_code_attribute_and_closing_tag
test_verification_tag_invalid_code_falls_back
test_goal_in_reason
test_no_git_repo

# Summary
echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
