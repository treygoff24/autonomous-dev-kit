#!/usr/bin/env bash
#
# Integration tests for autonomous loop system
#
# Note: Autonomous loop completion enforcement is handled by deterministic
# `hooks/stop.sh` state checks. Prompt-based Stop hooks in skill/agent frontmatter
# still provide role-specific verification. These tests verify:
# - File structure is correct
# - Hooks are executable
# - Loop helper functions work together
# - Session hooks produce expected output
#

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../hooks/lib/loop-helpers.sh"

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

# --- Integration Tests ---

test_file_structure() {
    echo "Testing file structure..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local all_ok=true

    # Verify all hooks exist and are executable
    for hook in pre-compact.sh session-start.sh user-prompt-submit.sh stop.sh; do
        if [[ ! -x "$TEST_DIR/../hooks/$hook" ]]; then
            echo "  ✗ Missing or not executable: hooks/$hook"
            all_ok=false
        fi
    done

    # Verify lib files exist (now in hooks/lib/)
    for lib in loop-helpers.sh cheatsheet.md; do
        if [[ ! -f "$TEST_DIR/../hooks/lib/$lib" ]]; then
            echo "  ✗ Missing lib file: hooks/lib/$lib"
            all_ok=false
        fi
    done

    if $all_ok; then
        echo "  ✓ All hooks and lib files present"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ File structure incomplete"
    fi
}

test_loop_state_lifecycle() {
    echo "Testing loop state lifecycle..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)
    local all_ok=true

    # Step 1: No loop initially
    if is_loop_active "$test_dir"; then
        echo "  ✗ Loop should not be active initially"
        all_ok=false
    else
        echo "  ✓ No loop initially"
    fi

    # Step 2: Initialize loop
    initialize_loop_state "$test_dir" "Test goal" 10
    if is_loop_active "$test_dir"; then
        echo "  ✓ Loop active after init"
    else
        echo "  ✗ Loop should be active after init"
        all_ok=false
    fi

    # Step 3: Read state
    local state=$(read_state_file "$test_dir")
    local goal=$(echo "$state" | jq -r '.goal')
    if [[ "$goal" == "Test goal" ]]; then
        echo "  ✓ Goal stored correctly"
    else
        echo "  ✗ Goal not stored correctly (got: $goal)"
        all_ok=false
    fi

    # Step 4: Update iteration
    update_state_field "$test_dir" ".iteration" "5"
    state=$(read_state_file "$test_dir")
    local iteration=$(echo "$state" | jq -r '.iteration')
    if [[ "$iteration" == "5" ]]; then
        echo "  ✓ Iteration updated"
    else
        echo "  ✗ Iteration not updated (got: $iteration)"
        all_ok=false
    fi

    # Step 5: Delete state
    delete_state_file "$test_dir"
    if ! is_loop_active "$test_dir"; then
        echo "  ✓ Loop inactive after delete"
    else
        echo "  ✗ Loop should be inactive after delete"
        all_ok=false
    fi

    if $all_ok; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    rm -rf "$test_dir"
}

test_session_start_hook() {
    echo "Testing session-start hook..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create a handoff file
    mkdir -p "$test_dir/thoughts/handoffs"
    cat > "$test_dir/thoughts/handoffs/auto-handoff-$(date +%Y%m%d-%H%M%S).md" << 'EOF'
# Test Handoff
This is a test handoff.
EOF

    # Run session-start hook
    local output=$(echo '{}' | CLAUDE_PROJECT_DIR="$test_dir" "$TEST_DIR/../hooks/session-start.sh" 2>/dev/null || true)

    # Should produce some output (handoff injection)
    if [[ -n "$output" ]]; then
        echo "  ✓ Session-start produces output"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Session-start should produce output with handoff present"
    fi

    rm -rf "$test_dir"
}

test_user_prompt_submit_hook() {
    echo "Testing user-prompt-submit hook..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)
    local all_ok=true

    # Test 1: No output when loop inactive
    local output=$(echo '{}' | CLAUDE_PROJECT_DIR="$test_dir" "$TEST_DIR/../hooks/user-prompt-submit.sh" 2>/dev/null || true)
    if [[ -z "$output" ]]; then
        echo "  ✓ No output when loop inactive"
    else
        echo "  ✗ Should have no output when loop inactive"
        all_ok=false
    fi

    # Test 2: Output when loop active
    initialize_loop_state "$test_dir" "Test goal" 10
    output=$(echo '{}' | CLAUDE_PROJECT_DIR="$test_dir" "$TEST_DIR/../hooks/user-prompt-submit.sh" 2>/dev/null || true)
    # Output is JSON with hookSpecificOutput.additionalContext containing "Autonomous Loop Protocol Anchor"
    if [[ "$output" == *"Autonomous Loop Protocol Anchor"* || "$output" == *"additionalContext"* ]]; then
        echo "  ✓ Protocol anchor when loop active"
    else
        echo "  ✗ Should produce protocol anchor when loop active (got: $output)"
        all_ok=false
    fi

    if $all_ok; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

test_stop_hook_inactive_allow() {
    echo "Testing stop hook inactive-loop allow behavior..."
    TESTS_RUN=$((TESTS_RUN + 1))

    # Stop hook should always approve (exit 0, no output)
    local exit_code=0
    local output=$(echo '{}' | "$TEST_DIR/../hooks/stop.sh" 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 && -z "$output" ]]; then
        echo "  ✓ Stop hook approves when loop inactive"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Stop hook should approve with no output (exit=$exit_code)"
    fi
}

test_session_start_no_handoff_dir() {
    echo "Testing session-start hook with no handoff directory..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir
    test_dir=$(create_test_repo)

    # Intentionally do not create thoughts/handoffs.
    local output
    output=$(echo '{"agent_type":"task-builder"}' | CLAUDE_PROJECT_DIR="$test_dir" "$TEST_DIR/../hooks/session-start.sh" 2>/dev/null || true)

    if [[ "$output" == *"hookSpecificOutput"* ]]; then
        echo "  ✓ Session-start handles missing handoff dir"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Session-start should handle missing handoff dir"
    fi

    rm -rf "$test_dir"
}

test_verification_code_generation() {
    echo "Testing verification code generation..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Initialize loop and set up verification
    initialize_loop_state "$test_dir" "Test goal" 10
    update_state_field "$test_dir" ".verification_pending" "true"

    local code=$(generate_verification_code)
    update_state_field "$test_dir" ".expected_verification_code" "\"$code\""

    # Read back and verify
    local state=$(read_state_file "$test_dir")
    local stored_code=$(echo "$state" | jq -r '.expected_verification_code')

    if [[ "$stored_code" == "$code" && ${#code} -eq 4 ]]; then
        echo "  ✓ Verification code stored and retrievable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Verification code issue (code=$code, stored=$stored_code)"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}

# --- Run all tests ---
echo "=== Integration Tests ==="
echo ""

test_file_structure
test_loop_state_lifecycle
test_session_start_hook
test_session_start_no_handoff_dir
test_user_prompt_submit_hook
test_stop_hook_inactive_allow
test_verification_code_generation

# Summary
echo ""
echo "=== Results ==="
echo "Integration Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
