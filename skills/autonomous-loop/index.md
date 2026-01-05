---
name: autonomous-loop
description: Activate autonomous loop mode for persistent development sessions. Use when user says "go autonomous" or wants unattended iteration until completion.
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

This creates a state file at `~/.claude/autonomous-loop/<hash>.json` with:
- `active: true`
- `goal: "Your goal"`
- `max_iterations: 100`
- `iteration: 0`
- Session token and verification code

### Step 3: Confirm Activation

Output to user:
```
Autonomous loop activated:
- Goal: [goal]
- Max iterations: 100
- State file: ~/.claude/autonomous-loop/[hash].json

I'll keep working until all completion criteria are met:
- All quality gates pass (if .claude-quality-gates exists)
- All phases in IMPLEMENTATION_PLAN.md complete
- Clean git state

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
1. Git working directory is clean (no uncommitted changes)
2. All quality gates pass (if `.claude-quality-gates` exists)
3. All tasks in IMPLEMENTATION_PLAN.md are checked off (if file exists)

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

## Protocol Re-Read

Every 3 iterations, the Stop hook triggers protocol re-read verification:

1. Hook prompts: "Read AUTONOMOUS_BUILD_CLAUDE.md and report verification code"
2. Read the full protocol file
3. Check state file for `expected_verification_code`
4. Update state file `verification_response` with the code
5. Continue working

This ensures the protocol stays fresh across context compactions.

## Arguments

- **goal** (optional): The task to work on. If not provided, inferred from context.
- **--max N**: Set max iterations (default: 100)

Examples:
```
/autonomous-loop "Implement user authentication"
/autonomous-loop --max 50
/autonomous-loop "Fix all failing tests" --max 200
```
