# Implementation Plan: Claude Code 2.1.x Enhancements

**Created:** 2026-01-09
**Goal:** Leverage Claude Code 2.1.x features to improve autonomous-dev-kit quality enforcement, developer experience, and context continuity.

---

## Summary

This plan implements 9 enhancements based on the Claude Code 2.1.0-2.1.2 changelog. Each enhancement either tightens quality enforcement, improves readability, or enables smarter context management.

| # | Enhancement | Impact | Files Changed |
|---|-------------|--------|---------------|
| 1 | Agent-scoped hooks | HIGH | 3 agent files |
| 2 | `once: true` for session-start hook | MEDIUM | hooks config |
| 3 | Wildcard bash permissions | MEDIUM | templates, docs |
| 4 | Skills auto-loading | MEDIUM | 5 skill files |
| 5 | `agent_type` in session-start.sh | MEDIUM | 1 hook file |
| 7 | Large outputs documentation | LOW | 1 agent file |
| 8 | YAML-style allowed-tools | LOW | all agents/skills |
| 9 | Ctrl+B backgrounding docs | LOW | 2 doc files |
| 10 | Prompt-based stop hooks | HIGH | DEFERRED |

---

## Task Breakdown

### Task 1: Add Scoped Hooks to Critical Agents

**Why:** Agent-scoped hooks enforce quality gates AT THE AGENT LEVEL, not globally. This means the `tdd-implementer` can't exit without tests passing, the `debugger` can't exit without identifying root cause, and `plan-executor` runs quality gates between tasks. Much tighter coupling than global hooks.

**Files:**
- `agents/tdd-implementer.md`
- `agents/debugger.md`
- `agents/plan-executor.md`

**Changes:**

#### agents/tdd-implementer.md
Add Stop hook that verifies tests pass:
```yaml
hooks:
  - event: Stop
    command: |
      if [[ -f package.json ]]; then
        npm test 2>&1 || { echo "BLOCKED: Tests must pass before TDD agent exits"; exit 1; }
      fi
```

#### agents/debugger.md
Add Stop hook that checks for root cause documentation:
```yaml
hooks:
  - event: Stop
    command: |
      echo "Debugger exit check: Ensure root cause was identified before claiming completion"
```

#### agents/plan-executor.md
Add PostToolUse hook for quality gates after Bash commands:
```yaml
hooks:
  - event: PostToolUse
    matcher: "Bash"
    command: |
      # Log tool usage for audit trail
      echo "[plan-executor] Bash command completed at $(date)"
```

**Verification:** Read each file, confirm hooks section exists and is valid YAML.

---

### Task 2: Add `once: true` to Session-Start Hook

**Why:** Prevents duplicate context injection if user runs `/clear` multiple times. The handoff and learnings should inject once per logical session, not per clear.

**File:** Update documentation for hook configuration in `docs/WORKFLOW_REFERENCE.md`

**Note:** This requires user to update their `~/.claude/settings.json`. We'll document the recommended config:

```json
{
  "hooks": [
    {
      "event": "SessionStart",
      "command": "~/.claude/hooks/session-start.sh",
      "once": true
    }
  ]
}
```

**Verification:** Check docs updated with `once: true` example.

---

### Task 3: Document Wildcard Bash Permissions

**Why:** Cleaner permission rules. Instead of listing every npm/git command, use wildcards.

**Files:**
- `docs/WORKFLOW_REFERENCE.md`
- `templates/settings.json.example` (if exists, otherwise add)

**Changes:**
Add section documenting wildcard patterns:
```json
{
  "permissions": {
    "allow": [
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(pnpm *)",
      "Bash(git *)",
      "Bash(claude *)"
    ]
  }
}
```

**Verification:** Grep for "Bash(" in docs, confirm wildcards documented.

---

### Task 4: Add Skills Auto-Loading to Dependent Skills

**Why:** Skills that depend on outputs from other skills should declare those dependencies. This auto-loads the dependent skills for reference without manual invocation.

**Files:**
- `skills/writing-plans/SKILL.md` — depends on brainstorming
- `skills/ticket-builder/SKILL.md` — depends on writing-plans
- `skills/requesting-code-review/SKILL.md` — often follows ticket-builder
- `skills/finishing-a-development-branch/SKILL.md` — follows code review
- `skills/using-git-worktrees/SKILL.md` — used before ticket-builder

**Changes:** Add `skills:` field to frontmatter where applicable.

Example for `writing-plans`:
```yaml
---
name: writing-plans
description: ...
skills:
  - brainstorming
---
```

**Verification:** Read each skill, confirm `skills:` field in frontmatter.

---

### Task 5: Enhance session-start.sh with agent_type

**Why:** The 2.1.2 changelog added `agent_type` to SessionStart hook input. The session-start hook can now customize context injection based on which agent is starting.

**File:** `hooks/session-start.sh`

**Changes:**
Add agent-type-aware logic:
```bash
# Read agent type from hook input (Claude Code 2.1.2+)
AGENT_TYPE="${CLAUDE_AGENT_TYPE:-}"

case "$AGENT_TYPE" in
  "plan-executor")
    # Could inject implementation plan summary
    ;;
  "debugger")
    # Could inject recent error context
    ;;
  "")
    # Main session - inject full handoff
    ;;
esac
```

**Verification:** Read session-start.sh, confirm agent_type handling exists.

---

### Task 6: SKIPPED (User Request)

Disabling agents via `Task(AgentName)` permissions — user explicitly excluded this.

---

### Task 7: Update Debugger Agent for Large Output References

**Why:** Claude Code 2.1.2 saves large bash outputs to disk instead of truncating. The debugger agent should know to look for file references when outputs are large.

**File:** `agents/debugger.md`

**Changes:**
Add note in agent instructions:
```markdown
## Large Output Handling

When bash commands produce large output (>30K chars), Claude Code saves the full output to a file and provides a reference. Always read the full file when debugging—truncated output hides critical details.
```

**Verification:** Read debugger.md, confirm large output note exists.

---

### Task 8: Convert All Frontmatter to YAML-Style Lists

**Why:** Readability. YAML lists are cleaner than inline arrays for `allowed-tools`.

**Files:** All agents and skills with `allowed-tools` in frontmatter.

**Before:**
```yaml
allowed-tools: [Read, Edit, Grep, Glob, Bash]
```

**After:**
```yaml
allowed-tools:
  - Read
  - Edit
  - Grep
  - Glob
  - Bash
```

**Verification:** Grep for `allowed-tools: \[` — should return 0 matches after conversion.

---

### Task 9: Document Ctrl+B Backgrounding

**Why:** Users can now background ANY running agent (not just bash). This pairs well with autonomous-loop—users can background the loop while checking other things.

**Files:**
- `docs/GETTING_STARTED.md`
- `skills/autonomous-loop/SKILL.md`

**Changes:**
Add section:
```markdown
## Backgrounding Agents (Ctrl+B)

Press `Ctrl+B` to background any running agent or bash command. This lets you:
- Check other files while an agent works
- Queue up additional messages
- Pause autonomous-loop without exiting

Background tasks continue running. You'll be notified when they complete.
```

**Verification:** Grep for "Ctrl+B" in docs, confirm documented.

---

### Task 10: Prompt-Based Stop Hooks — COMPLETE

**Why:** Game-changer for smart exit validation. Instead of brittle shell scripts checking git status, a model can evaluate whether work is truly complete.

**Status:** Implemented after discussion with user.

**Implementation:**
- Replaced 685-line stop.sh with minimal stub (approves exit for legacy <2.1 compatibility)
- Added comprehensive prompt-based Stop hooks to:
  - `skills/autonomous-loop/SKILL.md` — Global completion enforcement
  - `agents/tdd-implementer.md` — TDD discipline verification
  - `agents/debugger.md` — Root cause identification verification
  - `agents/plan-executor.md` — Plan completion verification

**User directive:** "Nuke the current stop hook and start over. The ONLY thing that should be the pass/fail for whether or not we stop the exit and tell the model to keep working should be the model we call to decide/review it. That model should always be Sonnet everywhere."

**Philosophy:** "You cannot exit until you have ACTUALLY done what I asked and, to the best you can tell, you've fully done it. Not half done it, not skipped implementation steps or details, not skipped testing and code review and ignored warnings in lint. It is DONE."

---

## Execution Order

1. Task 8 (YAML frontmatter) — Quick, no logic changes, reduces noise in diffs for later tasks
2. Task 1 (Agent-scoped hooks) — Highest impact
3. Task 4 (Skills auto-loading) — Medium impact
4. Task 5 (agent_type in session-start.sh) — Medium impact
5. Task 7 (Large output docs in debugger) — Low impact
6. Task 3 (Wildcard bash permissions docs) — Low impact
7. Task 2 (`once: true` docs) — Low impact
8. Task 9 (Ctrl+B docs) — Low impact
9. Task 10 (Prompt-based stop hooks) — COMPLETE

---

## Verification Checklist

After all tasks complete:
- [x] All agents with `tools:` use YAML list style
- [x] `tdd-implementer.md` has Stop hook for test verification
- [x] `debugger.md` has Stop hook and large output note
- [x] `plan-executor.md` has Stop hook for quality gates
- [x] Skills with dependencies have `skills:` field
- [x] `session-start.sh` handles agent_type
- [x] Docs mention `once: true`, wildcard permissions, Ctrl+B
- [x] Task 10 (prompt-based stop hooks) implemented with Sonnet
- [x] stop.sh replaced with minimal stub for legacy compatibility
- [ ] All changes committed with descriptive message

---

## Notes for Reviewer

- **Agent hooks are the big win.** They move quality enforcement from "global scripts that can be bypassed" to "built into the agent definition."
- **Skills auto-loading is about discoverability.** When `writing-plans` auto-loads `brainstorming`, users can reference brainstorming outputs without manually invoking it.
- **Task 10 is genuinely exciting.** Prompt-based stop hooks let a model decide whether to block exit—much smarter than regex/grep checks.
