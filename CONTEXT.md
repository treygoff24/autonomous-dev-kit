# Project Context — DO NOT DELETE

**Last Updated**: 2026-01-07 - Claude Code 2.1.0 alignment (in progress)

## Maximum Autonomy Warning

This template references `--dangerously-skip-permissions`, which bypasses safety prompts. Use only in trusted repos and remove the flag if you want approval gates.

## 🔄 Protocol Reminder (Re-read on every phase start)

**The Loop**: IMPLEMENT → TYPECHECK → LINT → BUILD → TEST → REVIEW → FIX → REPEAT → COMMIT

**Cross-agent checkpoints (mandatory):**
- Spec creation → Codex + Gemini reviews
- Implementation plan creation → Codex + Gemini reviews
- Phase completion → Tri code review (Claude + Codex + Gemini)
- Final completion → Codex + Gemini cross-check
- Stuck in error loop → Call Codex or Gemini for fresh perspective

**How to call Claude:**
```bash
claude -p --model opus --dangerously-skip-permissions --output-format text "[PROMPT]"
```

**How to call Codex:**
```bash
codex exec -m gpt-5.2-codex -c model_reasoning_effort="xhigh" --dangerously-bypass-approvals-and-sandbox "[PROMPT]"
```

**How to call Gemini:**
```bash
git diff | gemini -p "[PROMPT]" --output-format text
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

Align autonomous-dev-kit with Claude Code 2.1.0 features per plan in `docs/plans/2026-01-07-claude-code-2-1-0-updates.md`.

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
