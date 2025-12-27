# Project Learnings

> Append entries at session end. Read recent entries at session start.

---

## 2024-01-15 — Todo App Build

**What Worked:**

- Writing the spec with precise acceptance criteria meant no ambiguity during implementation
- Breaking into 4 phases kept each phase under 30 minutes
- Custom useTodos hook made component code very clean
- Writing storage utility tests first caught the corrupted JSON edge case before it hit production

**What Failed:**

- Initially skipped the empty state UI, had to retrofit in Phase 3
- First pass at checkbox styling was inconsistent across browsers
- Forgot to add aria-live for screen reader announcements (caught in Phase 4 review)

**Patterns:**

- Always define empty/error states in the spec, not just happy path
- Use CSS custom properties for theming, even in small projects
- Test localStorage operations with both valid and invalid data
- Browser-native checkboxes are ugly; plan for custom styling from the start

---

## Key Takeaways

1. **Spec precision pays off** — The upfront time spent on precise acceptance criteria saved debugging time later

2. **4 phases was right** — Each phase was a focused session, easy to maintain context

3. **Cross-agent reviews found different issues:**
   - Claude caught architectural concerns (hook design, error handling)
   - Codex caught edge cases (empty input, long text)
   - Both were needed

4. **Slop removal mattered** — First pass had 15+ console.log statements and several TODO comments. Clean code ships.

5. **75 minutes total** — From spec to working app, including reviews

---

## Patterns to Reuse

### Project Structure
```
src/
├── components/    # UI components with co-located CSS modules
├── hooks/         # Custom hooks for state/logic
├── types/         # TypeScript types
├── utils/         # Pure utility functions
└── App.tsx        # Root component
```

### localStorage Pattern
```typescript
export function loadData<T>(key: string, fallback: T): T {
  try {
    const stored = localStorage.getItem(key);
    return stored ? JSON.parse(stored) : fallback;
  } catch {
    console.error(`Failed to load ${key} from storage`);
    return fallback;
  }
}
```

### Filter Pattern
```typescript
const filteredItems = useMemo(() => {
  switch (filter) {
    case 'active': return items.filter(i => !i.completed);
    case 'completed': return items.filter(i => i.completed);
    default: return items;
  }
}, [items, filter]);
```
