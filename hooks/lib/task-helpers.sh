#!/usr/bin/env bash
#
# task-helpers.sh - Safe task list reading utilities
#
# These functions READ task state for display purposes.
# Task creation/updates are done by Claude via TaskCreate/TaskUpdate tools.
#

# Validate task list ID is a safe UUID pattern (prevents path traversal)
# Returns 0 if valid, 1 if invalid
validate_task_list_id() {
    local id="$1"
    [[ -z "$id" ]] && return 1

    # Convert to lowercase for case-insensitive matching (portable)
    local lower_id
    lower_id=$(echo "$id" | tr '[:upper:]' '[:lower:]')

    # Must match UUID pattern: 8-4-4-4-12 hex chars, or swarm-YYYYMMDD-HHMMSS
    if [[ "$lower_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || \
       [[ "$lower_id" =~ ^swarm-[0-9]{8}-[0-9]{6}$ ]]; then
        return 0
    fi
    return 1
}

# Get task list ID for current project
# Priority: 1) CLAUDE_CODE_TASK_LIST_ID env var, 2) .claude/task-list-id file
# Returns empty string if no valid task list found
get_task_list_id() {
    local project_path="${1:-$(pwd)}"
    local task_list_id="${CLAUDE_CODE_TASK_LIST_ID:-}"

    # Try project-local marker if env var not set
    if [[ -z "$task_list_id" ]] && [[ -f "$project_path/.claude/task-list-id" ]]; then
        task_list_id=$(cat "$project_path/.claude/task-list-id" 2>/dev/null | tr -d '[:space:]')
    fi

    # Validate before returning
    if [[ -n "$task_list_id" ]] && validate_task_list_id "$task_list_id"; then
        echo "$task_list_id"
    fi
}

# Get task directory path (validated)
# Returns empty string if invalid or doesn't exist
get_task_dir() {
    local task_list_id
    task_list_id=$(get_task_list_id "$@")

    [[ -z "$task_list_id" ]] && return

    local task_dir="$HOME/.claude/tasks/$task_list_id"
    [[ -d "$task_dir" ]] && echo "$task_dir"
}

# Get task summary using single jq pass for robustness
# Output: "completed/total complete (pending pending, in_progress active)"
get_task_summary() {
    local task_dir
    task_dir=$(get_task_dir "$@")

    [[ -z "$task_dir" ]] && echo "No task list" && return

    # Check if any JSON files exist (portable - works in bash and zsh)
    local file_count
    file_count=$(/usr/bin/find "$task_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$file_count" -eq 0 ]]; then
        echo "No tasks"
        return
    fi

    # Single jq -s pass over all task files with error handling
    /usr/bin/find "$task_dir" -maxdepth 1 -name "*.json" -type f -print0 2>/dev/null | \
        xargs -0 jq -s '
            if length == 0 then "No tasks"
            else
                (map(select(.status == "completed")) | length) as $completed |
                (map(select(.status == "pending")) | length) as $pending |
                (map(select(.status == "in_progress")) | length) as $in_progress |
                "\($completed)/\(length) complete (\($pending) pending, \($in_progress) active)"
            end
        ' 2>/dev/null || echo "Error reading tasks"
}

# Get current in-progress task subject
# Output: task subject or empty string
get_current_task() {
    local task_dir
    task_dir=$(get_task_dir "$@")

    [[ -z "$task_dir" ]] && return

    # Check if any JSON files exist (portable)
    local file_count
    file_count=$(/usr/bin/find "$task_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

    [[ "$file_count" -eq 0 ]] && return

    # Find first in_progress task
    /usr/bin/find "$task_dir" -maxdepth 1 -name "*.json" -type f -print0 2>/dev/null | \
        xargs -0 jq -s '
            map(select(.status == "in_progress")) |
            if length > 0 then .[0] | "Task #\(.id): \(.subject)" else "" end
        ' 2>/dev/null | tr -d '"'
}

# Check if all tasks are completed
# Returns 0 if complete (or no tasks), 1 if incomplete
check_task_completion() {
    local task_dir
    task_dir=$(get_task_dir "$@")

    [[ -z "$task_dir" ]] && return 0  # No tasks = complete

    # Check if any JSON files exist (portable)
    local file_count
    file_count=$(/usr/bin/find "$task_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

    [[ "$file_count" -eq 0 ]] && return 0  # No task files = complete

    local incomplete
    incomplete=$(/usr/bin/find "$task_dir" -maxdepth 1 -name "*.json" -type f -print0 2>/dev/null | \
        xargs -0 jq -s 'map(select(.status != "completed")) | length' 2>/dev/null)

    [[ "$incomplete" == "0" ]] && return 0
    return 1
}

# Get full task summary for handoff (multiline)
get_task_handoff_summary() {
    local task_dir
    task_dir=$(get_task_dir "$@")

    [[ -z "$task_dir" ]] && return

    local task_list_id
    task_list_id=$(get_task_list_id "$@")

    echo "## Task List State"
    echo ""
    echo "**Task List ID:** \`$task_list_id\`"
    echo "**Progress:** $(get_task_summary "$@")"

    local current
    current=$(get_current_task "$@")
    if [[ -n "$current" ]]; then
        echo "**Current Task:** $current"
    fi
}
