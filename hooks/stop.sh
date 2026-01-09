#!/usr/bin/env bash
#
# Stop Hook: Legacy shell-based hook (DEPRECATED)
#
# As of Claude Code 2.1+, Stop hooks should be defined as prompt-based hooks
# in skill/agent frontmatter. This shell script is kept only for backward
# compatibility with Claude Code <2.1.
#
# For 2.1+ users:
# - autonomous-loop skill has a prompt-based Stop hook that enforces completion
# - Individual agents (tdd-implementer, debugger, plan-executor) have their own
#   Stop hooks that verify discipline was followed
#
# This stub simply approves exit. The intelligent completion checking is done
# by the Sonnet model in prompt-based hooks.
#

set -euo pipefail

# Read input from stdin (Claude Code sends JSON)
INPUT=$(cat)

# Always approve exit - prompt-based hooks handle the logic in 2.1+
# No JSON output = approve
exit 0
