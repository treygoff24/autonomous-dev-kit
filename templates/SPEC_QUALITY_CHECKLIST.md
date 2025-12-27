# Spec Quality Checklist

> Use this to validate a specification before implementation. If any items fail, resolve the ambiguity before writing code.

---

## Precision Requirements

| Requirement | ❌ Bad (Ambiguous) | ✅ Good (Testable) |
|-------------|-------------------|-------------------|
| **Boundaries** | "green for low values" | "green when value < 3.5" |
| **Types** | "returns user data" | "returns `{ id: string, name: string, email: string }`" |
| **Error handling** | "handle errors gracefully" | "show toast on failure, log to console in dev only" |
| **Accessibility** | "make it accessible" | "arrow keys increment/decrement, changes announced to screen readers" |
| **States** | "show loading state" | "skeleton loader matching final layout dimensions while fetching" |
| **Timing** | "should be fast" | "response within 200ms at p95" |
| **Validation** | "validate the input" | "email must match RFC 5322, show inline error on blur" |
| **Permissions** | "admins can edit" | "users with role='admin' see Edit button, others see read-only view" |

---

## Completeness Checks

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

---

## Red Flags

Stop and clarify if you see:
- "etc." or "and so on" — enumerate the full list
- "appropriate" or "suitable" — define specifically what qualifies
- "user-friendly" or "intuitive" — describe the exact behavior
- "handle edge cases" — list the specific edge cases
- "similar to X" — specify the exact aspects to replicate
- Missing error scenarios — every happy path needs a sad path
