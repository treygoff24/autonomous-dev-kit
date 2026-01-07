#!/usr/bin/env bash
#
# Stop Hook: Safety net + autonomous loop continuation
# Uses the Stop hook decision JSON:
#   { "decision": "approve|block", "reason": "...", "systemMessage": "..." }
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

# Debug: show what directory we're checking
echo "🔍 Stop hook checking: $PROJECT_DIR" >&2

# --- Output Helpers ---

# NOTE: Only use for "block" decisions. For "approve", just exit 0 with no JSON output.
# Outputting JSON for "approve" causes the output to be fed back as user input, creating infinite loops.
emit_decision() {
    local decision="$1"
    local reason="${2:-}"
    local system_message="${3:-}"

    if [[ -n "$system_message" ]]; then
        jq -n --arg decision "$decision" --arg reason "$reason" --arg system "$system_message" '{
            decision: $decision,
            reason: $reason,
            systemMessage: $system
        }'
    else
        jq -n --arg decision "$decision" --arg reason "$reason" '{
            decision: $decision,
            reason: $reason
        }'
    fi
}

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

    # If no unchecked boxes, we're complete
    # (either all checked, no checkboxes at all, or has COMPLETE marker)
    return 0
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

# --- Transcript Reading (for output-based verification) ---

# Get the last assistant message from the transcript
# Returns empty string if transcript can't be read
get_last_assistant_output() {
    local transcript_path="$1"

    if [[ ! -f "$transcript_path" ]]; then
        echo ""
        return
    fi

    # Check if there are any assistant messages
    if ! grep -q '"role":"assistant"' "$transcript_path" 2>/dev/null; then
        echo ""
        return
    fi

    # Extract last assistant message (JSONL format - one JSON per line)
    local last_line
    last_line=$(grep '"role":"assistant"' "$transcript_path" | tail -1)

    if [[ -z "$last_line" ]]; then
        echo ""
        return
    fi

    # Parse JSON and extract text content
    echo "$last_line" | jq -r '
        .message.content |
        map(select(.type == "text")) |
        map(.text) |
        join("\n")
    ' 2>/dev/null || echo ""
}

# Check if Claude's output contains the verification tag
# Returns 0 (true) if verified, 1 (false) if not
check_verification_tag() {
    local output="$1"

    # Look for <verified/> or <verified></verified> or <verified>anything</verified>
    if echo "$output" | grep -qE '<verified\s*/?>' 2>/dev/null; then
        return 0
    fi
    return 1
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
echo "🔍 Checking loop active for: $PROJECT_DIR" >&2
if is_loop_active "$PROJECT_DIR"; then
    echo "🔄 Loop IS active" >&2
    # Read state
    STATE=$(read_state_file "$PROJECT_DIR")
    ITERATION=$(echo "$STATE" | jq -r '.iteration')
    MAX_ITERATIONS=$(echo "$STATE" | jq -r '.max_iterations')
    GOAL=$(echo "$STATE" | jq -r '.goal')
    PAUSED=$(echo "$STATE" | jq -r '.paused')
    STARTED_AT=$(echo "$STATE" | jq -r '.started_at')

    # If paused, allow exit (no JSON output = approve)
    if [[ "$PAUSED" == "true" ]]; then
        echo "✅ Loop paused - exit allowed" >&2
        exit 0
    fi

    # Check if work is complete
    if check_completion; then
        # Clear loop state and allow exit (no JSON output = approve)
        delete_state_file "$PROJECT_DIR"
        echo "✅ All completion criteria met. Loop state cleared." >&2
        exit 0
    fi

    # Increment iteration
    NEW_ITERATION=$((ITERATION + 1))
    update_state_field "$PROJECT_DIR" ".iteration" "$NEW_ITERATION"

    # --- Protocol Verification (Output-based with soft fail) ---
    # Every VERIFY_INTERVAL iterations, remind Claude to re-read protocol and output <verified/>
    # Check transcript for the tag. After MAX_VERIFY_ATTEMPTS, soft fail and continue.

    VERIFY_INTERVAL=5           # Request verification every N iterations
    MAX_VERIFY_ATTEMPTS=3       # Give up after this many attempts (prevent infinite loops)

    VERIFICATION_PENDING=$(echo "$STATE" | jq -r '.verification_pending // false')
    VERIFY_ATTEMPTS=$(echo "$STATE" | jq -r '.verification_attempts // 0')
    LAST_VERIFIED=$(echo "$STATE" | jq -r '.last_verified_iteration // 0')

    # Get transcript path from hook input
    TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

    # Check if verification is pending (we asked Claude to verify last iteration)
    if [[ "$VERIFICATION_PENDING" == "true" ]]; then
        LAST_OUTPUT=$(get_last_assistant_output "$TRANSCRIPT_PATH")

        if check_verification_tag "$LAST_OUTPUT"; then
            # Verification successful!
            echo "✅ Protocol verification confirmed" >&2
            update_state_field "$PROJECT_DIR" ".verification_pending" "false"
            update_state_field "$PROJECT_DIR" ".verification_attempts" "0"
            update_state_field "$PROJECT_DIR" ".last_verified_iteration" "$NEW_ITERATION"
        else
            # Verification not found, increment attempts
            NEW_ATTEMPTS=$((VERIFY_ATTEMPTS + 1))
            update_state_field "$PROJECT_DIR" ".verification_attempts" "$NEW_ATTEMPTS"

            if [[ $NEW_ATTEMPTS -ge $MAX_VERIFY_ATTEMPTS ]]; then
                # Soft fail - give up and continue
                echo "⚠️  Verification not received after $MAX_VERIFY_ATTEMPTS attempts, continuing anyway" >&2
                update_state_field "$PROJECT_DIR" ".verification_pending" "false"
                update_state_field "$PROJECT_DIR" ".verification_attempts" "0"
                update_state_field "$PROJECT_DIR" ".last_verified_iteration" "$NEW_ITERATION"
            fi
            # If still under max attempts, verification_pending stays true
            # and the systemMessage will keep asking
        fi
    fi

    # Check if it's time to request verification
    VERIFICATION_PENDING=$(echo "$(read_state_file "$PROJECT_DIR")" | jq -r '.verification_pending // false')
    if [[ "$VERIFICATION_PENDING" != "true" ]] && [[ $((NEW_ITERATION - LAST_VERIFIED)) -ge $VERIFY_INTERVAL ]]; then
        # Time for verification
        echo "📋 Requesting protocol verification (iteration $NEW_ITERATION)" >&2
        update_state_field "$PROJECT_DIR" ".verification_pending" "true"
        update_state_field "$PROJECT_DIR" ".verification_attempts" "0"
    fi

    # Check max iterations
    if [[ $NEW_ITERATION -ge $MAX_ITERATIONS ]]; then
        update_state_field "$PROJECT_DIR" ".paused" "true"
        MAX_ITERATIONS_MSG=$(cat << EOF
## Max Iterations Reached

Completed $NEW_ITERATION iterations on: $GOAL

Options:
- Continue working: say 'resume autonomous mode' or 'continue for 50 more iterations'
- Adjust direction: provide feedback and then resume
- Stop: say 'stop autonomous mode'
EOF
)
        emit_decision "block" "$MAX_ITERATIONS_MSG"
        exit 0
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

    # Build system message with status (NOT the reason - that's the task prompt)
    SYSTEM_MSG="🔄 Iteration $NEW_ITERATION/$MAX_ITERATIONS | Elapsed: $ELAPSED"
    if [[ ${#BLOCKERS[@]} -gt 0 ]]; then
        SYSTEM_MSG="$SYSTEM_MSG | Blocked: "
        for blocker in "${BLOCKERS[@]}"; do
            SYSTEM_MSG="$SYSTEM_MSG $blocker;"
        done
    fi

    # Add verification request if pending
    VERIFICATION_PENDING=$(echo "$(read_state_file "$PROJECT_DIR")" | jq -r '.verification_pending // false')
    if [[ "$VERIFICATION_PENDING" == "true" ]]; then
        VERIFY_ATTEMPTS=$(echo "$(read_state_file "$PROJECT_DIR")" | jq -r '.verification_attempts // 0')
        SYSTEM_MSG="$SYSTEM_MSG | ⚠️ VERIFICATION REQUIRED (attempt $((VERIFY_ATTEMPTS + 1))/$MAX_VERIFY_ATTEMPTS): Re-read AUTONOMOUS_BUILD_CLAUDE.md then output <verified/> to confirm"
    fi

    # KEY: reason = the GOAL (actionable task), systemMessage = status info
    # This is how ralph-wiggum does it - the reason becomes user input,
    # so it must be the actual task prompt, not status info
    jq -n \
        --arg prompt "$GOAL" \
        --arg msg "$SYSTEM_MSG" \
        '{
            "decision": "block",
            "reason": $prompt,
            "systemMessage": $msg
        }'
    exit 0
fi

# --- Safety Net (not in loop mode) ---
# In non-loop mode, safety net is advisory only (warns but doesn't block)
echo "📍 Loop NOT active - running safety net only" >&2

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

# If blockers, output warning but allow exit (advisory mode)
if [[ ${#BLOCKERS[@]} -gt 0 ]]; then
    echo "⚠️  Safety net warning:" >&2
    for blocker in "${BLOCKERS[@]}"; do
        echo "  - $blocker" >&2
    done
fi

# Allow exit (not in loop mode = advisory only)
# No JSON output = approve. Just exit cleanly.
echo "✅ Exit approved" >&2
exit 0
