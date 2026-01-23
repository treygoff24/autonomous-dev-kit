---
name: task-builder
description: |
  Execute ONE task in parallel with other task-builders. ALWAYS SPAWN MULTIPLE for independent tasks.

  ORCHESTRATOR: You coordinate, you don't implement. Spawn N task-builders for N unblocked tasks.
  Maximum parallelism = maximum speed = maximum quality (each task gets focused attention).
context: fork
agent: task-builder
skills:
  - requesting-code-review
  - using-git-worktrees
---

# Task Builder

Execute ONE task from the task system. **Spawn multiple task-builders in parallel for independent tasks.**

## ORCHESTRATOR: READ THIS FIRST

**You are the orchestrator. You do not implement. You spawn workers.**

```
# YOUR JOB
1. Create task DAG (TaskCreate + TaskUpdate for dependencies)
2. Find unblocked tasks (TaskList)
3. Spawn task-builder for EACH unblocked task IN PARALLEL
4. Monitor TaskList for completion
5. Review, test, merge
6. Repeat until done

# WRONG
spawn task-builder #1 → wait → spawn #2 → wait → spawn #3

# RIGHT
spawn task-builder #1, #2, #3 IN THE SAME MESSAGE
```

**If 5 tasks are unblocked, you spawn 5 task-builders simultaneously. Period.**

## When to Use

- You've created a task DAG via TaskCreate/TaskUpdate
- Tasks are unblocked (no incomplete dependencies)
- Tasks have clear file ownership (no conflicts)
- **You want SPEED** — parallel execution is the default

## Required Inputs

```
task_id: "3"                         # System ID from TaskCreate
worktree_path: "../project-task-3"   # Isolated worktree for this task
```

Each task-builder needs its own worktree. Create them first:
```bash
git worktree add ../wt-task-1 -b task-1
git worktree add ../wt-task-2 -b task-2
git worktree add ../wt-task-3 -b task-3
```

## What the Agent Does

1. `TaskGet(task_id)` — Retrieves task details + metadata
2. **Loads relevant skills** (see Skill Auto-Loading below)
3. `TaskUpdate(status="in_progress")` — Claims the task
4. Implements in the worktree (isolated, focused)
5. `TaskUpdate(status="completed")` — Marks done
6. Returns summary to orchestrator

The agent does NOT commit, merge, or push. You review and integrate.

## Skill Auto-Loading (Supercharges the Agent)

Task-builders automatically load domain-specific skills before implementing:

**Priority (Exclusive, Not Merged):**
1. `metadata.skills` — If specified, load ONLY those (skip keyword detection)
2. Keyword detection — ONLY if no metadata.skills, scan description for keywords
3. No matches — Proceed without skills, report "Skills Loaded: none"

**Orchestrator can specify skills explicitly:**
```
TaskCreate(
  subject="Build 3D product viewer",
  description="Create interactive Three.js scene...",
  metadata={"skills": ["threejs", "react-three-fiber"]}
)
```

**Or let the agent auto-detect** — keywords like "Three.js", "3D", "scene" trigger automatic skill loading.

**Skill routing (agent auto-detects):**
| Keywords | Skill |
|----------|-------|
| UI, UX, modal, component, form, button | `frontend-design` |
| Figma, design system | `figma:implement-design` |
| Three.js, 3D, WebGL, scene, mesh | `threejs` |
| R3F, Drei, react-three-fiber | `react-three-fiber` |
| shader, GLSL, material | `glsl-shaders` |
| Blender, GLB, GLTF | `blender-3d` |
| useChat, streamText, AI SDK | `vercel-ai-sdk` |
| React performance, Next.js, bundle | `vercel-react-best-practices` |
| vanilla JS, Web Components | `vanilla-web-dev` |
| .docx, Word document | `docx` |

Use bare skill names (no `/` prefix) in metadata and Skill() calls. See `agents/task-builder.md` for complete table.

## Parallel Execution Pattern

```
# Step 1: Create DAG
TaskCreate("Create user model") → #1
TaskCreate("Create auth middleware") → #2
TaskCreate("Create login endpoint") → #3
TaskUpdate(#3, addBlockedBy=[#1, #2])

# Step 2: Create worktrees for unblocked tasks
git worktree add ../wt-1 -b task-1
git worktree add ../wt-2 -b task-2

# Step 3: SPAWN IN PARALLEL (same message!)
/task-builder task_id=1 worktree_path=../wt-1
/task-builder task_id=2 worktree_path=../wt-2

# Step 4: Monitor
TaskList → #1 in_progress, #2 in_progress

# Step 5: When complete, #3 unblocks
git worktree add ../wt-3 -b task-3
/task-builder task_id=3 worktree_path=../wt-3

# Step 6: Review and merge each
cd ../wt-1 && git diff --stat && npm test
/requesting-code-review
git checkout main && git merge task-1
```

## Review Gate (Mandatory)

All changes require orchestrator review:
1. Agent returns summary with files changed
2. Orchestrator runs tests in worktree
3. Orchestrator runs `/requesting-code-review`
4. Only merge after approval

## Output Expectations

```
Task: #3
Status: complete
Subject: Create login endpoint

Skills Loaded:
- frontend-design (keyword: "form")

Files Changed:
- src/routes/auth/login.ts
- src/routes/auth/index.ts

Tests to Run:
- npm test -- src/routes/auth

Next Steps for Orchestrator:
1. cd ../wt-3 && git diff --stat
2. npm test -- src/routes/auth
3. /requesting-code-review
4. Merge if approved
```

Note: If no skills match, output shows "Skills Loaded: none"

## Cleanup

After merging:
```bash
git worktree remove ../wt-1
git worktree remove ../wt-2
git worktree remove ../wt-3
```

## Remember

**You are the orchestrator.** Your speed comes from parallelism, not from doing work yourself. Spawn task-builders. Monitor. Review. Merge. Repeat.
