#!/usr/bin/env bash
#
# Stop Hook: Safety net + autonomous loop continuation
#
# Exit codes:
#   0 = allow exit
#   2 = block exit (inject continuation prompt via stdout)
#

set -euo pipefail

# Source helper library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$HOME/.claude/lib/loop-helpers.sh" ]]; then
    source "$HOME/.claude/lib/loop-helpers.sh"
elif [[ -f "$SCRIPT_DIR/../lib/loop-helpers.sh" ]]; then
    source "$SCRIPT_DIR/../lib/loop-helpers.sh"
fi

# Read input from stdin (Claude Code sends JSON)
INPUT=$(cat)

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# --- Safety Net: Git State Check ---

check_git_clean() {
    if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
        # Not a git repo, skip check
        return 0
    fi

    # Check for uncommitted changes
    if [[ -n "$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)" ]]; then
        return 1
    fi

    return 0
}

# --- Safety Net: Quality Gates Check ---

FAILED_QUALITY_GATES=()

check_quality_gates() {
    local gates_file="$PROJECT_DIR/.claude-quality-gates"

    if [[ ! -f "$gates_file" ]]; then
        # No quality gates file, skip checks
        return 0
    fi

    local failed_gates=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Run the command
        if ! (cd "$PROJECT_DIR" && eval "$line") > /dev/null 2>&1; then
            failed_gates+=("$line")
        fi
    done < "$gates_file"

    if [[ ${#failed_gates[@]} -gt 0 ]]; then
        FAILED_QUALITY_GATES=("${failed_gates[@]}")
        return 1
    fi

    return 0
}

# --- Completion Check: Implementation Plan ---

check_plan_complete() {
    local plan_file="$PROJECT_DIR/IMPLEMENTATION_PLAN.md"

    if [[ ! -f "$plan_file" ]]; then
        # No plan file = assume complete (for non-plan projects)
        return 0
    fi

    # Check for incomplete tasks (unchecked boxes)
    if grep -q '\- \[ \]' "$plan_file"; then
        return 1
    fi

    # Check for "COMPLETE" status marker
    if grep -qi 'status.*complete\|complete.*status' "$plan_file"; then
        return 0
    fi

    # If has checkboxes and all checked, consider complete
    if grep -q '\- \[x\]' "$plan_file"; then
        return 0
    fi

    return 1
}

# Check all completion criteria
check_completion() {
    # Must have clean git
    if ! check_git_clean; then
        return 1
    fi

    # Must pass quality gates (if file exists)
    if ! check_quality_gates; then
        return 1
    fi

    # Must have plan complete (if file exists)
    if ! check_plan_complete; then
        return 1
    fi

    return 0
}

# --- Cheatsheet ---

get_cheatsheet() {
    local cheatsheet_path="$HOME/.claude/lib/cheatsheet.md"
    if [[ -f "$cheatsheet_path" ]]; then
        cat "$cheatsheet_path"
    elif [[ -f "$SCRIPT_DIR/../lib/cheatsheet.md" ]]; then
        cat "$SCRIPT_DIR/../lib/cheatsheet.md"
    fi
}

# Calculate elapsed time
get_elapsed_time() {
    local started_at="$1"
    local now=$(date +%s)

    # Try macOS format first, then Linux
    local started
    if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s > /dev/null 2>&1; then
        started=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s)
    elif date -d "$started_at" +%s > /dev/null 2>&1; then
        started=$(date -d "$started_at" +%s)
    else
        started=$now
    fi

    local elapsed=$((now - started))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))

    echo "${hours}h ${minutes}m"
}

# Build continuation prompt
build_continuation_prompt() {
    local iteration="$1"
    local max_iterations="$2"
    local goal="$3"
    local elapsed="$4"
    shift 4
    local blockers=("$@")

    # Start with cheatsheet
    get_cheatsheet

    echo ""
    echo "---"
    echo "## Loop Status"
    echo "Iteration: $iteration/$max_iterations | Elapsed: $elapsed"
    echo "Goal: $goal"
    echo ""

    # Add blockers if any
    if [[ ${#blockers[@]} -gt 0 ]]; then
        echo "Exit blocked because:"
        for blocker in "${blockers[@]}"; do
            echo "- $blocker"
        done
        echo ""
    fi

    echo "Continue working. Re-read CONTEXT.md for current state."
}

# --- Main Logic ---

BLOCKERS=()

# Check if in loop mode
if is_loop_active "$PROJECT_DIR"; then
    # Read state
    STATE=$(read_state_file "$PROJECT_DIR")
    ITERATION=$(echo "$STATE" | jq -r '.iteration')
    MAX_ITERATIONS=$(echo "$STATE" | jq -r '.max_iterations')
    GOAL=$(echo "$STATE" | jq -r '.goal')
    PAUSED=$(echo "$STATE" | jq -r '.paused')
    STARTED_AT=$(echo "$STATE" | jq -r '.started_at')
    AWAITING_VERIFICATION=$(echo "$STATE" | jq -r '.awaiting_verification')
    LAST_REREAD=$(echo "$STATE" | jq -r '.last_protocol_reread')

    # If paused, allow exit
    if [[ "$PAUSED" == "true" ]]; then
        exit 0
    fi

    # Check if work is complete
    if check_completion; then
        # Clear loop state and allow exit
        delete_state_file "$PROJECT_DIR"
        echo "## Build Complete!"
        echo ""
        echo "All completion criteria met. Loop state cleared."
        echo "Great work!"
        exit 0
    fi

    # Increment iteration
    NEW_ITERATION=$((ITERATION + 1))
    update_state_field "$PROJECT_DIR" ".iteration" "$NEW_ITERATION"

    # --- Protocol Verification ---

    if [[ "$AWAITING_VERIFICATION" == "true" ]]; then
        # Check if verification response provided
        VERIFICATION_RESPONSE=$(echo "$STATE" | jq -r '.verification_response // ""')
        EXPECTED_CODE=$(echo "$STATE" | jq -r '.expected_verification_code')

        if [[ "$VERIFICATION_RESPONSE" == "$EXPECTED_CODE" ]]; then
            # Verification passed! Generate new code and continue
            NEW_CODE=$(generate_verification_code)
            update_state_field "$PROJECT_DIR" ".expected_verification_code" "\"$NEW_CODE\""
            update_state_field "$PROJECT_DIR" ".verification_response" "null"
            update_state_field "$PROJECT_DIR" ".awaiting_verification" "false"
            update_state_field "$PROJECT_DIR" ".last_protocol_reread" "$NEW_ITERATION"
        else
            # Still awaiting verification
            STATE_FILE=$(get_state_file_path "$PROJECT_DIR")
            cat << EOF
## Protocol Re-Read Required (Iteration $NEW_ITERATION)

Full protocol re-read required before continuing.

1. Read AUTONOMOUS_BUILD_CLAUDE.md completely (from start to end)
2. After reading, check $STATE_FILE for expected_verification_code
3. Update the same file's verification_response field with that code
4. Resume work

You cannot proceed until verification is complete.
EOF
            exit 2
        fi
    fi

    # Check if it's time for verification (every 3 iterations from last reread)
    if [[ $((NEW_ITERATION - LAST_REREAD)) -ge 3 ]]; then
        # Trigger verification
        NEW_CODE=$(generate_verification_code)
        update_state_field "$PROJECT_DIR" ".expected_verification_code" "\"$NEW_CODE\""
        update_state_field "$PROJECT_DIR" ".awaiting_verification" "true"

        STATE_FILE=$(get_state_file_path "$PROJECT_DIR")
        cat << EOF
## Protocol Re-Read Required (Iteration $NEW_ITERATION)

Full protocol re-read required before continuing.

1. Read AUTONOMOUS_BUILD_CLAUDE.md completely (from start to end)
2. After reading, check $STATE_FILE for expected_verification_code
3. Update the same file's verification_response field with that code
4. Resume work

You cannot proceed until verification is complete.
EOF
        exit 2
    fi

    # Check max iterations
    if [[ $NEW_ITERATION -ge $MAX_ITERATIONS ]]; then
        update_state_field "$PROJECT_DIR" ".paused" "true"
        echo "## Max Iterations Reached"
        echo ""
        echo "Completed $NEW_ITERATION iterations on: $GOAL"
        echo ""
        echo "Options:"
        echo "- Continue working: say 'resume autonomous mode' or 'continue for 50 more iterations'"
        echo "- Adjust direction: provide feedback and then resume"
        echo "- Stop: say 'stop autonomous mode'"
        exit 2
    fi

    # Collect blockers for status display
    if ! check_git_clean; then
        BLOCKERS+=("Uncommitted changes in git")
    fi
    if ! check_quality_gates; then
        for gate in "${FAILED_QUALITY_GATES[@]}"; do
            BLOCKERS+=("Quality gate failed: $gate")
        done
    fi
    if ! check_plan_complete; then
        BLOCKERS+=("IMPLEMENTATION_PLAN.md has incomplete tasks")
    fi

    # Work not complete, block exit and continue
    ELAPSED=$(get_elapsed_time "$STARTED_AT")
    build_continuation_prompt "$NEW_ITERATION" "$MAX_ITERATIONS" "$GOAL" "$ELAPSED" "${BLOCKERS[@]}"
    exit 2
fi

# --- Safety Net (not in loop mode) ---

# Safety net: git check
if ! check_git_clean; then
    BLOCKERS+=("Uncommitted changes in git")
fi

# Safety net: quality gates
if ! check_quality_gates; then
    for gate in "${FAILED_QUALITY_GATES[@]}"; do
        BLOCKERS+=("Quality gate failed: $gate")
    done
fi

# If blockers, output message and block
if [[ ${#BLOCKERS[@]} -gt 0 ]]; then
    echo "## Exit Blocked: Safety Net"
    echo ""
    echo "The following issues must be resolved:"
    for blocker in "${BLOCKERS[@]}"; do
        echo "- $blocker"
    done
    echo ""
    echo "Fix the issues above or use Ctrl+C to force quit."
    exit 2
fi

# All checks passed
exit 0
