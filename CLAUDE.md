# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Your Role: Orchestrator, Not Implementer

**You are not a solo developer—you are an orchestrator coordinating specialized skills, agent-team workers (Claude Task subagents), and external AIs.**

**Skills are your primary interface.** Most skills spawn agent-team workers under the hood (Claude calls them subagents)—you don't need to manage that directly. When you invoke `/debugging-systematic`, it spawns the `debugger` agent. When you invoke `/writing-plans`, it handles the planning workflow. Skills encapsulate the complexity.

Your job is to:

1. **Check for a skill first** — before doing ANY non-trivial work
2. **Delegate** via the appropriate skill or tool
3. **Coordinate** parallel execution when tasks are independent
4. **Synthesize** results and manage the overall flow
5. **Handle directly** only simple, quick fixes (1-3 lines)

### Before Doing Anything, Ask:

| Question | If Yes → |
|----------|----------|
| Is there a skill for this? | Use it (e.g., `/debugging-systematic`, `/writing-plans`, `/codex`) |
| Is there an agent-team worker for this (Task subagent)? | Spawn it via Task tool (e.g., `debugger`, `tdd-implementer`) |
| Would Codex/Gemini catch what I'd miss? | Call `/codex` or `/gemini` |
| Is this a simple 1-3 line fix? | Do it directly |

**Skills are the preferred path.** They handle context, spawn appropriate agent-team workers, and manage the workflow. Direct Task tool usage is for when you need fine-grained control.

### The Orchestration Mindset

**Wrong:** "I'll implement this feature, then maybe get a review."
**Right:** "I'll spawn `task-builder` to implement this, `code-reviewer` to review, and `/codex` for a second opinion."

**Wrong:** "I'll debug this error by reading code and trying fixes."
**Right:** "I'll spawn `debugger` for disciplined root cause analysis."

**Wrong:** "I'll write all the tests after implementing."
**Right:** "I'll spawn `tdd-implementer` to drive development with tests first."

Direct implementation is the exception, not the rule. Your value is in coordination, not keystrokes.

---

## What This Is

Bootstrap repo for autonomous AI-assisted development. Contains install scripts, protocol templates, shell functions, and documentation—no application code.

## Repository Structure

```
autonomous-dev-kit/
├── install.sh          # Main installer
├── agents/             # Agent definitions (→ ~/.claude/agents/)
├── skills/             # Skill definitions (→ ~/.claude/skills/)
├── rules/              # Auto-loaded rules (→ ~/.claude/rules/)
├── hooks/              # Claude Code hooks
│   └── lib/            # Hook helper scripts (cheatsheet, loop-helpers)
├── shell/              # Shell functions
├── templates/          # Protocol templates for user projects
├── tests/              # Test scripts
├── examples/           # Worked examples
│   └── todo-app/
├── docs/
│   ├── GETTING_STARTED.md
│   ├── WORKFLOW_REFERENCE.md
│   ├── TROUBLESHOOTING.md
│   └── archive/        # Historical plans and research
└── thoughts/
    └── handoffs/       # Auto-generated session handoffs
```

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
3. `install_cli_tools` — fd, fzf, bat, delta, jq, yq, sd, ripgrep
4. `check_nodejs` — Installs Node.js via brew if missing, validates version 18+
5. `install_claude_code` — `npm install -g @anthropic-ai/claude-code`
6. `backup_shell_config` / `install_shell_config` — Sources functions.zsh and sets up direnv
7. `setup_claude_directory` — Creates ~/.claude/ with subdirectories and installs hooks
8. `configure_hooks` — Adds hook configuration to ~/.claude/settings.json
9. `verify_installation` — Checks all tools installed correctly

Uses `set -euo pipefail` and supports `--dry-run` mode.

## Hooks

The installer sets up Claude Code hooks for continuity and autonomous loop behavior:

- **pre-compact.sh** — Runs before context compaction, saves handoff with git state and CONTEXT.md
- **session-start.sh** — Runs after compaction or `/clear`, injects latest handoff + learnings into context
- **user-prompt-submit.sh** — Injects a short protocol anchor when autonomous loop mode is active
- **stop.sh** — Deterministic autonomous loop state engine (uses `.claude/autonomous-loop.json` to enforce completion criteria)

Handoffs are saved to:
- `$PROJECT/thoughts/handoffs/` when in a project
- `~/.claude/handoffs/` globally

Only handoffs < 48 hours old are auto-injected to prevent stale context.

### Stop Hook Enforcement (Claude Code 2.1+)

For Claude Code 2.1+, this kit uses a deterministic shell Stop hook (`hooks/stop.sh`) backed by `.claude/autonomous-loop.json` state.

- Verifies git is clean (excluding `.claude/`)
- Verifies task list completion when the task system is active
- Runs quality gates (`.claude-quality-gates` commands first; otherwise available npm scripts: `typecheck`, `lint`, `build`, `test`)
- Verifies scoped `IMPLEMENTATION_PLAN.md` checkboxes (phase-scoped when goal specifies a phase)
- Blocks exit (`exit 2`) until criteria are met, then clears loop state

Prompt-based Stop hooks in agent/skill frontmatter (for `tdd-implementer`, `debugger`, etc.) still provide role-specific verification.

## Task System Integration

The kit integrates with Claude Code's task management system (TaskCreate, TaskList, TaskGet, TaskUpdate) for progress tracking and parallel execution.

### Key Concepts

- **Task DAG**: Plans are parsed into task graphs with dependencies
- **Parallel Execution**: Independent tasks can run simultaneously
- **Shared Task Lists**: Multiple sessions coordinate via `CLAUDE_CODE_TASK_LIST_ID`
- **Progress Persistence**: Task state survives context compaction

### New Components

| Component | Type | Purpose |
|-----------|------|---------|
| `task-builder` | Agent + Skill | Execute single task via TaskGet/TaskUpdate |
| `swarm-coordinator` | Skill | Multi-session coordination |
| `task-helpers.sh` | Library | Safe task reading with validation |
| `statusline-task.sh` | Hook | Show task progress in status line |

### Workflow

1. Create implementation plan with `Parallel:` and `Blocked by:` fields
2. Orchestrator creates task DAG (TaskCreate + TaskUpdate for dependencies)
3. Spawn `task-builder` agents for parallel task execution
4. Each task-builder uses TaskGet/TaskUpdate for progress
5. Use `/swarm-coordinator` for multi-session work
6. Pre-compact hook captures task state for continuity

## Agents, Skills, and Rules

The kit organizes Claude's capabilities in three layers:

**Agents** (`agents/` → `~/.claude/agents/`): Run in isolated context windows, can run in parallel.
- `debugger` — Systematic debugging with root cause analysis
- `tdd-implementer` — Test-driven development
- `task-builder` — Execute a single task in isolated worktree; auto-loads domain skills (threejs, frontend-design, etc.)
- `slop-cleaner` — Remove AI-generated cruft
- `validator` — Defense-in-depth validation
- `root-cause-tracer` — Trace bugs backward through call stack
- `parallel-investigator` — Investigate independent failures concurrently

**Skills** (`skills/` → `~/.claude/skills/`): Require conversation context and user interaction.
- `orchestrator` — Activate orchestrator mode: coordinate specialists, maximize parallelism
- `task-builder` — Execute ONE task; spawn MULTIPLE in parallel for independent tasks
- `brainstorming` — Refine ideas into designs through dialogue
- `writing-plans` — Create detailed implementation plans
- `codex` — Delegate to OpenAI Codex for reviews, debugging help, second opinions
- `gemini` — Delegate to Google Gemini for reviews, debugging help, second opinions
- `using-git-worktrees` — Isolated workspaces for risky changes
- `swarm-coordinator` — Multi-session coordination via shared task list
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
- `AUTONOMOUS_BUILD_CLAUDE.md` — Main protocol for Claude-driven builds
- `AUTONOMOUS_BUILD_CODEX.md` — Protocol for Codex-driven builds
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
