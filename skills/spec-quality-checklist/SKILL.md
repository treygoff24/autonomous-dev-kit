---
name: spec-quality-checklist
description: "Validate a specification before implementation. Use when you've drafted a spec and need to verify it's complete, precise, and unambiguous. Creates TodoWrite items for each check. Run this before proceeding to implementation planning."
---

# Spec Quality Checklist

Validate a specification for precision and completeness before implementation.

## When to Use

- After drafting a spec with `superpowers:brainstorming`
- Before creating an implementation plan
- When reviewing an existing spec for gaps

## How to Use

**Announce:** "I'm using the spec-quality-checklist skill to validate this spec."

**Create TodoWrite items** for each section below. Mark items as you verify them.

## Precision Requirements

Check that boundaries are testable, not vague:

| Requirement | Bad (Ambiguous) | Good (Testable) |
|-------------|-----------------|-----------------|
| **Boundaries** | "green for low values" | "green when value < 3.5" |
| **Types** | "returns user data" | "returns `{ id: string, name: string, email: string }`" |
| **Error handling** | "handle errors gracefully" | "show toast on failure, log to console in dev only" |
| **Accessibility** | "make it accessible" | "arrow keys increment/decrement, changes announced to screen readers" |
| **States** | "show loading state" | "skeleton loader matching final layout dimensions while fetching" |
| **Timing** | "should be fast" | "response within 200ms at p95" |
| **Validation** | "validate the input" | "email must match RFC 5322, show inline error on blur" |
| **Permissions** | "admins can edit" | "users with role='admin' see Edit button, others see read-only view" |

## Completeness Checklist

Create TodoWrite items for each:

### User Stories
- [ ] All user types identified (admin, member, guest, etc.)
- [ ] Each user type has clear capabilities defined
- [ ] Edge user states covered (new user, returning user, user with no data)

### Data Model
- [ ] All entities have explicit field names and types
- [ ] Relationships are defined (one-to-many, many-to-many)
- [ ] Constraints are specified (required, unique, max length)
- [ ] Default values are defined where applicable

### API Contracts
- [ ] All endpoints have request/response shapes
- [ ] Error responses are defined with status codes
- [ ] Authentication/authorization requirements are clear
- [ ] Rate limiting or pagination specified if relevant

### UI/UX
- [ ] All screens/components are listed
- [ ] All states are defined: loading, empty, error, success
- [ ] Interaction patterns are explicit (click, hover, drag, keyboard)
- [ ] Responsive behavior is specified if relevant

### Acceptance Criteria
- [ ] Each criterion is independently testable
- [ ] Success and failure conditions are explicit
- [ ] No criterion uses subjective language ("looks good", "feels fast")

## Red Flags

**Stop and clarify if you see:**
- "etc." or "and so on" — enumerate the full list
- "appropriate" or "suitable" — define specifically what qualifies
- "user-friendly" or "intuitive" — describe the exact behavior
- "handle edge cases" — list the specific edge cases
- "similar to X" — specify the exact aspects to replicate
- Missing error scenarios — every happy path needs a sad path

## Workflow

1. Read the spec thoroughly
2. Create TodoWrite with all checklist items
3. Work through each item, marking complete or noting gaps
4. For any gaps found, either:
   - Fix them in the spec immediately, or
   - Document them for discussion with the user
5. Report: gaps found, gaps fixed, items needing clarification

## Output

After validation, provide:
- **Verdict:** Ready / Needs revision
- **Gaps fixed:** List of issues you corrected
- **Needs clarification:** Items requiring user input
- **Red flags:** Any vague language that should be made precise
