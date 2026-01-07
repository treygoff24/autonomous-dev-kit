#!/usr/bin/env bash
#
# Tests for loop-helpers.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/loop-helpers.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "  ✓ $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ $msg"
        echo "    Expected: $expected"
        echo "    Actual:   $actual"
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -n "$value" ]]; then
        echo "  ✓ $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ $msg (was empty)"
    fi
}

# --- Tests ---

test_get_project_hash() {
    echo "Testing get_project_hash..."

    # Same path should return same hash
    local hash1=$(get_project_hash "/Users/test/project")
    local hash2=$(get_project_hash "/Users/test/project")
    assert_equals "$hash1" "$hash2" "Same path returns same hash"

    # Different paths should return different hashes
    local hash3=$(get_project_hash "/Users/test/other")
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$hash1" != "$hash3" ]]; then
        echo "  ✓ Different paths return different hashes"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Different paths return different hashes"
    fi

    # Hash should be 12 characters
    assert_equals "12" "${#hash1}" "Hash is 12 characters"
}

test_get_state_file_path() {
    echo "Testing get_state_file_path..."

    local path=$(get_state_file_path "/Users/test/project")

    # Should be in the state directory
    assert_equals "$HOME/.claude/autonomous-loop/" "${path%/*}/" "Path is in state directory"

    # Should end with .json
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$path" == *.json ]]; then
        echo "  ✓ Path ends with .json"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Path ends with .json"
    fi

    # Should contain project hash
    local hash=$(get_project_hash "/Users/test/project")
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$path" == *"$hash"* ]]; then
        echo "  ✓ Path contains project hash"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Path contains project hash"
    fi
}

test_generate_verification_code() {
    echo "Testing generate_verification_code..."

    local code1=$(generate_verification_code)

    # Should be 4 digits
    assert_equals "4" "${#code1}" "Code is 4 digits"

    # Should be numeric
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$code1" =~ ^[0-9]+$ ]]; then
        echo "  ✓ Code is numeric"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Code is numeric"
    fi

    # Should be >= 1000 (4 digits)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$code1" -ge 1000 ]]; then
        echo "  ✓ Code is >= 1000"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Code is >= 1000"
    fi
}

test_generate_session_token() {
    echo "Testing generate_session_token..."

    local token=$(generate_session_token)

    # Should be 16 characters
    assert_equals "16" "${#token}" "Token is 16 characters"

    # Should be hex
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$token" =~ ^[a-f0-9]+$ ]]; then
        echo "  ✓ Token is hex"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ Token is hex (got: $token)"
    fi
}

test_state_file_operations() {
    echo "Testing state file operations..."

    # Create temp project path
    local test_project="/tmp/test-project-$$"
    local state_file=$(get_state_file_path "$test_project")

    # Clean up any existing state
    rm -f "$state_file"

    # read_state_file should return empty for missing file
    local state=$(read_state_file "$test_project")
    assert_equals "" "$state" "Missing file returns empty"

    # write_state_file should create file
    write_state_file "$test_project" '{"active":true,"iteration":1}'

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -f "$state_file" ]]; then
        echo "  ✓ State file created"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ State file created"
    fi

    # read_state_file should return contents
    state=$(read_state_file "$test_project")
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$state" == *'"active":true'* ]]; then
        echo "  ✓ State file contents readable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ State file contents readable"
    fi

    # Clean up
    rm -f "$state_file"
}

test_read_malformed_state() {
    echo "Testing malformed state file handling..."

    local test_project="/tmp/test-malformed-$$"
    local state_file=$(get_state_file_path "$test_project")

    # Write malformed JSON
    mkdir -p "$(dirname "$state_file")"
    echo "not valid json" > "$state_file"

    # Should return empty, not crash
    local state=$(read_state_file "$test_project" 2>/dev/null)
    assert_equals "" "$state" "Malformed JSON returns empty"

    # Clean up
    rm -f "$state_file"
}

test_is_loop_active() {
    echo "Testing is_loop_active..."

    local test_project="/tmp/test-active-$$"
    delete_state_file "$test_project"

    # No state file = not active
    TESTS_RUN=$((TESTS_RUN + 1))
    if ! is_loop_active "$test_project"; then
        echo "  ✓ No state file = not active"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ No state file = not active"
    fi

    # State file with active=false = not active
    write_state_file "$test_project" '{"active":false}'
    TESTS_RUN=$((TESTS_RUN + 1))
    if ! is_loop_active "$test_project"; then
        echo "  ✓ active=false = not active"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ active=false = not active"
    fi

    # State file with active=true = active
    write_state_file "$test_project" '{"active":true}'
    TESTS_RUN=$((TESTS_RUN + 1))
    if is_loop_active "$test_project"; then
        echo "  ✓ active=true = active"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ✗ active=true = active"
    fi

    # Clean up
    delete_state_file "$test_project"
}

test_initialize_loop_state() {
    echo "Testing initialize_loop_state..."

    local test_project="/tmp/test-init-$$"
    delete_state_file "$test_project"

    initialize_loop_state "$test_project" "Test goal" 100

    local state=$(read_state_file "$test_project")

    # Check all required fields
    local active=$(echo "$state" | jq -r '.active')
    assert_equals "true" "$active" "active is true"

    local goal=$(echo "$state" | jq -r '.goal')
    assert_equals "Test goal" "$goal" "goal is set"

    local max=$(echo "$state" | jq -r '.max_iterations')
    assert_equals "100" "$max" "max_iterations is set"

    local iteration=$(echo "$state" | jq -r '.iteration')
    assert_equals "0" "$iteration" "iteration starts at 0"

    local token=$(echo "$state" | jq -r '.session_token')
    assert_not_empty "$token" "session_token is set"

    local verification_pending=$(echo "$state" | jq -r '.verification_pending')
    assert_equals "false" "$verification_pending" "verification_pending defaults to false"

    local verification_attempts=$(echo "$state" | jq -r '.verification_attempts')
    assert_equals "0" "$verification_attempts" "verification_attempts starts at 0"

    local last_verified_iteration=$(echo "$state" | jq -r '.last_verified_iteration')
    assert_equals "0" "$last_verified_iteration" "last_verified_iteration starts at 0"

    delete_state_file "$test_project"
}

test_update_state_field() {
    echo "Testing update_state_field..."

    local test_project="/tmp/test-update-$$"
    delete_state_file "$test_project"

    # Initialize with iteration 0
    write_state_file "$test_project" '{"iteration":0}'

    # Update iteration to 5
    update_state_field "$test_project" ".iteration" "5"

    local state=$(read_state_file "$test_project")
    local iteration=$(echo "$state" | jq -r '.iteration')
    assert_equals "5" "$iteration" "iteration updated to 5"

    # Update string field
    update_state_field "$test_project" ".goal" '"New goal"'
    state=$(read_state_file "$test_project")
    local goal=$(echo "$state" | jq -r '.goal')
    assert_equals "New goal" "$goal" "goal updated"

    delete_state_file "$test_project"
}

# Run tests
echo "=== Loop Helpers Tests ==="
echo ""
test_get_project_hash
test_get_state_file_path
test_generate_verification_code
test_generate_session_token
test_state_file_operations
test_read_malformed_state
test_is_loop_active
test_initialize_loop_state
test_update_state_field

# Summary
echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
