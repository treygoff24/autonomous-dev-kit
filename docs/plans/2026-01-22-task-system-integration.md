# Task System Integration Implementation Plan

> **For Claude:** Spawn `task-plan-executor` agent to implement this plan task-by-task.

**Goal:** Integrate Claude Code's new task management system (TaskCreate, TaskUpdate, TaskList, TaskGet) throughout the autonomous dev kit, enabling parallel execution, cross-session coordination, and persistent progress tracking.

**Architecture:** The task system becomes the source of truth for implementation progress. Plans are parsed into task DAGs with dependencies. Multiple sessions can coordinate via shared task lists (`CLAUDE_CODE_TASK_LIST_ID`). The pre-compact hook preserves task state for continuity.

**Tech Stack:** Bash (hooks, utilities), Markdown (agents, skills), JSON (task storage at `~/.claude/tasks/<id>/`)

---

## Phase 1: Task-Aware Hooks (Foundation)

### Task 1.1: Update Pre-Compact Hook

**Parallel:** no
**Blocked by:** none
**Owned files:** `hooks/pre-compact.sh`

**Files:**
- Modify: `hooks/pre-compact.sh`

**Step 1: Read existing hook**

Run: `cat hooks/pre-compact.sh`
Understand current structure: gathers git info, CONTEXT.md, writes handoff.

**Step 2: Add task list state capture**

After the git info section (around line 57), add task list capture:

```bash
# Source task helpers for safe task list reading
TASK_INFO=""
if [[ -f "$HOME/.claude/lib/task-helpers.sh" ]]; then
    source "$HOME/.claude/lib/task-helpers.sh"

    # Get task summary using validated, safe helpers
    TASK_INFO=$(get_task_handoff_summary "$CLAUDE_PROJECT_DIR")
fi
```

**Step 3: Include task info in handoff output**

After the git info section in the output block (around line 84), add:

```bash
    # Include task list state
    if [[ -n "$TASK_INFO" ]]; then
        echo "$TASK_INFO"
        echo "---"
        echo ""
    fi
```

**Step 4: Test the hook**

Run: `cd /Users/treygoff/Code/autonomous-dev-kit && ./hooks/pre-compact.sh < /dev/null`
Expected: Hook runs without error, outputs handoff content.

**Step 5: Commit**

```bash
git add hooks/pre-compact.sh
git commit -m "feat(hooks): add task list state to pre-compact handoff"
```

---

### Task 1.2: Update Session-Start Hook

**Parallel:** no
**Blocked by:** Task 1.1
**Owned files:** `hooks/session-start.sh`

**Files:**
- Modify: `hooks/session-start.sh`

**Step 1: Read existing hook**

Run: `cat hooks/session-start.sh`

**Step 2: Add task list restoration hint**

After injecting the handoff content, add a reminder about task state:

```bash
# Add task list hint if task state was in handoff
if grep -q "Task List State" "$HANDOFF_FILE" 2>/dev/null; then
    CONTEXT="$CONTEXT

## Task List Hint

Task state was captured in the handoff above. Use \`TaskList\` to see current tasks and \`TaskGet <id>\` for details. Continue from the in-progress task if one exists."
fi
```

**Step 3: Test the hook**

Run: `cd /Users/treygoff/Code/autonomous-dev-kit && ./hooks/session-start.sh < /dev/null`
Expected: Hook runs without error.

**Step 4: Commit**

```bash
git add hooks/session-start.sh
git commit -m "feat(hooks): add task list hint to session-start"
```

---

## Phase 2: Task Utilities (Core Library)

### Task 2.1: Create Task Helper Functions

**Parallel:** no
**Blocked by:** Phase 1
**Owned files:** `hooks/lib/task-helpers.sh`

**Files:**
- Create: `hooks/lib/task-helpers.sh`

**Step 1: Create the helper library**

This library provides safe, robust functions for reading task state. Note: We do NOT create a markdown parser - the agent reads plans directly and calls TaskCreate, maintaining its own ID mapping.

```bash
#!/usr/bin/env bash
#
# task-helpers.sh - Safe task list reading utilities
#
# These functions READ task state for display purposes.
# Task creation/updates are done by Claude via TaskCreate/TaskUpdate tools.
#

# Validate task list ID is a safe UUID pattern (prevents path traversal)
# Returns 0 if valid, 1 if invalid
validate_task_list_id() {
    local id="$1"
    # Convert to lowercase for case-insensitive matching
    local lower_id="${id,,}"
    # Must match UUID pattern: 8-4-4-4-12 hex chars, or swarm-YYYYMMDD-HHMMSS
    if [[ "$lower_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || \
       [[ "$lower_id" =~ ^swarm-[0-9]{8}-[0-9]{6}$ ]]; then
        return 0
    fi
    return 1
}

# Get task list ID for current project
# Priority: 1) CLAUDE_CODE_TASK_LIST_ID env var, 2) .claude/task-list-id file
# Returns empty string if no valid task list found
get_task_list_id() {
    local project_path="${1:-$(pwd)}"
    local task_list_id="${CLAUDE_CODE_TASK_LIST_ID:-}"

    # Try project-local marker if env var not set
    if [[ -z "$task_list_id" ]] && [[ -f "$project_path/.claude/task-list-id" ]]; then
        task_list_id=$(cat "$project_path/.claude/task-list-id" 2>/dev/null | tr -d '[:space:]')
    fi

    # Validate before returning
    if [[ -n "$task_list_id" ]] && validate_task_list_id "$task_list_id"; then
        echo "$task_list_id"
    fi
}

# Get task directory path (validated)
# Returns empty string if invalid or doesn't exist
get_task_dir() {
    local task_list_id
    task_list_id=$(get_task_list_id "$@")

    [[ -z "$task_list_id" ]] && return

    local task_dir="$HOME/.claude/tasks/$task_list_id"
    [[ -d "$task_dir" ]] && echo "$task_dir"
}

# Get task summary using single jq pass for robustness
# Output: "completed/total complete (pending pending, in_progress active)"
get_task_summary() {
    local task_dir
    task_dir=$(get_task_dir "$@")

    [[ -z "$task_dir" ]] && echo "No task list" && return

    # Check if any JSON files exist (handle empty glob)
    shopt -s nullglob
    local files=("$task_dir"/*.json)
    shopt -u nullglob

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No tasks"
        return
    fi

    # Single jq -s pass over all task files with error handling
    jq -s '
        if length == 0 then "No tasks"
        else
            (map(select(.status == "completed")) | length) as $completed |
            (map(select(.status == "pending")) | length) as $pending |
            (map(select(.status == "in_progress")) | length) as $in_progress |
            "\($completed)/\(length) complete (\($pending) pending, \($in_progress) active)"
        end
    ' "${files[@]}" 2>/dev/null || echo "Error reading tasks"
}

# Get current in-progress task subject
# Output: task subject or empty string
get_current_task() {
    local task_dir
    task_dir=$(get_task_dir "$@")

    [[ -z "$task_dir" ]] && return

    # Find first in_progress task
    jq -s '
        map(select(.status == "in_progress")) |
        if length > 0 then .[0] | "Task #\(.id): \(.subject)" else "" end
    ' "$task_dir"/*.json 2>/dev/null | tr -d '"'
}

# Check if all tasks are completed
# Returns 0 if complete (or no tasks), 1 if incomplete
check_task_completion() {
    local task_dir
    task_dir=$(get_task_dir "$@")

    [[ -z "$task_dir" ]] && return 0  # No tasks = complete

    # Check if any JSON files exist (handle empty glob)
    shopt -s nullglob
    local files=("$task_dir"/*.json)
    shopt -u nullglob

    [[ ${#files[@]} -eq 0 ]] && return 0  # No task files = complete

    local incomplete
    incomplete=$(jq -s '
        map(select(.status != "completed")) | length
    ' "${files[@]}" 2>/dev/null)

    [[ "$incomplete" == "0" ]] && return 0
    return 1
}

# Get full task summary for handoff (multiline)
get_task_handoff_summary() {
    local task_dir
    task_dir=$(get_task_dir "$@")

    [[ -z "$task_dir" ]] && return

    local task_list_id
    task_list_id=$(get_task_list_id "$@")

    echo "## Task List State"
    echo ""
    echo "**Task List ID:** \`$task_list_id\`"
    echo "**Progress:** $(get_task_summary "$@")"

    local current
    current=$(get_current_task "$@")
    if [[ -n "$current" ]]; then
        echo "**Current Task:** $current"
    fi
}
```

**Step 2: Make executable and test**

```bash
chmod +x hooks/lib/task-helpers.sh
source hooks/lib/task-helpers.sh

# Test validation
validate_task_list_id "c84d12c4-40af-4958-bd24-90566f637b87" && echo "valid"
validate_task_list_id "../../../etc" || echo "invalid (good!)"

# Test with real tasks (if any exist)
get_task_summary
```

**Step 3: Commit**

```bash
git add hooks/lib/task-helpers.sh
git commit -m "feat(lib): add safe task helper functions with validation"
```

---

## Phase 3: Task-Based Plan Executor Agent

### Task 3.1: Create Task-Aware Plan Executor Agent

**Parallel:** no
**Blocked by:** Phase 2
**Owned files:** `agents/task-plan-executor.md`

**Files:**
- Create: `agents/task-plan-executor.md`

**Step 1: Create the agent definition**

```markdown
---
name: task-plan-executor
description: Execute implementation plans using Claude Code's task system. Creates task DAG from plan, enables parallel execution of independent tasks, tracks progress via TaskUpdate. Use instead of plan-executor for plans with Parallel/Blocked by fields.
model: sonnet
tools:
  - Read
  - Edit
  - Grep
  - Glob
  - Bash
  - Task
  - TaskCreate
  - TaskList
  - TaskGet
  - TaskUpdate
skills:
  - ticket-builder
  - requesting-code-review
  - finishing-a-development-branch
hooks:
  Stop:
    - type: prompt
      model: sonnet
      prompt: |
        You are about to exit the task-plan-executor agent. Verify the plan was executed completely.

        ## Verification (Do ALL of these)

        1. **Check task completion:**
           - Run `TaskList` — are there any tasks not marked `completed`?
           - Were any tasks skipped or left in_progress?

        2. **Run quality gates NOW:**
           - FIRST check if `.claude-quality-gates` exists — if so, run each command in that file
           - ONLY if no `.claude-quality-gates`: run `npm run typecheck && npm run lint && npm run test`
           - Any failures = you're not done.

        3. **Check for shortcuts:**
           - Any "will fix later" or "TODO" items added during execution?
           - Any tests skipped or marked `.skip`?
           - Any lint warnings suppressed instead of fixed?

        ## Decision

        If any tasks are incomplete or quality gates fail:
        - **BLOCK EXIT** — State what's unfinished and continue working.

        If all tasks complete and gates pass:
        - **ALLOW EXIT** — The plan is fully executed.
---

# Task-Based Plan Executor Agent

You execute implementation plans using Claude Code's task system for progress tracking and parallel execution.

## The Process

### 1. Load Plan and Create Task DAG

Read the plan file at the path provided. Parse tasks manually (do NOT use external parser scripts).

**ID Mapping is Critical:** Plan tasks use IDs like "1.1", "2.1", etc. TaskCreate returns system IDs like "1", "2", "3". You MUST maintain a mapping.

1. **First pass - Create all tasks and build ID map:**
   ```
   plan_id_to_system_id = {}

   For each task in plan:
     result = TaskCreate(subject, description, activeForm)
     plan_id_to_system_id["1.1"] = result.system_id  # e.g., "1"
   ```

2. **Second pass - Set up dependencies using the ID map:**
   ```
   For each task with "Blocked by: Task 1.1, Task 1.2":
     system_blockers = [plan_id_to_system_id["1.1"], plan_id_to_system_id["1.2"]]
     TaskUpdate(task_system_id, addBlockedBy=system_blockers)
   ```

3. **Report the task graph with both IDs for clarity:**
   ```
   Task DAG created (plan ID → system ID):
   - Task 1.1 → #1: [name] (ready)
   - Task 1.2 → #2: [name] (blocked by #1)
   - Task 2.1 → #3: [name] (blocked by #1, #2)
   ```

**Note:** "Phase N" blockers like "Blocked by: Phase 1" mean blocked by ALL tasks in that phase. Expand to individual task IDs.

### 2. Execute Unblocked Tasks

Loop until all tasks complete:

**a) Find next task**
- Run `TaskList` to see current state
- Pick an unblocked `pending` task (no incomplete blockers)
- If multiple tasks are unblocked and marked `Parallel: yes`, spawn parallel agents

**b) Claim and execute**
- `TaskUpdate` status to `in_progress`
- Implement the task per its spec
- Run quality gates after each task

**c) Complete task**
- `TaskUpdate` status to `completed`
- This automatically unblocks dependent tasks

### 3. Parallel Execution

When multiple tasks are unblocked simultaneously and marked `Parallel: yes`:

1. Verify no file ownership conflicts (check `Owned files`)
2. Spawn `ticket-builder` agent for each parallel task
3. Each agent updates its own task status
4. Wait for all parallel tasks to complete before proceeding to dependent tasks

### 4. Quality Gates Between Tasks

After each task completion:
```bash
npm run typecheck && npm run lint && npm run test
# or project-specific gates from .claude-quality-gates
```

**If gates fail:** Fix before proceeding. Do not accumulate broken state.

### 5. Final Report

```
Plan: [name]
Tasks: X/Y complete
Quality Gates: PASS | FAIL
Task Summary:
  #1: [name] - completed
  #2: [name] - completed
  ...
```

## Red Flags

Never:
- Skip quality gates between tasks
- Mark task complete with failing tests
- Execute blocked tasks before blockers complete
- Run parallel tasks with overlapping file ownership

## Output Format

For each task:
```
Task #N: [name]
Status: COMPLETE | BLOCKED | IN_PROGRESS
Tests: X passing, Y failing
Files: [list]
Notes: [any issues]
```
```

**Step 2: Commit**

```bash
git add agents/task-plan-executor.md
git commit -m "feat(agents): add task-plan-executor with DAG support"
```

---

## Phase 4: Swarm Coordinator Skill

### Task 4.1: Create Swarm Coordinator Skill

**Parallel:** yes
**Blocked by:** Phase 3
**Owned files:** `skills/swarm-coordinator/SKILL.md`

**Files:**
- Create: `skills/swarm-coordinator/SKILL.md`

**Step 1: Create skill directory**

Run: `mkdir -p skills/swarm-coordinator`

**Step 2: Create the skill definition**

```markdown
---
name: swarm-coordinator
description: Coordinate multiple Claude Code sessions working on the same project via shared task list. Creates task DAG, assigns work to parallel agents, monitors progress. Use for large implementations that benefit from true parallelism.
context: conversation
skills:
  - writing-plans
  - ticket-builder
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
```

**Step 3: Commit**

```bash
git add skills/swarm-coordinator/
git commit -m "feat(skills): add swarm-coordinator for multi-session coordination"
```

---

## Phase 5: Enhanced Autonomous Loop

### Task 5.1: Update Autonomous Loop Skill

**Parallel:** yes
**Blocked by:** Phase 3
**Owned files:** `skills/autonomous-loop/SKILL.md`

**Files:**
- Modify: `skills/autonomous-loop/SKILL.md`

**Step 1: Read current skill**

Run: `cat skills/autonomous-loop/SKILL.md`

**Step 2: Add task-aware completion checking**

In the Stop hook prompt, add task system verification after the git status check:

```markdown
        1b. **Check task list (if tasks exist):**
            - Run `TaskList` — are there pending or in_progress tasks?
            - If task list exists and has incomplete tasks, you're not done.
            - Task system takes precedence over IMPLEMENTATION_PLAN.md checkboxes.
```

**Step 3: Add task integration to activation steps**

After "Initialize Loop State", add:

```markdown
### Step 2b: Create Task DAG (if plan exists)

If IMPLEMENTATION_PLAN.md exists and contains tasks with `Parallel:` and `Blocked by:` fields:

1. Parse plan into task objects
2. Create tasks with `TaskCreate`
3. Set dependencies with `TaskUpdate`
4. Report: "Task DAG created with N tasks, M ready to start"

This enables:
- Progress tracking via task status
- Parallel execution of independent tasks
- Clear completion criteria (all tasks completed)
```

**Step 4: Commit**

```bash
git add skills/autonomous-loop/SKILL.md
git commit -m "feat(skills): add task system integration to autonomous-loop"
```

---

### Task 5.2: Update Loop Helpers Library

**Parallel:** yes
**Blocked by:** Phase 2
**Owned files:** `hooks/lib/loop-helpers.sh`

**Files:**
- Modify: `hooks/lib/loop-helpers.sh`

**Step 1: Read current helpers**

Run: `cat hooks/lib/loop-helpers.sh`

**Step 2: Source task-helpers and add task-aware completion**

At the top of the file, add:

```bash
# Source task helpers for safe task list operations
[[ -f "$HOME/.claude/lib/task-helpers.sh" ]] && source "$HOME/.claude/lib/task-helpers.sh"
```

The `check_task_completion` and `get_task_summary` functions are now provided by `task-helpers.sh`. Update any existing functions in loop-helpers.sh to delegate to the task-helpers versions.

**Step 3: Commit**

```bash
git add hooks/lib/loop-helpers.sh
git commit -m "feat(lib): integrate task-helpers into loop-helpers"
```

---

## Phase 6: Status Line Enhancement

### Task 6.1: Create Task-Aware Status Line

**Parallel:** no
**Blocked by:** Phase 5
**Owned files:** `hooks/statusline-task.sh`

**Files:**
- Create: `hooks/statusline-task.sh`

**Step 1: Create enhanced status line script**

```bash
#!/usr/bin/env bash
#
# statusline-task.sh - Status line with task progress
# Shows: [3/12] Working on auth flow...
#

# Source task helpers for safe, validated task reading
if [[ -f "$HOME/.claude/lib/task-helpers.sh" ]]; then
    source "$HOME/.claude/lib/task-helpers.sh"

    # Get validated task dir
    TASK_DIR=$(get_task_dir)

    if [[ -n "$TASK_DIR" ]]; then
        # Use single jq pass for efficiency and robustness
        SUMMARY=$(jq -s '
            if length == 0 then null
            else
                (map(select(.status == "completed")) | length) as $completed |
                (map(select(.status == "in_progress")) | first | .activeForm // .subject // null) as $current |
                {completed: $completed, total: length, current: $current}
            end
        ' "$TASK_DIR"/*.json 2>/dev/null)

        if [[ "$SUMMARY" != "null" ]] && [[ -n "$SUMMARY" ]]; then
            COMPLETED=$(echo "$SUMMARY" | jq -r '.completed')
            TOTAL=$(echo "$SUMMARY" | jq -r '.total')
            CURRENT=$(echo "$SUMMARY" | jq -r '.current // empty')

            OUTPUT="[$COMPLETED/$TOTAL]"
            [[ -n "$CURRENT" ]] && OUTPUT="$OUTPUT $CURRENT"
            echo "$OUTPUT"
            exit 0
        fi
    fi
fi

# Fallback to git branch
git branch --show-current 2>/dev/null || echo ""
```

**Step 2: Make executable**

Run: `chmod +x hooks/statusline-task.sh`

**Step 3: Add installation to install.sh**

Add to the hook setup section:

```bash
# Copy status line script
cp "$SCRIPT_DIR/hooks/statusline-task.sh" "$HOME/.claude/statusline-task.sh"
chmod +x "$HOME/.claude/statusline-task.sh"
```

**Step 4: Commit**

```bash
git add hooks/statusline-task.sh
git commit -m "feat(hooks): add task-aware status line script"
```

---

## Phase 7: Documentation and Integration

### Task 7.1: Update CLAUDE.md

**Parallel:** no
**Blocked by:** Phase 6
**Owned files:** `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add task system section**

Add after "Hooks" section:

```markdown
## Task System Integration

The kit integrates with Claude Code's task management system for progress tracking and parallel execution.

### Key Concepts

- **Task DAG**: Plans are parsed into task graphs with dependencies
- **Parallel Execution**: Independent tasks can run simultaneously
- **Shared Task Lists**: Multiple sessions coordinate via `CLAUDE_CODE_TASK_LIST_ID`
- **Progress Persistence**: Task state survives context compaction

### New Components

| Component | Type | Purpose |
|-----------|------|---------|
| `task-plan-executor` | Agent | Execute plans using task system |
| `swarm-coordinator` | Skill | Multi-session coordination |
| `task-helpers.sh` | Library | Safe task reading with validation |
| `statusline-task.sh` | Hook | Show task progress in status line |

### Workflow

1. Create implementation plan with `Parallel:` and `Blocked by:` fields
2. Use `/swarm-coordinator` for multi-session work, or
3. Spawn `task-plan-executor` agent for single-session execution
4. Tasks are created, dependencies tracked, progress persisted
5. Pre-compact hook captures task state for continuity
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add task system integration documentation"
```

---

### Task 7.2: Update README.md

**Parallel:** yes
**Blocked by:** Task 7.1
**Owned files:** `README.md`

**Files:**
- Modify: `README.md`

**Step 1: Add task system to features**

In the features section, add:

```markdown
### Task System Integration (New in v2.0)

- **Task-Based Progress**: Plans become task DAGs with dependencies
- **Parallel Execution**: Run independent tasks simultaneously
- **Multi-Session Coordination**: Share task lists across Claude Code instances
- **Persistent State**: Task progress survives context compaction
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add task system features to README"
```

---

### Task 7.3: Update Install Script

**Parallel:** yes
**Blocked by:** Phase 6
**Owned files:** `install.sh`

**Files:**
- Modify: `install.sh`

**Step 1: Add new files to installation**

In the `setup_claude_directory` function, add:

```bash
# Copy task helpers library
cp "$SCRIPT_DIR/hooks/lib/task-helpers.sh" "$HOME/.claude/lib/task-helpers.sh"
chmod +x "$HOME/.claude/lib/task-helpers.sh"

# Copy task status line
cp "$SCRIPT_DIR/hooks/statusline-task.sh" "$HOME/.claude/statusline-task.sh"
chmod +x "$HOME/.claude/statusline-task.sh"
```

Add new agent and skill:

```bash
# Copy task-plan-executor agent
cp "$SCRIPT_DIR/agents/task-plan-executor.md" "$HOME/.claude/agents/task-plan-executor.md"

# Copy swarm-coordinator skill
mkdir -p "$HOME/.claude/skills/swarm-coordinator"
cp "$SCRIPT_DIR/skills/swarm-coordinator/SKILL.md" "$HOME/.claude/skills/swarm-coordinator/SKILL.md"
```

**Step 2: Test dry run**

Run: `./install.sh --dry-run`
Expected: No errors, shows what would be installed.

**Step 3: Commit**

```bash
git add install.sh
git commit -m "feat(install): add task system components to installer"
```

---

## Phase 8: Final Verification

### Task 8.1: End-to-End Test

**Parallel:** no
**Blocked by:** Phase 7
**Owned files:** none (testing only)

**Step 1: Run installer**

```bash
./install.sh
```

**Step 2: Verify components installed**

```bash
ls -la ~/.claude/agents/task-plan-executor.md
ls -la ~/.claude/skills/swarm-coordinator/
ls -la ~/.claude/lib/task-helpers.sh
ls -la ~/.claude/statusline-task.sh
```

**Step 3: Test task helpers**

```bash
source ~/.claude/lib/task-helpers.sh

# Test validation (should work)
validate_task_list_id "c84d12c4-40af-4958-bd24-90566f637b87" && echo "UUID valid"
validate_task_list_id "swarm-20260122-143052" && echo "swarm ID valid"

# Test path traversal protection (should fail)
validate_task_list_id "../../../etc" || echo "path traversal blocked (good!)"

# Test summary (if tasks exist)
get_task_summary
```

**Step 4: Test pre-compact hook with tasks**

```bash
# Create some tasks first via Claude Code, then:
./hooks/pre-compact.sh < /dev/null
# Should include "Task List State" section
```

**Step 5: Test status line**

```bash
~/.claude/statusline-task.sh
# Should show task progress if tasks exist
```

---

### Task 8.2: Code Review

**Parallel:** no
**Blocked by:** Task 8.1
**Owned files:** none

Run `/requesting-code-review` for the full diff.
Then run `/codex` and `/gemini` for external review.

Fix any issues found and re-run quality gates.

---

## Completion Checklist

- [ ] Phase 1: Task-aware hooks (pre-compact, session-start)
- [ ] Phase 2: Task helper library (validated, safe reading)
- [ ] Phase 3: Task-plan-executor agent (with ID mapping)
- [ ] Phase 4: Swarm-coordinator skill
- [ ] Phase 5: Enhanced autonomous-loop with tasks
- [ ] Phase 6: Task-aware status line
- [ ] Phase 7: Documentation updates
- [ ] Phase 8: End-to-end verification and review
