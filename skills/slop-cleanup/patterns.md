# Slop Discovery Patterns

Grep patterns for finding AI slop. Adapt file type flags to the codebase.

## Empty/Swallowing Catch Blocks

```bash
# Empty catch
rg 'catch\s*\([^)]*\)\s*\{\s*\}' --type ts --type js

# Log-and-continue (often hides real errors)
rg 'catch.*\{[^}]*console\.(log|warn|error)[^}]*\}' --type ts --type js

# Returns null/undefined in catch (silent failure)
rg 'catch.*return\s*(null|undefined|{})' --type ts --type js
```

## Defensive Over-Engineering

```bash
# Deep optional chaining (often defensive cruft)
rg '\?\.\w+\?\.\w+\?\.' --type ts

# Nullish coalescing chains
rg '\?\?\s*\w+\s*\?\?' --type ts

# Excessive null checks
rg 'if\s*\(\s*\w+\s*(===?|!==?)\s*(null|undefined)\s*\)' --type ts --type js
```

## Dead Code Signals

```bash
# Stale markers
rg 'TODO|FIXME|XXX|HACK|TEMP|temporary|remove this' -i

# Commented-out code blocks
rg '^\s*//.*\{' --type ts --type js
rg '^\s*//.*function' --type ts --type js

# Unused exports (cross-reference with imports)
rg '^export (const|function|class|interface|type) \w+' --type ts -l
```

## Suspicious Patterns

```bash
# Generic variable names
rg '\b(data|obj|result|temp|tmp|item|value)\d*\s*=' --type ts --type js

# Single-letter variables outside loops
rg '\b(const|let|var)\s+[a-z]\s*=' --type ts --type js

# "Helper" or "Utils" that may be single-use
rg '(helper|util|utils|common)' -i -l
```

## Wrapper Function Detection

Look for functions that:
1. Are exported
2. Have only one call site
3. Simply wrap another function with minimal logic

```bash
# Find all exported functions
rg '^export (async )?function \w+' --type ts -l

# Then check usage count for each
rg 'functionName' --type ts -c
```

## Framework-Specific Patterns

### React
```bash
# Unused hooks
rg 'use[A-Z]\w+\(' --type tsx -l
# Then verify each is actually used in JSX

# Empty useEffect dependencies that should have deps
rg 'useEffect\([^)]+,\s*\[\s*\]\)' --type tsx
```

### Node/Express
```bash
# Catch-all error handlers that swallow
rg 'app\.use\([^)]*err[^)]*\{' --type ts --type js

# Unhandled promise in route
rg '(get|post|put|delete)\([^)]+async' --type ts --type js
```

## What NOT to Grep For

These catch comments/docs, not actual slop:
- "generated", "ChatGPT", "Copilot", "AI"
- "auto-generated", "created by"

Focus on **code patterns**, not self-identifying comments.
