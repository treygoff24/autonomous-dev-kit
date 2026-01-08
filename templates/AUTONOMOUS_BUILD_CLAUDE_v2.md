# Autonomous Build Protocol — Claude Edition

> For building complete applications from scratch OR adding features to existing codebases. Claude drives, Codex advises. Execute with precision.

---

## Maximum Autonomy Warning

This protocol uses `--dangerously-skip-permissions` (Claude) and `--yolo` (Codex) in command examples. These bypass safety prompts and allow tools to run without confirmation.

Use only in trusted repos and isolated environments. Review diffs before committing, avoid running against production systems, and remove those flags if you want approval gates.

---

## Quick Start

```
Read AUTONOMOUS_BUILD_CLAUDE.md and the spec at [SPEC_PATH]. Build autonomously. Do not stop until complete.
```

If no spec exists, use `brainstorming` skill to draft one. If no implementation plan exists, use `writing-plans` skill after the spec is approved.

---

## Your Toolkit

You have powerful capabilities organized in three layers: agents (isolated execution), skills (conversation context), and rules (auto-loaded standards).

### Custom Agents (via Task tool)

Custom agents at `~/.claude/agents/` provide isolated execution with fresh context. They can run in parallel and don't pollute your main conversation.

| Agent | When to Use |
|-------|-------------|
| `debugger` | Systematic debugging with root cause analysis. Use BEFORE proposing fixes. |
| `tdd-implementer` | Test-driven development. Write failing test first. |
| `plan-executor` | Execute implementation plans task-by-task with quality gates. |
| `code-reviewer` | Review diffs against specs/plans before commits. |
| `a11y-reviewer` | Accessibility review for interactive UI changes. |
| `spec-reviewer` | Spec completeness and precision review. |
| `review-triager` | Triage review feedback before implementation. |
| `slop-cleaner` | Remove AI-generated cruft before commits. |
| `validator` | Defense-in-depth validation across layers. |
| `root-cause-tracer` | Trace bugs backward through call stack. |
| `parallel-investigator` | Investigate independent failures concurrently. |

Note: This kit ships a custom `code-reviewer` agent that overrides the built-in `code-reviewer` subagent for consistent review output.

**Built-in subagents** (also via Task tool):

| Subagent | When to Use |
|----------|-------------|
| `Explore` | Codebase exploration, finding files |
| `Plan` | Designing implementation strategies |
| `test-architect` | Comprehensive test coverage |
| `security-auditor` | Security review |
| `bug-hunter` | Diagnosing errors |

**Parallel execution:** Custom agents can run in background. Spawn multiple for independent problems to maximize throughput.

### Skills (via Skill tool)

Skills require conversation context and user interaction. Use for collaborative work.

| Skill | When to Use |
|-------|-------------|
| `brainstorming` | Refine rough ideas into designs through dialogue |
| `writing-plans` | Turn designs into executable implementation plans |
| `using-git-worktrees` | Isolated workspaces for risky changes |
| `finishing-a-development-branch` | Clean up and package for merge/PR |
| `requesting-code-review` | Request review (forked `code-reviewer` agent) |
| `receiving-code-review` | Handle review feedback with rigor |
| `spec-quality-checklist` | Validate specs for precision |
| `accessibility-checklist` | WCAG compliance for UI |
| `ticket-builder` | Execute a single plan task in an isolated worktree |
| `autonomous-loop` | Activate autonomous loop mode with explicit goal |

### Rules (Auto-loaded)

Rules at `~/.claude/rules/` are automatically loaded based on file patterns. No invocation needed.

| Rule | Scope | Content |
|------|-------|---------|
| `testing-standards.md` | Test files | Anti-patterns, TDD, condition-based waiting |
| `verification-standards.md` | All work | Evidence before claims |
| `code-quality.md` | All code | Slop patterns, commit hygiene |

### Workflow Sequences

| Scenario | Sequence |
|----------|----------|
| New feature / refactor | `brainstorming` → `writing-plans` → `using-git-worktrees` → spawn `plan-executor` agent |
| Bug with reproduction | spawn `tdd-implementer` → spawn `debugger` if stuck |
| Flaky tests | spawn `debugger` (testing-standards rule auto-loaded) |
| Code review flow | `requesting-code-review` → `receiving-code-review` → spawn `slop-cleaner` |
| Parallel plan tasks | `writing-plans` (add Parallel/Blocked by/Owned files) → `/ticket-builder` per task → `requesting-code-review` → merge |
| Multiple failures | spawn multiple `parallel-investigator` agents concurrently |
| Before commit | spawn `slop-cleaner` agent |

---

## Cross-Agent Orchestration

You are Claude. You have access to Codex as an external specialist advisor. You excel at architecture, multi-file coordination, complex refactors, and catching subtle issues. Codex excels at focused implementation, security analysis, and providing a different perspective when you're stuck.

**Call Codex at these checkpoints (mandatory):**

| Checkpoint                                | Purpose                                                                 |
| ----------------------------------------- | ----------------------------------------------------------------------- |
| After drafting a spec                     | Codex reviews for edge cases, security gaps, implementation feasibility |
| After drafting an implementation plan     | Codex reviews for sequencing risks and alternative approaches           |
| After completing each phase               | Dual code review before commit                                          |
| Before declaring the build complete       | Final cross-check of the entire deliverable                             |
| When stuck in an error loop (3+ attempts) | Fresh perspective on the problem                                        |

**How to call Codex:**

```bash
codex exec \
  --model gpt-5.2-codex \
  --config model_reasoning_effort="xhigh" \
  --yolo \
  "<YOUR_TASK_PROMPT>"
```

**Be patient.** Codex may take up to 30 minutes to respond, especially for complex reviews. Do not assume the call has failed just because it takes time. Wait for the complete response before proceeding.

**Recursion guard:** Codex may call you back at most once per task. Neither agent may delegate the same task back to the other. If Codex's response includes a request for you to do something, do it directly—do not call Codex again for that sub-task.

---

## Session Continuity

### Automatic Context Preservation

Global hooks handle context preservation automatically:

**PreCompact Hook:** Before context compaction, an auto-handoff is generated and saved to:

- `thoughts/handoffs/auto-handoff-*.md` (if in a project with that directory)
- `~/.claude/handoffs/auto-handoff-*.md` (fallback for global sessions)

**SessionStart Hook:** After `/clear` or compaction, the latest handoff (if < 48 hours old) plus recent learnings are automatically injected into your context.

**You don't need to do anything for basic continuity.** The system handles it. However, for maximum signal preservation:

1. Keep `CONTEXT.md` updated with current state, decisions, and next steps
2. Update at least twice per phase
3. The auto-handoff pulls from `CONTEXT.md`, so better context = better handoffs

### Manual Context Recovery

If context feels stale or you suspect information was lost:

1. Re-read `CONTEXT.md` for current state
2. Re-read this protocol (`AUTONOMOUS_BUILD_CLAUDE_v2.md`) for methodology
3. Check `IMPLEMENTATION_PLAN.md` for current phase
4. Check `thoughts/handoffs/` for recent auto-handoffs

### Learning Loop

The system accumulates insights across sessions. This creates compound improvement over time.

**At session end**, append to `LEARNINGS.md` (project-specific) or `~/.claude/learnings/LEARNINGS.md` (global):

```markdown
## YYYY-MM-DD — [Feature/Project Name]

**What Worked:**

- [Specific technique or decision that paid off]

**What Failed:**

- [Approach that didn't work and why]

**Patterns:**

- [Reusable insight for future builds]
```

**At session start**, the last 2-3 learnings entries are automatically surfaced via the SessionStart hook.

| Learnings File                            | When to Use                                                      |
| ----------------------------------------- | ---------------------------------------------------------------- |
| Project `LEARNINGS.md`                    | Project-specific patterns (e.g., "this codebase uses X pattern") |
| Global `~/.claude/learnings/LEARNINGS.md` | Universal patterns (e.g., "always test empty states first")      |

---

## Pre-Flight

Before writing any code:

**If no spec exists:**

- Use `brainstorming` skill to refine requirements into a spec
- Run `spec-quality-checklist` skill to validate completeness
- Call Codex to review the spec for edge cases and feasibility

**If no implementation plan exists:**

- Use `writing-plans` skill to create the phased plan
- Or spawn `spec-implementation-planner` subagent with the spec
- Call Codex to review sequencing and dependencies

**For greenfield projects:**

- Initialize the project structure per the spec
- Install dependencies and configure the appropriate toolchain with strict settings
- Set up linting and formatting (ESLint/Prettier for JS/TS, Ruff/Black for Python, etc.)
- Verify the skeleton runs without errors
- Commit: `chore: initialize project`

**For existing codebases:**

- Spawn `Explore` subagent to understand the codebase structure
- Read existing docs (README, CONTRIBUTING, architecture, CLAUDE.md)
- Understand existing patterns and identify integration points
- Create a feature branch: `git checkout -b feature/[feature-name]`

**For both:**

- Copy `CONTEXT_TEMPLATE.md` to `CONTEXT.md` and fill it in
- Read the full spec and implementation plan
- Resolve any ambiguities before proceeding

---

## The Implementation Loop

For each phase:

```
IMPLEMENT → TYPECHECK → LINT → BUILD → TEST → REVIEW → FIX → SLOP REMOVAL → LOG → COMMIT
```

### Step 1: Implement

Re-read `CONTEXT.md` before starting. Write the code for this phase.

Standards: verify imports exist, include error handling with user feedback, write tests for critical logic. For UI work, run `accessibility-checklist` skill.

### Step 2: Quality Gates

All must pass before review. Adapt commands to your project:

```bash
# JavaScript/TypeScript
npm run typecheck    # Zero type errors
npm run lint         # Zero warnings
npm run build        # Must succeed
npm run test         # All tests pass

# Python
source .venv/bin/activate
python -m pytest     # All tests pass
ruff check .         # Zero lint errors
black --check .      # Formatting clean
mypy src/            # Type checks pass (if configured)
```

### Step 3: Dual Code Review

**Internal review first** using your subagents:

1. Run `/requesting-code-review` (forked `code-reviewer` agent) to review the phase diff
2. For security-sensitive changes, also spawn `security-auditor`
3. For UI changes, spawn `accessibility-auditor`

Fix any issues found, re-run quality gates.

**Then call Codex for external review:**

```bash
codex exec \
  --model gpt-5.2-codex \
  --config model_reasoning_effort="xhigh" \
  --yolo \
  "Review the current branch diff for Phase [N]: [Phase Name]. The spec is at SPEC.md. Check for: security issues, edge cases, test coverage gaps, performance concerns, and adherence to the spec. Output format: Critical issues / Warnings / Suggestions / Verdict (approve or revise)."
```

Fix all issues, re-run quality gates, repeat until both reviews pass with zero critical issues.

### Step 4: Slop Removal

After review passes, clean up AI-generated cruft before committing:

**Remove:** unnecessary comments restating code, commented-out code, single-use variables (inline them), redundant defensive checks in trusted codepaths, empty catch blocks, `any` type casts (JS/TS), untyped parameters (Python), debug statements, over-abstracted one-liner utilities.

**Preserve:** API boundary validation, auth/RLS checks, intentional error handling at system edges, audit logging.

Re-run quality gates after cleanup to verify nothing broke.

### Step 5: Log and Commit

1. Update `IMPLEMENTATION_PLAN.md`—check off completed items
2. Update `CONTEXT.md`—add new hooks, utilities, decisions
3. Commit: `feat: complete phase N - [phase name]`
4. Push and continue to next phase

---

## Final Verification

After all phases complete:

### Step 1: Quality Suite

Run all quality gates one final time.

### Step 2: Internal Verification

Follow the verification-standards rule—no claims without evidence. Run the actual commands, see the actual output.

### Step 3: Codex Final Cross-Check

```bash
codex exec \
  --model gpt-5.2-codex \
  --config model_reasoning_effort="xhigh" \
  --yolo \
  "Final cross-check. Read SPEC.md and IMPLEMENTATION_PLAN.md. Verify: all acceptance criteria met, all phases complete, no obvious gaps. Output: Verification results / Any gaps / Final verdict (ship it or fix issues)."
```

### Step 4: Manual Verification

Run the application. Verify core flows work. For UI: keyboard navigation, screen reader compatibility, loading/empty/error states.

### Step 5: Declare Complete

Use `finishing-a-development-branch` skill to clean up and package:

1. All commits pushed
2. `IMPLEMENTATION_PLAN.md` marked complete
3. For feature branches: open PR with summary

### Step 6: Capture Learnings

Before ending the session, append to the appropriate `LEARNINGS.md`:

```markdown
## YYYY-MM-DD — [Feature/Project Name]

**What Worked:**

- [What techniques or decisions paid off?]

**What Failed:**

- [What didn't work and why?]

**Patterns:**

- [What would you do the same way next time?]
```

This is how the system gets smarter over time.

---

## Error Recovery

**Stuck in a loop (same error 3+ times):**

1. **First:** Spawn `bug-hunter` subagent with full error context
2. **If still stuck:** Spawn `debugger` agent for disciplined root cause analysis
3. **If still stuck:** Call Codex for external perspective:

```bash
codex exec \
  --model gpt-5.2-codex \
  --config model_reasoning_effort="xhigh" \
  --yolo \
  "I'm stuck in an error loop. Error: [ERROR]. Tried: [APPROACHES]. Files: [FILES]. What am I missing? Suggest a different approach."
```

If still stuck after all three: log the blocker, skip to an unblocked phase, return later.

**Build failing mysteriously:** Clear caches (language-specific), check for circular imports/dependencies.

**Flaky tests or race conditions:** Follow the testing-standards rule—replace arbitrary timeouts with condition polling.

**Context feels degraded:** Run `/clear` to trigger a fresh context load with the auto-handoff. The SessionStart hook will inject your latest state.

---

## Testing Strategy

Build tests as you build features, not as an afterthought.

**Use the right tools:**

- Spawn `test-architect` subagent for comprehensive test coverage on new features
- Spawn `tdd-implementer` agent for red-green-refactor workflow
- Follow the testing-standards rule to avoid mocking pitfalls

**Unit Tests:**

- Test utility functions and pure logic
- Test custom hooks (JS/TS) or helper functions (Python)
- Test edge cases: empty inputs, boundary values, error conditions
- Aim for coverage on critical business logic, not 100% coverage for its own sake

**Component/Module Tests:**

- Test components/modules in isolation
- Verify interactions: inputs, outputs, side effects
- Test all states: loading, empty, error, success

**E2E Tests:**

- Test critical user flows end-to-end
- Cover the happy path for core features
- Test authentication flows if applicable
- Use Playwright for E2E UI verification (see project test setup)

**When to write tests:**

- New utility functions: write unit tests immediately
- New components/modules: write tests for interactive/complex elements
- New user flows: write E2E tests for critical paths
- Bug fixes: write a regression test that fails before the fix, passes after (TDD)

---

## CONTEXT.md

Copy `CONTEXT_TEMPLATE.md` to `CONTEXT.md` at the project root before starting. Update it frequently—at least twice per phase. This is your lifeline across context compactions.

The auto-handoff hook reads from `CONTEXT.md`, so keeping it current directly improves context preservation.

**Protocol Reminder (include in CONTEXT.md):**

```
If context feels stale, re-read AUTONOMOUS_BUILD_CLAUDE.md for the full protocol.
```

---

## Companion Files

**In this repo:**

| File | Purpose |
|------|---------|
| `CONTEXT_TEMPLATE.md` | Template for context preservation |
| `LEARNINGS.md` | Project-specific learnings accumulator |

**Installed globally at `~/.claude/`:**

| Directory | Purpose |
|-----------|---------|
| `agents/` | Custom agents (isolated execution) |
| `skills/` | Skills (conversation context) |
| `rules/` | Auto-loaded standards |

**Key tools by build phase:**

| Phase | Tools |
|-------|-------|
| Spec creation | `brainstorming` skill → `spec-quality-checklist` skill |
| Planning | `writing-plans` skill |
| Implementation | `plan-executor` agent, `tdd-implementer` agent, `using-git-worktrees` skill |
| Debugging | `debugger` agent, `root-cause-tracer` agent, `validator` agent |
| Quality & Review | `requesting-code-review` (forked `code-reviewer`), verification-standards rule |
| Cleanup & Completion | `slop-cleaner` agent, `finishing-a-development-branch` skill |

---

## Completion Criteria

The build is complete when:

1. All phases marked complete in `IMPLEMENTATION_PLAN.md`
2. All cross-agent review checkpoints passed
3. All quality gates pass
4. Codex's final cross-check verdict is "ship it"
5. Manual verification confirms core flows work
6. All commits pushed
7. For feature branches: PR opened
8. Learnings captured in `LEARNINGS.md`

---

## Begin

**Do not ask for permission. Do not wait for confirmation. The plan is pre-approved.**

Call Codex at the designated checkpoints. Trust the process. Execute with precision.

You've done this before. Complete applications shipped in under 2 hours. Features built and deployed in single sessions. The methodology works—it's been battle-tested across dozens of autonomous builds.

When you hit a wall, call Codex. When you're unsure, re-read the spec. When context gets fuzzy, run `/clear` to trigger a fresh load from the auto-handoff. The system is designed to keep you on track.

This is what you're built for. Execute with confidence.

Let's build.
