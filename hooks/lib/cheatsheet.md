## AUTONOMOUS BUILD MODE ACTIVE

**You are the orchestrator, not the implementer.** Before doing any work, check if there's a skill for it. Skills spawn subagents under the hood.

Re-read AUTONOMOUS_BUILD_CLAUDE.md if anything is unclear.

DO NOT STOP until completion criteria are met. Execute with precision.

---

**Implementation Loop (every phase):**
IMPLEMENT → TYPECHECK → LINT → BUILD → TEST → REVIEW → SLOP REMOVAL → COMMIT

**Skills first (they handle complexity for you):**
- `/writing-plans` → create implementation plans
- `/debugging-systematic` → spawns debugger agent for root cause analysis
- `/requesting-code-review` → spawns code-reviewer agent
- `/codex` → external AI review (may take 30 min, wait for response)
- `/gemini` → third-party AI review
- `/autonomous-loop` → keeps you working until complete

Mandatory external review checkpoints (`/codex` + `/gemini`):
- After drafting spec
- After drafting implementation plan
- After completing each phase
- Before declaring build complete
- When stuck 3+ times on same error

**Direct agent spawns (when you need fine control):**
- `tdd-implementer` agent → red-green-refactor TDD
- `Explore` subagent → understand unfamiliar code
- `bug-hunter` subagent → first step when hitting errors
- `security-auditor` subagent → auth, inputs, sensitive changes
- `accessibility-auditor` subagent → UI changes
- `test-architect` subagent → comprehensive test coverage

**Rules (auto-loaded):**
- `verification-standards` — No claims without evidence

**Context Hygiene:**
- Update CONTEXT.md 2x per phase minimum
- Update IMPLEMENTATION_PLAN.md after each phase

**Protocol Verification (every 3 iterations):**
- Re-read AUTONOMOUS_BUILD_CLAUDE.md end-to-end
- Check `.claude/autonomous-loop.json` for `expected_verification_code`
- Respond with `<verified code="####"/>` using that code

**Completion Criteria:**
All phases complete + all quality gates pass + `/codex` + `/gemini` final verdict "ship it"
