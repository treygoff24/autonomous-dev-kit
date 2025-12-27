# Getting Started

This guide walks you through your first autonomous AI-assisted build, from zero to deployed feature.

---

## Prerequisites

Before starting, verify you have:

### Required

| Requirement | Check Command | Expected Output |
|-------------|---------------|-----------------|
| Node.js 18+ | `node -v` | `v18.x.x` or higher |
| npm | `npm -v` | Any version |
| Git | `git --version` | Any version |
| Homebrew (macOS) | `brew --version` | Any version |

### API Keys

You'll need accounts and API keys for:

1. **Anthropic** — Get from [console.anthropic.com](https://console.anthropic.com/)
2. **OpenAI** — Get from [platform.openai.com](https://platform.openai.com/)

Save these as environment variables in your shell config (`~/.zshrc` or `~/.bashrc`):

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
```

---

## Installation

### Step 1: Clone and Install

```bash
# Clone the repo
git clone https://github.com/yourusername/autonomous-dev-kit.git
cd autonomous-dev-kit

# Run the installer
./install.sh
```

The installer will:
- Install CLI tools (fd, fzf, bat, ripgrep, etc.)
- Install Claude Code CLI
- Configure shell aliases
- Create `~/.claude/` directory
- Copy templates to the right locations

### Step 2: Restart Your Terminal

```bash
# Or source your config directly
source ~/.zshrc
```

### Step 3: Verify Installation

```bash
# Check Claude Code is installed
claude --version

# Check CLI tools
fd --version
bat --version
rg --version

# Check the autonomous-init function
autonomous-init --help
```

If anything is missing, run `./install.sh` again or install manually via `brew install <tool>`.

---

## Your First Build

Let's build something simple: a command-line task manager. This will teach you the full workflow.

### Step 1: Create Your Project

```bash
mkdir my-task-cli
cd my-task-cli
git init
```

### Step 2: Initialize for Autonomous Builds

```bash
autonomous-init
```

This creates:
- `CONTEXT.md` — Your context preservation file
- `CLAUDE.md` — Project-specific Claude instructions
- `LEARNINGS.md` — For accumulating insights

### Step 3: Write the Spec

Create `SPEC.md` with your requirements. Use the SPEC_WRITING template as guidance:

```bash
# Read the spec writing guide first
cat ~/.claude/autonomous-dev-kit/templates/SPEC_WRITING.md

# Then create your spec
code SPEC.md
```

For this example, your spec might include:

```markdown
# Task CLI Specification

## Problem Statement
I need a command-line tool to manage tasks from my terminal.

## Scope
In scope:
- Add tasks with description
- List all tasks
- Mark tasks complete
- Delete tasks
- Persist tasks to a JSON file

Out of scope:
- Due dates
- Categories/tags
- Cloud sync

## User Stories
- As a developer, I want to add a task so I can track what needs doing
- As a developer, I want to list tasks so I can see what's pending
- As a developer, I want to mark tasks complete so I can track progress

## Technical Approach
- Node.js CLI using Commander.js
- Tasks stored in ~/.tasks.json
- TypeScript for type safety

## Data Model
Task:
- id: string (UUID)
- description: string
- completed: boolean
- createdAt: string (ISO date)

## Commands
- `task add "description"` — Add a new task
- `task list` — List all tasks
- `task done <id>` — Mark task complete
- `task delete <id>` — Delete task

## Acceptance Criteria
- [ ] `task add "test"` creates a task and shows confirmation
- [ ] `task list` shows all tasks with completion status
- [ ] `task done <id>` marks the task complete
- [ ] `task delete <id>` removes the task
- [ ] Tasks persist across sessions
- [ ] Clear error messages for invalid operations
```

### Step 4: Get the Spec Reviewed

```bash
claude-review 'SPEC.md review'
```

Or manually:

```bash
claude -p --model opus --dangerously-skip-permissions --output-format text \
  "Review the specification at SPEC.md. Evaluate for: completeness, clarity, technical feasibility, edge cases, and testable acceptance criteria. Output: Critical gaps / Ambiguities / Suggestions / Verdict (approve or revise)."
```

Fix any issues Claude identifies, then repeat until approved.

### Step 5: Create the Implementation Plan

```bash
# Read the planning guide
cat ~/.claude/autonomous-dev-kit/templates/IMPLEMENTATION_PLAN_WRITING.md

# Create your plan
code IMPLEMENTATION_PLAN.md
```

Break the work into phases:

```markdown
# Implementation Plan: Task CLI

## Current Status
**Phase**: 0 - Not Started
**Working on**: N/A
**Blockers**: None

## Phase 1: Project Setup
**Objective:** Initialize Node.js project with TypeScript and Commander.js

**Tasks:**
- npm init
- Install TypeScript, Commander.js, uuid
- Configure tsconfig.json
- Create src/ directory structure
- Create placeholder index.ts

**Acceptance:** `npm run build` succeeds

## Phase 2: Data Layer
**Objective:** Implement task storage and retrieval

**Tasks:**
- Create Task type definition
- Implement loadTasks() and saveTasks()
- Add file path configuration
- Write unit tests for data functions

**Acceptance:** Tests pass for load/save operations

## Phase 3: Commands
**Objective:** Implement all CLI commands

**Tasks:**
- Implement add command
- Implement list command
- Implement done command
- Implement delete command
- Add error handling

**Acceptance:** All commands work as specified

## Phase 4: Polish
**Objective:** Error handling, help text, final testing

**Tasks:**
- Add --help for all commands
- Improve error messages
- Test edge cases
- Update README

**Acceptance:** All acceptance criteria from spec pass
```

### Step 6: Get the Plan Reviewed

```bash
claude -p --model opus --dangerously-skip-permissions --output-format text \
  "Review IMPLEMENTATION_PLAN.md against SPEC.md. Check for: correct sequencing, completeness, phase sizing, and risk identification. Output: Issues / Suggestions / Verdict (approve or revise)."
```

### Step 7: Start the Autonomous Build

Now for the magic. Tell Claude to build it:

```bash
claude "Read AUTONOMOUS_BUILD_CLAUDE_v2.md and the spec at SPEC.md. Build autonomously. Do not stop until complete."
```

Or if you have the protocol locally:

```bash
claude "Read the autonomous build protocol and spec. Execute all phases. Call Codex at checkpoints. Ship it."
```

### Step 8: Monitor Progress

Claude will:
1. Read your spec and plan
2. Execute each phase
3. Run quality gates
4. Call Codex for reviews at checkpoints
5. Commit after each phase
6. Continue until complete

You can:
- Watch the terminal for progress
- Check `CONTEXT.md` for current state
- Run `autonomous-status` to see progress
- Interrupt with Ctrl+C if something goes wrong

### Step 9: Verify the Build

When Claude declares complete:

```bash
# Run quality gates
quality-gates

# Test the CLI manually
npm link
task add "Test my new CLI"
task list
task done <id>

# Check the final code
git log --oneline
```

### Step 10: Capture Learnings

After the build, add to `LEARNINGS.md`:

```markdown
## 2024-01-15 — Task CLI

**What Worked:**
- Spec was detailed enough that Claude didn't need clarification
- Breaking into 4 phases kept each phase manageable

**What Failed:**
- Initially forgot to specify error handling in spec

**Patterns:**
- Always specify error scenarios in the spec
- 4-5 phases seems optimal for this size project
```

---

## What to Expect

### First-Time Builds

- **Duration:** 30-90 minutes for a simple feature
- **Interruptions:** Claude may ask clarifying questions
- **Iterations:** Expect 1-2 review cycles per phase

### Common First-Timer Mistakes

| Mistake | Fix |
|---------|-----|
| Vague spec ("make it user-friendly") | Use precise, testable language |
| Giant phases | Break into 30-60 minute chunks |
| Skipping reviews | Always run cross-agent reviews |
| Not updating CONTEXT.md | Update at least twice per phase |
| No error cases in spec | Define what happens when things fail |

### You'll Know It's Working When

- Claude reads the spec without asking many questions
- Each phase completes with passing quality gates
- Reviews come back with "approve" verdicts
- The final product matches the spec
- You have a clean git history with semantic commits

---

## Next Steps

1. **Study the example** — Check `examples/todo-app/` for a complete worked example
2. **Read the workflow reference** — See `docs/WORKFLOW_REFERENCE.md` for complete details
3. **Build something real** — Pick a feature you've been putting off
4. **Customize your setup** — Adjust templates and shell functions to your preferences

---

## Getting Help

- **Stuck during build?** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Workflow questions?** See [WORKFLOW_REFERENCE.md](WORKFLOW_REFERENCE.md)
- **Template questions?** Check the template files in `templates/`

Happy building!
