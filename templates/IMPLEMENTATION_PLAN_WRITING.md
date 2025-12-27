# Implementation Plan Writing Guide

> Use this when you need to create a phased implementation plan from an approved spec.

---

## When to Use

Use this guide when:
- You have an approved `SPEC.md` and need to plan the build
- You're breaking down a large feature into manageable phases

Skip this if a complete `IMPLEMENTATION_PLAN.md` already exists.

---

## Draft the Plan

Create `IMPLEMENTATION_PLAN.md` with a phased approach. Each phase should be completable in one focused session (roughly 30-90 minutes of work). Order phases by dependency—foundational work before features that depend on it.

### Status Header

Start with this status block (update it throughout the build):

```markdown
## Current Status

**Phase**: [N] - [Name]
**Working on**: [Current file/component]
**Cross-agent reviews completed**: [List checkpoints passed]
**Blockers**: [None or description]
**Runtime**: [Elapsed time since start]
```

### Phase Structure

For each phase, specify:

**Phase [N]: [Name]**
- **Objective:** What this phase accomplishes
- **Dependencies:** What must be complete before starting
- **Tasks:** Specific work items (files to create/modify, tests to write)
- **Acceptance criteria:** How to verify this phase is complete
- **Estimated complexity:** Simple / Moderate / Complex

### For Existing Codebases

Include a Phase 0.5 that covers:
- Understanding the existing code structure
- Identifying integration points
- Noting existing patterns to follow
- Creating a feature branch

### Sizing Guidelines

- **Simple phase:** Single file changes, straightforward logic, <30 min
- **Moderate phase:** Multiple related files, some complexity, 30-60 min
- **Complex phase:** Cross-cutting changes, new patterns, 60-90 min

If a phase feels larger than 90 minutes, split it.

---

## Get Claude's Review

Call Claude to review your plan:

```bash
claude -p --model opus --dangerously-skip-permissions --output-format text \
  "Review the implementation plan at IMPLEMENTATION_PLAN.md against the spec at SPEC.md. Evaluate for: correct sequencing (dependencies respected?), completeness (does it cover the full spec?), phase sizing (are phases appropriately scoped?), risk identification (what could go wrong?), and missing steps. Output: Sequencing issues / Missing work / Risk factors / Suggestions / Verdict (approve or revise)."
```

If Claude's verdict is "revise," address all issues, then call Claude again. Repeat until approved.

---

## Next Step

Once approved, proceed to the autonomous build protocol (`AUTONOMOUS_BUILD_CLAUDE_v2.md` or `AUTONOMOUS_BUILD_CODEX_v2.md`) to begin implementation.
