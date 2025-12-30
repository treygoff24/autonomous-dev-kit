#!/usr/bin/env bash
#
# Session-Start Hook: Inject context after /clear or compaction
# Loads latest handoff + recent learnings into Claude's context
#
# OUTPUT FORMAT: For SessionStart, stdout is added to context.
# Can be plain text OR JSON with hookSpecificOutput.additionalContext
#

set -euo pipefail

# Read input from stdin
INPUT=$(cat)

# Determine locations
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]] && [[ -d "$CLAUDE_PROJECT_DIR" ]]; then
    HANDOFF_DIR="$CLAUDE_PROJECT_DIR/thoughts/handoffs"
    PROJECT_LEARNINGS="$CLAUDE_PROJECT_DIR/LEARNINGS.md"
else
    HANDOFF_DIR="$HOME/.claude/handoffs"
    PROJECT_LEARNINGS=""
fi

GLOBAL_LEARNINGS="$HOME/.claude/learnings/LEARNINGS.md"

# Build context string
CONTEXT=""

# 1. Find and include most recent handoff (if < 48 hours old)
if [[ -d "$HANDOFF_DIR" ]]; then
    LATEST_HANDOFF=$(ls -t "$HANDOFF_DIR"/*.md 2>/dev/null | head -1 || echo "")

    if [[ -n "$LATEST_HANDOFF" ]] && [[ -f "$LATEST_HANDOFF" ]]; then
        # Get file age in hours (works on both macOS and Linux)
        if [[ "$(uname)" == "Darwin" ]]; then
            FILE_TIME=$(stat -f %m "$LATEST_HANDOFF")
        else
            FILE_TIME=$(stat -c %Y "$LATEST_HANDOFF")
        fi
        NOW=$(date +%s)
        AGE_HOURS=$(( (NOW - FILE_TIME) / 3600 ))

        if [[ $AGE_HOURS -lt 48 ]]; then
            HANDOFF_CONTENT=$(head -150 "$LATEST_HANDOFF")
            CONTEXT="## Latest Handoff

$(basename "$LATEST_HANDOFF")

$HANDOFF_CONTENT

---

"
        fi
    fi
fi

# 2. Include recent learnings (last 50 lines from each file)
LEARNINGS=""

if [[ -n "$PROJECT_LEARNINGS" ]] && [[ -f "$PROJECT_LEARNINGS" ]]; then
    PROJECT_RECENT=$(tail -50 "$PROJECT_LEARNINGS" 2>/dev/null || echo "")
    if [[ -n "$PROJECT_RECENT" ]]; then
        LEARNINGS="### Project Learnings

$PROJECT_RECENT

"
    fi
fi

if [[ -f "$GLOBAL_LEARNINGS" ]]; then
    GLOBAL_RECENT=$(tail -50 "$GLOBAL_LEARNINGS" 2>/dev/null || echo "")
    if [[ -n "$GLOBAL_RECENT" ]]; then
        LEARNINGS="${LEARNINGS}### Global Learnings

$GLOBAL_RECENT
"
    fi
fi

if [[ -n "$LEARNINGS" ]]; then
    CONTEXT="${CONTEXT}## Recent Learnings

$LEARNINGS
---

"
fi

# 3. Add session resume reminder
CONTEXT="${CONTEXT}## Session Resumed

Context was restored automatically. If anything feels stale:
- Re-read CONTEXT.md for current state
- Re-read AUTONOMOUS_BUILD_CLAUDE.md for the full protocol
- Check IMPLEMENTATION_PLAN.md for current phase

Continue from where you left off."

# Output using JSON format for reliable context injection
# The hookSpecificOutput.additionalContext field is added to Claude's context
if [[ -n "$CONTEXT" ]]; then
    # Use jq to properly escape the context string
    jq -n --arg ctx "$CONTEXT" '{
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": $ctx
        }
    }'
else
    echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Session resumed."}}'
fi

exit 0
