# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Bootstrap repo for autonomous AI-assisted development. Contains install scripts, protocol templates, shell functions, and documentation—no application code.

## Repository Structure

- `install.sh` — Main installer (Homebrew, CLI tools, Node.js, Claude Code CLI, shell config, hooks)
- `agents/` — Custom agent definitions for isolated execution (→ `~/.claude/agents/`)
- `rules/` — Auto-loaded standards based on file patterns (→ `~/.claude/rules/`)
- `skills/` — Interactive workflows requiring conversation context (→ `~/.claude/skills/`)
- `hooks/` — Claude Code hooks for session continuity (pre-compact.sh, session-start.sh, stop.sh)
- `templates/` — Protocol documents (AUTONOMOUS_BUILD_CLAUDE_v2.md, CONTEXT_TEMPLATE.md, etc.)
- `shell/` — Shell aliases and functions (functions.zsh, aliases.zsh)
- `docs/` — User documentation (GETTING_STARTED.md, WORKFLOW_REFERENCE.md, TROUBLESHOOTING.md)
- `examples/todo-app/` — Worked example with full build cycle

## Key Commands

```bash
# Test the installer
./install.sh --dry-run

# Run the installer
./install.sh

# Shell functions (after install, source ~/.zshrc)
autonomous-init          # Initialize project for autonomous builds
autonomous-status        # Show current build status
quality-gates            # Run typecheck/lint/build/test
slop-check [path]        # Grep for AI cruft patterns
```

## Install Script Architecture

The installer (`install.sh`) runs these steps in order:
1. `detect_os` — macOS or Linux, sets SHELL_CONFIG path
2. `install_homebrew` — Installs Homebrew if missing
3. `install_cli_tools` — fd, fzf, bat, delta, zoxide, jq, yq, sd, ripgrep
4. `check_nodejs` — Installs Node.js via brew if missing, validates version 18+
5. `install_claude_code` — `npm install -g @anthropic-ai/claude-code`
6. `backup_shell_config` / `install_shell_config` — Adds aliases and sources functions.zsh
7. `setup_claude_directory` — Creates ~/.claude/ with subdirectories and installs hooks
8. `configure_hooks` — Adds hook configuration to ~/.claude/settings.json
9. `verify_installation` — Checks all tools installed correctly

Uses `set -euo pipefail` and supports `--dry-run` mode.

## Hooks

The installer sets up two Claude Code hooks for session continuity:

- **pre-compact.sh** — Runs before context compaction, saves handoff with git state and CONTEXT.md
- **session-start.sh** — Runs after compaction or `/clear`, injects latest handoff + learnings into context

Handoffs are saved to:
- `$PROJECT/thoughts/handoffs/` when in a project
- `~/.claude/handoffs/` globally

Only handoffs < 48 hours old are auto-injected to prevent stale context.

## Agents, Skills, and Rules

The kit organizes Claude's capabilities in three layers:

**Agents** (`agents/` → `~/.claude/agents/`): Run in isolated context windows, can run in parallel.
- `debugger` — Systematic debugging with root cause analysis
- `tdd-implementer` — Test-driven development
- `plan-executor` — Execute implementation plans task-by-task
- `slop-cleaner` — Remove AI-generated cruft
- `validator` — Defense-in-depth validation
- `root-cause-tracer` — Trace bugs backward through call stack
- `parallel-investigator` — Investigate independent failures concurrently

**Skills** (`skills/` → `~/.claude/skills/`): Require conversation context and user interaction.
- `brainstorming` — Refine ideas into designs through dialogue
- `writing-plans` — Create detailed implementation plans
- `using-git-worktrees` — Isolated workspaces for risky changes
- `finishing-a-development-branch` — Clean up for merge/PR
- `requesting-code-review` / `receiving-code-review` — Code review workflow
- `spec-quality-checklist` / `accessibility-checklist` — Validation checklists
- `autonomous-loop` — Activate autonomous loop mode

**Rules** (`rules/` → `~/.claude/rules/`): Auto-loaded based on file patterns. No invocation needed.
- `testing-standards.md` — Anti-patterns, TDD, condition-based waiting
- `verification-standards.md` — Evidence before claims
- `code-quality.md` — Slop patterns, commit hygiene

## Template Files

Templates are copied to user projects via `autonomous-init`. Key ones:
- `AUTONOMOUS_BUILD_CLAUDE_v2.md` — Main protocol for Claude-driven builds
- `AUTONOMOUS_BUILD_CODEX_v2.md` — Protocol for Codex-driven builds
- `CONTEXT_TEMPLATE.md` — Context preservation across sessions

## Shell Functions

`shell/functions.zsh` provides the helper commands. Each function has `--help` support. The functions assume:
- Templates are in `~/Code/autonomous-dev-kit/templates/` or similar paths
- Node.js projects with npm scripts for typecheck/lint/build/test
- Git is initialized in the project

## Making Changes

When editing the installer or shell functions:
- Test with `--dry-run` before running live
- The installer backs up shell configs before modifying
- Shell functions are idempotent (check before creating files)
