# autonomous-dev-kit

> A bootstrap repo for autonomous AI-assisted development with Claude Code and Codex CLI.

This kit turns Claude Code + Codex into a ready-to-run autonomous build stack, wiring in the protocols, context handling, and quality gates so agents can ship features with minimal hand-holding. Use it if you want fast, high-signal cycles from idea → spec → plan → implementation without rewriting prompts every time.

- `install.sh` installs CLI essentials, Claude Code CLI, and writes shell aliases/functions that drive the autonomous workflow. skips anything you already have installed, gives you options to pick and choose what to install.
- Seeds Claude Code skills, templates, and checklists so agents follow opinionated protocols instead of ad-hoc prompting.
- Installs Claude Code hooks (pre-compact, session-start, stop) to keep context synced, quality gates enforced, and enable autonomous loop mode.
- Ships helper commands (`autonomous-init`, `quality-gates`, `claude-review`, `codex-review`, etc.) that keep sessions on-rails.
- Includes a worked example app that demonstrates the full spec → plan → build → test loop.

---

## What This Is

This kit provides everything you need to build complete applications using AI agents as development partners. Instead of treating AI as a fancy autocomplete, this system treats Claude and Codex as autonomous agents capable of executing multi-phase builds with minimal human intervention.

**The core idea:** Structured protocols beat ad-hoc prompting. When you give AI agents clear methodology, context management, and quality gates, they can build complete features—or entire applications—in single sessions.

This isn't about replacing developers. It's about removing the friction between "I know what I want to build" and "it's built, tested, and deployed."

---

## How It Works

### The Problems

AI coding assistants are powerful but frustrating out of the box:

1. **Context amnesia** — Every time the context window fills up or you start a new session, the AI forgets everything. You re-explain the project, the decisions, where you left off. Multiply this across a multi-day build and you've wasted hours on context restoration.

2. **Ad-hoc prompting** — Without structure, you get inconsistent results. The AI might write tests one time and skip them the next. It might follow your coding standards or hallucinate new ones. You end up micromanaging instead of building.

3. **No quality enforcement** — AI will confidently ship broken code. Unless you explicitly run typecheck, lint, build, and test after every change, errors compound. By the time you notice, you're debugging a mess.

4. **Session fragmentation** — Real features take multiple sessions. Without explicit handoffs, you lose momentum. What was the architectural decision from yesterday? Why did you choose that approach? Gone.

5. **Single-agent limitations** — One AI has blind spots. It gets stuck in loops, misses edge cases, or over-engineers simple things. No external check means no course correction.

### The Solutions

This kit solves each problem with a specific mechanism:

| Problem | Solution | Implementation |
|---------|----------|----------------|
| Context amnesia | Auto-handoffs + session injection | `pre-compact.sh` saves state before compaction; `session-start.sh` restores it |
| Ad-hoc prompting | Battle-tested protocols | Templates define exactly how to write specs, plans, and execute phases |
| No quality enforcement | Mandatory quality gates | `stop.sh` blocks completion until typecheck/lint/build/test pass |
| Session fragmentation | Living context file | `CONTEXT.md` is updated each phase with decisions, hook signatures, next steps |
| Single-agent limitations | Cross-agent review | Claude and Codex review each other at checkpoints |

### The Mechanics

**Hooks** intercept Claude Code events to enforce workflow:
- `pre-compact.sh` — Fires before context compaction, dumps git state + CONTEXT.md to a handoff file
- `session-start.sh` — Fires on new session, injects recent handoffs + learnings into context
- `stop.sh` — Fires on exit attempt, blocks if work is incomplete, enables autonomous loop mode

**Templates** encode methodology:
- `AUTONOMOUS_BUILD_CLAUDE_v2.md` — The master protocol: how to move through spec → plan → build → verify
- `CONTEXT_TEMPLATE.md` — What to track: current phase, hook signatures, import locations, decisions
- `SPEC_WRITING.md` / `IMPLEMENTATION_PLAN_WRITING.md` — How to write docs that agents can execute

**Skills** provide reusable workflows:
- Brainstorming, plan writing, TDD, debugging, code review — each is a documented process the agent follows
- Installed to `~/.claude/skills/` and invoked via slash commands

**Shell functions** keep you in the loop:
- `autonomous-init` seeds a project with templates
- `quality-gates` runs the full check suite
- `slop-check` greps for AI-generated cruft patterns

### The Result

Instead of:
```
You: "Build a todo app"
AI: [writes random code]
You: "Wait, run the tests"
AI: [tests fail]
You: "Fix the tests"
AI: [fixes one, breaks another]
You: [repeat for hours]
```

You get:
```
You: "Read the spec and go autonomous"
AI: [activates loop mode]
AI: [Phase 1: implement → typecheck → lint → build → test → commit]
AI: [Phase 2: implement → typecheck → lint → build → test → commit]
...
AI: [All phases complete, quality gates pass, PR ready]
```

The difference is structure. Same AI, same capabilities—but now it follows a methodology that catches errors early, preserves context, and ships clean code.

---

## Maximum Autonomy Warning

This kit is configured for maximum autonomy. Command examples and helpers intentionally use `--dangerously-skip-permissions` (Claude) and `--yolo` (Codex), which bypass safety prompts and allow tools to run without confirmation.

Use this setup only in trusted repositories and isolated environments. Review diffs before committing, avoid running against production systems, and remove those flags if you want approval gates.

---

## Philosophy

### Protocols Over Prompts

Ad-hoc prompting produces ad-hoc results. This system uses battle-tested protocols for:

- **Spec writing** — Turn vague ideas into unambiguous requirements
- **Implementation planning** — Break specs into phased, testable chunks
- **Autonomous execution** — Run through phases with quality gates
- **Context preservation** — Maintain state across sessions and context windows
- **Cross-agent review** — Claude and Codex review each other's work

### AI Agents as Partners

Claude excels at architecture, multi-file coordination, and catching subtle issues. Codex excels at focused implementation and security analysis. This system uses both, calling each at specific checkpoints for dual review.

### Quality Over Speed

Every phase runs through quality gates (typecheck, lint, build, test) before review. Every commit is clean. Slop is removed before it accumulates. The result: production-ready code, not demo-ware.

---

## The Workflow

```
IDEA → SPEC → PLAN → BUILD → DEPLOY
         ↓      ↓       ↓
       Review  Review  Review (after each phase)
```

1. **Write a spec** — Define what you're building using the SPEC_WRITING template
2. **Get spec reviewed** — Cross-agent review catches gaps before you start coding
3. **Create implementation plan** — Break the spec into phases with clear acceptance criteria
4. **Get plan reviewed** — Validate sequencing and dependencies
5. **Execute phases** — Each phase: implement → quality gates → review → commit
6. **Final verification** — Run the full quality suite, manual verification, cross-check
7. **Ship it** — Push, open PR, deploy

---

## Quick Start

### Prerequisites

- **macOS or Linux** (Windows WSL works too)
- **Node.js 18+** and npm
- **Homebrew** (macOS) or **apt** (Linux)
- **API keys** for Claude (Anthropic) and OpenAI (for Codex)

### Install

```bash
git clone https://github.com/yourusername/autonomous-dev-kit.git
cd autonomous-dev-kit
./install.sh
```

The install script will:

- Install CLI tools (fd, fzf, bat, ripgrep, etc.)
- Install Claude Code CLI
- Set up shell aliases and functions
- Create `~/.claude/` for global config
- Walk you through API key setup

### First Project

```bash
mkdir my-project && cd my-project
autonomous-init              # Creates CONTEXT.md and project structure
```

Launch Claude Code and prompt it: "Read the autonomous build prompt and then help me create a spec for this project."

---

## Directory Structure

```
autonomous-dev-kit/
├── README.md                 # You are here
├── install.sh                # One-command setup
├── docs/
│   ├── GETTING_STARTED.md    # First project walkthrough
│   ├── WORKFLOW_REFERENCE.md # Complete workflow details
│   └── TROUBLESHOOTING.md    # Common issues and fixes
├── templates/
│   ├── AUTONOMOUS_BUILD_CLAUDE_v2.md  # Claude-primary protocol
│   ├── AUTONOMOUS_BUILD_CODEX_v2.md   # Codex-primary protocol
│   ├── SPEC_WRITING.md                # Spec writing guide
│   ├── IMPLEMENTATION_PLAN_WRITING.md # Plan writing guide
│   ├── CONTEXT_TEMPLATE.md            # Context preservation template
│   ├── SPEC_QUALITY_CHECKLIST.md      # Spec validation checklist
│   ├── ACCESSIBILITY_CHECKLIST.md     # A11y checks for UI
│   └── LEARNINGS.md                   # Learning accumulator template
├── hooks/
│   ├── pre-compact.sh        # Auto-handoff before context compaction
│   ├── session-start.sh      # Context injection on session start
│   └── stop.sh               # Autonomous loop + safety net
├── lib/
│   ├── loop-helpers.sh       # Shared functions for loop state
│   └── cheatsheet.md         # Protocol cheatsheet (injected by stop hook)
├── shell/
│   ├── aliases.zsh           # Shell aliases
│   ├── functions.zsh         # Helper functions
│   └── README.md             # Shell setup instructions
├── skills/
│   └── autonomous-loop/      # /autonomous-loop skill
├── tests/                    # Test suites for hooks and helpers
├── examples/
│   └── todo-app/             # Worked example with full build cycle
└── CHANGELOG.md
```

---

## Templates Reference

| Template                        | Purpose                                           |
| ------------------------------- | ------------------------------------------------- |
| `AUTONOMOUS_BUILD_CLAUDE_v2.md` | Main protocol when Claude is the primary agent    |
| `AUTONOMOUS_BUILD_CODEX_v2.md`  | Main protocol when Codex is the primary agent     |
| `CONTEXT_TEMPLATE.md`           | Template for context preservation across sessions |
| `LEARNINGS.md`                  | Accumulator for insights across builds            |
| `CLAUDE.md`                     | Project-specific Claude instructions              |

Spec and plan creation now live in skills (installed to `~/.claude/skills/`): `superpowers:brainstorming`, `superpowers:writing-plans`, `spec-quality-checklist`, and `accessibility-checklist`.

---

## Shell Functions

After running `install.sh`, you'll have these commands:

| Command             | Description                                           |
| ------------------- | ----------------------------------------------------- |
| `autonomous-init`   | Initialize a new project for autonomous builds        |
| `autonomous-status` | Show current phase and context summary                |
| `quality-gates`     | Run all quality checks (typecheck, lint, build, test) |
| `claude-review`     | Run Claude code review with standard prompt           |
| `codex-review`      | Run Codex code review with standard prompt            |
| `slop-check`        | Grep for common AI-generated cruft patterns           |

---

## The Example

The `examples/todo-app/` directory contains a complete worked example:

- **SPEC.md** — Specification for a simple todo app
- **IMPLEMENTATION_PLAN.md** — 4-phase build plan
- **CONTEXT.md** — Context file showing mid-build state
- **BUILD_LOG.md** — Annotated log of the build with timestamps
- **src/** — The actual working code

Study this to understand the full workflow before starting your own build.

---

## Cross-Agent Architecture

This system uses Claude and Codex as complementary agents:

```
┌─────────────────────────────────────────────────┐
│                  CLAUDE                         │
│  • Architecture and multi-file coordination    │
│  • Complex refactors and debugging             │
│  • Context management and planning             │
└──────────────────────┬──────────────────────────┘
                       │ Calls at checkpoints
                       ▼
┌─────────────────────────────────────────────────┐
│                  CODEX                          │
│  • Focused implementation tasks                │
│  • Security analysis and edge cases            │
│  • Fresh perspective when stuck                │
└─────────────────────────────────────────────────┘
```

Each agent reviews the other's work at defined checkpoints:

- After drafting specs and plans
- After completing each phase
- Before declaring build complete
- When stuck in an error loop

---

## Context Preservation

The system automatically preserves context across sessions:

1. **CONTEXT.md** — You update this with current state, decisions, next steps
2. **Auto-handoff** — Hooks capture state before context compaction
3. **SessionStart** — Fresh sessions load the latest context automatically

Keep `CONTEXT.md` current (update at least twice per phase) for best results.

---

## Autonomous Loop Mode

For truly hands-off operation, activate autonomous loop mode. This keeps Claude working until completion criteria are met, even across context compactions.

### Activation

```bash
# Explicit goal
/autonomous-loop "Build comprehensive Playwright tests for the auth flow"

# Or interactive (Claude infers goal from context)
"Go autonomous"
```

### How It Works

When active, the Stop hook intercepts exit attempts and:
1. Checks completion criteria (clean git, quality gates, plan tasks)
2. If incomplete: blocks exit, injects continuation prompt with protocol cheatsheet
3. If complete: allows exit, cleans up state

### Completion Criteria

The loop ends automatically when ALL are true:
- Git working directory is clean
- All quality gates pass (if `.claude-quality-gates` exists)
- All tasks in `IMPLEMENTATION_PLAN.md` are checked off

### Safety Features

- **Max iterations** (default 100) — Pauses for human check-in
- **Protocol re-read** — Every 3 iterations, verifies Claude re-read the full protocol
- **Quality gates** — Optional per-project via `.claude-quality-gates` file
- **Escape hatch** — Ctrl+C always works, or say "stop autonomous mode"

### Example Session

```bash
# Initialize project
autonomous-init
# Write spec and plan...

# Go autonomous
claude "Read the spec and go autonomous"
# Claude activates loop, works through phases, commits after each
# Loop ends when all criteria met
```

See [docs/WORKFLOW_REFERENCE.md](docs/WORKFLOW_REFERENCE.md) for complete details.

---

## Getting Help

- **Stuck on setup?** See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **First build confusing?** Follow [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) step by step
- **Need workflow details?** See [docs/WORKFLOW_REFERENCE.md](docs/WORKFLOW_REFERENCE.md)

---

## License

MIT — Use freely, modify freely, build cool stuff.

---

## Credits

This methodology was developed through dozens of autonomous builds, shipping complete applications in single sessions. The protocols encode lessons learned the hard way so you don't have to.

Now go build something.
