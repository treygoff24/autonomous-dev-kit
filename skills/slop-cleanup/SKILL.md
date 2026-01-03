---
name: slop-cleanup
description: "Remove AI-generated low-quality code artifacts from a codebase. Use when asked to: clean up AI slop, remove AI artifacts, fix AI-generated code quality issues, clean up LLM-generated code, remove dead code and redundant abstractions, or audit codebase for AI-generated problems. Works autonomously until all checks pass."
---

# AI Slop Cleanup

Remove AI-generated low-quality artifacts while preserving behavior. Work autonomously until done.

## Done Criteria

1. All high/medium confidence slop addressed
2. All quality checks pass (typecheck, lint, test, build)
3. No regressions introduced

## Constraint Priority

When constraints conflict, follow this order:

1. **Don't break things** — changes must pass existing checks
2. **Preserve public APIs** — unless provably unused
3. **Minimize diff** — prefer deletion over rewrite
4. **Respect conventions** — use repo's formatter/linter
5. **Add tests for modified behavior** — but don't gold-plate

No new dependencies unless absolutely required.

## What Counts as Slop

### A) Hallucination Artifacts
- Calls to non-existent functions, wrong argument orders, fake options
- Wrappers that restate library behavior

### B) Reliability Traps
- Broad try/catch that swallows errors or returns empty defaults
- Defensive null checks everywhere with no invariants
- Missing awaits, unhandled promises, leaky resources

### C) Maintainability Sludge
- Over-commenting that narrates obvious code
- Generic names (`data`, `obj`, `result2`)
- Single-use abstractions for one call site
- Duplicate logic that should be consolidated

### D) Dead Code
- Unused imports, exports, types, params, flags
- Unreachable branches, stale TODO/FIXME
- "Example" or "temporary" code in production

## Autonomous Decision Rules

**Fix it if:**
- Verified unused (zero grep references)
- Behavior preserved (tests pass or you add a test)
- Strict deletion or simplification
- High or medium confidence

**Skip it if:**
- Can't verify usage without production context
- Requires unknown business logic
- Entangled with intentional code
- Low confidence

**When in doubt:** Leave it alone.

## Workflow

### Phase 0: Baseline

1. Create branch: `slop-removal-YYYY-MM-DD`
2. Identify quality gates (lint/typecheck/test/build commands)
3. Run all checks, record results
4. If baseline fails, document and proceed (don't fix unrelated issues)

### Phase 1: Discovery

Build internal slop map with confidence levels:

- **High** — clearly slop, safe to remove
- **Medium** — likely slop, verifiable with tests/usage analysis
- **Low** — suspicious but could be intentional; **skip these**

See [patterns.md](patterns.md) for discovery grep patterns.

Prioritize by risk:
1. Hallucinated APIs / correctness bugs
2. Silent error handling
3. Dead code
4. Redundant abstractions
5. Comment sludge (lowest)

### Phase 2: Cleanup

Work through hotspots in priority order:

1. Smallest edit that removes slop
2. Add targeted test if behavior modified
3. Run checks after each change
4. If checks fail, fix or revert before continuing
5. Commit with message:
   ```
   slop: [category] short description

   - What was removed
   - Why it's safe
   ```

Continue until all high/medium items addressed.

### Phase 3: Final Verification

1. Run full check suite
2. Fix any failures
3. Prepare summary

## Good Fixes

- **Delete** unused code — don't refactor it
- **Inline** single-use wrappers
- **Replace** broad try/catch with precise handling
- **Delete** misleading comments
- **Consolidate** duplicates only if it simplifies

## Hard Prohibitions

- No drive-by formatting
- No renaming sprees
- No architecture changes beyond identified slop
- No speculative fixes
- No touching low-confidence items

## Deliverable

When done, provide:

1. **Summary** — slop removed by category A-D with counts
2. **Check output** — showing all passes
3. **Risk notes** — anything needing attention
4. **Skipped items** — low-confidence items left alone and why

Branch should be ready to merge.
