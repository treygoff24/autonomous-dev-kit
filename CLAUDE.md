# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Your Role: Orchestrator, Not Implementer

**You are not a solo developer—you are an orchestrator coordinating specialized skills, subagents, and external AIs.**

**Skills are your primary interface.** Most skills spawn subagents under the hood—you don't need to manage that directly. When you invoke `/debugging-systematic`, it spawns the `debugger` agent. When you invoke `/writing-plans`, it handles the planning workflow. Skills encapsulate the complexity.

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
| Is there a subagent for this? | Spawn it via Task tool (e.g., `debugger`, `tdd-implementer`) |
| Would Codex/Gemini catch what I'd miss? | Call `/codex` or `/gemini` |
| Is this a simple 1-3 line fix? | Do it directly |

**Skills are the preferred path.** They handle context, spawn appropriate subagents, and manage the workflow. Direct Task tool usage is for when you need fine-grained control.

### The Orchestration Mindset

**Wrong:** "I'll implement this feature, then maybe get a review."
**Right:** "I'll spawn `plan-executor` to implement this, `code-reviewer` to review, and `/codex` for a second opinion."

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
├── shell/              # Shell aliases and functions
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
3. `install_cli_tools` — fd, fzf, bat, delta, zoxide, jq, yq, sd, ripgrep
4. `check_nodejs` — Installs Node.js via brew if missing, validates version 18+
5. `install_claude_code` — `npm install -g @anthropic-ai/claude-code`
6. `backup_shell_config` / `install_shell_config` — Adds aliases and sources functions.zsh
7. `setup_claude_directory` — Creates ~/.claude/ with subdirectories and installs hooks
8. `configure_hooks` — Adds hook configuration to ~/.claude/settings.json
9. `verify_installation` — Checks all tools installed correctly

Uses `set -euo pipefail` and supports `--dry-run` mode.

## Hooks

The installer sets up Claude Code hooks for continuity and autonomous loop behavior:

- **pre-compact.sh** — Runs before context compaction, saves handoff with git state and CONTEXT.md
- **session-start.sh** — Runs after compaction or `/clear`, injects latest handoff + learnings into context
- **user-prompt-submit.sh** — Injects a short protocol anchor when autonomous loop mode is active
- **stop.sh** — Legacy stub for Claude Code <2.1 (see Stop Hooks below)

Handoffs are saved to:
- `$PROJECT/thoughts/handoffs/` when in a project
- `~/.claude/handoffs/` globally

Only handoffs < 48 hours old are auto-injected to prevent stale context.

### Stop Hooks (Claude Code 2.1+)

For Claude Code 2.1+, completion enforcement uses **prompt-based Stop hooks** in skill/agent frontmatter instead of shell scripts. This lets a Sonnet model intelligently evaluate whether work is truly complete.

- **autonomous-loop skill** — Stop hook verifies: git clean, quality gates pass, plan tasks complete, no half-done work
- **tdd-implementer agent** — Stop hook verifies: TDD discipline followed, tests pass, no violations
- **debugger agent** — Stop hook verifies: root cause identified with evidence, fix verified
- **plan-executor agent** — Stop hook verifies: all tasks complete, quality gates between tasks, code review done

**Note:** Claude Code <2.1 does not support prompt-based hooks. Users on older versions will have reduced autonomous loop enforcement. Upgrade to Claude Code 2.1+ for full completion verification.

## Agents, Skills, and Rules

The kit organizes Claude's capabilities in three layers:

**Agents** (`agents/` → `~/.claude/agents/`): Run in isolated context windows, can run in parallel.
- `debugger` — Systematic debugging with root cause analysis
- `tdd-implementer` — Test-driven development
- `plan-executor` — Execute implementation plans task-by-task
- `ticket-builder` — Implement a single plan task in an isolated worktree
- `slop-cleaner` — Remove AI-generated cruft
- `validator` — Defense-in-depth validation
- `root-cause-tracer` — Trace bugs backward through call stack
- `parallel-investigator` — Investigate independent failures concurrently

**Skills** (`skills/` → `~/.claude/skills/`): Require conversation context and user interaction.
- `brainstorming` — Refine ideas into designs through dialogue
- `writing-plans` — Create detailed implementation plans
- `codex` — Delegate to OpenAI Codex for reviews, debugging help, second opinions
- `gemini` — Delegate to Google Gemini for reviews, debugging help, second opinions
- `ticket-builder` — Execute a single plan task in an isolated worktree
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
