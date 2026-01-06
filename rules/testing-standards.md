---
globs: "**/*.test.*,**/*.spec.*,**/test/**,**/tests/**,**/__tests__/**"
---

# Testing Standards

These standards are auto-loaded when working with test files.

## Anti-Patterns to Avoid

### Never Test Mock Behavior

```typescript
// BAD: Testing that mock exists
expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();

// GOOD: Test real component behavior
expect(screen.getByRole('navigation')).toBeInTheDocument();
```

### Never Add Test-Only Methods to Production

```typescript
// BAD: Production class with test-only method
class Session {
  destroy() { /* only used in tests */ }
}

// GOOD: Test utilities handle cleanup
// In test-utils/
export function cleanupSession(session) { ... }
```

### Never Mock Without Understanding

Before mocking, ask:
1. What side effects does the real method have?
2. Does this test depend on those side effects?
3. Am I mocking at the right level?

### Incomplete Mocks Hide Bugs

Mock the COMPLETE data structure, not just fields you think you need.

## Condition-Based Waiting

Replace arbitrary timeouts with condition polling:

```typescript
// BAD
await new Promise(r => setTimeout(r, 1000));
expect(element).toBeVisible();

// GOOD
await waitFor(() => expect(element).toBeVisible());
```

```python
# BAD
time.sleep(1)
assert element.is_visible()

# GOOD
wait_for(lambda: element.is_visible())
```

## TDD Requirements

1. Write failing test first
2. Watch it fail for expected reason
3. Write minimal code to pass
4. Verify tests pass
5. Then refactor

## Good Test Qualities

| Quality | Good | Bad |
|---------|------|-----|
| Minimal | One thing per test | "and" in test name |
| Clear | Name describes behavior | "test1", "works" |
| Real | Tests actual code | Tests mock behavior |
| Fast | Runs in milliseconds | Arbitrary sleeps |
