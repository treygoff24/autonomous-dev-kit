# Project Context — DO NOT DELETE

**Last Updated**: Phase [N] - [Name] ([STATUS])

## 🔄 Protocol Reminder (Re-read on every phase start)

**The Loop**: IMPLEMENT → TYPECHECK → LINT → BUILD → TEST → REVIEW → FIX → REPEAT → COMMIT

**Cross-agent checkpoints (mandatory):**
- Spec creation → Claude reviews
- Implementation plan creation → Claude reviews  
- Phase completion → Dual code review with Claude
- Final completion → Claude cross-check
- Stuck in error loop → Call Claude for fresh perspective

**How to call Claude:**
```bash
claude -p --model opus --dangerously-skip-permissions --output-format text "[PROMPT]"
```

**Be patient:** Claude may take 30 seconds to several minutes to respond for complex reviews.

**Quality gates before review:**
```bash
npm run typecheck && npm run lint && npm run build && npm run test
```

## Build Context

**Type**: [Greenfield | Feature addition | Refactor]
**Spec location**: [path to SPEC.md]
**Plan location**: [path to IMPLEMENTATION_PLAN.md]

## Project Setup

- Framework: [e.g., Next.js 14 + TypeScript]
- Styling: [e.g., Tailwind CSS]
- State: [e.g., TanStack Query + Zustand]
- Database: [e.g., Supabase with RLS]
- Testing: [e.g., Vitest + Playwright]

## Current Phase

[What you're working on right now]

## Hook Signatures

[Add every custom hook with its exact return type as you create them]

### useExample()
```typescript
Returns: {
  data: Example[] | null;
  isLoading: boolean;
  error: Error | null;
  refresh: () => void;
}
```

## Utility Functions

[Track utilities and their locations]
- `formatDate(date: Date): string` → `src/utils/dateUtils.ts`

## Import Locations

[Track non-obvious imports to prevent errors]
- `Button` → `@/components/ui/Button`

## Design Decisions

[Record decisions that affect multiple files]
- All dates stored as ISO strings, displayed in local time
- All API responses follow `{ data, error }` shape

## API Contracts

[Document endpoints as you build them]

### GET /api/items
Query: `?limit=10&offset=0`
Response: `{ items: Item[], total: number }`

## Files That Don't Exist

[Prevent importing non-existent modules]
- There is no `getAllItems()` function—use the `items` array directly
