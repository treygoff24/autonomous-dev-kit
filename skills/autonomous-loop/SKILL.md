---
name: autonomous-loop
description: Activate autonomous loop mode for persistent development sessions. Use when user says "go autonomous" or wants unattended iteration until completion.
hooks:
  Stop:
    - type: prompt
      model: sonnet
      prompt: |
        You are about to exit autonomous loop mode. Verify the work is ACTUALLY COMPLETE.

        ## Verification Steps (Do ALL of these)

        1. **Run `git status`** — Are there uncommitted changes (excluding `.claude/` directory)?
           If yes, you're not done.

        2. **Run quality gates:**
           - FIRST check if `.claude-quality-gates` exists — if so, run each command in that file
           - ONLY if no `.claude-quality-gates`: check package.json for npm scripts (typecheck, lint, build, test)
           - Any failures = you're not done.

        3. **Check IMPLEMENTATION_PLAN.md** (if it exists):
           - Read the current goal from `.claude/autonomous-loop.json` (the `goal` field)
           - If the goal mentions a specific phase or module (e.g., "Phase 2", "auth module"),
             only check that section of the plan for unchecked `[ ]` boxes
           - If no specific scope, check the entire plan
           - Were any tasks skipped or marked "TODO later"? If yes, you're not done.

        4. **Review what was requested vs what was delivered:**
           - Did you implement the FULL feature, not a skeleton?
           - Did you write REAL tests, not placeholder assertions?
           - Did you run code review and address the feedback?
           - Did you handle edge cases and error states?

        5. **Check for half-done work:**
           - Are there TODO comments you added and didn't resolve?
           - Are there console.log/debug statements to remove?
           - Did you skip any "nice to have" items that were actually requested?

        ## Decision

        If ANY of the above reveals incomplete work:
        - **BLOCK EXIT** — Respond with what's still needed and continue working.

        If ALL checks pass and the work is genuinely complete:
        - **Clear loop state:** Run `rm -f .claude/autonomous-loop.json` to clean up
        - **ALLOW EXIT** — The work is done.

        Be rigorous. "Almost done" is not done. "Works but needs cleanup" is not done.
        The bar is: would you ship this to production right now?
---

# Autonomous Loop Activation

This skill activates autonomous loop mode, which keeps Claude working toward a goal until completion criteria are met. The Stop hook will block exit attempts and inject continuation prompts until work is complete.

## When to Use

- User explicitly says `/autonomous-loop "goal"`
- User says "go autonomous", "start autonomous mode", "keep going until done"
- After completing brainstorming/spec and user approves implementation

## Activation Steps

### Step 1: Determine Goal

**If explicit goal provided:**
```
/autonomous-loop "Build comprehensive Playwright tests for the auth flow"
```
Use the provided goal directly.

**If no explicit goal (interactive activation):**
1. Check CONTEXT.md for current objective
2. Check SPEC.md for project goal
3. Summarize from recent conversation
4. Confirm with user: "I'll work autonomously on: [goal]. Sound right?"

### Step 2: Initialize Loop State

Source the helper library and call initialize_loop_state:

```bash
source ~/.claude/lib/loop-helpers.sh
initialize_loop_state "$(pwd)" "Your goal here" 100
```

This creates a state file at `.claude/autonomous-loop.json` (project-local) with:
- `active: true`
- `goal: "Your goal"`
- `max_iterations: 100`
- `iteration: 0`
- `verification_pending: false`
- `expected_verification_code: null`
- `last_verified_iteration: 0`
- `stuck_count: 0`
- `last_goal_hash: ""`
- `last_progress_hash: ""`

### Step 3: Confirm Activation

Output to user:
```
Autonomous loop activated:
- Goal: [goal]
- Max iterations: 100
- State file: .claude/autonomous-loop.json

I'll keep working until all completion criteria are met:
- All quality gates pass (if .claude-quality-gates exists)
- All scoped tasks in IMPLEMENTATION_PLAN.md complete (phase/module if the goal names one)
- Clean git state (excluding .claude/ directory)

To pause: press Escape and say "stop autonomous mode"
To force quit: Ctrl+C

Starting now...
```

### Step 4: Begin Working

- If IMPLEMENTATION_PLAN.md exists, continue from current phase
- Otherwise, start executing the goal directly
- Follow the autonomous build protocol

## Completion Criteria

The loop automatically ends when ALL of these are true:
1. Git working directory is clean (no uncommitted changes, `.claude/` excluded)
2. All quality gates pass (if `.claude-quality-gates` exists)
3. All tasks in IMPLEMENTATION_PLAN.md are checked off (if file exists, no `- [ ]` boxes)

If the goal mentions a phase or module and a matching section exists, only that section is
checked. If the scoped section is missing, the plan check is skipped.

## Protocol Verification

Every 3 iterations, the Stop hook requests protocol verification to ensure Claude stays aligned with the autonomous build protocol.

**How it works:**
1. At iteration 3, 6, 9, etc., the hook sets `verification_pending: true`
2. The hook writes `expected_verification_code` to `.claude/autonomous-loop.json`
3. The continuation prompt instructs Claude to re-read AUTONOMOUS_BUILD_CLAUDE.md and reply with `<verified code="####"/>` (or `<verified>####</verified>`) using that code
4. The hook reads the transcript and looks for the tag containing the expected code
5. If found, verification passes and `last_verified_iteration` is updated

**Soft fail (prevents infinite loops):**
- If the tag isn't received after 3 attempts, the hook clears verification and continues
- This prevents the verification system from causing infinite loops if transcript parsing fails

**To pass verification:** Output `<verified code="####"/>` using `expected_verification_code` from `.claude/autonomous-loop.json`.

## Deactivation

User says any of:
- "Stop autonomous mode"
- "Pause the loop"
- "Exit autonomous mode"

**When deactivating:**
1. Source helpers: `source ~/.claude/lib/loop-helpers.sh`
2. Delete state: `delete_state_file "$(pwd)"`
3. Confirm: "Autonomous loop stopped. State cleared."

## Max Iterations Reached

When max iterations hit (default 100), the loop pauses automatically:

```
Max iterations reached (100).

Options:
- Say "continue for 50 more" to extend
- Provide feedback to adjust direction
- Say "stop autonomous mode" to end
```

To resume: update max_iterations in state file and set paused=false, or user says "resume" / "continue".

## Stuck Detection

If the goal and git progress stay unchanged for 5 consecutive iterations, the loop
pauses and asks for updated direction to avoid infinite loops.

## Arguments

- **goal** (optional): The task to work on. If not provided, inferred from context.
- **--max N**: Set max iterations (default: 100)

Examples:
```
/autonomous-loop "Implement user authentication"
/autonomous-loop --max 50
/autonomous-loop "Fix all failing tests" --max 200
```

## State File Reference

Location: `.claude/autonomous-loop.json` (project-local)

```json
{
  "active": true,
  "session_token": "abc123",
  "project_path": "/path/to/project",
  "goal": "Your goal here",
  "started_at": "2026-01-07T20:00:00Z",
  "iteration": 5,
  "max_iterations": 100,
  "paused": false,
  "verification_pending": false,
  "expected_verification_code": null,
  "verification_attempts": 0,
  "last_verified_iteration": 0,
  "stuck_count": 0,
  "last_goal_hash": "",
  "last_progress_hash": ""
}
```
