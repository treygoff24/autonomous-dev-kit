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

    # Check for uncommitted changes, excluding .claude/ directory (our state files)
    local status
    status=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | grep -v '^?? \.claude/' | grep -v '^.. \.claude/')
    if [[ -n "$status" ]]; then
        return 1
    fi

    return 0
}

# --- Safety Net: Quality Gates Check ---

FAILED_QUALITY_GATES=()
GIT_CLEAN="true"
QUALITY_GATES_OK="true"
PLAN_COMPLETE="true"
PLAN_SCOPE_NOTE=""

STUCK_THRESHOLD=5

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

parse_goal_scope() {
    local goal="$1"

    if [[ -z "$goal" ]]; then
        echo ""
        return 0
    fi

    local module
    module=$(printf '%s' "$goal" | grep -oiE '[-[:alnum:]]+[[:space:]]+module' | head -1 || true)
    if [[ -n "$module" ]]; then
        echo "module|$(printf '%s' "$module" | tr '[:upper:]' '[:lower:]')"
        return 0
    fi

    local phase
    phase=$(printf '%s' "$goal" | grep -oiE 'phase[[:space:]]+[0-9]+' | head -1 || true)
    if [[ -n "$phase" ]]; then
        local phase_num
        phase_num=$(printf '%s' "$phase" | awk '{print $2}')
        if [[ -n "$phase_num" ]]; then
            echo "phase|$phase_num"
            return 0
        fi
    fi

    echo ""
}

extract_plan_module_section() {
    local plan_file="$1"
    local scope="$2"

    if [[ -z "$scope" ]]; then
        return 0
    fi

    awk -v scope="$scope" '
        BEGIN { found=0 }
        {
            line=$0
            lower=tolower($0)
            if (lower ~ /^## /) {
                if (found) { exit }
                if (index(lower, scope) > 0) { found=1 }
            }
            if (found) { print line }
        }
    ' "$plan_file"
}

extract_plan_phase_section() {
    local plan_file="$1"
    local phase="$2"

    if [[ -z "$phase" ]]; then
        return 0
    fi

    awk -v phase="$phase" '
        BEGIN { found=0 }
        {
            line=$0
            lower=tolower($0)
            if (lower ~ /^## /) {
                if (found) { exit }
                if (lower ~ ("phase[[:space:]]+" phase "([^0-9]|$)")) { found=1 }
            }
            if (found) { print line }
        }
    ' "$plan_file"
}

check_plan_complete() {
    local plan_file="$PROJECT_DIR/IMPLEMENTATION_PLAN.md"
    local goal="${1:-}"

    PLAN_SCOPE_NOTE=""

    if [[ ! -f "$plan_file" ]]; then
        # No plan file = assume complete (for non-plan projects)
        return 0
    fi

    local scope_line
    scope_line=$(parse_goal_scope "$goal")

    if [[ -n "$scope_line" ]]; then
        local scope_type="${scope_line%%|*}"
        local scope_value="${scope_line#*|}"
        local section=""

        if [[ "$scope_type" == "phase" ]]; then
            section=$(extract_plan_phase_section "$plan_file" "$scope_value")
        else
            section=$(extract_plan_module_section "$plan_file" "$scope_value")
        fi

        if [[ -z "$section" ]]; then
            PLAN_SCOPE_NOTE="Plan scope not found in IMPLEMENTATION_PLAN.md; skipping plan completion check."
            return 0
        fi

        if printf '%s' "$section" | grep -q '\- \[ \]'; then
            return 1
        fi

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
    GIT_CLEAN="true"
    QUALITY_GATES_OK="true"
    PLAN_COMPLETE="true"
    PLAN_SCOPE_NOTE=""

    # Must have clean git
    if ! check_git_clean; then
        GIT_CLEAN="false"
    fi

    # Must pass quality gates (if file exists)
    if ! check_quality_gates; then
        QUALITY_GATES_OK="false"
    fi

    # Must have plan complete (if file exists)
    if ! check_plan_complete "$GOAL"; then
        PLAN_COMPLETE="false"
    fi

    [[ "$GIT_CLEAN" == "true" && "$QUALITY_GATES_OK" == "true" && "$PLAN_COMPLETE" == "true" ]]
}

hash_string() {
    local input="$1"
    printf '%s' "$input" | cksum | awk '{print $1 "-" $2}'
}

get_progress_fingerprint() {
    local project_dir="${1:-$PROJECT_DIR}"

    if git -C "$project_dir" rev-parse --git-dir > /dev/null 2>&1; then
        local head
        head=$(git -C "$project_dir" rev-parse HEAD 2>/dev/null || echo "")
        local status
        status=$(git -C "$project_dir" status --porcelain 2>/dev/null | grep -v '^?? \.claude/' | grep -v '^.. \.claude/' || true)
        local diff_hash
        diff_hash=$(git -C "$project_dir" diff --no-color --no-ext-diff 2>/dev/null | cksum | awk '{print $1 "-" $2}' || true)
        local cached_hash
        cached_hash=$(git -C "$project_dir" diff --cached --no-color --no-ext-diff 2>/dev/null | cksum | awk '{print $1 "-" $2}' || true)
        printf '%s\n%s\n%s\n%s' "$head" "$status" "$cached_hash" "$diff_hash"
        return 0
    fi

    echo ""
}

check_stuck_loop() {
    local state="$1"
    local goal="$2"

    local progress
    progress=$(get_progress_fingerprint "$PROJECT_DIR")

    if [[ -z "$progress" ]]; then
        return 0
    fi

    local goal_hash
    goal_hash=$(hash_string "$goal")
    local progress_hash
    progress_hash=$(hash_string "$progress")

    local last_goal_hash
    last_goal_hash=$(echo "$state" | jq -r '.last_goal_hash // ""')
    local last_progress_hash
    last_progress_hash=$(echo "$state" | jq -r '.last_progress_hash // ""')
    local stuck_count
    stuck_count=$(echo "$state" | jq -r '.stuck_count // 0')

    if [[ "$goal_hash" == "$last_goal_hash" && "$progress_hash" == "$last_progress_hash" ]]; then
        stuck_count=$((stuck_count + 1))
    else
        stuck_count=0
    fi

    update_state_field "$PROJECT_DIR" ".stuck_count" "$stuck_count"
    update_state_field "$PROJECT_DIR" ".last_goal_hash" "\"$goal_hash\""
    update_state_field "$PROJECT_DIR" ".last_progress_hash" "\"$progress_hash\""

    if [[ $stuck_count -ge $STUCK_THRESHOLD ]]; then
        update_state_field "$PROJECT_DIR" ".paused" "true"
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
    printf '%s' "$last_line" | jq -r '
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
    local expected_code="${2:-}"

    if [[ -z "$output" ]]; then
        return 1
    fi

    if [[ -n "$expected_code" && ! "$expected_code" =~ ^[0-9]{4}$ ]]; then
        expected_code=""
    fi

    if [[ -n "$expected_code" ]]; then
        local code_pattern
        code_pattern=$(printf '%s' "$expected_code" | sed 's/[][\\.^$*+?{}|()]/\\&/g')
        if echo "$output" | grep -qE "<verified[^>]*code=[\"']?$code_pattern([\"']|[[:space:]/>])" 2>/dev/null; then
            return 0
        fi
        if echo "$output" | grep -qE "<verified>[[:space:]]*$expected_code[[:space:]]*</verified>" 2>/dev/null; then
            return 0
        fi
        return 1
    fi

    # Legacy fallback when no code is present
    if echo "$output" | grep -qE '<verified[[:space:]]*/?>|<verified>.*</verified>' 2>/dev/null; then
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

# Build verification instructions
build_verification_prompt() {
    local iteration="$1"
    local state_file="$2"

    cat << EOF
## Protocol Re-Read Required (Iteration $iteration)

1. Read AUTONOMOUS_BUILD_CLAUDE.md completely (start to finish).
2. Open $state_file and find expected_verification_code.
3. Reply with <verified code="####"/> using that code (or <verified>####</verified>).

Do not continue until verification is complete.
EOF
}

# --- Main Logic ---

# Allow sourcing for tests without executing main logic
if [[ "${STOP_HOOK_LIB_ONLY:-}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Read input from stdin (Claude Code sends JSON)
INPUT=$(cat)

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

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
    # Every VERIFY_INTERVAL iterations, remind Claude to re-read protocol and confirm with a code.
    # Check transcript for the tag. After MAX_VERIFY_ATTEMPTS, soft fail and continue.

    VERIFY_INTERVAL=3           # Request verification every N iterations
    MAX_VERIFY_ATTEMPTS=3       # Give up after this many attempts (prevent infinite loops)

    VERIFICATION_PENDING=$(echo "$STATE" | jq -r '.verification_pending // false')
    VERIFY_ATTEMPTS=$(echo "$STATE" | jq -r '.verification_attempts // 0')
    LAST_VERIFIED=$(echo "$STATE" | jq -r '.last_verified_iteration // 0')
    EXPECTED_CODE=$(echo "$STATE" | jq -r '.expected_verification_code // ""')

    # Get transcript path from hook input
    TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

    # Ensure pending verification has a code
    if [[ "$VERIFICATION_PENDING" == "true" && -z "$EXPECTED_CODE" ]]; then
        EXPECTED_CODE=$(generate_verification_code)
        update_state_field "$PROJECT_DIR" ".expected_verification_code" "\"$EXPECTED_CODE\""
    fi

    # Check if verification is pending (we asked Claude to verify last iteration)
    if [[ "$VERIFICATION_PENDING" == "true" ]]; then
        LAST_OUTPUT=$(get_last_assistant_output "$TRANSCRIPT_PATH")

        if check_verification_tag "$LAST_OUTPUT" "$EXPECTED_CODE"; then
            # Verification successful!
            echo "✅ Protocol verification confirmed" >&2
            update_state_field "$PROJECT_DIR" ".verification_pending" "false"
            update_state_field "$PROJECT_DIR" ".verification_attempts" "0"
            update_state_field "$PROJECT_DIR" ".expected_verification_code" "null"
            update_state_field "$PROJECT_DIR" ".last_verified_iteration" "$NEW_ITERATION"
            LAST_VERIFIED="$NEW_ITERATION"
        else
            # Verification not found, increment attempts
            NEW_ATTEMPTS=$((VERIFY_ATTEMPTS + 1))
            update_state_field "$PROJECT_DIR" ".verification_attempts" "$NEW_ATTEMPTS"

            if [[ $NEW_ATTEMPTS -ge $MAX_VERIFY_ATTEMPTS ]]; then
                # Soft fail - give up and continue
                echo "⚠️  Verification not received after $MAX_VERIFY_ATTEMPTS attempts, continuing anyway" >&2
                update_state_field "$PROJECT_DIR" ".verification_pending" "false"
                update_state_field "$PROJECT_DIR" ".verification_attempts" "0"
                update_state_field "$PROJECT_DIR" ".expected_verification_code" "null"
                update_state_field "$PROJECT_DIR" ".last_verified_iteration" "$NEW_ITERATION"
                LAST_VERIFIED="$NEW_ITERATION"
            fi
            # If still under max attempts, verification_pending stays true
        fi
    fi

    # Refresh state for current verification flags
    STATE=$(read_state_file "$PROJECT_DIR")
    VERIFICATION_PENDING=$(echo "$STATE" | jq -r '.verification_pending // false')
    LAST_VERIFIED=$(echo "$STATE" | jq -r '.last_verified_iteration // 0')
    EXPECTED_CODE=$(echo "$STATE" | jq -r '.expected_verification_code // ""')

    # Check if it's time to request verification
    if [[ "$VERIFICATION_PENDING" != "true" ]] && [[ $((NEW_ITERATION - LAST_VERIFIED)) -ge $VERIFY_INTERVAL ]]; then
        # Time for verification
        echo "📋 Requesting protocol verification (iteration $NEW_ITERATION)" >&2
        EXPECTED_CODE=$(generate_verification_code)
        update_state_field "$PROJECT_DIR" ".verification_pending" "true"
        update_state_field "$PROJECT_DIR" ".verification_attempts" "0"
        update_state_field "$PROJECT_DIR" ".expected_verification_code" "\"$EXPECTED_CODE\""
        update_state_field "$PROJECT_DIR" ".stuck_count" "0"
        VERIFICATION_PENDING="true"
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

    # Stuck detection (skip while verification is pending)
    if [[ "$VERIFICATION_PENDING" != "true" ]]; then
        STATE=$(read_state_file "$PROJECT_DIR")
        if ! check_stuck_loop "$STATE" "$GOAL"; then
            STUCK_MSG=$(cat << EOF
## Loop Paused (No Progress Detected)

Repeated the same goal without visible git progress for $STUCK_THRESHOLD iterations.

Options:
- Provide updated direction or scope, then say "resume autonomous mode"
- Extend iterations if this is expected
- Stop: say "stop autonomous mode"
EOF
)
            emit_decision "block" "$STUCK_MSG"
            exit 0
        fi
    fi

    # Collect blockers for status display
    if [[ "$GIT_CLEAN" != "true" ]]; then
        BLOCKERS+=("Uncommitted changes in git")
    fi
    if [[ "$QUALITY_GATES_OK" != "true" ]]; then
        for gate in "${FAILED_QUALITY_GATES[@]}"; do
            BLOCKERS+=("Quality gate failed: $gate")
        done
    fi
    if [[ "$PLAN_COMPLETE" != "true" ]]; then
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
    if [[ -n "$PLAN_SCOPE_NOTE" ]]; then
        SYSTEM_MSG="$SYSTEM_MSG | $PLAN_SCOPE_NOTE"
    fi

    # Add verification request if pending (user-visible status only)
    if [[ "$VERIFICATION_PENDING" == "true" ]]; then
        VERIFY_ATTEMPTS=$(echo "$STATE" | jq -r '.verification_attempts // 0')
        STATE_FILE=$(get_state_file_path "$PROJECT_DIR")
        SYSTEM_MSG="$SYSTEM_MSG | VERIFICATION REQUIRED (attempt $((VERIFY_ATTEMPTS + 1))/$MAX_VERIFY_ATTEMPTS): Read AUTONOMOUS_BUILD_CLAUDE.md and reply with <verified code=\"####\"/> using expected_verification_code from $STATE_FILE"
    fi

    # Build continuation prompt for Claude (reason becomes the next user input)
    PROMPT="$(build_continuation_prompt "$NEW_ITERATION" "$MAX_ITERATIONS" "$GOAL" "$ELAPSED" "${BLOCKERS[@]}")"

    if [[ "$VERIFICATION_PENDING" == "true" ]]; then
        STATE_FILE=$(get_state_file_path "$PROJECT_DIR")
        VERIFICATION_PROMPT="$(build_verification_prompt "$NEW_ITERATION" "$STATE_FILE")"
        PROMPT="$PROMPT

$VERIFICATION_PROMPT"
    fi

    emit_decision "block" "$PROMPT" "$SYSTEM_MSG"
    exit 0
fi

# --- Safety Net (not in loop mode) ---
# In non-loop mode, safety net is advisory only (warns but doesn't block)

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
