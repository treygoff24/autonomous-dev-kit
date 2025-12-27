# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-15

### Added

- Initial release of autonomous-dev-kit
- **Install script** (`install.sh`) for one-command setup
  - OS detection (macOS/Linux)
  - CLI tool installation (fd, fzf, bat, delta, zoxide, jq, yq, sd, ripgrep)
  - Claude Code CLI installation
  - Shell configuration with aliases and functions
  - API key setup guidance
  - Dry-run mode for previewing changes

- **Protocol templates**
  - `AUTONOMOUS_BUILD_CLAUDE_v2.md` - Claude-primary autonomous build protocol
  - `AUTONOMOUS_BUILD_CODEX_v2.md` - Codex-primary autonomous build protocol
  - `SPEC_WRITING.md` - Guide for writing specifications
  - `IMPLEMENTATION_PLAN_WRITING.md` - Guide for creating phased plans
  - `CONTEXT_TEMPLATE.md` - Template for context preservation
  - `SPEC_QUALITY_CHECKLIST.md` - Validation checklist for specs
  - `ACCESSIBILITY_CHECKLIST.md` - A11y checks for UI components
  - `LEARNINGS.md` - Learning accumulator template
  - `CLAUDE.md` - Global Claude instructions template

- **Shell configuration**
  - `aliases.zsh` - CLI tool and git aliases
  - `functions.zsh` - Helper functions for autonomous builds
    - `autonomous-init` - Initialize project for autonomous builds
    - `autonomous-status` - Show current build status
    - `quality-gates` - Run all quality checks
    - `claude-review` - Request Claude code review
    - `codex-review` - Request Codex code review
    - `slop-check` - Grep for AI-generated cruft
    - Git commit helpers

- **Documentation**
  - `README.md` - Philosophy, workflow overview, quick start
  - `docs/GETTING_STARTED.md` - Step-by-step first project guide
  - `docs/WORKFLOW_REFERENCE.md` - Complete workflow details
  - `docs/TROUBLESHOOTING.md` - Common issues and fixes

- **Worked example**
  - `examples/todo-app/` - Complete React + TypeScript todo app
    - Full spec, implementation plan, context, learnings, build log
    - Working source code demonstrating post-slop-removal quality
    - Unit tests for storage utilities

### Notes

This is the initial release, built using the autonomous build methodology it documents. The entire kit was created in a single autonomous build session.
