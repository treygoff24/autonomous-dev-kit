# Autonomous Protocol Adherence Improvements (2026-01-08)

## Why This Plan

Autonomous sessions drift from the protocol because reminders and verification
instructions are not reliably present in the model-facing input. The current Stop
hook uses `systemMessage` for verification (shown to the user, not Claude), and
the continuation prompt with the cheatsheet is defined but not injected. This
plan fixes those delivery paths, adds a verifiable re-read handshake, and
reinjects protocol anchors at the moments context is most likely to degrade.

## Goals

- Keep the protocol in Claude's context for every autonomous iteration.
- Enforce periodic, explicit protocol re-reads with a simple verification step.
- Align docs/templates with the actual runtime behavior.

## Non-Goals

- Tool-level guardrails (CLI wrappers, tool restrictions, `--append-system-prompt`,
  `outputStyle` changes, or sandbox policies).
- Changing completion criteria or adding new quality gates.

## Implementation Plan

1. **Make the Stop hook deliver the protocol to Claude**
   - Move the continuation prompt (cheatsheet + loop status + blockers) into the
     Stop hook `reason`, and keep `systemMessage` for human-readable status only.
   - Align verification cadence to every 3 iterations (per docs).
   - **Why:** Claude only sees the `reason` payload; this fixes the missing
     protocol reminders and verification instructions.

2. **Add a verification code handshake**
   - Store `expected_verification_code` in `.claude/autonomous-loop.json`.
   - Require `<verified code="####"/>` (or `<verified>####</verified>`) after
     a full protocol re-read.
   - Preserve the soft-fail after N attempts to avoid infinite loops.
   - **Why:** reduces false positives and forces an explicit, observable action.

3. **Re-inject protocol anchors at reliable entry points**
   - SessionStart hook: when loop active, append a protocol reminder/cheatsheet
     snippet to the injected context.
   - UserPromptSubmit hook: when loop active, add a small protocol anchor before
     each new prompt.
   - Wire the new hook in `install.sh` so it is configured automatically.
   - **Why:** SessionStart handles compaction resets; UserPromptSubmit keeps the
     protocol fresh on each iteration.

4. **Align docs and templates with new behavior**
   - Update the cheatsheet, autonomous loop skill doc, and protocol template to
     describe the verification code flow.
   - Update `WORKFLOW_REFERENCE.md` and `GETTING_STARTED.md` to match the new
     state file path and verification mechanics.
   - Update `templates/CLAUDE.md` with a short autonomous protocol anchor.
   - **Why:** removes mismatches between documentation and runtime behavior.

## Expected File Touches

- `hooks/stop.sh`
- `lib/loop-helpers.sh`
- `lib/cheatsheet.md`
- `hooks/session-start.sh`
- `hooks/user-prompt-submit.sh` (new)
- `install.sh`
- `skills/autonomous-loop/index.md`
- `templates/AUTONOMOUS_BUILD_CLAUDE_v2.md`
- `templates/CLAUDE.md`
- `docs/WORKFLOW_REFERENCE.md`
- `docs/GETTING_STARTED.md`
