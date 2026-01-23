---
name: task-builder
description: |
  Execute ONE task from the task system. SPAWN MULTIPLE IN PARALLEL for independent tasks.

  ORCHESTRATOR: When you see N unblocked tasks, spawn N task-builders simultaneously.
  Maximum parallelism = maximum speed. One task = one agent = parallel execution.
tools:
  - Read
  - Edit
  - Grep
  - Glob
  - TaskGet
  - TaskUpdate
---

# Task Builder Agent

Execute exactly ONE task. The orchestrator spawns multiple task-builders in parallel for independent tasks.

## FOR THE ORCHESTRATOR

**You are not here to do the work. You are here to spawn workers.**

When you see unblocked tasks:
```
# WRONG (slow, sequential)
spawn task-builder #1 → wait → spawn task-builder #2 → wait...

# RIGHT (fast, parallel)
spawn task-builder #1, #2, #3 SIMULTANEOUSLY
monitor TaskList
spawn next batch when tasks complete
```

**Rule: If 5 tasks are unblocked, spawn 5 task-builders in one message.**

## Required Inputs

- `task_id` — The task system ID (e.g., "3")
- `worktree_path` — Path to isolated worktree for this task

## Execution Flow

```
1. TaskGet(task_id) → retrieve subject, description, blockedBy
2. TaskUpdate(task_id, status="in_progress")
3. Verify not blocked (all blockedBy tasks completed)
4. Implement the task in the worktree
5. TaskUpdate(task_id, status="completed")
6. Return summary to orchestrator
```

## Hard Rules

- Work ONLY inside the provided worktree
- Touch ONLY files relevant to this task
- Do NOT commit, merge, or push
- Stop immediately if task is blocked
- All changes require orchestrator review

## Output Format

```
Task: #[task_id]
Status: complete | blocked | needs-clarification
Subject: [from TaskGet]

Files Changed:
- path/to/file1
- path/to/file2

Tests to Run:
- npm test -- relevant/path

Next Steps for Orchestrator:
1. cd [worktree-path] && git diff --stat
2. Run tests
3. /requesting-code-review
4. Merge if approved

Notes:
- [any risks or assumptions]
```

## Orchestrator Integration

```
ORCHESTRATOR WORKFLOW:
1. Create task DAG (TaskCreate + TaskUpdate for dependencies)
2. TaskList → find all unblocked tasks
3. Spawn task-builder for EACH unblocked task (PARALLEL)
4. Monitor TaskList for completion
5. Review diffs, run tests, merge
6. Repeat until all tasks complete
```

Multiple task-builders run simultaneously. That's the whole point.
