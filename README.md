# autonomous-dev-kit

> A bootstrap repo for autonomous AI-assisted development with Claude Code and Codex CLI.

This kit is the result of me taking the best of what works from continuous claude and that ralph skill & hook that's been making the rounds, along with tons of trial and error derived subagents, skills, and prompts to enable unlimited duration agent coding sessions that actually fully complete what you ask it to. Really only works with Claude Code, but if someone can make it work with Codex CLI, do it!

- `install.sh` installs CLI essentials, Claude Code CLI, and writes shell aliases/functions that drive the autonomous workflow. skips anything you already have installed, gives you options to pick and choose what to install.
- Seeds Claude Code skills, templates, and checklists so agents follow opinionated protocols instead of ad-hoc prompting.
- Installs Claude Code hooks (pre-compact, session-start, stop) to keep context synced, quality gates enforced, and enable autonomous loop mode.
- Ships helper commands (`autonomous-init`, `quality-gates`, `claude-review`, `codex-review`, etc.) that keep sessions on-rails.
- Includes a worked example app that demonstrates the full spec → plan → build → test loop.

## How It Works

### The Problems

Out of box, Opus 4.5 with Claude Code is very good, but it's not "build a whole web app without gigantic issues" good for a few reasons:

1. Context management remains an issue, especially with autocompaction running

2. I get real tired of typing the same prompt over and over, and copy/pasting is annoying

3. The model will still confidently ship broken code

4. Getting Claude nice and wet again after you stopped one session and started another is very annoying

5. LLM capability is spiky, so using only Claude won't work

### The Solutions

This kit solves each problem with a specific mechanism:

| Problem                  | Solution                          | Implementation                                                                 |
| ------------------------ | --------------------------------- | ------------------------------------------------------------------------------ |
| Context amnesia          | Auto-handoffs + session injection | `pre-compact.sh` saves state before compaction; `session-start.sh` restores it |
| Ad-hoc prompting         | Battle-tested protocols           | Templates define exactly how to write specs, plans, and execute phases         |
| No quality enforcement   | Mandatory quality gates           | `stop.sh` blocks completion until typecheck/lint/build/test pass               |
| Session fragmentation    | Living context file               | `CONTEXT.md` is updated each phase with decisions, hook signatures, next steps |
| Single-agent limitations | Cross-agent review                | Claude and Codex review each other at checkpoints                              |

Okay I'll let Claude explain how it works in detail:

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
You: "dang, this actually works, and only has like 2-3 bugs instead of 200"
```

---

## Maximum Autonomy Warning

Listen, you and I both know you don't actually care about this, but I have to say it just in case you do:

This kit is configured for maximum autonomy. Command examples and helpers intentionally use `--dangerously-skip-permissions` (Claude) and `--yolo` (Codex), which bypass safety prompts and allow tools to run without confirmation.

Use this setup only in trusted repositories and isolated environments. Review diffs before committing, avoid running against production systems, and remove those flags if you want approval gates.

---

## The Workflow

```
IDEA → SPEC → PLAN → BUILD → DEPLOY
         ↓      ↓       ↓
       Review  Review  Review (after each phase)
```

## Quick Start

### Prerequisites

- **macOS or Linux** (Windows WSL works too)
- **Node.js 18+** and npm
- **Homebrew** (macOS) or **apt** (Linux)
- **Claude API key** (Anthropic) — Codex/OpenAI optional for cross-agent review

### Install

```bash
git clone https://github.com/treygoff24/autonomous-dev-kit.git
cd autonomous-dev-kit
./install.sh
```

The installer is interactive and will:

- Install CLI tools (fd, fzf, bat, ripgrep, delta, zoxide, jq, yq, sd)
- Install Claude Code CLI via npm
- Set up shell aliases and functions
- Create `~/.claude/` with hooks, skills, and lib files
- Let you pick and choose what to install (skips what you already have)

### First Project

```bash
mkdir my-project && cd my-project
autonomous-init              # Creates CONTEXT.md, copies protocol templates
```

Then launch Claude Code: `claude`

Prompt it: "Read the autonomous build protocol and help me create a spec for [your idea]"

---

## Directory Structure

```
autonomous-dev-kit/
├── install.sh                # Interactive installer
├── docs/
│   ├── GETTING_STARTED.md    # First project walkthrough
│   ├── WORKFLOW_REFERENCE.md # Complete workflow details
│   └── TROUBLESHOOTING.md    # Common issues and fixes
├── templates/
│   ├── AUTONOMOUS_BUILD_CLAUDE_v2.md  # The main protocol
│   ├── AUTONOMOUS_BUILD_CODEX_v2.md   # Codex variant
│   ├── CONTEXT_TEMPLATE.md            # Context preservation template
│   ├── CLAUDE.md                      # Project-specific Claude instructions
│   ├── LEARNINGS.md                   # Cross-session learning accumulator
│   └── .claude-quality-gates.example  # Example quality gates config
├── hooks/
│   ├── pre-compact.sh        # Saves handoff before context compaction
│   ├── session-start.sh      # Injects context on session start
│   └── stop.sh               # Autonomous loop + safety net warnings
├── lib/
│   ├── loop-helpers.sh       # Shared functions for loop state
│   └── cheatsheet.md         # Protocol cheatsheet (injected during loop)
├── shell/
│   ├── aliases.zsh           # fd, bat, delta, zoxide aliases
│   ├── functions.zsh         # autonomous-init, quality-gates, etc.
│   └── README.md             # Manual shell setup if needed
├── skills/                   # Claude Code skills (see Skills section)
│   ├── autonomous-loop/
│   ├── brainstorming/
│   ├── writing-plans/
│   ├── test-driven-development/
│   ├── systematic-debugging/
│   └── ... (15 total)
├── tests/                    # Test suites (43 tests)
│   ├── test-loop-helpers.sh
│   ├── test-stop-hook.sh
│   └── test-integration.sh
└── examples/
    └── todo-app/             # Complete worked example
```

---

## Templates

| Template                        | Purpose                                      |
| ------------------------------- | -------------------------------------------- |
| `AUTONOMOUS_BUILD_CLAUDE_v2.md` | The main protocol — read this first          |
| `AUTONOMOUS_BUILD_CODEX_v2.md`  | Codex variant (if you prefer Codex-primary)  |
| `CONTEXT_TEMPLATE.md`           | Context preservation across sessions         |
| `CLAUDE.md`                     | Project-specific Claude instructions         |
| `LEARNINGS.md`                  | Cross-session learning accumulator           |
| `.claude-quality-gates.example` | Example quality gates config                 |

The protocol is the core. CONTEXT.md keeps Claude oriented across compactions. LEARNINGS.md accumulates insights that get injected into future sessions.

---

## Shell Functions

After running `install.sh`, you'll have these commands:

| Command             | Description                                           |
| ------------------- | ----------------------------------------------------- |
| `autonomous-init`   | Initialize a project (copies templates, creates CONTEXT.md) |
| `autonomous-status` | Show current phase and context summary                |
| `quality-gates`     | Run typecheck → lint → build → test                   |
| `claude-review`     | Run Claude code review on current changes             |
| `codex-review`      | Run Codex code review on current changes              |
| `slop-check`        | Grep for AI-generated cruft patterns                  |
| `git-feature`       | Create branch with `feature/` prefix                  |
| `git-feat`          | Alias for `git-feature`                               |
| `git-fix`           | Create branch with `fix/` prefix                      |
| `git-chore`         | Create branch with `chore/` prefix                    |

All commands support `--help` for usage details.

---

## Skills

Skills are reusable workflows that Claude invokes via `/skill-name`. Installed to `~/.claude/skills/`.

| Skill | What it does |
|-------|--------------|
| `/autonomous-loop` | Activate autonomous loop mode with explicit goal |
| `/brainstorming` | Refine vague ideas into concrete designs via Socratic questioning |
| `/writing-plans` | Create detailed implementation plans with phases and acceptance criteria |
| `/test-driven-development` | Red-green-refactor: write failing test first, then implement |
| `/systematic-debugging` | Structured debugging: reproduce → isolate → hypothesize → fix |
| `/verification-before-completion` | Require proof (test output, screenshots) before claiming done |
| `/requesting-code-review` | Self-review checklist before commit |
| `/using-git-worktrees` | Create isolated worktrees for risky changes |
| `/finishing-a-development-branch` | Clean up branch for merge/PR |
| `/spec-quality-checklist` | Validate specs before implementation |
| `/accessibility-checklist` | A11y audit for UI components |
| `/slop-cleanup` | Find and remove AI-generated cruft |
| `/testing-anti-patterns` | Avoid common testing mistakes |
| `/condition-based-waiting` | Replace flaky sleeps with condition polling |
| `/subagent-driven-development` | Dispatch subagents for parallel task execution |

Skills are the "how" — they encode methodology so Claude doesn't improvise.

---

## The Example

`examples/todo-app/` is a complete worked example showing the full cycle:

- `SPEC.md` — What we're building
- `IMPLEMENTATION_PLAN.md` — Phased build plan with checkboxes
- `CONTEXT.md` — Context file (updated throughout the build)
- `BUILD_LOG.md` — Annotated log with timestamps
- `LEARNINGS.md` — What we learned during the build
- `src/` — The working code (Vite + TypeScript)

Study this before your first build to see how the pieces fit together.

---

## Cross-Agent Review (Optional)

Claude does the heavy lifting. Codex is optional for cross-review:

- After drafting specs/plans → Codex reviews for gaps
- After each phase → Codex spots what Claude missed
- When stuck → Fresh perspective breaks the loop

Use `claude-review` and `codex-review` shell commands, or just ask Claude to "get Codex's opinion on this."

---

## Context Preservation

Hooks handle this automatically:

1. **Pre-compact hook** — Saves git state + CONTEXT.md before compaction
2. **Session-start hook** — Injects recent handoffs + learnings into new sessions
3. **CONTEXT.md** — You update this with current phase, decisions, hook signatures

The system survives context compactions and session restarts. Just keep CONTEXT.md current.

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

Built on top of ideas from [continuous-claude](https://github.com/samwho/continuous-claude), the Ralph skill/hook that made the rounds, and a lot of trial and error.

Now go build something.
