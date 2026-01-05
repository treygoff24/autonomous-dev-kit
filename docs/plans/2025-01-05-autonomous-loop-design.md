# Autonomous Loop Design

> Persistent development loops where Claude iterates toward completion without human intervention between cycles.

**Date:** 2025-01-05
**Status:** Approved
**Inspiration:** [Ralph Wiggum plugin](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/)

---

## Problem Statement

Claude Code sessions can exit prematurely — either accidentally (user hits exit when work isn't done) or through context degradation (after many compactions, Claude forgets it's supposed to keep going). Additionally, after 5-6 compactions, Claude forgets the autonomous build protocol itself: stops calling Codex for reviews, stops using skills, forgets the implementation loop.

## Solution Overview

Two-layer system:

1. **Safety Net (always on):** Prevents accidental exits when work is incomplete
2. **Explicit Loop Mode:** Full autonomous iteration with continuation prompts, protocol re-reads, and completion criteria

---

## Layer 1: Safety Net

**Always active.** Catches accidental premature exits.

### Triggers (any blocks exit)

| Check | Condition |
|-------|-----------|
| Quality gates | `npm run typecheck`, `npm run lint`, `npm run build`, `npm test` — any failing |
| Dirty git state | Uncommitted changes or untracked files in src/ |
| CONTEXT.md incomplete | Exists and shows work in progress (current phase not marked complete) |

### Behavior

- Blocks exit (return code 2)
- Injects warning: "Exit blocked: [reason]. Finish your work or use Ctrl+C to force quit."
- No iteration tracking, no continuation prompt
- User can override by finishing work or using Ctrl+C

---

## Layer 2: Explicit Loop Mode

**Activated explicitly.** Full autonomous operation with continuation prompts.

### Activation

Two paths:

1. **Fire and forget:** User starts with explicit goal
   ```
   /autonomous-loop "Write comprehensive Playwright tests" --max 100
   ```

2. **Interactive → Autonomous:** After brainstorming session
   ```
   User: "Spec looks good. Go autonomous."
   Claude: [Generates goal from context, activates loop mode]
   ```

When activating, Claude:
- Generates goal summary from current context/spec
- Can ask user for confirmation if goal is unclear
- Creates `.autonomous-loop.json` state file

### State File

Location: `.autonomous-loop.json` in project root (add to `.gitignore`)

```json
{
  "active": true,
  "goal": "Build complete e-commerce platform per SPEC.md",
  "started_at": "2025-01-05T14:30:00Z",
  "iteration": 47,
  "max_iterations": 100,
  "last_protocol_reread": 45,
  "completion_check": null,
  "paused": false,
  "awaiting_verification": false,
  "verification_response": null
}
```

| Field | Purpose |
|-------|---------|
| `active` | Is loop mode on? |
| `goal` | Original task for re-injection |
| `started_at` | When loop started (for elapsed time) |
| `iteration` | Current iteration count |
| `max_iterations` | The limit (default: 100) |
| `last_protocol_reread` | Which iteration had full protocol re-read |
| `completion_check` | Custom check command (null = use defaults) |
| `paused` | True when at max iterations or user interrupted |
| `awaiting_verification` | True when waiting for protocol verification code |
| `verification_response` | Code Claude reports after reading protocol |

### Completion Criteria

Default (when `completion_check` is null):
- All quality gates pass (typecheck, lint, build, test)
- All phases in IMPLEMENTATION_PLAN.md marked complete

Custom override:
```
/autonomous-loop "Migrate to Vitest" --check "npm test && ! grep -r 'jest' src/"
```

### Continuation Prompt

When exit is blocked in loop mode, inject:

1. **Protocol cheat sheet** (every iteration)
2. **Dynamic loop status** (iteration, elapsed time, blockers)
3. **Full protocol re-read directive** (every 3rd iteration)

#### Protocol Cheat Sheet

```markdown
## AUTONOMOUS BUILD MODE ACTIVE

You are in an autonomous build session. This cheat sheet summarizes
AUTONOMOUS_BUILD_CLAUDE.md — re-read the full protocol if anything is unclear.

DO NOT STOP until completion criteria are met. Execute with precision.

---

**Implementation Loop (every phase):**
IMPLEMENT → TYPECHECK → LINT → BUILD → TEST → REVIEW → SLOP REMOVAL → COMMIT

**Codex = External AI Reviewer:**
Codex is OpenAI's coding model. Call it for external review at checkpoints.
May take up to 30 min to respond. Wait for the full response.

Mandatory checkpoints:
- After drafting spec
- After drafting implementation plan
- After completing each phase
- Before declaring build complete
- When stuck 3+ times on same error

Syntax:
codex exec --model gpt-5.2-codex --config model_reasoning_effort="xhigh" --yolo "<PROMPT>"

**Subagents (spawn via Task tool):**
- code-reviewer → after each phase (before Codex)
- bug-hunter → first step when hitting errors
- Explore → understand unfamiliar code
- security-auditor → auth, inputs, sensitive changes
- accessibility-auditor → UI changes
- test-architect → comprehensive test coverage

**Skills:**
- Stuck in error loop → systematic-debugging
- Writing tests → test-driven-development (red-green-refactor)
- Before claiming done → verification-before-completion
- UI work → frontend-design + accessibility-checklist

**Context Hygiene:**
- Update CONTEXT.md 2x per phase minimum
- Update IMPLEMENTATION_PLAN.md after each phase

**Completion Criteria:**
All phases complete + all quality gates pass + Codex final verdict "ship it"
```

#### Dynamic Status Block

```markdown
---
## Loop Status
Iteration: 47/100 | Elapsed: 12h 34m
Goal: Build complete e-commerce platform per SPEC.md

Exit blocked because:
- npm test: 3 failures in checkout.test.ts
- IMPLEMENTATION_PLAN.md: Phase 4 incomplete

Continue working. Re-read CONTEXT.md for current state.
```

---

## Protocol Re-Read Verification

After many compactions, Claude forgets the protocol. Every 3rd iteration, force a verified re-read.

### Mechanism

The protocol file contains a verification code at the end:

```markdown
<!-- VERIFICATION:7429 -->
```

### Flow

1. Iteration 3, 6, 9, etc. → hook detects time for re-read
2. Hook sets `awaiting_verification: true` in JSON
3. Hook blocks exit and injects:

```markdown
## Protocol Re-Read Required (Iteration 6)

Full protocol re-read required before continuing.

1. Read AUTONOMOUS_BUILD_CLAUDE.md completely
2. Find the verification code at the end: <!-- VERIFICATION:XXXX -->
3. Update .autonomous-loop.json field: "verification_response": "XXXX"
4. Resume work

You cannot proceed until verification is complete.
```

4. Claude reads protocol, finds code, updates JSON
5. Next exit attempt, hook validates `verification_response` against actual code
6. Match → hook clears `awaiting_verification`, generates new random code in protocol file, continues
7. Mismatch → stays blocked, re-prompts

### Code Generation

Script generates new 4-digit code after each successful verification:

```bash
NEW_CODE=$((RANDOM % 9000 + 1000))
sed -i '' "s/<!-- VERIFICATION:[0-9]* -->/<!-- VERIFICATION:$NEW_CODE -->/" AUTONOMOUS_BUILD_CLAUDE.md
```

---

## User Controls

### Max Iterations

Default: 100

When max is reached:
- Loop pauses (not terminates)
- Claude surfaces: "Hit 100 iterations. Continue, adjust direction, or stop?"
- User can chat freely — autonomous mode is paused
- Resume only when user explicitly says "resume" or confirms Claude's ask

### Escape Hatches

| Action | Behavior |
|--------|----------|
| **Escape key** | Interrupts Claude, pauses loop mode. User chats, must explicitly resume. |
| **Ctrl+C** | Kills Claude Code entirely. Loop state cleared (nuclear option). |

### Resume After Pause

Loop stays paused until:
- User says "resume autonomous mode" / "continue" / etc.
- Or Claude asks "Want me to resume autonomous mode?" and user confirms

---

## Hook Integration

### Existing Hooks

| Hook | Purpose |
|------|---------|
| `pre-compact.sh` | Saves handoff before context compaction |
| `session-start.sh` | Injects handoff + learnings after compaction |

### New Hook

`stop.sh` — Intercepts exit attempts

### Flow Diagram

```
[Claude tries to exit]
        ↓
    stop.sh runs
        ↓
    ┌─ In loop mode? (.autonomous-loop.json exists and active)
    │   │
    │   ├─ Yes, awaiting_verification?
    │   │   ├─ Yes → validate verification_response
    │   │   │        ├─ Match → clear flag, generate new code, continue to completion check
    │   │   │        └─ No match → block exit, re-prompt for verification
    │   │   │
    │   │   └─ No → check completion criteria
    │   │            ├─ Complete → clear state, exit 0 (allow exit)
    │   │            ├─ Max iterations → set paused=true, exit 0, prompt user
    │   │            └─ Not complete → increment iteration
    │   │                              ├─ iteration % 3 == 0 → set awaiting_verification, prompt re-read
    │   │                              └─ else → inject cheat sheet + status, exit 2 (block)
    │   │
    │   └─ No (loop not active) → Check safety net
    │        ├─ Quality gates failing → exit 2 (block) + warn
    │        ├─ Dirty git state → exit 2 (block) + warn
    │        ├─ CONTEXT.md incomplete → exit 2 (block) + warn
    │        └─ All clear → exit 0 (allow exit)
```

### Hook Coordination

The hooks complement each other:

1. **stop.sh** blocks exit, injects continuation prompt
2. **pre-compact.sh** saves handoff when compaction occurs (during long loops)
3. **session-start.sh** restores context after compaction
4. **stop.sh** continuation adds cheat sheet on top of restored context

---

## Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `hooks/stop.sh` | Main stop hook with safety net + loop logic |
| `shell/autonomous-loop.zsh` | Shell function for `/autonomous-loop` skill |
| `templates/PROTOCOL_CHEATSHEET.md` | The cheat sheet (embedded in stop.sh or separate) |
| `tests/test-stop-hook.sh` | Test suite for stop hook |
| `tests/test-autonomous-loop.sh` | Integration tests for full loop |

### Modified Files

| File | Change |
|------|--------|
| `install.sh` | Add stop.sh to hook installation, configure Stop hook in settings.json |
| `templates/AUTONOMOUS_BUILD_CLAUDE.md` | Add verification code marker at end |
| `.gitignore` (template) | Add `.autonomous-loop.json` |

---

## Test Plan

### Unit Tests (test-stop-hook.sh)

| Test | Description |
|------|-------------|
| `test_safety_net_blocks_on_failing_tests` | Mock failing npm test, verify exit code 2 |
| `test_safety_net_blocks_on_dirty_git` | Create uncommitted changes, verify exit code 2 |
| `test_safety_net_allows_clean_exit` | All checks pass, verify exit code 0 |
| `test_loop_mode_blocks_when_incomplete` | Active loop, criteria not met, verify exit code 2 |
| `test_loop_mode_allows_when_complete` | Active loop, criteria met, verify exit code 0 |
| `test_loop_increments_iteration` | Verify iteration counter increases |
| `test_max_iterations_pauses` | Hit max, verify paused=true |
| `test_verification_required_every_3` | Iterations 3,6,9 trigger awaiting_verification |
| `test_verification_validates_code` | Correct code clears flag, wrong code stays blocked |
| `test_verification_generates_new_code` | After validation, protocol file has new code |
| `test_ctrl_c_clears_state` | Simulate SIGINT, verify JSON deleted |
| `test_cheatsheet_injected` | Verify stdout contains cheat sheet on block |

### Integration Tests (test-autonomous-loop.sh)

| Test | Description |
|------|-------------|
| `test_fire_and_forget_activation` | `/autonomous-loop "goal"` creates state file |
| `test_interactive_activation` | "Go autonomous" without explicit goal works |
| `test_full_loop_cycle` | Complete mini-task through multiple iterations |
| `test_pause_and_resume` | Hit max, pause, resume, verify continuation |
| `test_escape_pauses_loop` | Simulate escape, verify paused=true |
| `test_completion_clears_state` | Meet criteria, verify state file removed |

### Manual Testing Checklist

- [ ] Fire and forget: simple task completes autonomously
- [ ] Interactive → autonomous transition works
- [ ] Cheat sheet appears in continuation
- [ ] Protocol re-read triggers at iteration 3
- [ ] Verification code mechanism works
- [ ] Max iterations pauses correctly
- [ ] Escape key pauses, resume works
- [ ] Ctrl+C clears state
- [ ] Works across context compaction
- [ ] Codex calls happen at checkpoints (human verification)

---

## Open Questions (Resolved)

| Question | Resolution |
|----------|------------|
| Where does state live? | `.autonomous-loop.json` in project root |
| How to ensure protocol re-read? | Verification code mechanism |
| How to handle interactive→autonomous? | Claude generates goal, explicit activation |
| What blocks exit in safety net? | Quality gates + dirty git + CONTEXT.md incomplete |

---

## Implementation Phases

### Phase 1: Stop Hook Foundation
- Create `hooks/stop.sh` with safety net logic only
- Add to install.sh
- Test safety net triggers

### Phase 2: Loop Mode Core
- Add loop mode detection and state management
- Implement completion criteria checking
- Add iteration tracking and max iterations

### Phase 3: Continuation Prompts
- Implement cheat sheet injection
- Add dynamic status block
- Test continuation flow

### Phase 4: Protocol Verification
- Add verification code to protocol template
- Implement verification check in stop hook
- Add code regeneration logic

### Phase 5: Activation Skill
- Create `/autonomous-loop` skill
- Handle fire-and-forget and interactive activation
- Test both activation paths

### Phase 6: Integration & Polish
- Full integration testing
- Update install.sh for all new files
- Documentation updates

---

## Appendix: Full Continuation Prompt Example

When Claude tries to exit at iteration 7 with failing tests:

```markdown
## AUTONOMOUS BUILD MODE ACTIVE

You are in an autonomous build session. This cheat sheet summarizes
AUTONOMOUS_BUILD_CLAUDE.md — re-read the full protocol if anything is unclear.

DO NOT STOP until completion criteria are met. Execute with precision.

---

**Implementation Loop (every phase):**
IMPLEMENT → TYPECHECK → LINT → BUILD → TEST → REVIEW → SLOP REMOVAL → COMMIT

**Codex = External AI Reviewer:**
Codex is OpenAI's coding model. Call it for external review at checkpoints.
May take up to 30 min to respond. Wait for the full response.

Mandatory checkpoints:
- After drafting spec
- After drafting implementation plan
- After completing each phase
- Before declaring build complete
- When stuck 3+ times on same error

Syntax:
codex exec --model gpt-5.2-codex --config model_reasoning_effort="xhigh" --yolo "<PROMPT>"

**Subagents (spawn via Task tool):**
- code-reviewer → after each phase (before Codex)
- bug-hunter → first step when hitting errors
- Explore → understand unfamiliar code
- security-auditor → auth, inputs, sensitive changes
- accessibility-auditor → UI changes
- test-architect → comprehensive test coverage

**Skills:**
- Stuck in error loop → systematic-debugging
- Writing tests → test-driven-development (red-green-refactor)
- Before claiming done → verification-before-completion
- UI work → frontend-design + accessibility-checklist

**Context Hygiene:**
- Update CONTEXT.md 2x per phase minimum
- Update IMPLEMENTATION_PLAN.md after each phase

**Completion Criteria:**
All phases complete + all quality gates pass + Codex final verdict "ship it"

---
## Loop Status
Iteration: 7/100 | Elapsed: 2h 14m
Goal: Build complete e-commerce platform per SPEC.md

Exit blocked because:
- npm test: 3 failures in checkout.test.ts
- IMPLEMENTATION_PLAN.md: Phase 4 incomplete

Continue working. Re-read CONTEXT.md for current state.
```
