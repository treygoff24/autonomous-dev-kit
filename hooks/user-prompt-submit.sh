#!/usr/bin/env bash
#
# User-Prompt-Submit Hook: Inject protocol anchor for autonomous loop prompts
# OUTPUT FORMAT: stdout is added to context via hookSpecificOutput.additionalContext
#

set -euo pipefail

# Source helper library (optional)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$HOME/.claude/lib/loop-helpers.sh" ]]; then
    source "$HOME/.claude/lib/loop-helpers.sh"
elif [[ -f "$SCRIPT_DIR/../lib/loop-helpers.sh" ]]; then
    source "$SCRIPT_DIR/../lib/loop-helpers.sh"
fi

# Read input from stdin (unused, but consumed)
INPUT=$(cat)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"

if ! declare -f is_loop_active > /dev/null 2>&1; then
    exit 0
fi

if [[ -z "$PROJECT_DIR" ]] || [[ ! -d "$PROJECT_DIR" ]]; then
    exit 0
fi

if ! is_loop_active "$PROJECT_DIR"; then
    exit 0
fi

STATE=$(read_state_file "$PROJECT_DIR")
VERIFICATION_PENDING=$(echo "$STATE" | jq -r '.verification_pending // false')

PROTOCOL_ANCHOR=$(cat << 'EOF'
## Autonomous Loop Protocol Anchor

- Follow AUTONOMOUS_BUILD_CLAUDE.md and the approved spec/plan.
- Do not stop until completion criteria are met (clean git + gates + plan).
- Update CONTEXT.md and IMPLEMENTATION_PLAN.md each phase.
- Every 3 iterations: re-read the protocol and reply with <verified code="####"/> using
  expected_verification_code from .claude/autonomous-loop.json.
EOF
)

if [[ "$VERIFICATION_PENDING" == "true" ]]; then
    PROTOCOL_ANCHOR="$PROTOCOL_ANCHOR

Verification pending: re-read AUTONOMOUS_BUILD_CLAUDE.md and use the code from .claude/autonomous-loop.json."
fi

jq -n --arg ctx "$PROTOCOL_ANCHOR" '{
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": $ctx
    }
}'

exit 0
