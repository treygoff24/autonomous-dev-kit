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
│                     SPEC REVIEW (Claude)                             │
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
│                   PLAN REVIEW (Codex)                                │
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
│    │   REVIEW    │────► Dual code review (Claude + Codex)            │
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
│  • Final cross-check (Codex)                                         │
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

1. **Initialize state** — Creates `~/.claude/autonomous-loop/<project-hash>.json`
2. **Block exits** — Stop hook intercepts exit attempts
3. **Check completion** — Clean git + quality gates + plan complete
4. **Continue or exit** — If incomplete, injects continuation prompt; if complete, allows exit

### Completion Criteria

Loop ends when ALL are true:
- Git working directory is clean (no uncommitted changes)
- All quality gates pass (if `.claude-quality-gates` file exists)
- All tasks in `IMPLEMENTATION_PLAN.md` are checked `[x]`

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
| Protocol re-read | Every 3 iterations, verifies Claude re-read full protocol |
| Escape hatch | Ctrl+C always works, "stop autonomous mode" clears state |
| State isolation | Per-project state files prevent cross-contamination |

### Commands During Loop

| Action | Command |
|--------|---------|
| Check status | `cat ~/.claude/autonomous-loop/*.json \| jq` |
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

**Note:** Autonomous loop mode handles this automatically — the Stop hook injects the protocol cheatsheet on every iteration and forces full protocol re-read every 3 iterations.

### Autonomous Loop Issues

**Loop won't end:**
- Check completion criteria: `git status`, quality gates, plan checkboxes
- Verify `.claude-quality-gates` commands pass manually
- Check for unchecked `[ ]` boxes in `IMPLEMENTATION_PLAN.md`

**Loop paused unexpectedly:**
- Max iterations reached — say "continue for 50 more" to extend
- Check state file: `cat ~/.claude/autonomous-loop/*.json | jq`

**Need to escape:**
- Ctrl+C always works
- Say "stop autonomous mode" to clear state
- Delete state file manually: `rm ~/.claude/autonomous-loop/*.json`

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

## Shell Commands Quick Reference

```bash
# Initialize project
autonomous-init

# Check status
autonomous-status

# Run quality gates
quality-gates

# Review with Claude
claude-review 'Phase 2 - Auth'

# Review with Codex
codex-review 'Phase 2 - Auth'

# Check for slop
slop-check src/

# Git helpers
git-feature my-feature
git-feat 'add login'
git-fix 'resolve bug'
```
