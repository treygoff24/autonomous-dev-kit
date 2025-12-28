#!/usr/bin/env bash
#
# Pre-Compact Hook: Auto-generate handoff before context compaction
# Saves state to thoughts/handoffs/ (project) or ~/.claude/handoffs/ (global)
#

set -euo pipefail

# Read input from stdin (Claude Code sends JSON)
INPUT=$(cat)

# Determine output location based on whether we're in a project
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]] && [[ -d "$CLAUDE_PROJECT_DIR" ]]; then
    HANDOFF_DIR="$CLAUDE_PROJECT_DIR/thoughts/handoffs"
    CONTEXT_FILE="$CLAUDE_PROJECT_DIR/CONTEXT.md"
    PROJECT_NAME=$(basename "$CLAUDE_PROJECT_DIR")
else
    HANDOFF_DIR="$HOME/.claude/handoffs"
    CONTEXT_FILE=""
    PROJECT_NAME="global"
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HANDOFF_FILE="$HANDOFF_DIR/auto-handoff-$TIMESTAMP.md"

# Create directory if needed
mkdir -p "$HANDOFF_DIR"

# Gather git info if in a repo
GIT_INFO=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
    GIT_STATUS=$(git status --short 2>/dev/null | head -20 || echo "")
    GIT_RECENT=$(git log --oneline -5 2>/dev/null || echo "")

    GIT_INFO="## Git State

**Branch:** \`$GIT_BRANCH\`
"
    if [[ -n "$GIT_STATUS" ]]; then
        GIT_INFO="$GIT_INFO
**Uncommitted Changes:**
\`\`\`
$GIT_STATUS
\`\`\`
"
    fi

    if [[ -n "$GIT_RECENT" ]]; then
        GIT_INFO="$GIT_INFO
**Recent Commits:**
\`\`\`
$GIT_RECENT
\`\`\`
"
    fi
fi

# Build the handoff content
{
    echo "# Auto-Handoff — $TIMESTAMP"
    echo ""
    echo "**Project:** $PROJECT_NAME"
    echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "---"
    echo ""

    # Include CONTEXT.md if it exists
    if [[ -n "$CONTEXT_FILE" ]] && [[ -f "$CONTEXT_FILE" ]]; then
        echo "## Current Context"
        echo ""
        head -200 "$CONTEXT_FILE"
        echo ""
        echo "---"
        echo ""
    fi

    # Include git state
    if [[ -n "$GIT_INFO" ]]; then
        echo "$GIT_INFO"
        echo "---"
        echo ""
    fi

    echo "## Resume Instructions"
    echo ""
    echo "1. Re-read this handoff"
    echo "2. Re-read CONTEXT.md if it exists"
    echo "3. Check the implementation plan for current phase"
    echo "4. Continue from where you left off"
    echo ""
    echo "*Auto-generated before context compaction.*"

} > "$HANDOFF_FILE"

# Exit 0 = success, hook continues normally
# Print message to stderr so user sees it (stdout would go to transcript in some modes)
echo "Auto-handoff saved: $HANDOFF_FILE" >&2

exit 0
