#!/usr/bin/env bash
#
# Tests for stop.sh hook
#
# Note: As of Claude Code 2.1+, stop.sh is a minimal stub that always approves.
# The actual completion logic is handled by prompt-based Stop hooks in skill/agent
# frontmatter. These tests verify the stub behaves correctly.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/../hooks/stop.sh"

TESTS_RUN=0
TESTS_PASSED=0

# Helper to run hook
run_hook() {
    local input="${1:-{}}"
    printf '%s' "$input" | "$HOOK_PATH"
}

echo "=== Stop Hook Tests (2.1+ Stub) ==="
echo ""

# Test 1: Hook exists and is executable
echo "Testing hook exists and is executable..."
TESTS_RUN=$((TESTS_RUN + 1))
if [[ -x "$HOOK_PATH" ]]; then
    echo "  ✓ stop.sh exists and is executable"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  ✗ stop.sh missing or not executable"
fi

# Test 2: Hook always approves (exits 0)
echo "Testing hook always approves..."
TESTS_RUN=$((TESTS_RUN + 1))
exit_code=0
run_hook '{}' > /dev/null 2>&1 || exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    echo "  ✓ Hook exits 0 (approve)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  ✗ Hook exited with $exit_code"
fi

# Test 3: Hook produces no output (empty = approve)
echo "Testing hook produces no output..."
TESTS_RUN=$((TESTS_RUN + 1))
output=$(run_hook '{}' 2>&1)
if [[ -z "$output" ]]; then
    echo "  ✓ No output (approve behavior)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  ✗ Unexpected output: $output"
fi

# Test 4: Hook handles various inputs gracefully
echo "Testing hook handles various inputs..."
TESTS_RUN=$((TESTS_RUN + 1))
all_ok=true
for input in '{}' '{"stop_hook_active": true}' '' 'invalid json'; do
    if ! run_hook "$input" > /dev/null 2>&1; then
        echo "  ✗ Failed on input: $input"
        all_ok=false
    fi
done
if $all_ok; then
    echo "  ✓ Handles all input types"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Summary
echo ""
echo "=== Results ==="
echo "Stop Hook Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
