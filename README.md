# autonomous-dev-kit

> A bootstrap repo for autonomous AI-assisted development with Claude Code and Codex CLI.

---

## What This Is

This kit provides everything you need to build complete applications using AI agents as development partners. Instead of treating AI as a fancy autocomplete, this system treats Claude and Codex as autonomous agents capable of executing multi-phase builds with minimal human intervention.

**The core idea:** Structured protocols beat ad-hoc prompting. When you give AI agents clear methodology, context management, and quality gates, they can build complete features—or entire applications—in single sessions.

This isn't about replacing developers. It's about removing the friction between "I know what I want to build" and "it's built, tested, and deployed."

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

Then follow [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) for a step-by-step walkthrough of your first autonomous build.

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
├── shell/
│   ├── aliases.zsh           # Shell aliases
│   ├── functions.zsh         # Helper functions
│   └── README.md             # Shell setup instructions
├── skills/                   # Claude Code skills (optional)
├── examples/
│   └── todo-app/             # Worked example with full build cycle
└── CHANGELOG.md
```

---

## Templates Reference

| Template | Purpose |
|----------|---------|
| `AUTONOMOUS_BUILD_CLAUDE_v2.md` | Main protocol when Claude is the primary agent |
| `AUTONOMOUS_BUILD_CODEX_v2.md` | Main protocol when Codex is the primary agent |
| `SPEC_WRITING.md` | Guide for turning ideas into structured specs |
| `IMPLEMENTATION_PLAN_WRITING.md` | Guide for breaking specs into phases |
| `CONTEXT_TEMPLATE.md` | Template for context preservation across sessions |
| `SPEC_QUALITY_CHECKLIST.md` | Validation checklist before approving a spec |
| `ACCESSIBILITY_CHECKLIST.md` | A11y verification for UI components |
| `LEARNINGS.md` | Accumulator for insights across builds |

---

## Shell Functions

After running `install.sh`, you'll have these commands:

| Command | Description |
|---------|-------------|
| `autonomous-init` | Initialize a new project for autonomous builds |
| `autonomous-status` | Show current phase and context summary |
| `quality-gates` | Run all quality checks (typecheck, lint, build, test) |
| `claude-review` | Run Claude code review with standard prompt |
| `codex-review` | Run Codex code review with standard prompt |
| `slop-check` | Grep for common AI-generated cruft patterns |

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
