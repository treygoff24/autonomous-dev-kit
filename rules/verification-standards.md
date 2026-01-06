---
globs: "**/*"
---

# Verification Standards

These standards apply to ALL work. Always loaded.

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

## Before Claiming Any Status

1. **IDENTIFY:** What command proves this claim?
2. **RUN:** Execute the FULL command (fresh)
3. **READ:** Full output, check exit code
4. **VERIFY:** Does output confirm claim?
5. **ONLY THEN:** Make the claim

## Evidence Requirements

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test output: 0 failures | "should pass" |
| Build succeeds | Build exit code: 0 | Linter passing |
| Bug fixed | Test original symptom | "code changed" |
| Requirements met | Line-by-line checklist | Tests passing |
| Agent completed | VCS diff shows changes | Agent reports success |

## Red Flags - STOP

If you catch yourself:
- Using "should", "probably", "seems to"
- Expressing satisfaction before verification
- About to commit without running tests
- Trusting agent success reports without checking
- Thinking "just this once"

**All of these mean: Run verification first.**

## The Pattern

```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

## Agent Delegation

When spawning agents:
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report blindly
```

## The Bottom Line

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
