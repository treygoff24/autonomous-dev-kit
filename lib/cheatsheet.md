## AUTONOMOUS BUILD MODE ACTIVE

You are in an autonomous build session. This cheat sheet summarizes
AUTONOMOUS_BUILD_CLAUDE_v2.md — re-read the full protocol if anything is unclear.

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
