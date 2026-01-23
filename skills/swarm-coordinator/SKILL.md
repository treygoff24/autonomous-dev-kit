---
name: swarm-coordinator
description: Coordinate multiple Claude Code sessions working on the same project via shared task list. Creates task DAG, assigns work to parallel agents, monitors progress. Use for large implementations that benefit from true parallelism.
context: conversation
skills:
  - writing-plans
  - task-builder
  - requesting-code-review
---

# Swarm Coordinator

Orchestrate multiple Claude Code sessions or agents working on the same project through a shared task list.

## Overview

The swarm coordinator uses `CLAUDE_CODE_TASK_LIST_ID` to enable multiple Claude Code instances to share progress state. Each instance can:
- See all tasks via `TaskList`
- Claim unblocked tasks
- Update task status
- Coordinate without conflicts

## When to Use

- Large implementation with many independent tasks
- Want true parallelism (multiple terminal windows)
- Tasks have clear file ownership (no conflicts)
- Implementation plan includes `Parallel: yes` tasks

## Setup Process

### Step 1: Generate Shared Task List ID

```bash
TASK_LIST_ID="swarm-$(date +%Y%m%d-%H%M%S)"
echo "export CLAUDE_CODE_TASK_LIST_ID=$TASK_LIST_ID"
```

Save this ID - all workers need it.

### Step 2: Create Task DAG from Plan

If IMPLEMENTATION_PLAN.md exists:

1. Read plan and parse tasks manually (agent maintains ID mapping)
2. Create all tasks with `TaskCreate`, recording plan ID → system ID mapping
3. Set up dependencies with `TaskUpdate` using mapped system IDs

Output the task graph for user review.

### Step 3: Launch Worker Sessions

Guide user to open additional terminal windows:

```bash
# Terminal 2 (worker)
export CLAUDE_CODE_TASK_LIST_ID=[same-id]
cd [project]
claude

# Terminal 3 (worker)
export CLAUDE_CODE_TASK_LIST_ID=[same-id]
cd [project]
claude
```

### Step 4: Worker Protocol

Each worker follows this loop:

```
1. TaskList to see available work
2. Find unblocked pending task with no owner
3. TaskUpdate to claim (set owner to session ID)
4. TaskUpdate status to in_progress
5. Implement the task
6. Run tests
7. TaskUpdate status to completed
8. Repeat
```

### Step 5: Orchestrator Monitoring

The coordinator (this session) monitors progress:

```
- TaskList every few minutes to see global state
- Identify stuck tasks (in_progress too long)
- Handle blockers and conflicts
- Run final integration tests when all tasks complete
```

## Task Claiming Protocol

To prevent race conditions:

1. Worker calls `TaskUpdate` with `owner: "session-<id>"` for a pending task
2. If another worker claimed it first, the task will have a different owner
3. Worker checks `TaskGet` to verify ownership before proceeding
4. Only the owner can transition to `in_progress` and `completed`

## Conflict Resolution

If two workers modify the same file:

1. First to complete wins
2. Second worker must rebase/resolve conflicts
3. If conflict is complex, coordinator arbitrates

## Completion

When all tasks are `completed`:

1. Coordinator runs full quality gate suite
2. Integration tests across all changes
3. Final code review via `/requesting-code-review`
4. Merge/squash if using worktrees

## Example Session

```
Coordinator: "Starting swarm for auth-system implementation"

TaskList shows:
#1 [pending] Create user model - ready
#2 [pending] Create auth middleware - ready
#3 [pending] Create login endpoint - blocked by #1, #2
#4 [pending] Create register endpoint - blocked by #1
#5 [pending] Add password hashing - blocked by #1

Coordinator assigns:
- Worker 1: Task #1 (user model)
- Worker 2: Task #2 (auth middleware)

Workers complete, TaskList now shows:
#1 [completed] - by worker-1
#2 [completed] - by worker-2
#3 [pending] - now unblocked!
#4 [pending] - now unblocked!
#5 [pending] - now unblocked!

Coordinator assigns next batch...
```

## Limitations

- Works best with clear task boundaries
- File conflicts require manual resolution
- All workers must have same env setup
- Shared task list requires same `CLAUDE_CODE_TASK_LIST_ID`
