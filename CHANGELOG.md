# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-01-07

### Added

- **Ticket Builder parallel workflow**
  - `ticket-builder` agent and skill for executing single plan tasks in isolated worktrees
  - Parallel task metadata (`Parallel`, `Blocked by`, `Owned files`) guidance
  - Worktree-based workflow example in `docs/WORKFLOW_REFERENCE.md`
- **Installer update prompts**
  - Update-all/none/individual prompts for skills and agents
  - Non-interactive detection to skip prompts in CI

### Changed

- **Writing plans guidance**
  - Owned files validation script for parallel work
  - Execution handoff updated for ticket-builder
- **Documentation**
  - Added ticket-builder references across README and getting started materials

---

## [1.1.0] - 2025-01-05

### Added

- **Autonomous Loop Mode** — Persistent development loops that keep Claude working until completion
  - Stop hook (`hooks/stop.sh`) intercepts exit attempts and enforces completion criteria
  - Continuation prompts inject protocol cheatsheet on every iteration
  - Protocol re-read verification every 3 iterations to prevent drift
  - Max iterations (default 100) with automatic pause for human check-in
  - Per-project state files in `~/.claude/autonomous-loop/`

- **Loop activation skill** (`skills/autonomous-loop/`)
  - `/autonomous-loop "goal"` command for explicit activation
  - Interactive activation via "go autonomous" or similar phrases
  - Configurable max iterations with `--max N` flag

- **Safety net layer** (always active, even without loop mode)
  - Blocks exit on dirty git state
  - Runs quality gates if `.claude-quality-gates` file exists
  - Non-blocking for non-git directories

- **Quality gates file** (`.claude-quality-gates`)
  - Optional per-project file listing commands that must pass
  - Each line is a shell command that must exit 0
  - Example: `npm run typecheck`, `npm run lint`, `npm run test`

- **Helper library** (`hooks/lib/loop-helpers.sh`)
  - State file management functions
  - Verification code generation
  - Project hash calculation for state isolation

- **Protocol cheatsheet** (`hooks/lib/cheatsheet.md`)
  - Condensed protocol summary injected on each iteration
  - Covers implementation loop, checkpoints, subagents, skills

- **Test suites**
  - 26 unit tests for loop helpers
  - 11 tests for stop hook behavior
  - 6 integration tests for full loop lifecycle

### Changed

- **Installer** (`install.sh`)
  - Now installs Stop hook alongside PreCompact and SessionStart
  - Creates `~/.claude/lib/` and `~/.claude/autonomous-loop/` directories
  - Installs loop-helpers.sh and cheatsheet.md
  - Added detection for new files and hooks
  - Robust upgrade path for existing users (single-object hook normalization, legacy file cleanup with backup)

- **Documentation**
  - README.md: Added Autonomous Loop Mode section, updated directory structure
  - GETTING_STARTED.md: Added autonomous loop as recommended build option
  - WORKFLOW_REFERENCE.md: Added complete Autonomous Loop Mode reference and troubleshooting

### Fixed

- Installer now handles edge cases for upgrading from older versions
  - Single-object hook formats normalized to arrays
  - Legacy `autonomous-loop.md` skill file backed up and migrated to directory format
  - Malformed `.hooks` key in settings.json handled gracefully

---

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
