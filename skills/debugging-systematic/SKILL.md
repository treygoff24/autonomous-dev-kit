---
name: debugging-systematic
description: Apply systematic root cause analysis and debugging methodologies to diagnose and fix bugs, test failures, and unexpected behavior. Use when encountering production issues, investigating test failures, diagnosing performance problems, tracing error sources through call stacks, analyzing logs and stack traces, reproducing inconsistent bugs, debugging race conditions, investigating memory leaks, or applying scientific method to problem-solving before proposing fixes.
context: fork
agent: debugger
hooks:
  Stop:
    - type: prompt
      prompt: "Did you identify the root cause with evidence before proposing a fix? Verify you have reproduction steps and a clear explanation of WHY the bug occurred."
      once: true
---

# Systematic Debugging

This skill activates the `debugger` agent in a forked context for focused, systematic root cause analysis.

## When to Use

- Bug reports or unexpected behavior
- Test failures (especially intermittent ones)
- Performance regressions
- Error traces that need investigation
- Any situation where you need to understand WHY something is broken before fixing it

## What the Debugger Agent Does

The debugger agent follows a strict investigation-first methodology:

### Phase 1: Investigation (BEFORE any fixes)

1. **Reproduce the issue** — Get a reliable reproduction
2. **Gather evidence** — Logs, stack traces, git blame, recent changes
3. **Trace data flow** — Follow the data from entry to failure point
4. **Identify root cause** — Find WHERE and WHY the bug occurs
5. **Document findings** — Clear explanation with evidence

### Phase 2: Fix (AFTER root cause is confirmed)

1. **Write a failing test** — Proves the bug exists
2. **Implement minimal fix** — Fix at the source, not the symptom
3. **Verify the test passes** — Confirms the fix works
4. **Check for regressions** — Run full test suite

## Key Principles

- **Investigate before fixing** — Never propose a fix without understanding the root cause
- **Evidence over intuition** — Every conclusion needs supporting evidence
- **Fix at the source** — Don't patch symptoms, fix the actual cause
- **One bug at a time** — Focus on a single issue per investigation

## Usage

```
/debugging-systematic "Tests in auth module are failing intermittently"
```

Or simply:

```
/debugging-systematic
```

The agent will ask for context about the issue to investigate.

## Integration

This skill wraps the `debugger` agent defined in `agents/debugger.md`. The agent has access to Read, Edit, Grep, Glob, Bash, and WebFetch tools, and runs with `permissionMode: bypassPermissions` for autonomous investigation.

The debugger agent's Stop hook verifies that root cause analysis was completed with evidence before allowing exit.
