#!/usr/bin/env bash
#
# Stop Hook: Deterministic autonomous loop state engine
#
# Exit codes:
#   0 = allow exit
#   2 = block exit and continue autonomous loop
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$HOME/.claude/lib/loop-helpers.sh" ]]; then
    source "$HOME/.claude/lib/loop-helpers.sh"
elif [[ -f "$SCRIPT_DIR/lib/loop-helpers.sh" ]]; then
    source "$SCRIPT_DIR/lib/loop-helpers.sh"
fi

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
BLOCKERS=()

has_npm_script() {
    local script="$1"
    local package_json="$PROJECT_DIR/package.json"

    [[ -f "$package_json" ]] || return 1

    if command -v jq &> /dev/null; then
        jq -e --arg script "$script" '.scripts[$script]' "$package_json" > /dev/null 2>&1
        return $?
    fi

    if command -v node &> /dev/null; then
        (cd "$PROJECT_DIR" && node -e "const s=process.argv[1];const p=require('./package.json');process.exit(p.scripts && Object.prototype.hasOwnProperty.call(p.scripts,s)?0:1)" "$script" > /dev/null 2>&1)
        return $?
    fi

    if command -v rg &> /dev/null; then
        rg -q "\"$script\"[[:space:]]*:" "$package_json"
    else
        grep -q "\"$script\"[[:space:]]*:" "$package_json"
    fi
}

hash_string() {
    local input="$1"
    if command -v shasum &> /dev/null; then
        printf '%s' "$input" | shasum -a 256 | awk '{print $1}' | cut -c1-16
    elif command -v sha256sum &> /dev/null; then
        printf '%s' "$input" | sha256sum | awk '{print $1}' | cut -c1-16
    else
        # Fallback: deterministic enough for local stuck detection.
        printf '%s' "$input" | cksum | awk '{print $1}'
    fi
}

check_git_clean() {
    if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
        return 0
    fi

    local status
    status=$(git -C "$PROJECT_DIR" status --porcelain -- . ':(exclude).claude/**' 2>/dev/null || true)
    if [[ -n "$status" ]]; then
        BLOCKERS+=("Git working tree has uncommitted changes")
        return 1
    fi

    return 0
}

run_command_gate() {
    local cmd="$1"
    if ! (cd "$PROJECT_DIR" && eval "$cmd") > /dev/null 2>&1; then
        BLOCKERS+=("Quality gate failed: $cmd")
        return 1
    fi
    return 0
}

check_quality_gates() {
    local gates_file="$PROJECT_DIR/.claude-quality-gates"
    local all_ok=true

    if [[ -f "$gates_file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Trim leading/trailing whitespace.
            local cmd
            cmd=$(echo "$line" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
            [[ -z "$cmd" ]] && continue
            [[ "$cmd" =~ ^# ]] && continue
            if ! run_command_gate "$cmd"; then
                all_ok=false
            fi
        done < "$gates_file"

        $all_ok && return 0 || return 1
    fi

    local scripts=(typecheck lint build test)
    for script in "${scripts[@]}"; do
        if has_npm_script "$script"; then
            if ! run_command_gate "npm run $script"; then
                all_ok=false
            fi
        fi
    done

    $all_ok && return 0 || return 1
}

extract_phase_scope() {
    local goal="$1"
    echo "$goal" | grep -Eio 'phase[[:space:]]+[0-9]+' | head -1 | grep -Eo '[0-9]+' || true
}

check_plan_completion() {
    local plan_file="$PROJECT_DIR/IMPLEMENTATION_PLAN.md"
    local goal="$1"

    [[ -f "$plan_file" ]] || return 0

    local phase
    phase=$(extract_phase_scope "$goal")
    if [[ -n "$phase" ]]; then
        local scoped_section
        scoped_section=$(awk -v phase="$phase" '
            BEGIN {capture=0}
            {
                lower=$0
                for (i=1; i<=length(lower); i++) {
                    c=substr(lower, i, 1)
                    if (c >= "A" && c <= "Z") {
                        lower=substr(lower, 1, i-1) tolower(c) substr(lower, i+1)
                    }
                }
            }
            $0 ~ /^## / && lower ~ ("phase[[:space:]]*" phase "([^0-9]|$)") {capture=1; print; next}
            $0 ~ /^## / && capture==1 {exit}
            capture==1 {print}
        ' "$plan_file")

        if [[ -n "$scoped_section" ]]; then
            if echo "$scoped_section" | grep -q '\- \[ \]'; then
                BLOCKERS+=("Implementation plan has incomplete tasks in Phase $phase")
                return 1
            fi
            return 0
        fi
        return 0
    fi

    if grep -q '\- \[ \]' "$plan_file"; then
        BLOCKERS+=("Implementation plan has incomplete tasks")
        return 1
    fi

    return 0
}

check_task_list_completion() {
    if ! declare -f check_task_completion > /dev/null 2>&1; then
        return 0
    fi

    if ! check_task_completion "$PROJECT_DIR"; then
        BLOCKERS+=("Task list has pending or in_progress tasks")
        return 1
    fi

    return 0
}

check_completion() {
    local goal="$1"
    local complete=true

    if ! check_git_clean; then
        complete=false
    fi

    if ! check_task_list_completion; then
        complete=false
    fi

    if ! check_quality_gates; then
        complete=false
    fi

    if ! check_plan_completion "$goal"; then
        complete=false
    fi

    $complete && return 0 || return 1
}

get_elapsed_time() {
    local started_at="$1"
    local now started elapsed hours minutes

    now=$(date +%s)
    if [[ "$(uname)" == "Darwin" ]]; then
        started=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s 2>/dev/null || echo "$now")
    else
        started=$(date -d "$started_at" +%s 2>/dev/null || echo "$now")
    fi

    elapsed=$((now - started))
    hours=$((elapsed / 3600))
    minutes=$(((elapsed % 3600) / 60))
    echo "${hours}h ${minutes}m"
}

build_continuation_prompt() {
    local iteration="$1"
    local max_iterations="$2"
    local goal="$3"
    local started_at="$4"

    local elapsed
    elapsed=$(get_elapsed_time "$started_at")

    echo "## Autonomous Loop Continuing"
    echo ""
    echo "Iteration: $iteration/$max_iterations"
    echo "Elapsed: $elapsed"
    echo "Goal: $goal"
    echo ""
    if [[ ${#BLOCKERS[@]} -gt 0 ]]; then
        echo "Exit blocked because:"
        for blocker in "${BLOCKERS[@]}"; do
            echo "- $blocker"
        done
        echo ""
    fi
    echo "Continue working until all completion criteria are met."
}

input_has_verification_code() {
    local expected_code="$1"
    if [[ -z "$expected_code" ]]; then
        return 1
    fi

    if echo "$INPUT" | grep -Eq "<verified[[:space:]]+code=\"$expected_code\"[[:space:]]*/>"; then
        return 0
    fi

    if echo "$INPUT" | grep -Eq "<verified>$expected_code</verified>"; then
        return 0
    fi

    return 1
}

handle_verification_pending() {
    local state="$1"
    local iteration="$2"

    local expected attempts
    expected=$(echo "$state" | jq -r '.expected_verification_code // ""')
    attempts=$(echo "$state" | jq -r '.verification_attempts // 0')

    if input_has_verification_code "$expected"; then
        update_state_field "$PROJECT_DIR" ".verification_pending" "false"
        update_state_field "$PROJECT_DIR" ".expected_verification_code" "null"
        update_state_field "$PROJECT_DIR" ".verification_attempts" "0"
        update_state_field "$PROJECT_DIR" ".last_verified_iteration" "$iteration"
        return 0
    fi

    attempts=$((attempts + 1))
    update_state_field "$PROJECT_DIR" ".verification_attempts" "$attempts"

    if [[ "$attempts" -ge 3 ]]; then
        # Soft fail to avoid infinite loops when transcript parsing is unavailable.
        update_state_field "$PROJECT_DIR" ".verification_pending" "false"
        update_state_field "$PROJECT_DIR" ".expected_verification_code" "null"
        update_state_field "$PROJECT_DIR" ".verification_attempts" "0"
        return 0
    fi

    echo "## Protocol Re-Read Required"
    echo ""
    echo "Verification pending. Re-read AUTONOMOUS_BUILD_CLAUDE.md and respond with:"
    echo "<verified code=\"$expected\"/>"
    echo ""
    echo "Attempt: $attempts/3"
    exit 2
}

trigger_verification() {
    local code
    code=$(generate_verification_code)
    update_state_field "$PROJECT_DIR" ".verification_pending" "true"
    update_state_field "$PROJECT_DIR" ".expected_verification_code" "\"$code\""
    update_state_field "$PROJECT_DIR" ".verification_attempts" "0"

    echo "## Protocol Re-Read Required"
    echo ""
    echo "Read AUTONOMOUS_BUILD_CLAUDE.md end-to-end, then reply with:"
    echo "<verified code=\"$code\"/>"
    exit 2
}

update_stuck_state() {
    local state="$1"
    local goal="$2"

    local head status progress_material
    head=$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || echo "no-git")
    status=$(git -C "$PROJECT_DIR" status --porcelain -- . ':(exclude).claude/**' 2>/dev/null || true)
    progress_material="$head"$'\n'"$status"

    local goal_hash progress_hash last_goal_hash last_progress_hash stuck_count
    goal_hash=$(hash_string "$goal")
    progress_hash=$(hash_string "$progress_material")
    last_goal_hash=$(echo "$state" | jq -r '.last_goal_hash // ""')
    last_progress_hash=$(echo "$state" | jq -r '.last_progress_hash // ""')
    stuck_count=$(echo "$state" | jq -r '.stuck_count // 0')

    if [[ "$goal_hash" == "$last_goal_hash" && "$progress_hash" == "$last_progress_hash" ]]; then
        stuck_count=$((stuck_count + 1))
    else
        stuck_count=0
    fi

    update_state_field "$PROJECT_DIR" ".last_goal_hash" "\"$goal_hash\""
    update_state_field "$PROJECT_DIR" ".last_progress_hash" "\"$progress_hash\""
    update_state_field "$PROJECT_DIR" ".stuck_count" "$stuck_count"

    if [[ "$stuck_count" -ge 5 ]]; then
        update_state_field "$PROJECT_DIR" ".paused" "true"
        echo "## Autonomous Loop Paused: No Progress Detected"
        echo ""
        echo "No goal/git progress detected for 5 consecutive iterations."
        echo "Provide updated direction, then resume."
        exit 2
    fi
}

# No loop state support loaded or invalid project path: allow exit.
if ! declare -f is_loop_active > /dev/null 2>&1; then
    exit 0
fi

if [[ -z "$PROJECT_DIR" || ! -d "$PROJECT_DIR" ]]; then
    exit 0
fi

if ! is_loop_active "$PROJECT_DIR"; then
    exit 0
fi

STATE=$(read_state_file "$PROJECT_DIR")
if [[ -z "$STATE" ]]; then
    exit 0
fi

GOAL=$(echo "$STATE" | jq -r '.goal // ""')
ITERATION=$(echo "$STATE" | jq -r '.iteration // 0')
MAX_ITERATIONS=$(echo "$STATE" | jq -r '.max_iterations // 100')
PAUSED=$(echo "$STATE" | jq -r '.paused // false')
VERIFICATION_PENDING=$(echo "$STATE" | jq -r '.verification_pending // false')
LAST_VERIFIED_ITERATION=$(echo "$STATE" | jq -r '.last_verified_iteration // 0')
STARTED_AT=$(echo "$STATE" | jq -r '.started_at // ""')

if [[ "$PAUSED" == "true" ]]; then
    exit 0
fi

if check_completion "$GOAL"; then
    delete_state_file "$PROJECT_DIR"
    exit 0
fi

if [[ "$VERIFICATION_PENDING" == "true" ]]; then
    handle_verification_pending "$STATE" "$ITERATION"
    STATE=$(read_state_file "$PROJECT_DIR")
fi

NEW_ITERATION=$((ITERATION + 1))
update_state_field "$PROJECT_DIR" ".iteration" "$NEW_ITERATION"

if [[ "$NEW_ITERATION" -ge "$MAX_ITERATIONS" ]]; then
    update_state_field "$PROJECT_DIR" ".paused" "true"
    echo "## Max Iterations Reached"
    echo ""
    echo "Reached $NEW_ITERATION/$MAX_ITERATIONS iterations."
    echo "Say \"continue for 50 more\" to extend, or provide new direction."
    exit 2
fi

if [[ $((NEW_ITERATION - LAST_VERIFIED_ITERATION)) -ge 3 ]]; then
    trigger_verification
fi

STATE=$(read_state_file "$PROJECT_DIR")
update_stuck_state "$STATE" "$GOAL"

if [[ -z "$STARTED_AT" || "$STARTED_AT" == "null" ]]; then
    STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
fi

build_continuation_prompt "$NEW_ITERATION" "$MAX_ITERATIONS" "$GOAL" "$STARTED_AT"
exit 2

