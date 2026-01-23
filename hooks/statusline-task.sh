#!/usr/bin/env bash
#
# statusline-task.sh - Status line with task progress
# Shows: [3/12] Working on auth flow...
#

# Source task helpers for safe, validated task reading
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$HOME/.claude/lib/task-helpers.sh" ]]; then
    source "$HOME/.claude/lib/task-helpers.sh"
elif [[ -f "$SCRIPT_DIR/lib/task-helpers.sh" ]]; then
    source "$SCRIPT_DIR/lib/task-helpers.sh"
fi

# Check if task helpers are available
if declare -f get_task_dir > /dev/null 2>&1; then
    # Get validated task dir
    TASK_DIR=$(get_task_dir)

    if [[ -n "$TASK_DIR" ]]; then
        # Use single jq pass for efficiency and robustness
        SUMMARY=$(/usr/bin/find "$TASK_DIR" -maxdepth 1 -name "*.json" -type f -print0 2>/dev/null | \
            xargs -0 jq -s '
                if length == 0 then null
                else
                    (map(select(.status == "completed")) | length) as $completed |
                    (map(select(.status == "in_progress")) | first | .activeForm // .subject // null) as $current |
                    {completed: $completed, total: length, current: $current}
                end
            ' 2>/dev/null)

        if [[ "$SUMMARY" != "null" ]] && [[ -n "$SUMMARY" ]]; then
            COMPLETED=$(echo "$SUMMARY" | jq -r '.completed')
            TOTAL=$(echo "$SUMMARY" | jq -r '.total')
            CURRENT=$(echo "$SUMMARY" | jq -r '.current // empty')

            OUTPUT="[$COMPLETED/$TOTAL]"
            [[ -n "$CURRENT" ]] && OUTPUT="$OUTPUT $CURRENT"
            echo "$OUTPUT"
            exit 0
        fi
    fi
fi

# Fallback to git branch
git branch --show-current 2>/dev/null || echo ""
