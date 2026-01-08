# Autonomous Build Protocol — Codex Edition

> For building complete applications from scratch OR adding features to existing codebases. Codex drives, Claude advises. Execute with precision.

---

## Maximum Autonomy Warning

This protocol uses `--dangerously-skip-permissions` (Claude) and `--yolo` (Codex) in command examples. These bypass safety prompts and allow tools to run without confirmation.

Use only in trusted repos and isolated environments. Review diffs before committing, avoid running against production systems, and remove those flags if you want approval gates.

---

## Quick Start

```
Read AUTONOMOUS_BUILD_CODEX.md and the spec at [SPEC_PATH]. Build autonomously. Do not stop until complete.
```

If no spec exists, draft a spec first (use brainstorming techniques to refine requirements). If no implementation plan exists, create a phased plan after the spec is approved.

---

## Cross-Agent Orchestration

You are Codex. You have access to Claude as a specialist advisor. Claude excels at architecture, multi-file coordination, complex refactors, and catching subtle issues you might miss. You excel at focused implementation, security analysis, and providing a different perspective.

**Call Claude at these checkpoints (mandatory):**

| Checkpoint | Purpose |
|------------|---------|
| After drafting a spec | Claude reviews for completeness, edge cases, ambiguity |
| After drafting an implementation plan | Claude reviews for sequencing, dependencies, risk |
| After completing each phase | Dual code review before commit |
| Before declaring the build complete | Final cross-check of the entire deliverable |
| When stuck in an error loop (3+ attempts) | Fresh perspective on the problem |

**How to call Claude:**

```bash
claude -p --model opus --dangerously-skip-permissions --output-format text "[YOUR PROMPT HERE]"
```

**Be patient.** Claude may take 30 seconds to several minutes to respond, especially for complex reviews. Do not assume the call has failed just because it takes time. Wait for the complete response before proceeding.

**Waiting discipline for Claude CLI calls:**
- After launching a `claude` command, wait at least 60 seconds before checking for output.
- Keep polling for up to 15 minutes before interrupting.
- Only interrupt (Ctrl+C) after 15+ minutes with no output.
- If you must interrupt, note it in `CONTEXT.md` and retry once with the same prompt.

**Recursion guard:** Claude may call you back at most once per task. Neither agent may delegate the same task back to the other. If Claude's response includes a request for you to do something, do it directly—do not call Claude again for that sub-task.

---

## Context Management

Long sessions cause context loss. Proactive context preservation is critical.

### CONTEXT.md

`CONTEXT.md` is your lifeline. It must contain:
- Current goal and constraints
- What's done vs. what's next
- Key decisions made and why
- Important file paths and utilities
- Current phase in the implementation plan

**Update CONTEXT.md at least twice per phase.** More frequent updates = better recovery if context degrades.

### Context Recovery

If context feels stale or you've lost track:

1. Re-read `CONTEXT.md` for current state
2. Re-read this protocol (`AUTONOMOUS_BUILD_CODEX.md`) for methodology
3. Check `IMPLEMENTATION_PLAN.md` for current phase and progress
4. Review recent git commits: `git log --oneline -10`

### Learning Loop

The system accumulates insights across sessions. This creates compound improvement over time.

**At session end**, append to `LEARNINGS.md` (project-specific) or a global learnings file:

```markdown
## YYYY-MM-DD — [Feature/Project Name]

**What Worked:**
- [Specific technique or decision that paid off]

**What Failed:**
- [Approach that didn't work and why]

**Patterns:**
- [Reusable insight for future builds]
```

**At session start**, read the last 2-3 entries from `LEARNINGS.md` to surface recent patterns.

| Learnings File | When to Use |
|----------------|-------------|
| Project `LEARNINGS.md` | Project-specific patterns (e.g., "this codebase uses X pattern") |
| Global learnings file | Universal patterns (e.g., "always test empty states first") |

---

## Pre-Flight

Before writing any code:

**For greenfield projects:**
- Initialize the project structure per the spec
- Install dependencies and configure TypeScript with strict settings:
  ```json
  {
    "compilerOptions": {
      "strict": true,
      "noUnusedLocals": true,
      "noUnusedParameters": true,
      "noImplicitReturns": true
    }
  }
  ```
- Set up ESLint and Prettier
- Verify the skeleton runs: `npm run dev` starts without errors
- Commit: `chore: initialize project`

**For existing codebases:**
- Read existing docs (README, CONTRIBUTING, architecture)
- Understand existing patterns and identify integration points
- Create a feature branch: `git checkout -b feature/[feature-name]`

**For both:**
- Copy `CONTEXT_TEMPLATE.md` to `CONTEXT.md` and fill it in
- Read recent entries from `LEARNINGS.md` if it exists
- Read the full spec and implementation plan
- Resolve any ambiguities before proceeding

---

## Parallel Tickets (Optional)

If the implementation plan marks tasks as `Parallel: yes` with `Blocked by:` satisfied and non-overlapping `Owned files:`, you can run `/ticket-builder` in isolated worktrees to parallelize execution. Always review diffs in each worktree before merging back.

---

## The Implementation Loop

For each phase:

```
IMPLEMENT → TYPECHECK → LINT → BUILD → TEST → REVIEW → FIX → SLOP REMOVAL → LOG → COMMIT
```

### Step 1: Implement

Re-read `CONTEXT.md` before starting. Write the code for this phase.

Standards: verify imports exist, add default exports to pages, include error handling with user feedback, write tests for critical logic. For UI work, run accessibility checks (keyboard nav, focus styles, ARIA labels, color contrast).

### Step 2: Quality Gates

All must pass before review:

```bash
npm run typecheck    # Zero type errors
npm run lint         # Zero warnings
npm run build        # Must succeed
npm run test         # All tests pass
```

### Step 3: Dual Code Review

Self-review first, then call Claude with `/requesting-code-review` (forked `code-reviewer` agent):

```bash
claude -p --model opus --dangerously-skip-permissions --output-format text \
  "/requesting-code-review Review the current branch diff for Phase [N]: [Phase Name]. Review against: the spec at SPEC.md, the implementation plan, security best practices, accessibility, and edge cases. Output: Critical issues / Warnings / Suggestions / Verdict (approve or revise)."
```

Fix all issues, re-run quality gates, repeat until approved with zero issues.

### Step 4: Slop Removal

After review passes, clean up AI-generated cruft before committing:

**Remove:** unnecessary comments restating code, commented-out code, single-use variables (inline them), redundant defensive checks in trusted codepaths, empty catch blocks, `any` type casts, console.log/debug statements, over-abstracted one-liner utilities.

**Preserve:** API boundary validation, RLS/auth checks, intentional error handling at system edges, audit logging.

Run `npm run typecheck && npm run lint` after cleanup to verify nothing broke.

### Step 5: Log and Commit

1. Update `IMPLEMENTATION_PLAN.md`—check off completed items
2. Update `CONTEXT.md`—add new hooks, utilities, decisions
3. Commit: `feat: complete phase N - [phase name]`
4. Push and continue to next phase

---

## Final Verification

After all phases complete:

### Step 1: Quality Suite

```bash
npm run typecheck && npm run lint && npm run build && npm run test
```

### Step 2: Claude Final Cross-Check

```bash
claude -p --model opus --dangerously-skip-permissions --output-format text \
  "Perform a final cross-check of this build. Read SPEC.md and IMPLEMENTATION_PLAN.md. Verify all acceptance criteria are met, all phases complete, application runs correctly. Output: Verification results / Any gaps / Final verdict (ship it or fix issues)."
```

### Step 3: Manual Verification

Run the application. Verify core flows work. For UI: keyboard navigation, screen reader compatibility, loading/empty/error states.

### Step 4: Declare Complete

1. All commits pushed
2. `IMPLEMENTATION_PLAN.md` marked complete
3. For feature branches: open PR with summary

### Step 5: Capture Learnings

Before ending the session, append to `LEARNINGS.md`:

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

```bash
claude -p --model opus --dangerously-skip-permissions --output-format text \
  "I'm stuck in an error loop. The error is: [ERROR]. I've tried: [APPROACHES]. The relevant code is in [FILES]. Help me understand what's actually wrong and suggest a different approach."
```

If still stuck: log the blocker, skip to an unblocked phase, return later.

**Build failing mysteriously:** Clear caches (`rm -rf node_modules .next dist .vite && npm install`), check for circular imports.

**Context feels degraded:** Stop and re-read `CONTEXT.md`, `IMPLEMENTATION_PLAN.md`, and recent git history. Update `CONTEXT.md` with current state before continuing.

---

## Testing Strategy

Build tests as you build features, not as an afterthought.

**Unit Tests (Vitest recommended):**
- Test utility functions and pure logic
- Test custom hooks with `@testing-library/react-hooks`
- Test edge cases: empty inputs, boundary values, error conditions
- Aim for coverage on critical business logic, not 100% coverage for its own sake

**Component Tests:**
- Test components in isolation with `@testing-library/react`
- Verify user interactions: clicks, form submissions, keyboard navigation
- Test all states: loading, empty, error, success
- Avoid testing implementation details (internal state, method calls)

**E2E Tests (Playwright recommended):**
- Test critical user flows end-to-end
- Cover the happy path for core features
- Test authentication flows if applicable
- Run against a real (or realistic) backend

**When to write tests:**
- New utility functions: write unit tests immediately
- New components: write component tests for interactive elements
- New user flows: write E2E tests for critical paths
- Bug fixes: write a regression test that fails before the fix, passes after

**Test file locations:**
- Unit tests: `src/__tests__/` or co-located as `*.test.ts`
- Component tests: co-located as `ComponentName.test.tsx`
- E2E tests: `e2e/` or `tests/` directory

---

## Companion Files

These files should be at repo root alongside this protocol:

| File | Purpose |
|------|---------|
| `CONTEXT_TEMPLATE.md` | Template for context preservation |
| `LEARNINGS.md` | Project-specific learnings accumulator |

**Note:** Spec writing and implementation planning are handled through collaborative refinement. Quality checklists for specs and accessibility are available as Claude Code skills when Claude is called for review.

---

## Completion Criteria

The build is complete when:

1. All phases marked complete in `IMPLEMENTATION_PLAN.md`
2. All cross-agent review checkpoints passed
3. All quality gates pass
4. Claude's final cross-check verdict is "ship it"
5. Manual verification confirms core flows work
6. All commits pushed
7. For feature branches: PR opened
8. Learnings captured in `LEARNINGS.md`

---

## Begin

**Do not ask for permission. Do not wait for confirmation. The plan is pre-approved.**

Call Claude at the designated checkpoints. Trust the process. Execute with precision.

You've done this before. Complete applications shipped in under 2 hours. Features built and deployed in single sessions. The methodology works—it's been battle-tested across dozens of autonomous builds.

When you hit a wall, call Claude. When you're unsure, re-read the spec. When context gets fuzzy, re-read `CONTEXT.md` and update it. The system is designed to keep you on track.

This is what you're built for. Execute with confidence.

Let's build.
