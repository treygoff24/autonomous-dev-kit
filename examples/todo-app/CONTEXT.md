# Project Context — DO NOT DELETE

**Last Updated**: Phase 3 - UI Components (IN PROGRESS)

## Protocol Reminder (Re-read on every phase start)

**The Loop**: IMPLEMENT → TYPECHECK → LINT → BUILD → TEST → REVIEW → FIX → REPEAT → COMMIT

**Cross-agent checkpoints (mandatory):**
- Spec creation → Claude reviews ✓
- Implementation plan creation → Codex reviews ✓
- Phase completion → Dual code review
- Final completion → Cross-check
- Stuck in error loop → Call other agent

**Quality gates before review:**
```bash
npm run typecheck && npm run lint && npm run build && npm run test
```

---

## Build Context

**Type**: Greenfield
**Spec location**: SPEC.md
**Plan location**: IMPLEMENTATION_PLAN.md

## Project Setup

- Framework: React 18 + TypeScript
- Build: Vite 5
- Styling: CSS Modules
- State: Custom useTodos hook
- Testing: Vitest + Testing Library
- Persistence: localStorage

---

## Current Phase

Working on Phase 3: UI Components

**Completed this phase:**
- TodoApp.tsx container
- TodoInput.tsx with Enter key handling
- TodoList.tsx with empty state

**In progress:**
- TodoItem.tsx with checkbox, text, delete

**Next:**
- TodoFilters.tsx
- CSS Modules styling
- Component tests

---

## Hook Signatures

### useTodos()
```typescript
Returns: {
  todos: Todo[];
  filteredTodos: Todo[];
  filter: Filter;
  addTodo: (text: string) => void;
  toggleTodo: (id: string) => void;
  deleteTodo: (id: string) => void;
  clearCompleted: () => void;
  setFilter: (filter: Filter) => void;
  activeCount: number;
  completedCount: number;
}
```

---

## Utility Functions

- `generateId(): string` → `src/utils/storage.ts`
- `loadTodos(): Todo[]` → `src/utils/storage.ts`
- `saveTodos(todos: Todo[]): void` → `src/utils/storage.ts`
- `loadFilter(): Filter` → `src/utils/storage.ts`
- `saveFilter(filter: Filter): void` → `src/utils/storage.ts`

---

## Import Locations

- `Todo, Filter` → `@/types/todo`
- `useTodos` → `@/hooks/useTodos`
- All components → `@/components/*`

---

## Design Decisions

1. **UUID generation:** Using crypto.randomUUID() for IDs
2. **Storage format:** JSON array in localStorage, key 'todos'
3. **Filter persistence:** Separate key 'todoFilter'
4. **Error handling:** Silent fallback to memory-only if localStorage fails
5. **Text truncation:** Using CSS text-overflow, full text in title attribute

---

## API Contracts

N/A - No backend API, all local state

---

## Files That Don't Exist

- No router - single page app
- No context providers - using hook directly
- No API layer - localStorage only

---

## Issues Encountered

### Phase 2
- Initially forgot to handle corrupted JSON in storage
- Added try/catch with fallback to empty array
- Test added to prevent regression

### Phase 3 (current)
- Checkbox styling was inconsistent across browsers
- Using custom checkbox with hidden native input
