---
name: ticket-builder
description: Build a single implementation-plan task in a forked ticket-builder agent. Use for parallel-safe tasks only.
context: fork
agent: ticket-builder
---

# Ticket Builder

Use this skill to execute one implementation plan task in a fresh, isolated agent context.

The ticket builder runs without Bash permissions; the orchestrator handles git diffs and test commands in the worktree.

## Forked Context Behavior

- The agent runs in an isolated context and does not see the main conversation history
- Provide all required inputs up front
- The agent may ask clarifying questions, but it cannot see prior chat unless you restate it

## When to Use

- The plan task is marked **Parallel: yes**
- All tasks listed in **Blocked by** are complete
- The task has clear file ownership and acceptance criteria

## Required Inputs

Provide these before starting:
- Task identifier (e.g., Phase 3, Task 3.2)
- Worktree path to operate in
- Any constraints or file ownership notes from the plan
- Ensure `SPEC.md` and `IMPLEMENTATION_PLAN.md` are present in the worktree for review context
- Verify the worktree exists and is clean before invoking this skill

## Review Gate (Mandatory)

This agent must NOT commit, merge, or push. All changes must be reviewed by the orchestrator before integration:

1. Run `/requesting-code-review` against the ticket diff
2. Merge or cherry-pick only after review approval

Run `/requesting-code-review` from the worktree so the diff includes the ticket changes. The orchestrator should run tests and diff commands inside the worktree.

## Test Authorization

By default, the orchestrator runs tests in the worktree. Only authorize the ticket builder to run tests if you temporarily add `Bash` to the agent definition.

## Output Expectations

The agent will return:
- Task status
- Files changed
- Tests to run (not executed unless authorized)
- Reminder to run `git status -sb` and `git diff --stat` in the worktree
- Next steps reminder for review and tests

## Example Workflow

```bash
# 1. Create isolated worktree
git worktree add ../project-task-3-2 feature/task-3-2 || { echo "Failed to create worktree"; exit 1; }
cd ../project-task-3-2 && git status -sb

# 2. Invoke ticket-builder
/ticket-builder
# Provide: Task 3.2, worktree path, file ownership notes

# 3. Review the diff
cd ../project-task-3-2
git status -sb
git diff --stat
npm test
/requesting-code-review

# 4. If approved, merge back
git checkout main
git merge feature/task-3-2
git worktree remove ../project-task-3-2  # Use --force only to discard unmerged changes
```

## Cleanup Scenarios

**If review fails:**
```bash
cd [worktree-path]
git restore -SW .
# Fix issues and re-run /ticket-builder
```

**If abandoning the worktree:**
```bash
cd [main-repo]
git worktree remove ../project-task-3-2 --force
```
