# Workflow Reference

Complete reference for the autonomous build workflow.

---

## Maximum Autonomy Warning

This workflow uses maximum autonomy commands. Examples below include `--dangerously-skip-permissions` (Claude) and `--dangerously-bypass-approvals-and-sandbox` (Codex), which bypass safety prompts and allow tools to run without confirmation.

Use only in trusted repos and isolated environments. Review diffs before committing, avoid running against production systems, and remove those flags if you want approval gates.

---

## Workflow Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                           IDEA                                        │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       SPEC WRITING                                    │
│  • Problem statement                                                 │
│  • User stories                                                      │
│  • Data model                                                        │
│  • Acceptance criteria                                               │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                  SPEC REVIEW (Claude + Gemini)                       │
│  • Completeness check                                                │
│  • Edge cases                                                        │
│  • Feasibility                                                       │
│                           ┌───────┐                                  │
│              ◄────────────│Revise │◄─────── if issues                │
└────────────────────────────┴───────┴─────────────────────────────────┘
                                 │ approved
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    IMPLEMENTATION PLANNING                            │
│  • Phase breakdown                                                   │
│  • Dependencies                                                      │
│  • Acceptance criteria per phase                                     │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                PLAN REVIEW (Codex + Gemini)                          │
│  • Sequencing                                                        │
│  • Risk identification                                               │
│                           ┌───────┐                                  │
│              ◄────────────│Revise │◄─────── if issues                │
└────────────────────────────┴───────┴─────────────────────────────────┘
                                 │ approved
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     PHASE EXECUTION LOOP                             │
│                                                                      │
│    ┌─────────────┐                                                   │
│    │  IMPLEMENT  │────► Write code for this phase                    │
│    └──────┬──────┘                                                   │
│           │                                                          │
│           ▼                                                          │
│    ┌─────────────┐                                                   │
│    │  TYPECHECK  │────► npm run typecheck (zero errors)              │
│    └──────┬──────┘                                                   │
│           │                                                          │
│           ▼                                                          │
│    ┌─────────────┐                                                   │
│    │    LINT     │────► npm run lint (zero warnings)                 │
│    └──────┬──────┘                                                   │
│           │                                                          │
│           ▼                                                          │
│    ┌─────────────┐                                                   │
│    │    BUILD    │────► npm run build (must succeed)                 │
│    └──────┬──────┘                                                   │
│           │                                                          │
│           ▼                                                          │
│    ┌─────────────┐                                                   │
│    │    TEST     │────► npm run test (all pass)                      │
│    └──────┬──────┘                                                   │
│           │                                                          │
│           ▼                                                          │
│    ┌─────────────┐                                                   │
│    │   REVIEW    │────► Tri review (Claude + Codex + Gemini)         │
│    └──────┬──────┘                                                   │
│           │                                                          │
│           ▼                                                          │
│    ┌─────────────┐      ┌───────┐                                    │
│    │    FIX      │◄─────│Issues?│───────► if yes, loop back          │
│    └──────┬──────┘      └───────┘                                    │
│           │ no issues                                                │
│           ▼                                                          │
│    ┌─────────────┐                                                   │
│    │SLOP REMOVAL │────► Clean AI-generated cruft                     │
│    └──────┬──────┘                                                   │
│           │                                                          │
│           ▼                                                          │
│    ┌─────────────┐                                                   │
│    │   COMMIT    │────► feat: complete phase N                       │
│    └──────┬──────┘                                                   │
│           │                                                          │
│           ▼                                                          │
│    ┌─────────────┐                                                   │
│    │ Next Phase? │───────► if more phases, loop to IMPLEMENT         │
│    └──────┬──────┘                                                   │
│           │ all phases complete                                      │
└───────────┼──────────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     FINAL VERIFICATION                               │
│  • Full quality suite                                                │
│  • Final cross-check (Codex + Gemini)                                │
│  • Manual verification                                               │
│  • Capture learnings                                                 │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                           SHIP IT                                    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Cross-Agent Call Reference

### Using Skills (Preferred in Claude Code)

When working within a Claude Code session, use the `/codex` and `/gemini` skills instead of shell commands. The skills handle background execution automatically and integrate with Claude Code's task management.

| Checkpoint | Skill Invocation |
|------------|------------------|
| Spec review | `/codex Review SPEC.md for completeness, edge cases, security gaps, and implementation feasibility. Output: Critical gaps / Ambiguities / Suggestions / Verdict.` |
| Plan review | `/gemini Review IMPLEMENTATION_PLAN.md against SPEC.md. Check for sequencing risks and alternative approaches. Verdict: approve or revise.` |
| Phase review | `/codex Review the current branch diff for Phase [N]. Check for security issues, edge cases, test coverage, performance. Verdict: approve or revise.` |
| Final check | `/gemini Final cross-check. Read SPEC.md and IMPLEMENTATION_PLAN.md. Verify all criteria met. Verdict: ship it or fix issues.` |
| Stuck | `/codex I'm stuck. Error: [ERROR]. Tried: [APPROACHES]. What am I missing?` |

**Why skills over shell commands:**
- Skills run in background mode — no timeout issues
- Automatic task management and notifications
- Cleaner integration with Claude Code workflow
- Self-contained prompts with all context

The bash commands below are for reference when calling agents from outside Claude Code (e.g., Codex calling Claude, or direct terminal use).

### When to Call Claude (from Codex)

| Checkpoint | Command |
|------------|---------|
| Spec review | `claude -p --model opus --dangerously-skip-permissions --output-format text "Review SPEC.md for completeness, edge cases, and feasibility. Output: Gaps / Ambiguities / Suggestions / Verdict."` |
| Plan review | `claude -p --model opus --dangerously-skip-permissions --output-format text "Review IMPLEMENTATION_PLAN.md against SPEC.md. Check sequencing and risks. Verdict: approve or revise."` |
| Phase review | `claude -p --model opus --dangerously-skip-permissions --output-format text "Review the current branch diff for Phase [N]. Check security, edge cases, tests. Verdict: approve or revise."` |
| Final check | `claude -p --model opus --dangerously-skip-permissions --output-format text "Final cross-check. Verify all acceptance criteria met. Verdict: ship it or fix issues."` |
| Stuck | `claude -p --model opus --dangerously-skip-permissions --output-format text "I'm stuck on [ERROR]. Tried [APPROACHES]. Suggest a different approach."` |

### When to Call Codex (from Claude)

| Checkpoint | Command |
|------------|---------|
| Spec review | `codex exec -m gpt-5.2-codex -c model_reasoning_effort="xhigh" --dangerously-bypass-approvals-and-sandbox "Review SPEC.md for completeness, edge cases, security gaps, and implementation feasibility. Output: Critical gaps / Ambiguities / Suggestions / Verdict."` |
| Plan review | `codex exec -m gpt-5.2-codex -c model_reasoning_effort="xhigh" --dangerously-bypass-approvals-and-sandbox "Review IMPLEMENTATION_PLAN.md against SPEC.md. Check for sequencing risks and alternative approaches. Verdict: approve or revise."` |
| Phase review | `codex exec -m gpt-5.2-codex -c model_reasoning_effort="xhigh" --dangerously-bypass-approvals-and-sandbox "Review the current branch diff for Phase [N]. Check for security issues, edge cases, test coverage, performance. Verdict: approve or revise."` |
| Final check | `codex exec -m gpt-5.2-codex -c model_reasoning_effort="xhigh" --dangerously-bypass-approvals-and-sandbox "Final cross-check. Read SPEC.md and IMPLEMENTATION_PLAN.md. Verify all criteria met. Verdict: ship it or fix issues."` |
| Stuck | `codex exec -m gpt-5.2-codex -c model_reasoning_effort="xhigh" --dangerously-bypass-approvals-and-sandbox "I'm stuck. Error: [ERROR]. Tried: [APPROACHES]. What am I missing?"` |

### When to Call Gemini (from Claude or Codex)

| Checkpoint | Command |
|------------|---------|
| Spec review | `cat SPEC.md \| gemini -p "Review SPEC.md for completeness, edge cases, security gaps, and implementation feasibility. Output: Critical gaps / Ambiguities / Suggestions / Verdict." --output-format text` |
| Plan review | `cat SPEC.md IMPLEMENTATION_PLAN.md \| gemini -p "Review IMPLEMENTATION_PLAN.md against SPEC.md. Check for sequencing risks and alternative approaches. Verdict: approve or revise." --output-format text` |
| Phase review | `git diff \| gemini -p "Review the current branch diff for Phase [N]. Check for security issues, edge cases, test coverage, performance. Verdict: approve or revise." --output-format text` |
| Final check | `cat SPEC.md IMPLEMENTATION_PLAN.md \| gemini -p "Final cross-check. Verify all criteria met. Verdict: ship it or fix issues." --output-format text` |
| Stuck | `gemini -p "I'm stuck. Error: [ERROR]. Tried: [APPROACHES]. What am I missing?" --output-format text` |

---

## Parallel Ticket Builder

Use `/ticket-builder` to execute parallel-safe plan tasks in isolated worktrees.

**Prereqs in `IMPLEMENTATION_PLAN.md`:**
- `Parallel: yes`
- `Blocked by: none` (or all blockers complete)
- `Owned files:` list with no overlaps across parallel tasks

**Workflow:**
1. Create a worktree per parallel task
2. Run `/ticket-builder` with the task ID and worktree path
3. In the worktree, run tests + `git diff`, then `/requesting-code-review`
4. Merge/cherry-pick only after review approval

**Example:**
```bash
git worktree add ../project-task-3-2 feature/task-3-2
cd ../project-task-3-2
/ticket-builder
# Provide: Task 3.2, worktree path, owned files
git status -sb
git diff --stat
npm test
/requesting-code-review
```

---

## Autonomous Loop Mode

For hands-off operation, activate autonomous loop mode. The Stop hook will keep Claude working until completion criteria are met.

### Activation

```bash
# With explicit goal
/autonomous-loop "Build comprehensive Playwright tests"

# With max iterations override
/autonomous-loop "Fix all failing tests" --max 200

# Interactive (Claude infers goal from context)
"Go autonomous" or "Start autonomous mode"
```

### How It Works

1. **Initialize state** — Creates `.claude/autonomous-loop.json` in the project root
2. **Block exits** — Stop hook intercepts exit attempts
3. **Check completion** — Clean git + quality gates + plan scope complete
4. **Continue or exit** — If incomplete, injects continuation prompt; if complete, allows exit

### Completion Criteria

Loop ends when ALL are true:
- Git working directory is clean (no uncommitted changes)
- All quality gates pass (if `.claude-quality-gates` file exists)
- All tasks in `IMPLEMENTATION_PLAN.md` are checked `[x]`

If the goal mentions a phase or module and a matching section exists, only that
section is checked. If the scoped section is missing, the plan check is skipped.

### Quality Gates File (Optional)

Create `.claude-quality-gates` in your project root:

```bash
# Each line is a command that must exit 0
npm run typecheck
npm run lint
npm run build
npm run test
```

If this file exists, all commands must pass for the loop to complete.

### Safety Features

| Feature | Behavior |
|---------|----------|
| Max iterations | Pauses at 100 (configurable) for human check-in |
| Protocol re-read | Every 3 iterations, re-read full protocol and verify with code from `.claude/autonomous-loop.json` |
| Stuck detection | Pauses after 5 consecutive iterations with no goal or git progress change |
| Escape hatch | Ctrl+C always works, "stop autonomous mode" clears state |
| State isolation | Per-project state files prevent cross-contamination |

If verification is requested, re-read `AUTONOMOUS_BUILD_CLAUDE.md` and respond
with `<verified code="####"/>` using `expected_verification_code` from
`.claude/autonomous-loop.json`.

### Commands During Loop

| Action | Command |
|--------|---------|
| Check status | `cat .claude/autonomous-loop.json \| jq` |
| Pause loop | Say "pause autonomous mode" |
| Resume loop | Say "resume" or "continue" |
| Stop permanently | Say "stop autonomous mode" |
| Extend iterations | Say "continue for 50 more iterations" |

### Deactivation

Say any of:
- "Stop autonomous mode"
- "Exit autonomous mode"
- "Pause the loop"

This clears the state file and allows normal exit behavior.

### How This Compares to Ralph Wiggum

[Ralph Wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) is Anthropic's official autonomous loop plugin for Claude Code. We took what works from Ralph and improved it in every way that matters for real production builds.

**What Ralph Does**

Ralph implements a simple loop: Claude works → tries to exit → Stop hook blocks exit (exit code 2) → re-feeds the same prompt → repeat. The genius insight is that Claude reads its own modified files and git history to understand what to improve next. The prompt never changes—context accumulates in the filesystem.

```
User: /ralph-loop "Build X" --completion-promise "DONE" --max-iterations 50
                    ↓
              Claude works
                    ↓
              Tries to exit
                    ↓
         Stop hook blocks (exit 2)
                    ↓
          Re-feeds same prompt
                    ↓
         (loop until "DONE" found)
```

**What We Improved**

| Aspect | Ralph Wiggum | This Kit |
|--------|--------------|----------|
| **Completion detection** | Exact string match (`<promise>DONE</promise>`) | Sonnet evaluates "is this actually done?" |
| **What gets checked** | Just the completion string | Git clean + quality gates + plan tasks + code review |
| **Task scope** | Single-task loops | Multi-phase builds (Spec → Plan → Implement → Verify) |
| **Context survival** | Filesystem only | Hooks inject handoffs + learnings after compaction |
| **Protocol drift** | No protection | Verification codes + protocol re-reads every 3 iterations |
| **Cross-agent review** | None | `/codex` and `/gemini` for independent verification |
| **Stuck detection** | None | Pauses after 5 iterations with no progress |
| **Quality gates** | None | Configurable `.claude-quality-gates` file |

**The Core Difference: Intelligent Completion**

Ralph uses exact string matching. If Claude outputs `<promise>DONE</promise>`, the loop ends—whether or not the work is actually done.

We use **prompt-based Stop hooks** where Sonnet evaluates completion:

```yaml
hooks:
  Stop:
    - type: prompt
      model: sonnet
      prompt: |
        You are about to exit. Verify the work is ACTUALLY COMPLETE.

        1. Run `git status` — uncommitted changes = not done
        2. Run quality gates — failures = not done
        3. Check IMPLEMENTATION_PLAN.md — unchecked boxes = not done
        4. Would you ship this to production right now?
```

This catches:
- "Tests pass" claims when tests weren't run
- "Complete" claims with uncommitted changes
- Phase completions with unchecked plan tasks
- Half-done work that looks finished

**When to Use Ralph vs This Kit**

| Use Ralph When | Use This Kit When |
|----------------|-------------------|
| Single well-defined task | Multi-phase feature builds |
| Clear mechanical completion ("tests pass") | Complex completion criteria |
| Quick iteration loops | Production-quality requirements |
| You want minimal setup | You want quality enforcement |

Ralph is a scalpel. This kit is an operating room.

**Can They Work Together?**

Yes. Ralph handles tight inner loops ("iterate until this test passes"), while this kit manages the outer structure (phases, reviews, cross-agent verification). The approaches are complementary—Ralph for tactical iteration, this kit for strategic builds.

---

## Quality Gates

Run before every code review:

```bash
# JavaScript/TypeScript projects
npm run typecheck    # Zero type errors
npm run lint         # Zero warnings
npm run build        # Must succeed
npm run test         # All tests pass
```

```bash
# Python projects
source .venv/bin/activate
python -m pytest     # All tests pass
ruff check .         # Zero lint errors
black --check .      # Formatting clean
mypy src/            # Type checks pass
```

Quick command:

```bash
quality-gates
```

---

## Slop Removal Patterns

After review passes, before committing:

### Remove These

| Pattern | Example |
|---------|---------|
| Unnecessary comments | `// This function adds two numbers` before `function add(a, b)` |
| Commented-out code | `// const oldImplementation = ...` |
| Single-use variables | `const result = foo(); return result;` → `return foo();` |
| Redundant defensive checks | Null checks deep in trusted codepaths |
| Empty catch blocks | `catch (e) {}` |
| `any` type casts | `as any`, `: any` |
| Debug statements | `console.log`, `debugger` |
| Over-abstracted utilities | Single-use helper functions |

### Preserve These

| Pattern | Why |
|---------|-----|
| API boundary validation | User input is never trusted |
| Auth/RLS checks | Security critical |
| Error handling at system edges | External services fail |
| Audit logging | Compliance/debugging |

### Check for Slop

```bash
slop-check src/
```

---

## Commit Conventions

Use semantic commit messages:

| Prefix | Usage |
|--------|-------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `chore:` | Maintenance, dependencies |
| `refactor:` | Code restructuring without behavior change |
| `docs:` | Documentation only |
| `test:` | Adding or updating tests |
| `style:` | Formatting, whitespace |

### Phase Commits

```bash
git commit -m "feat: complete phase 1 - project setup"
git commit -m "feat: complete phase 2 - data layer"
git commit -m "feat: complete phase 3 - API endpoints"
git commit -m "chore: complete phase 4 - polish and testing"
```

---

## Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<name>` | `feature/user-auth` |
| Bugfix | `fix/<issue>` | `fix/login-redirect` |
| Hotfix | `hotfix/<issue>` | `hotfix/security-patch` |
| Experiment | `experiment/<name>` | `experiment/new-api` |

Create feature branch:

```bash
git checkout -b feature/my-feature
# or
git-feature my-feature
```

---

## Context Management

### CONTEXT.md Structure

```markdown
# Project Context — DO NOT DELETE

**Last Updated**: Phase [N] - [Name] ([STATUS])

## Protocol Reminder
[Brief reminder of the loop and checkpoints]

## Build Context
**Type**: [Greenfield | Feature | Refactor]
**Spec location**: SPEC.md
**Plan location**: IMPLEMENTATION_PLAN.md

## Current Phase
[What you're working on right now]

## Hook Signatures
[Custom hooks with return types]

## Utility Functions
[Utilities and their locations]

## Design Decisions
[Key decisions that affect multiple files]

## API Contracts
[Endpoints documented as you build them]
```

### Update Frequency

- **Minimum:** Twice per phase
- **Recommended:** After every significant decision
- **Critical:** Before any break or context switch

### Context Recovery

If context feels stale:

1. Re-read `CONTEXT.md`
2. Re-read `AUTONOMOUS_BUILD_*.md`
3. Check `IMPLEMENTATION_PLAN.md` for current phase
4. Review recent commits: `git log --oneline -10`

---

## Testing Strategy

### When to Write Tests

| Event | Test Type |
|-------|-----------|
| New utility function | Unit test immediately |
| New component | Component test for interactive elements |
| New user flow | E2E test for critical path |
| Bug fix | Regression test (fails before fix, passes after) |

### Test Locations

| Type | Location |
|------|----------|
| Unit tests | `src/__tests__/*.test.ts` or co-located |
| Component tests | `ComponentName.test.tsx` (co-located) |
| E2E tests | `e2e/` or `tests/` |

### Coverage Philosophy

- **Do:** Cover critical business logic
- **Don't:** Chase 100% coverage for its own sake
- **Focus:** User-facing behavior, not implementation details

---

## Accessibility Checklist

For every interactive component:

- [ ] `aria-label` on icon buttons
- [ ] Keyboard navigation (Enter/Space activates, Escape dismisses)
- [ ] Focus visible styles
- [ ] Color contrast WCAG AA (4.5:1 text, 3:1 UI)
- [ ] Touch targets 44x44px minimum
- [ ] `prefers-reduced-motion` respected

Quick test:
1. Keyboard-only navigation
2. Screen reader spot-check
3. 200% zoom test

---

## Error Recovery

### Stuck in a Loop (3+ attempts)

1. Call the other agent for fresh perspective
2. Log the blocker
3. Skip to an unblocked phase
4. Return later with fresh context

### Build Failing Mysteriously

```bash
# Clear all caches
rm -rf node_modules .next dist .vite
npm install
npm run build
```

Check for:
- Circular imports
- Missing peer dependencies
- Stale lock file

### Context Degraded

1. Run `/clear` to trigger fresh context load
2. Re-read `CONTEXT.md` and `IMPLEMENTATION_PLAN.md`
3. Update `CONTEXT.md` with current state
4. Continue

**Note:** Autonomous loop mode handles this automatically — the Stop hook injects the protocol cheatsheet into the continuation prompt on every iteration and requires a code-based verification every 3 iterations.

### Autonomous Loop Issues

**Loop won't end:**
- Check completion criteria: `git status`, quality gates, plan checkboxes
- Verify `.claude-quality-gates` commands pass manually
- Check for unchecked `[ ]` boxes in `IMPLEMENTATION_PLAN.md`

**Loop paused unexpectedly:**
- Max iterations reached — say "continue for 50 more" to extend
- Check state file: `cat .claude/autonomous-loop.json | jq`

**Need to escape:**
- Ctrl+C always works
- Say "stop autonomous mode" to clear state
- Delete state file manually: `rm .claude/autonomous-loop.json`

### Flaky Tests

- Replace arbitrary timeouts with condition polling
- Wait for actual state changes, not time
- Follow the `testing-standards` rule for best practices

---

## File Reference

| File | Purpose | Update Frequency |
|------|---------|------------------|
| `SPEC.md` | Requirements | Once, before build |
| `IMPLEMENTATION_PLAN.md` | Phased work plan | After each phase |
| `CONTEXT.md` | Current state | Twice per phase minimum |
| `LEARNINGS.md` | Insights | At session end |
| `CLAUDE.md` | Project instructions | As needed |

---

## Claude Code 2.1.x Features

This toolkit leverages features from Claude Code 2.1.0 through 2.1.2. Here's what's available:

### Skill Hot-Reload

Skills in `~/.claude/skills` or `.claude/skills` are **immediately available** without restarting the session. Edit a skill file and it's live instantly.

### Named Sessions

Organize work with named sessions:

```bash
# In REPL
/rename "auth-feature"       # Name current session
/resume auth-feature         # Resume by name

# From terminal
claude --resume auth-feature
```

### LSP Tool

Agents can use Language Server Protocol for code intelligence:
- Go-to-definition
- Find references
- Hover documentation

No configuration needed — works automatically when LSP servers are available.

### Wildcard Bash Permissions

Configure flexible bash permissions in `settings.json` using `*` at any position:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm *)",        // All npm commands
      "Bash(npx *)",        // All npx commands
      "Bash(pnpm *)",       // All pnpm commands
      "Bash(git *)",        // All git commands
      "Bash(claude *)",     // All claude commands
      "Bash(* --help)",     // Any command with --help
      "Bash(git * main)",   // Git commands ending with main
      "Bash(npm run *)"     // All npm scripts
    ]
  }
}
```

**Pattern matching rules:**
- `*` matches any sequence of characters at that position
- `Bash(npm *)` matches `npm install`, `npm run test`, `npm publish`, etc.
- `Bash(git * main)` matches `git checkout main`, `git merge main`, `git rebase main`
- `Bash(* install)` matches `npm install`, `pnpm install`, `brew install`

**Recommended permissions for autonomous builds:**

```json
{
  "permissions": {
    "allow": [
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(git *)",
      "Bash(claude *)",
      "Bash(codex *)",
      "Bash(cat *)",
      "Bash(ls *)",
      "Bash(pwd)",
      "Bash(echo *)"
    ]
  }
}
```

### Backgrounding with Ctrl+B

Press `Ctrl+B` to background **any running task** — bash commands OR agents:

**What you can background:**
- Long-running bash commands (dev servers, tailing logs, builds)
- Agents working on complex tasks
- Test suites running in the background
- Any foreground task you want to continue in background

**Workflow:**
1. Start a task (command or agent)
2. Realize it's taking a while
3. Press `Ctrl+B` to background it
4. Continue working on other things
5. Get notified when the background task completes

**Useful with autonomous-loop:**
- Background the loop to check files or run manual tests
- Queue up additional messages while agents work
- Pause without exiting the loop

**Commands:**
```bash
/tasks                    # List all background tasks
# Background tasks show completion notifications automatically
```

**Note:** Background tasks continue running and you'll see a notification when they complete. You don't need to poll or check — Claude Code tells you.

### Forked Context (`context: fork`)

Skills can run in isolated sub-agent context:

```yaml
---
name: my-skill
context: fork      # Runs in fresh context
agent: my-agent    # Optional: specify agent type
---
```

Benefits:
- Clean context without conversation noise
- Parallel execution without interference
- Focused task completion

Skills using `context: fork` in this kit:
- `writing-plans`
- `using-git-worktrees`
- `accessibility-checklist`
- `requesting-code-review`
- `receiving-code-review`
- `spec-quality-checklist`
- `ticket-builder`

### Skills Auto-Loading

Skills can declare dependencies that auto-load for subagents:

```yaml
---
name: brainstorming
skills:
  - using-git-worktrees
  - writing-plans
---
```

When `brainstorming` runs, its subagents automatically have access to the listed skills.

### Hooks in Skills and Agents

Skills and agents can define hooks that fire during their lifecycle:

```yaml
---
name: my-skill
hooks:
  Stop:
    - type: prompt
      prompt: "Verify the output file was saved"
      once: true    # Only fires once per session
  PreToolUse:
    - type: command
      command: ./validate.sh
      matcher: "Bash"   # Only for Bash tool
---
```

**Hook events:**
- `Stop` — Fires when agent/skill is about to exit
- `PreToolUse` — Fires before a tool is used
- `PostToolUse` — Fires after a tool completes
- `SessionStart` — Fires when session begins (global hooks only)

**Hook types:**
- `prompt` — Runs a prompt-based check (Claude evaluates the prompt)
- `command` — Runs a shell command

**The `once: true` option:**

Hooks with `once: true` only fire once per session, even if the skill/agent runs multiple times:

```yaml
hooks:
  Stop:
    - type: prompt
      prompt: "Did you save the design document?"
      once: true  # Won't keep asking every time
```

**Use cases for `once: true`:**
- Session initialization (only need to inject context once)
- One-time verification prompts
- Preventing duplicate notifications

**Agent-scoped hooks (2.1.0+):**

Agents can now have their own hooks in frontmatter:

```yaml
---
name: tdd-implementer
hooks:
  Stop:
    - type: prompt
      prompt: "Did you verify RED then GREEN for each test?"
      once: true
---
```

This ensures the TDD workflow is followed — the hook fires when the agent exits.

### Agent Type in Session Hooks (2.1.2+)

SessionStart hooks now receive `agent_type` when Claude is started with `--agent`:

```bash
claude --agent plan-executor  # agent_type = "plan-executor"
```

This allows hooks to customize context injection per agent. The `session-start.sh` hook in this kit uses this to inject agent-specific reminders:

- `plan-executor` → Quality gates reminder
- `debugger` → Root cause investigation reminder
- `tdd-implementer` → RED-GREEN-REFACTOR reminder

**Custom hook usage:**

```bash
# In your hook script
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
case "$AGENT_TYPE" in
    "my-agent")
        echo "## Custom Context for my-agent"
        ;;
esac
```

### Large Output Handling (2.1.2+)

When bash commands produce large output (>30K chars), Claude Code saves the full output to a file and provides a reference path. This is crucial for debugging:

- Test output with many failures
- Build logs with stack traces
- Long diff outputs

The `debugger` agent knows to read these files. Always use the Read tool to access full content when you see a file reference.

### Plan Mode Shortcut

Enter plan mode directly:

```bash
/plan                    # Shortcut to enable plan mode
```

Or say "think" / "make a plan" in your prompt.

---

## Shell Commands Quick Reference

```bash
# Initialize project
autonomous-init

# Check status
autonomous-status

# Run quality gates
quality-gates

# Check for slop
slop-check src/

# Git helpers
git-feature my-feature
git-feat 'add login'
git-fix 'resolve bug'
```

### Cross-Agent Reviews

**Within Claude Code sessions (preferred):**
```
/codex Review the current branch diff for Phase 2 - Auth...
/gemini Review the current branch diff for Phase 2 - Auth...
```

**From terminal (outside Claude Code):**
```bash
claude-review 'Phase 2 - Auth'
codex-review 'Phase 2 - Auth'
gemini-review 'Phase 2 - Auth'
```
