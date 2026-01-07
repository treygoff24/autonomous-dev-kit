---
name: autonomous-loop
description: Activate autonomous loop mode for persistent development sessions. Use when user says "go autonomous" or wants unattended iteration until completion.
hooks:
  Stop:
    - type: command
      command: ~/.claude/hooks/stop.sh
      once: true
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
- `last_verified_iteration: 0`

### Step 3: Confirm Activation

Output to user:
```
Autonomous loop activated:
- Goal: [goal]
- Max iterations: 100
- State file: .claude/autonomous-loop.json

I'll keep working until all completion criteria are met:
- All quality gates pass (if .claude-quality-gates exists)
- All phases in IMPLEMENTATION_PLAN.md complete
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

## Protocol Verification

Every 5 iterations, the Stop hook requests protocol verification to ensure Claude stays aligned with the autonomous build protocol.

**How it works:**
1. At iteration 5, 10, 15, etc., the hook sets `verification_pending: true`
2. The `systemMessage` includes: "Re-read AUTONOMOUS_BUILD_CLAUDE.md then output `<verified/>` to confirm"
3. Claude should re-read the protocol and include `<verified/>` in its response
4. The hook reads the transcript and looks for the `<verified/>` tag
5. If found, verification passes and `last_verified_iteration` is updated

**Soft fail (prevents infinite loops):**
- If Claude doesn't output `<verified/>` after 3 attempts, the hook gives up and continues
- This prevents the verification system from causing infinite loops
- A warning is logged: "Verification not received after 3 attempts, continuing anyway"

**To pass verification:** Simply output `<verified/>` anywhere in your response after re-reading the protocol.

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
  "verification_attempts": 0,
  "last_verified_iteration": 0
}
```
