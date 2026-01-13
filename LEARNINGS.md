# Project Learnings

> Append entries at session end. Read recent entries at session start. This accumulator compounds insights across builds.

---

## Template Entry

```markdown
## YYYY-MM-DD — [Feature/Project Name]

**What Worked:**
- [Specific technique or decision that paid off]

**What Failed:**
- [Approach that didn't work and why]

**Patterns:**
- [Reusable insight for future builds]
```

---

## Example Entries

### 2024-01-15 — User Authentication Feature

**What Worked:**
- Writing integration tests before implementing the auth flow caught API contract mismatches early
- Splitting the auth provider into smaller hooks (`useAuth`, `useSession`, `usePermissions`) made testing easier

**What Failed:**
- Initially tried to handle all auth states in a single context, led to complex conditional logic
- Skipped error state UI during first pass, had to retrofit later

**Patterns:**
- Always design error states alongside happy paths in the spec
- For auth flows, write the logout flow first - it exercises the same paths but is simpler

### 2024-01-22 — Dashboard Performance Optimization

**What Worked:**
- Profiling before optimizing identified the actual bottleneck (excessive re-renders, not data fetching)
- Memoizing expensive list computations with `useMemo` + stable keys solved 80% of the issue

**What Failed:**
- First instinct was to add caching, but the problem was client-side rendering, not data fetching

**Patterns:**
- Profile first, optimize second - intuition about performance issues is often wrong
- Virtual scrolling is usually overkill for lists under 1000 items; simple memoization suffices

---

## Your Learnings

<!-- Add your entries below -->
