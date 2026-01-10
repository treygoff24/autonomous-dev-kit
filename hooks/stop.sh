#!/usr/bin/env bash
#
# Stop Hook: Minimal stub (Claude Code 2.1+ required)
#
# This script always approves exit. Completion enforcement is handled by
# prompt-based Stop hooks in skill/agent frontmatter, which require Claude
# Code 2.1+.
#
# Users on Claude Code <2.1 will not have completion enforcement.
# Upgrade to 2.1+ for full autonomous loop functionality.
#

set -euo pipefail

# Read input from stdin (Claude Code sends JSON)
INPUT=$(cat)

# Always approve exit - prompt-based hooks handle the logic in 2.1+
# No JSON output = approve
exit 0
