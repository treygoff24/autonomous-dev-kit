#!/usr/bin/env bash
#
# loop-helpers.sh — Shared functions for autonomous loop state management
#
# Source this file in hooks: source "$HOME/.claude/lib/loop-helpers.sh"
#

set -euo pipefail

# Get the state file path for a project (project-local, like ralph-wiggum)
# Usage: get_state_file_path "/path/to/project"
get_state_file_path() {
    local project_path="$1"
    # Store in project's .claude directory (like ralph-wiggum does)
    echo "$project_path/.claude/autonomous-loop.json"
}

# Generate a random 4-digit verification code (OS-agnostic)
generate_verification_code() {
    if command -v shuf &> /dev/null; then
        shuf -i 1000-9999 -n 1
    else
        echo $((RANDOM % 9000 + 1000))
    fi
}

# Generate a random session token
generate_session_token() {
    if command -v openssl &> /dev/null; then
        openssl rand -hex 8
    elif [[ -r /dev/urandom ]]; then
        head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 16
    else
        # Fallback: use date + random
        echo "$(date +%s%N)$RANDOM" | shasum -a 256 | cut -c1-16
    fi
}

# Read state file for a project, returns empty string if missing/invalid
# Usage: state=$(read_state_file "/path/to/project")
read_state_file() {
    local project_path="$1"
    local state_file=$(get_state_file_path "$project_path")

    if [[ ! -f "$state_file" ]]; then
        echo ""
        return 0
    fi

    # Validate JSON before returning
    if jq -e . "$state_file" > /dev/null 2>&1; then
        cat "$state_file"
    else
        echo ""
    fi
}

# Write state to file for a project
# Usage: write_state_file "/path/to/project" '{"active":true}'
write_state_file() {
    local project_path="$1"
    local state="$2"
    local state_file=$(get_state_file_path "$project_path")

    # Ensure .claude directory exists in project
    mkdir -p "$(dirname "$state_file")"
    echo "$state" > "$state_file"
}

# Update a single field in state file
# Usage: update_state_field "/path/to/project" ".iteration" "5"
update_state_field() {
    local project_path="$1"
    local field="$2"
    local value="$3"
    local state_file=$(get_state_file_path "$project_path")

    # Ensure .claude directory exists
    mkdir -p "$(dirname "$state_file")"

    if [[ ! -f "$state_file" ]]; then
        echo "{}" > "$state_file"
    fi

    local tmp_file=$(mktemp)
    jq "$field = $value" "$state_file" > "$tmp_file" && mv "$tmp_file" "$state_file"
}

# Delete state file for a project
# Usage: delete_state_file "/path/to/project"
delete_state_file() {
    local project_path="$1"
    local state_file=$(get_state_file_path "$project_path")
    rm -f "$state_file"
}

# Check if loop mode is active for a project
# Usage: if is_loop_active "/path/to/project"; then ...
is_loop_active() {
    local project_path="$1"
    local state=$(read_state_file "$project_path")

    if [[ -z "$state" ]]; then
        return 1
    fi

    local active=$(echo "$state" | jq -r '.active // false')
    [[ "$active" == "true" ]]
}

# Initialize a new loop state for a project
# Usage: initialize_loop_state "/path/to/project" "goal description" max_iterations
initialize_loop_state() {
    local project_path="$1"
    local goal="$2"
    local max_iterations="${3:-100}"

    local session_token=$(generate_session_token)
    local started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local state=$(jq -n \
        --arg active "true" \
        --arg token "$session_token" \
        --arg path "$project_path" \
        --arg goal "$goal" \
        --arg started "$started_at" \
        --argjson iter 0 \
        --argjson max "$max_iterations" \
        --arg paused "false" \
        --arg verification_pending "false" \
        --argjson verification_attempts 0 \
        --argjson last_verified 0 \
        '{
            active: ($active == "true"),
            session_token: $token,
            project_path: $path,
            goal: $goal,
            started_at: $started,
            iteration: $iter,
            max_iterations: $max,
            paused: ($paused == "true"),
            verification_pending: ($verification_pending == "true"),
            verification_attempts: $verification_attempts,
            last_verified_iteration: $last_verified
        }')

    write_state_file "$project_path" "$state"
}
