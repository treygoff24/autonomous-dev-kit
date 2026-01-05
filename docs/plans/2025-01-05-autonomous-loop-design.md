# Autonomous Loop Design

> Persistent development loops where Claude iterates toward completion without human intervention between cycles.

**Date:** 2025-01-05
**Status:** Approved (Revised after Codex review)
**Inspiration:** [Ralph Wiggum plugin](https://paddo.dev/blog/ralph-wiggum-autonomous-loops/)

---

## Revision Notes (Codex Review 2025-01-05)

**Security fixes:**
- State file moved to `~/.claude/autonomous-loop/<project-hash>.json` with session token
- Custom `completion_check` removed (use default criteria only)
- Safety net quality gates require explicit opt-in per project via `.claude-quality-gates`

**Portability fixes:**
- Verification code stored in state file, not protocol file (no sed mutation)
- OS-agnostic shell commands throughout

**Design adjustments:**
- Escape/Ctrl+C behavior acknowledged as non-hookable; documentation updated
- Max-iteration pause uses exit code 2 with prompt, not exit 0

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

Location: `~/.claude/autonomous-loop/<project-hash>.json`

The state file is stored outside the project to prevent:
- Pre-seeded attack vectors (malicious repo with `active: true`)
- Git pollution
- Cross-project state conflicts

Project hash is derived from absolute path: `echo -n "$PROJECT_PATH" | sha256sum | cut -c1-12`

```json
{
  "active": true,
  "session_token": "abc123def456",
  "project_path": "/Users/trey/Code/my-project",
  "goal": "Build complete e-commerce platform per SPEC.md",
  "started_at": "2025-01-05T14:30:00Z",
  "iteration": 47,
  "max_iterations": 100,
  "last_protocol_reread": 45,
  "paused": false,
  "awaiting_verification": false,
  "verification_response": null,
  "expected_verification_code": "7429"
}
```

| Field | Purpose |
|-------|---------|
| `active` | Is loop mode on? |
| `session_token` | Random nonce generated on activation (makes state file unique per initialization; Claude Code doesn't expose session IDs so true validation isn't possible) |
| `project_path` | Absolute path to project (recorded for debugging) |
| `goal` | Original task for re-injection |
| `started_at` | When loop started (for elapsed time) |
| `iteration` | Current iteration count |
| `max_iterations` | The limit (default: 100) |
| `last_protocol_reread` | Which iteration had full protocol re-read |
| `paused` | True when at max iterations or user interrupted |
| `awaiting_verification` | True when waiting for protocol verification code |
| `verification_response` | Code Claude reports after reading protocol |
| `expected_verification_code` | The code Claude must report (script-generated) |

### Completion Criteria

Fixed criteria (no custom overrides for security):
- All quality gates pass (typecheck, lint, build, test) — if `.claude-quality-gates` exists
- All phases in IMPLEMENTATION_PLAN.md marked complete (if file exists)
- No uncommitted changes in git

The quality gates file (`.claude-quality-gates`) explicitly opts in to automatic quality checks:
```bash
# .claude-quality-gates - opt-in to automatic quality gate checks
npm run typecheck
npm run lint
npm run build
npm run test
```

If this file doesn't exist, quality gates are skipped (safety net only checks git state).

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

The verification code is stored in the state file (`expected_verification_code`), not the protocol file. This avoids:
- Dirty git state from editing tracked files
- macOS vs Linux `sed` incompatibilities
- Symlink/permission issues

The protocol file contains a static marker that tells Claude where to find the code:

```markdown
<!-- END OF PROTOCOL -->
## Verification

When prompted for protocol re-read verification, check your loop state file
for the expected verification code and report it to prove you've read this file.
```

### Flow

1. Iteration 3, 6, 9, etc. → hook detects time for re-read
2. Hook generates new `expected_verification_code`, sets `awaiting_verification: true`
3. Hook blocks exit and injects:

```markdown
## Protocol Re-Read Required (Iteration 6)

Full protocol re-read required before continuing.

1. Read AUTONOMOUS_BUILD_CLAUDE.md completely (from start to end)
2. After reading, check ~/.claude/autonomous-loop/<hash>.json for expected_verification_code
3. Update the same file's verification_response field with that code
4. Resume work

You cannot proceed until verification is complete.
```

4. Claude reads protocol fully, then reads state file for code, updates `verification_response`
5. Next exit attempt, hook validates `verification_response` === `expected_verification_code`
6. Match → hook clears `awaiting_verification`, generates NEW code for next time, continues
7. Mismatch → stays blocked, re-prompts

### Code Generation

Script generates new 4-digit code (OS-agnostic):

```bash
generate_verification_code() {
    # Works on both macOS and Linux
    if command -v shuf &> /dev/null; then
        shuf -i 1000-9999 -n 1
    else
        echo $((RANDOM % 9000 + 1000))
    fi
}
```

Code is written to state file JSON via `jq`:
```bash
NEW_CODE=$(generate_verification_code)
jq --arg code "$NEW_CODE" '.expected_verification_code = $code' "$STATE_FILE" > tmp.$$.json && mv tmp.$$.json "$STATE_FILE"
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
| **Escape key** | Interrupts Claude, user can chat. Loop state persists but Claude won't auto-continue. |
| **Ctrl+C** | Kills Claude Code entirely. Loop state persists (not hookable). |
| **"Stop loop"** | User says "stop autonomous mode" — Claude should clear state file manually. |
| **Manual cleanup** | `rm ~/.claude/autonomous-loop/*.json` to clear all loop states |

**Note:** SIGINT (Ctrl+C) and Escape are not hookable — the stop hook only runs on graceful exit attempts. This means:
- Ctrl+C won't automatically clear state (user may need to manually clean up)
- Escape pauses because Claude stops working, not because the hook runs
- On next `claude` session, stale state will be detected and user prompted

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
| `skills/autonomous-loop.md` | Skill definition for `/autonomous-loop` |
| `lib/cheatsheet.md` | The protocol cheat sheet (sourced by stop.sh) |
| `lib/loop-helpers.sh` | Shared functions for state management |
| `tests/test-stop-hook.sh` | Test suite for stop hook |
| `tests/test-loop-helpers.sh` | Unit tests for helper functions |
| `tests/test-integration.sh` | Integration tests for full loop |
| `templates/.claude-quality-gates.example` | Example quality gates file |

### Modified Files

| File | Change |
|------|--------|
| `install.sh` | Add stop.sh to hook installation, configure Stop hook in settings.json, create ~/.claude/autonomous-loop/ |
| `templates/AUTONOMOUS_BUILD_CLAUDE.md` | Add verification section at end (static, no code) |

### Directory Structure

```
~/.claude/
├── autonomous-loop/           # NEW: Loop state files
│   └── <project-hash>.json    # Per-project loop state
├── hooks/
│   ├── pre-compact.sh
│   ├── session-start.sh
│   └── stop.sh               # NEW
├── lib/                       # NEW: Shared libraries
│   ├── cheatsheet.md
│   └── loop-helpers.sh
└── skills/
    └── autonomous-loop.md    # NEW
```

---

## Test Plan

### Unit Tests: Helper Functions (test-loop-helpers.sh)

| Test | Description |
|------|-------------|
| `test_get_project_hash` | Verify consistent hash generation for same path |
| `test_get_state_file_path` | Verify correct path construction |
| `test_generate_verification_code` | Code is 4 digits, different on each call |
| `test_read_state_file_missing` | Gracefully handle missing state file |
| `test_read_state_file_malformed` | Gracefully handle invalid JSON |
| `test_write_state_file` | Verify JSON written correctly |
| `test_session_token_validation` | Token mismatch detected |

### Unit Tests: Stop Hook (test-stop-hook.sh)

| Test | Description |
|------|-------------|
| `test_safety_net_blocks_on_dirty_git` | Uncommitted changes, verify exit code 2 |
| `test_safety_net_allows_clean_exit` | Clean git state, verify exit code 0 |
| `test_safety_net_respects_quality_gates_file` | Only runs gates if `.claude-quality-gates` exists |
| `test_safety_net_skips_quality_gates_if_missing` | No gates file = skip quality checks |
| `test_loop_mode_blocks_when_incomplete` | Active loop, criteria not met, verify exit code 2 |
| `test_loop_mode_allows_when_complete` | Active loop, criteria met, verify exit code 0 |
| `test_loop_mode_ignores_stale_state` | State file from different project ignored |
| `test_loop_mode_validates_session_token` | Mismatched token = inactive |
| `test_loop_increments_iteration` | Verify iteration counter increases |
| `test_max_iterations_pauses` | Hit max, verify paused=true, exit code 2 |
| `test_verification_required_every_3` | Iterations 3,6,9 trigger awaiting_verification |
| `test_verification_validates_code` | Correct code clears flag, wrong code stays blocked |
| `test_verification_generates_new_code` | After validation, new code in state file |
| `test_cheatsheet_injected` | Verify stdout contains cheat sheet on block |
| `test_dynamic_status_injected` | Verify iteration count and blockers in output |

### Edge Case Tests (test-edge-cases.sh)

| Test | Description |
|------|-------------|
| `test_no_git_repo` | Works in non-git directory |
| `test_no_npm` | Works without npm/package.json |
| `test_no_implementation_plan` | Works without IMPLEMENTATION_PLAN.md |
| `test_concurrent_sessions` | Second session detects existing state |
| `test_cross_platform_code_generation` | Works on Linux (shuf) and macOS (RANDOM) |
| `test_state_file_permissions` | State dir created with correct permissions |
| `test_symlink_project_path` | Handles symlinked project directories |

### Integration Tests (test-integration.sh)

| Test | Description |
|------|-------------|
| `test_fire_and_forget_activation` | Skill creates state file with correct fields |
| `test_interactive_activation` | Goal inferred from context |
| `test_full_loop_cycle` | Complete mini-task through multiple iterations |
| `test_pause_and_resume` | Hit max, pause, resume, verify continuation |
| `test_completion_clears_state` | Meet criteria, verify state file removed |
| `test_stale_state_prompts_user` | Old state from previous session prompts |
| `test_hook_chain_integration` | stop.sh works with pre-compact and session-start |

### Manual Testing Checklist

- [ ] Fire and forget: simple task completes autonomously
- [ ] Interactive → autonomous transition works
- [ ] Cheat sheet appears in continuation prompt
- [ ] Protocol re-read triggers at iteration 3
- [ ] Verification code mechanism works end-to-end
- [ ] Max iterations pauses and prompts correctly
- [ ] Escape key interrupts, state persists
- [ ] Ctrl+C kills, state persists (manual cleanup needed)
- [ ] Works across context compaction
- [ ] Codex calls happen at checkpoints (human verification)
- [ ] Quality gates only run if `.claude-quality-gates` exists
- [ ] Works on fresh clone (no prior state)

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
