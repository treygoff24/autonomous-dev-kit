# Spec Writing Guide

> Use this when you need to create a specification for a new feature or application.

---

## When to Use

Use this guide when:
- Building a new application from scratch (greenfield)
- Adding a significant feature to an existing codebase
- The user has provided requirements but no formal spec exists

Skip this if a complete `SPEC.md` already exists.

---

## Draft the Spec

Read any context provided (user requirements, existing codebase, etc.) and create `SPEC.md` with these sections:

**Problem Statement:** What are we building and why? What problem does it solve?

**Scope:** What's in scope for this build? What's explicitly out of scope?

**User Stories:** Who uses this and what do they need to accomplish? Write as "As a [user], I want [capability] so that [benefit]."

**Technical Approach:** High-level architecture, technologies, patterns, and conventions. For existing codebases, how does this integrate with what's already there?

**Data Model:** Entities, relationships, field names, types, and constraints.

**API Contracts:** Endpoints or interfaces needed. Specify request/response shapes, status codes, error formats.

**UI/UX Requirements:** Screens or components needed, interaction patterns. Include all states: loading, empty, error, success.

**Acceptance Criteria:** How do we know this is done? Write specific, testable criteria. Use precise boundaries ("green when value < 3.5") not vague descriptions ("green for low values").

**Edge Cases:** What happens when things go wrong? Network failures, validation errors, concurrent edits, empty states, boundary conditions.

**Non-Functional Requirements:** Performance targets, accessibility requirements, browser/device support, security considerations.

---

## Quality Check

Before requesting review, verify against `SPEC_QUALITY_CHECKLIST.md`:
- Boundaries are precise, not vague
- Types are explicit, not implied
- Error handling is specific, not generic
- Accessibility requirements are actionable
- All states are defined

---

## Get Claude's Review

Call Claude to review your spec:

```bash
claude -p --model opus --dangerously-skip-permissions --output-format text \
  "Review the specification at SPEC.md. Evaluate for: completeness (are all user stories covered?), clarity (are requirements unambiguous?), technical feasibility (is the approach sound?), edge cases (what's missing?), and acceptance criteria quality (are they testable?). Output: Critical gaps / Ambiguities / Suggestions / Verdict (approve or revise)."
```

If Claude's verdict is "revise," address all critical gaps and ambiguities, then call Claude again. Repeat until approved.

---

## Next Step

Once approved, proceed to `IMPLEMENTATION_PLAN_WRITING.md` to create the phased build plan.
