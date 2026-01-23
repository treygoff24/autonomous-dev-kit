---
name: ticket-builder
description: Execute a single task from the task system in an isolated worktree. Spawns ticket-builder agent which uses TaskGet/TaskUpdate for progress tracking. Use for parallel-safe tasks.
context: fork
agent: ticket-builder
skills:
  - requesting-code-review
  - using-git-worktrees
---

# Ticket Builder

Execute one task from the task system in a fresh, isolated agent context. The agent integrates with Claude Code's task system—it calls `TaskGet` to retrieve task details and `TaskUpdate` to mark progress.

## When to Use

- You've created a task DAG via TaskCreate/TaskUpdate
- The task is unblocked (no incomplete dependencies)
- You want parallel execution of independent tasks
- The task has clear file ownership (no conflicts with other tasks)

## Required Inputs

**For task-system execution (recommended):**
```
task_id: "3"                              # System ID from TaskCreate
worktree_path: "../project-worktree"      # Isolated worktree
```

**For plan-based execution (fallback):**
```
task_identifier: "Phase 3, Task 3.2"      # From IMPLEMENTATION_PLAN.md
worktree_path: "../project-worktree"
file_ownership: [list of files]           # From plan's "Owned files" field
```

## What the Agent Does

1. **TaskGet** — Retrieves task subject, description, blockedBy
2. **TaskUpdate** — Marks task `in_progress`
3. **Implements** — Works only in the provided worktree
4. **TaskUpdate** — Marks task `completed`
5. **Returns** — Summary with files changed, tests to run

The agent does NOT commit, merge, or push. You review and integrate.

## Parallel Execution Pattern

```
# Orchestrator creates DAG
TaskCreate(...) → #1
TaskCreate(...) → #2
TaskCreate(...) → #3
TaskUpdate(#3, addBlockedBy=[#1, #2])

# Spawn parallel ticket-builders for unblocked tasks
/ticket-builder task_id=1 worktree=../wt-task-1
/ticket-builder task_id=2 worktree=../wt-task-2

# Monitor progress
TaskList → see #1 and #2 in_progress

# When complete, #3 becomes unblocked
/ticket-builder task_id=3 worktree=../wt-task-3
```

## Example Workflow

```bash
# 1. Create isolated worktree
git worktree add ../project-task-3 feature/task-3

# 2. Invoke ticket-builder with task_id
/ticket-builder task_id=3 worktree_path=../project-task-3

# 3. Agent implements, marks complete via TaskUpdate

# 4. Review the diff (orchestrator does this)
cd ../project-task-3
git diff --stat
npm test
/requesting-code-review

# 5. If approved, merge back
git checkout main
git merge feature/task-3
git worktree remove ../project-task-3
```

## Review Gate (Mandatory)

All changes require orchestrator review before integration:

1. Agent returns summary with files changed
2. Orchestrator runs tests in worktree
3. Orchestrator runs `/requesting-code-review`
4. Only merge after approval

## Forked Context Behavior

- The agent runs in isolated context (doesn't see main conversation)
- Provide all required inputs up front
- Agent has TaskGet/TaskUpdate but no Bash (orchestrator runs tests)

## Output Expectations

```
Ticket: #3
Status: complete
Task: Create auth middleware

Files Changed:
- src/middleware/auth.ts
- src/middleware/index.ts

Tests to Run:
- npm test -- src/middleware

Next Steps for Orchestrator:
1. cd ../project-task-3
2. git diff --stat
3. npm test -- src/middleware
4. /requesting-code-review
5. Merge if approved
```

## Cleanup

**If review fails:**
```bash
cd [worktree-path]
git restore -SW .
# Fix issues, re-run /ticket-builder
```

**If abandoning:**
```bash
git worktree remove ../project-task-3 --force
```
