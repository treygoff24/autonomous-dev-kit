---
globs: "**/*.js,**/*.jsx,**/*.ts,**/*.tsx,**/*.py,**/*.go,**/*.rs,**/*.java,**/*.rb,**/*.php,**/*.c,**/*.cpp,**/*.h,**/*.hpp,**/*.cs,**/*.swift,**/*.kt"
---

# Code Quality Standards

Auto-loaded for all code work.

## Slop Patterns to Remove

Before committing, check for and remove:

**Comments:**
- Unnecessary comments restating code
- Commented-out code blocks
- Empty TODO comments
- JSDoc that just repeats function name

**Variables:**
- Single-use variables (inline them)
- Unused imports
- Unused variables/parameters

**Code:**
- Empty catch blocks
- `any` type casts (TypeScript)
- Untyped parameters (Python)
- Debug statements (console.log, print)
- Over-abstracted one-liner utilities

## Patterns to PRESERVE

Do NOT remove:
- API boundary validation
- Auth/RLS checks
- Error handling at system edges
- Comments explaining WHY (not what)
- Audit logging
- Type annotations that add clarity

## Commit Hygiene

### Before Every Commit

```bash
# JavaScript/TypeScript
npm run typecheck && npm run lint && npm run test

# Python
pytest && ruff check . && black --check .
```

### Commit Message Format

```
type: short description

- What changed
- Why it changed

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

### One Logical Change Per Commit

Don't bundle:
- Feature + unrelated refactor
- Bug fix + "improvements"
- Multiple independent changes

## Import Hygiene

- Remove unused imports
- Sort imports (auto-format should handle)
- No circular dependencies
- Use absolute imports over deep relative paths

## YAGNI

Don't add:
- Features "we might need later"
- Abstractions for one-time operations
- Configuration for single values
- Backwards-compatibility shims for new code
