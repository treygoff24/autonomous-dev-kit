---
name: writing-plans
description: Use when design is complete and you need detailed implementation tasks for engineers with zero codebase context - creates comprehensive implementation plans with exact file paths, complete code examples, and verification steps assuming engineer has minimal domain knowledge
context: fork
skills:
  - task-builder
  - requesting-code-review
hooks:
  Stop:
    - type: prompt
      prompt: "Before ending: Was the implementation plan saved to docs/plans/YYYY-MM-DD-<feature>.md? Verify the file exists and was committed."
      once: true
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** Spawn `task-builder` agent to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

```markdown
### Task N: [Component Name]

**Parallel:** yes | no
**Blocked by:** [Task IDs or none]
**Owned files:** `path/to/file.ts`, `path/to/test.ts`

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

**Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```

**If Parallel: yes** (task-builder):
- Replace commit step with: "Return diff summary for orchestrator review (no commit)"
```

## Remember
- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- Include **Parallel**, **Blocked by**, and **Owned files** for every task
- Validate **Owned files** do not overlap across parallel tasks (use a quick table or script to check for duplicates)
- DRY, YAGNI, TDD, frequent commits

## Owned Files Validation

Use a quick duplicate check before running parallel tasks (portable across macOS/Linux):

```bash
rg '\*\*Owned files:\*\*' IMPLEMENTATION_PLAN.md \
  | sed 's/.*\*\*Owned files:\*\* *//' \
  | tr ',' '\n' \
  | sed 's/`//g' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | grep -v '^$' \
  | sort \
  | uniq -d
```

If this outputs any paths, fix overlaps before parallelizing.

## Example Parallel Task

```markdown
### Task 3.2: Add User Authentication

**Parallel:** yes
**Blocked by:** Task 3.1
**Owned files:** `src/auth/auth.ts`, `src/auth/auth.test.ts`, `src/middleware/auth-middleware.ts`

**Files:**
- Create: `src/auth/auth.ts`
- Modify: `src/middleware/auth-middleware.ts:12-48`
- Test: `src/auth/auth.test.ts`
```

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/plans/<filename>.md`. Two execution options:**

**1. Execute Now (this session)** - I spawn `task-builder` agent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session in worktree, spawn `task-builder` agent, batch execution with checkpoints

**3. Parallel Tickets** - Mark tasks with Parallel/Blocked by/Owned files, create worktrees, run `/task-builder` per task, review diffs before merge

**Which approach?"**

**If Execute Now chosen:**
- Spawn `task-builder` agent with the plan path
- Stay in this session
- Fresh agent per task + code review

**If Parallel Session chosen:**
- Guide them to open new session in worktree
- Spawn `task-builder` agent with the plan path

**If Parallel Tickets chosen:**
- Validate plan tasks include Parallel/Blocked by/Owned files
- Run the Owned Files Validation script to check for overlaps
- Create one worktree per parallel task
- Run `/task-builder` for each worktree
- Review diffs + tests in worktrees before merging
- Prefer `task-builder` when tasks share files or require shared context
