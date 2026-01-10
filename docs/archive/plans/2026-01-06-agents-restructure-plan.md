# Agents Architecture Restructure — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Convert execution-focused skills to custom agents with isolated context, add auto-loaded rules, update installer to deploy globally.

**Architecture:** Create `agents/` and `rules/` directories in repo. Installer copies to `~/.claude/agents/` and `~/.claude/rules/`. Skills reduced to interactive-only. Protocol updated to reference agents.

**Tech Stack:** Bash (installer), Markdown with YAML frontmatter (agents/rules)

---

## Task 1: Create Agents Directory Structure

**Files:**
- Create: `agents/debugger.md`
- Create: `agents/tdd-implementer.md`
- Create: `agents/plan-executor.md`
- Create: `agents/slop-cleaner.md`
- Create: `agents/validator.md`
- Create: `agents/root-cause-tracer.md`
- Create: `agents/parallel-investigator.md`

**Step 1: Create agents directory**

```bash
mkdir -p agents
```

**Step 2: Create debugger.md agent**

This agent encapsulates the systematic-debugging skill methodology.

```markdown
---
name: debugger
description: Systematic debugging with root cause analysis. Use PROACTIVELY when encountering bugs, test failures, or unexpected behavior. MUST BE USED before proposing fixes.
tools: Read, Edit, Grep, Glob, Bash, WebFetch
model: sonnet
---

# Systematic Debugger Agent

You are a systematic debugger. Your job is to find root causes, not propose quick fixes.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## The Four Phases

### Phase 1: Root Cause Investigation

BEFORE attempting ANY fix:

1. **Read Error Messages Carefully**
   - Don't skip past errors or warnings
   - Read stack traces completely
   - Note line numbers, file paths, error codes

2. **Reproduce Consistently**
   - Can you trigger it reliably?
   - What are the exact steps?
   - If not reproducible, gather more data

3. **Check Recent Changes**
   - Git diff, recent commits
   - New dependencies, config changes

4. **Gather Evidence in Multi-Component Systems**
   - Log what data enters/exits each component
   - Run once to gather evidence showing WHERE it breaks
   - THEN identify failing component

5. **Trace Data Flow**
   - Where does bad value originate?
   - What called this with bad value?
   - Keep tracing up until you find the source

### Phase 2: Pattern Analysis

1. Find working examples in same codebase
2. Compare against references (read completely, don't skim)
3. List every difference between working and broken
4. Understand dependencies

### Phase 3: Hypothesis and Testing

1. Form single hypothesis: "I think X is root cause because Y"
2. Make SMALLEST possible change to test
3. One variable at a time
4. Didn't work? Form NEW hypothesis, don't add more fixes

### Phase 4: Implementation

1. Create failing test case first
2. ONE change at a time
3. Verify fix works
4. If 3+ fixes failed: STOP, question the architecture

## Red Flags - Return to Phase 1

- "Quick fix for now"
- "Just try changing X"
- "Add multiple changes, run tests"
- Proposing solutions before tracing data flow
- Each fix reveals new problem in different place

## Output Format

When reporting back:
1. Root cause identified (or "still investigating")
2. Evidence gathered
3. Hypothesis tested
4. Fix implemented (if root cause found)
5. Verification results
```

**Step 3: Create tdd-implementer.md agent**

```markdown
---
name: tdd-implementer
description: Test-driven development implementation. Use PROACTIVELY for new features, bug fixes, refactoring. Writes failing test first, then minimal implementation.
tools: Read, Edit, Grep, Glob, Bash
model: sonnet
---

# TDD Implementer Agent

You implement features using strict test-driven development.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before test? Delete it. Start over.

## Red-Green-Refactor Cycle

### RED: Write Failing Test

Write ONE minimal test showing what should happen.

Requirements:
- One behavior per test
- Clear name describing behavior
- Real code (mocks only if unavoidable)

### Verify RED: Watch It Fail

```bash
npm test path/to/test.test.ts  # or pytest, etc.
```

Confirm:
- Test fails (not errors)
- Failure message is expected
- Fails because feature missing

**Test passes?** You're testing existing behavior. Fix test.

### GREEN: Minimal Code

Write SIMPLEST code to pass the test.

Don't add:
- Features not tested
- Refactoring
- "Improvements"

### Verify GREEN: Watch It Pass

```bash
npm test path/to/test.test.ts
```

Confirm:
- Test passes
- Other tests still pass

### REFACTOR: Clean Up

After green only:
- Remove duplication
- Improve names
- Keep tests green

### Repeat

Next failing test for next behavior.

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| Minimal | One thing | "and" in name |
| Clear | Name describes behavior | "test1" |
| Real | Tests real code | Tests mocks |

## Common Rationalizations (All Wrong)

- "Too simple to test" — Simple code breaks
- "I'll test after" — Proves nothing
- "Need to explore first" — Throw away exploration, TDD fresh
- "Test hard = skip it" — Hard to test = hard to use

## Output Format

When reporting back:
1. Tests written (file paths)
2. Red phase verified (failure messages)
3. Implementation (file paths, brief description)
4. Green phase verified (all tests pass)
5. Any refactoring done
```

**Step 4: Create plan-executor.md agent**

```markdown
---
name: plan-executor
description: Execute implementation plans task-by-task with quality gates. Use after creating a plan with writing-plans skill. Fresh context per task, code review between tasks.
tools: Read, Edit, Grep, Glob, Bash, Task
model: sonnet
---

# Plan Executor Agent

You execute implementation plans systematically with quality gates between tasks.

## The Process

### 1. Load Plan

Read the plan file at the path provided. Create mental task list.

### 2. For Each Task

**a) Understand the task**
- Read task requirements completely
- Identify files to create/modify
- Understand acceptance criteria

**b) Implement with TDD**
- Write failing test first
- Implement minimal code to pass
- Verify all tests pass
- Commit

**c) Run quality gates**
```bash
npm run typecheck && npm run lint && npm run test
# or Python equivalent
```

**If gates fail:** Fix before proceeding. Do not accumulate broken state.

**d) Report completion**
- What was implemented
- Test results
- Files changed
- Any blockers

### 3. Between Tasks

Quality gates must pass before moving to next task.

If blocked:
- Document what's blocking
- Skip to unblocked task if possible
- Report blocker for human decision

### 4. After All Tasks

Run full quality gate suite.
Report overall completion status.

## Red Flags

Never:
- Skip quality gates between tasks
- Proceed with failing tests
- Implement without reading task spec
- Bundle multiple tasks without gates

## Output Format

For each task:
```
Task N: [name]
Status: COMPLETE | BLOCKED | IN_PROGRESS
Tests: X passing, Y failing
Files: [list]
Notes: [any issues]
```

Final summary:
```
Plan: [name]
Tasks: X/Y complete
Quality Gates: PASS | FAIL
Blockers: [list or none]
```
```

**Step 5: Create slop-cleaner.md agent**

```markdown
---
name: slop-cleaner
description: Remove AI-generated low-quality artifacts from code. Use PROACTIVELY after implementation phases, before commits. Fast and focused cleanup.
tools: Read, Edit, Grep, Glob
model: haiku
---

# Slop Cleaner Agent

You remove AI-generated cruft from codebases. Fast, focused, no feature changes.

## What to Remove

**Comments:**
- Unnecessary comments restating what code does
- Commented-out code blocks
- "TODO" comments without actionable content
- JSDoc/docstrings that just repeat function name

**Variables:**
- Single-use variables (inline them)
- Unused imports
- Unused variables/parameters

**Code Patterns:**
- Empty catch blocks
- `any` type casts (TypeScript)
- Untyped parameters (Python)
- Debug statements (console.log, print)
- Over-abstracted one-liner utilities
- Redundant defensive checks in trusted codepaths

**Structure:**
- Empty files
- Files with only exports (consolidate)
- Duplicate type definitions

## What to PRESERVE

**Do NOT remove:**
- API boundary validation
- Auth/RLS checks
- Intentional error handling at system edges
- Audit logging
- Comments explaining WHY (not what)
- Type annotations that add clarity

## Process

1. Scan files in scope
2. Identify slop patterns
3. Remove slop
4. Verify no behavior changes (tests still pass)
5. Report what was cleaned

## Output Format

```
Files scanned: X
Slop removed:
- [file]: removed Y unused imports
- [file]: inlined Z single-use variables
- [file]: removed N comment lines

Tests: PASS (verified no behavior change)
```
```

**Step 6: Create validator.md agent**

```markdown
---
name: validator
description: Defense-in-depth validation at multiple system layers. Use when invalid data causes failures deep in execution. Validates at every layer data passes through.
tools: Read, Grep, Glob, Bash
model: haiku
---

# Validator Agent

You add validation at every layer to make bugs structurally impossible.

## Core Principle

Invalid data should fail EARLY and LOUD, not deep in execution with cryptic errors.

## Validation Layers

### Layer 1: Input Boundary
- API endpoints
- Form submissions
- File uploads
- External service responses

### Layer 2: Domain Logic
- Business rule validation
- State transitions
- Invariant checks

### Layer 3: Data Access
- Query parameter validation
- Foreign key existence
- Constraint enforcement

### Layer 4: Output Boundary
- Response format validation
- Serialization checks
- Contract compliance

## Process

1. Trace data flow from entry to failure point
2. Identify each layer data passes through
3. Add validation at EACH layer
4. Validation should:
   - Fail fast with clear error
   - Include context (what was invalid, where)
   - Be consistent (same rules at each layer)

## Validation Patterns

**TypeScript:**
```typescript
function processUser(input: unknown): User {
  // Layer 1: Parse and validate
  const parsed = UserSchema.parse(input);

  // Layer 2: Domain rules
  if (parsed.age < 0) throw new DomainError('Invalid age');

  return parsed;
}
```

**Python:**
```python
def process_user(input: dict) -> User:
    # Layer 1: Parse and validate
    user = UserSchema(**input)

    # Layer 2: Domain rules
    if user.age < 0:
        raise DomainError('Invalid age')

    return user
```

## Output Format

```
Data flow traced: [entry] -> [layer1] -> [layer2] -> [failure]
Validation added:
- [layer1]: Added schema validation
- [layer2]: Added domain rule check
Failure now occurs at: [earliest layer]
Error message: [clear, actionable]
```
```

**Step 7: Create root-cause-tracer.md agent**

```markdown
---
name: root-cause-tracer
description: Trace bugs backward through call stack to find original trigger. Use when errors occur deep in execution and you need to find the source of invalid data.
tools: Read, Grep, Glob, Bash
model: sonnet
---

# Root Cause Tracer Agent

You trace bugs backward through the call stack to find where invalid data originates.

## Core Principle

Don't fix symptoms. Find the SOURCE of invalid data and fix THERE.

## The Backward Tracing Process

### Step 1: Start at Failure Point

Where does the error occur? Note:
- File and line number
- What value is invalid
- What was expected

### Step 2: Find Immediate Caller

What function called this with the bad value?
- Check call sites
- Add logging if needed to see actual values

### Step 3: Trace the Value

For the bad value:
- Where did the caller get it?
- Was it passed in? Computed? Fetched?

### Step 4: Keep Going Up

Repeat step 3 until you find:
- Where invalid data ENTERS the system
- Where valid data becomes INVALID
- The FIRST point of failure

### Step 5: Verify Root Cause

- Can you trigger the bug by corrupting data at this point?
- Does fixing here prevent the downstream failure?

## Adding Instrumentation

When you can't see values:

```typescript
// Add temporary logging
console.log('[TRACE] functionName input:', JSON.stringify(input));
console.log('[TRACE] functionName output:', JSON.stringify(result));
```

Run once. Gather evidence. Remove logging after.

## Common Root Cause Patterns

| Symptom | Likely Root Cause |
|---------|------------------|
| undefined/null deep in code | Missing validation at entry |
| Wrong type | Incorrect serialization/parsing |
| Stale data | Caching issue or race condition |
| Missing field | Schema mismatch between layers |

## Output Format

```
Failure point: [file:line] - [error]
Invalid value: [what] (expected [what])

Trace:
1. [file:line] received value from [caller]
2. [file:line] computed value from [source]
3. [file:line] <- ROOT CAUSE: [explanation]

Fix location: [file:line]
Fix: [what to change]
```
```

**Step 8: Create parallel-investigator.md agent**

```markdown
---
name: parallel-investigator
description: Investigate independent failures concurrently. Use when facing 3+ independent problems that can be investigated without shared state.
tools: Read, Edit, Grep, Glob, Bash
model: sonnet
---

# Parallel Investigator Agent

You investigate one independent problem domain. Multiple instances of this agent can run concurrently on different problems.

## When You're Invoked

You've been given ONE specific problem to investigate:
- A specific test file
- A specific subsystem
- A specific error category

Focus ONLY on your assigned scope.

## Investigation Process

### 1. Understand the Problem

Read the specific failure:
- What test/feature is broken?
- What's the error message?
- What's the expected behavior?

### 2. Gather Evidence

- Read relevant source files
- Check recent changes to these files
- Reproduce the failure

### 3. Identify Root Cause

Follow systematic debugging:
- Don't guess
- Trace data flow
- Find the actual source

### 4. Implement Fix

- Write failing test if none exists
- Fix the root cause
- Verify fix works

### 5. Verify Isolation

- Your fix should ONLY affect your assigned scope
- Don't modify files outside your domain
- If you need changes elsewhere, report it

## Constraints

**DO:**
- Focus on your assigned scope
- Report what you found and fixed
- Note any dependencies on other domains

**DON'T:**
- Edit files outside your scope
- Make "improvements" beyond the fix
- Assume other agents' domains

## Output Format

```
Scope: [what you were assigned]
Root Cause: [what was wrong]
Fix: [what you changed]
Files Modified: [list]
Tests: [pass/fail status]
Dependencies: [any cross-domain issues found]
```
```

**Step 9: Verify agents directory created with all files**

```bash
ls -la agents/
# Should show 7 .md files
```

**Step 10: Commit**

```bash
git add agents/
git commit -m "feat: add custom agent definitions

7 agents for isolated execution:
- debugger: systematic debugging with root cause analysis
- tdd-implementer: test-driven development
- plan-executor: execute implementation plans
- slop-cleaner: remove AI cruft
- validator: defense-in-depth validation
- root-cause-tracer: backward stack tracing
- parallel-investigator: concurrent problem investigation"
```

---

## Task 2: Create Rules Directory Structure

**Files:**
- Create: `rules/testing-standards.md`
- Create: `rules/verification-standards.md`
- Create: `rules/code-quality.md`

**Step 1: Create rules directory**

```bash
mkdir -p rules
```

**Step 2: Create testing-standards.md rule**

```markdown
---
paths: "**/*.test.*,**/*.spec.*,**/test/**,**/tests/**"
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

## TDD Requirements

1. Write failing test first
2. Watch it fail for expected reason
3. Write minimal code to pass
4. Verify tests pass
5. Then refactor
```

**Step 3: Create verification-standards.md rule**

```markdown
# Verification Standards

These standards apply to ALL work, always loaded.

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
| Bug fixed | Test original symptom | Code changed |
| Requirements met | Line-by-line checklist | Tests passing |

## Red Flags

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification
- Trusting agent success reports without checking
- "Just this once"

## The Bottom Line

Run the command. Read the output. THEN claim the result.
```

**Step 4: Create code-quality.md rule**

```markdown
# Code Quality Standards

Auto-loaded for all code work.

## Slop Patterns to Remove

**Before committing, check for:**

- Unnecessary comments restating code
- Commented-out code blocks
- Single-use variables (inline them)
- Unused imports
- Empty catch blocks
- `any` type casts
- Debug statements
- Over-abstracted utilities

## Patterns to Preserve

**Do NOT remove:**

- API boundary validation
- Auth/RLS checks
- Error handling at system edges
- Comments explaining WHY
- Audit logging

## Commit Hygiene

- One logical change per commit
- Clear commit message describing WHY
- Run quality gates before commit:
  ```bash
  npm run typecheck && npm run lint && npm run test
  ```

## Import Hygiene

- Remove unused imports
- Sort imports (auto-format should handle)
- No circular dependencies
```

**Step 5: Verify rules directory**

```bash
ls -la rules/
# Should show 3 .md files
```

**Step 6: Commit**

```bash
git add rules/
git commit -m "feat: add auto-loaded rules

3 rule files for consistent standards:
- testing-standards: anti-patterns, TDD, condition-based waiting
- verification-standards: evidence before claims
- code-quality: slop patterns, commit hygiene"
```

---

## Task 3: Update Installer for Agents and Rules

**Files:**
- Modify: `install.sh`

**Step 1: Update detect_claude_files to include agents and rules**

In `install.sh`, find the `detect_claude_files` function and add:

```bash
detect_claude_files() {
    local -a our_files=(
        "$HOME/.claude/CLAUDE.md"
        "$HOME/.claude/shell/functions.zsh"
        "$HOME/.claude/shell/aliases.zsh"
        "$HOME/.claude/hooks/pre-compact.sh"
        "$HOME/.claude/hooks/session-start.sh"
        "$HOME/.claude/hooks/stop.sh"
        "$HOME/.claude/lib/loop-helpers.sh"
        "$HOME/.claude/lib/cheatsheet.md"
        "$HOME/.claude/autonomous-dev-kit/templates"
        "$HOME/.claude/skills"
        "$HOME/.claude/agents"    # NEW
        "$HOME/.claude/rules"     # NEW
    )
    # ... rest of function unchanged
}
```

**Step 2: Update setup_claude_directory to create agents and rules dirs**

Find the `setup_claude_directory` function. Add after `run mkdir -p "$claude_dir/skills"`:

```bash
    run mkdir -p "$claude_dir/agents"
    run mkdir -p "$claude_dir/rules"
```

**Step 3: Add agent installation to setup_claude_directory_full**

After the skills installation block, add:

```bash
    # Install agents
    local agents_src="$SCRIPT_DIR/agents"
    local agents_dest="$claude_dir/agents"
    if [ -d "$agents_src" ]; then
        info "Installing agents..."
        for agent_file in "$agents_src"/*.md; do
            if [ -f "$agent_file" ]; then
                local agent_name=$(basename "$agent_file")
                install_file_with_prompt "$agent_file" "$agents_dest/$agent_name" "agent: $agent_name"
            fi
        done
    fi

    # Install rules
    local rules_src="$SCRIPT_DIR/rules"
    local rules_dest="$claude_dir/rules"
    if [ -d "$rules_src" ]; then
        info "Installing rules..."
        for rule_file in "$rules_src"/*.md; do
            if [ -f "$rule_file" ]; then
                local rule_name=$(basename "$rule_file")
                install_file_with_prompt "$rule_file" "$rules_dest/$rule_name" "rule: $rule_name"
            fi
        done
    fi
```

**Step 4: Add agent/rule installation to setup_claude_directory_additive**

After the skills installation block, add:

```bash
    # Install missing agents
    local agents_src="$SCRIPT_DIR/agents"
    local agents_dest="$claude_dir/agents"
    local agents_installed=0
    if [ -d "$agents_src" ]; then
        for agent_file in "$agents_src"/*.md; do
            if [ -f "$agent_file" ]; then
                local agent_name=$(basename "$agent_file")
                if [ ! -f "$agents_dest/$agent_name" ]; then
                    run cp "$agent_file" "$agents_dest/$agent_name"
                    success "Installed agent: $agent_name"
                    agents_installed=$((agents_installed + 1))
                fi
            fi
        done
        if [ $agents_installed -eq 0 ]; then
            success "All agents already installed"
        else
            success "Installed $agents_installed agents"
        fi
    fi

    # Install missing rules
    local rules_src="$SCRIPT_DIR/rules"
    local rules_dest="$claude_dir/rules"
    local rules_installed=0
    if [ -d "$rules_src" ]; then
        for rule_file in "$rules_src"/*.md; do
            if [ -f "$rule_file" ]; then
                local rule_name=$(basename "$rule_file")
                if [ ! -f "$rules_dest/$rule_name" ]; then
                    run cp "$rule_file" "$rules_dest/$rule_name"
                    success "Installed rule: $rule_name"
                    rules_installed=$((rules_installed + 1))
                fi
            fi
        done
        if [ $rules_installed -eq 0 ]; then
            success "All rules already installed"
        else
            success "Installed $rules_installed rules"
        fi
    fi
```

**Step 5: Update verify_installation to check agents and rules**

Add after the skills check:

```bash
    # Check agents
    local agents_dir="$HOME/.claude/agents"
    if [ -d "$agents_dir" ]; then
        local agent_count=$(find "$agents_dir" -maxdepth 1 -name "*.md" -type f | wc -l)
        if [ $agent_count -gt 0 ]; then
            success "$agent_count agents installed in $agents_dir"
        else
            warn "No agents found in $agents_dir"
        fi
    else
        warn "Agents directory not found"
    fi

    # Check rules
    local rules_dir="$HOME/.claude/rules"
    if [ -d "$rules_dir" ]; then
        local rule_count=$(find "$rules_dir" -maxdepth 1 -name "*.md" -type f | wc -l)
        if [ $rule_count -gt 0 ]; then
            success "$rule_count rules installed in $rules_dir"
        else
            warn "No rules found in $rules_dir"
        fi
    else
        warn "Rules directory not found"
    fi
```

**Step 6: Test installer in dry-run mode**

```bash
./install.sh --dry-run
```

Expected: Should show agents and rules in detection summary.

**Step 7: Commit**

```bash
git add install.sh
git commit -m "feat(installer): add agents and rules support

- Detect existing agents/rules in status
- Create ~/.claude/agents/ and ~/.claude/rules/ directories
- Install agent .md files to ~/.claude/agents/
- Install rule .md files to ~/.claude/rules/
- Verify installation counts in summary"
```

---

## Task 4: Remove Deprecated Skills

**Files:**
- Delete: `skills/systematic-debugging/`
- Delete: `skills/test-driven-development/`
- Delete: `skills/executing-plans/`
- Delete: `skills/slop-cleanup/`
- Delete: `skills/defense-in-depth/`
- Delete: `skills/root-cause-tracing/`
- Delete: `skills/dispatching-parallel-agents/`
- Delete: `skills/subagent-driven-development/`
- Delete: `skills/testing-anti-patterns/`
- Delete: `skills/verification-before-completion/`
- Delete: `skills/condition-based-waiting/`

**Step 1: Remove skills that became agents**

```bash
rm -rf skills/systematic-debugging
rm -rf skills/test-driven-development
rm -rf skills/executing-plans
rm -rf skills/slop-cleanup
rm -rf skills/defense-in-depth
rm -rf skills/root-cause-tracing
rm -rf skills/dispatching-parallel-agents
rm -rf skills/subagent-driven-development
```

**Step 2: Remove skills that became rules**

```bash
rm -rf skills/testing-anti-patterns
rm -rf skills/verification-before-completion
rm -rf skills/condition-based-waiting
```

**Step 3: Verify remaining skills**

```bash
ls skills/
```

Expected remaining:
- `brainstorming/`
- `writing-plans/`
- `using-git-worktrees/`
- `finishing-a-development-branch/`
- `autonomous-loop/`
- `requesting-code-review/`
- `receiving-code-review/`
- `accessibility-checklist/`
- `spec-quality-checklist/`

**Step 4: Commit**

```bash
git add -A skills/
git commit -m "refactor: remove skills converted to agents/rules

Removed (now agents):
- systematic-debugging → debugger agent
- test-driven-development → tdd-implementer agent
- executing-plans → plan-executor agent
- slop-cleanup → slop-cleaner agent
- defense-in-depth → validator agent
- root-cause-tracing → root-cause-tracer agent
- dispatching-parallel-agents → parallel-investigator agent
- subagent-driven-development → merged into plan-executor

Removed (now rules):
- testing-anti-patterns → testing-standards rule
- verification-before-completion → verification-standards rule
- condition-based-waiting → testing-standards rule

Remaining 9 skills require conversation context."
```

---

## Task 5: Update Protocol Document

**Files:**
- Modify: `templates/AUTONOMOUS_BUILD_CLAUDE_v2.md`

**Step 1: Update Subagents table**

Find the "Subagents (via Task tool)" section. Replace with:

```markdown
### Agents (Custom + Built-in)

Custom agents installed at `~/.claude/agents/` provide isolated execution with fresh context:

| Agent | When to Use |
|-------|-------------|
| `debugger` | Systematic debugging with root cause analysis. Use BEFORE proposing fixes. |
| `tdd-implementer` | Test-driven development. Write failing test first. |
| `plan-executor` | Execute implementation plans task-by-task with quality gates. |
| `slop-cleaner` | Remove AI-generated cruft before commits. |
| `validator` | Defense-in-depth validation across layers. |
| `root-cause-tracer` | Trace bugs backward through call stack. |
| `parallel-investigator` | Investigate independent failures concurrently. |

Built-in subagents (via Task tool):

| Subagent | When to Use |
|----------|-------------|
| `Explore` | Codebase exploration, finding files |
| `Plan` | Designing implementation strategies |
| `code-reviewer` | Code review before commits |
| `test-architect` | Comprehensive test coverage |
| `security-auditor` | Security review |
| `bug-hunter` | Diagnosing errors |

**Parallel execution:** Custom agents can run in background. Spawn multiple for independent problems.
```

**Step 2: Update Skills table**

Find the "Skills (via Skill tool)" section. Reduce to:

```markdown
### Skills (via Skill tool)

Skills require conversation context and user interaction:

| Skill | When to Use |
|-------|-------------|
| `brainstorming` | Refine rough ideas into designs through dialogue |
| `writing-plans` | Turn designs into executable implementation plans |
| `using-git-worktrees` | Isolated workspaces for risky changes |
| `finishing-a-development-branch` | Clean up and package for merge/PR |
| `requesting-code-review` | Request review (spawns code-reviewer agent) |
| `receiving-code-review` | Handle review feedback with rigor |
| `spec-quality-checklist` | Validate specs for precision |
| `accessibility-checklist` | WCAG compliance for UI |
```

**Step 3: Update Skill Sequences table**

Replace with:

```markdown
**Workflow sequences:**

| Scenario | Sequence |
|----------|----------|
| New feature / refactor | `brainstorming` → `writing-plans` → `using-git-worktrees` → spawn `plan-executor` agent |
| Bug with reproduction | spawn `tdd-implementer` → spawn `debugger` if stuck |
| Flaky tests | spawn `debugger` (uses condition-based waiting in testing-standards rule) |
| Code review flow | `requesting-code-review` → `receiving-code-review` → fix → spawn `slop-cleaner` |
| Multiple failures | spawn multiple `parallel-investigator` agents concurrently |
| Before commit | spawn `slop-cleaner` agent |
```

**Step 4: Add Rules section**

After the Skills section, add:

```markdown
### Rules (Auto-loaded)

Rules at `~/.claude/rules/` are automatically loaded based on file patterns:

| Rule | Scope | Content |
|------|-------|---------|
| `testing-standards.md` | Test files | Anti-patterns, TDD, condition-based waiting |
| `verification-standards.md` | All work | Evidence before claims |
| `code-quality.md` | All code | Slop patterns, commit hygiene |

Rules don't need invocation—they're always active for matching files.
```

**Step 5: Update Companion Files section**

Update to:

```markdown
## Companion Files

| Location | Purpose |
|----------|---------|
| `~/.claude/agents/` | Custom agents (isolated execution) |
| `~/.claude/skills/` | Skills (conversation context) |
| `~/.claude/rules/` | Auto-loaded standards |
| `CONTEXT_TEMPLATE.md` | Context preservation template |
| `LEARNINGS.md` | Project learnings accumulator |
```

**Step 6: Commit**

```bash
git add templates/AUTONOMOUS_BUILD_CLAUDE_v2.md
git commit -m "docs(protocol): update for agents architecture

- Replace skills-only with agents + skills + rules model
- Add custom agents table with 7 agents
- Reduce skills to 8 interactive-only
- Add rules section (auto-loaded)
- Update workflow sequences to use agents
- Update companion files table"
```

---

## Task 6: Update Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/GETTING_STARTED.md`
- Modify: `CLAUDE.md`

**Step 1: Update README Directory Structure**

Find the Directory Structure section. Update to show agents and rules:

```markdown
## Directory Structure

```
autonomous-dev-kit/
├── install.sh              # Main installer
├── agents/                 # Custom agent definitions (→ ~/.claude/agents/)
│   ├── debugger.md
│   ├── tdd-implementer.md
│   ├── plan-executor.md
│   └── ...
├── rules/                  # Auto-loaded standards (→ ~/.claude/rules/)
│   ├── testing-standards.md
│   ├── verification-standards.md
│   └── code-quality.md
├── skills/                 # Interactive skills (→ ~/.claude/skills/)
├── hooks/                  # Claude Code hooks
├── templates/              # Protocol documents
├── shell/                  # Shell functions and aliases
└── docs/                   # Documentation
```
```

**Step 2: Add Agents section to README**

After the Skills section, add:

```markdown
## Agents

Custom agents run in isolated context windows, enabling parallel execution:

| Agent | Purpose |
|-------|---------|
| `debugger` | Systematic debugging with root cause analysis |
| `tdd-implementer` | Test-driven development implementation |
| `plan-executor` | Execute plans task-by-task with quality gates |
| `slop-cleaner` | Remove AI-generated cruft |
| `validator` | Defense-in-depth validation |
| `root-cause-tracer` | Trace bugs through call stack |
| `parallel-investigator` | Concurrent problem investigation |

Agents are spawned via Task tool and return summarized results. Multiple agents can run in parallel for independent problems.
```

**Step 3: Update CLAUDE.md Quick Reference**

Update the skill quick reference table:

```markdown
### Quick Reference: When to Use What

| Scenario | Tool |
|----------|------|
| New feature / refactor | `writing-plans` skill → `plan-executor` agent |
| Bug / error | `debugger` agent |
| Before commit | `slop-cleaner` agent |
| Test failures | `tdd-implementer` agent |
| Multiple independent failures | Multiple `parallel-investigator` agents |
| Need user input | Skills (brainstorming, finishing-branch) |
```

**Step 4: Update GETTING_STARTED.md**

Add section explaining the architecture:

```markdown
## Architecture: Agents vs Skills vs Rules

**Agents** (`~/.claude/agents/`):
- Run in isolated context windows
- Can run in parallel
- Best for: execution tasks, debugging, implementation

**Skills** (`~/.claude/skills/`):
- Run in main conversation context
- Require user interaction
- Best for: brainstorming, planning, decisions

**Rules** (`~/.claude/rules/`):
- Auto-loaded based on file patterns
- Always active, no invocation needed
- Best for: standards, anti-patterns, hygiene
```

**Step 5: Commit**

```bash
git add README.md docs/GETTING_STARTED.md CLAUDE.md
git commit -m "docs: update for agents architecture

- README: add agents section, update directory structure
- GETTING_STARTED: explain agents vs skills vs rules
- CLAUDE.md: update quick reference table"
```

---

## Task 7: Final Verification

**Step 1: Run installer dry-run**

```bash
./install.sh --dry-run
```

Expected: Shows agents and rules in detection.

**Step 2: Verify agent files exist**

```bash
ls -la agents/*.md | wc -l
# Should be 7
```

**Step 3: Verify rule files exist**

```bash
ls -la rules/*.md | wc -l
# Should be 3
```

**Step 4: Verify skills reduced**

```bash
ls -d skills/*/ | wc -l
# Should be 9
```

**Step 5: Run full installer (on test machine or with backup)**

```bash
./install.sh
# Choose option 2 (additive)
```

**Step 6: Verify installation**

```bash
ls ~/.claude/agents/
ls ~/.claude/rules/
ls ~/.claude/skills/
```

**Step 7: Final commit**

```bash
git add -A
git status
# If any uncommitted changes, commit them

git log --oneline -10
# Verify all commits in place
```

---

## Completion Checklist

- [ ] 7 agent files in `agents/`
- [ ] 3 rule files in `rules/`
- [ ] 9 skills remaining in `skills/` (interactive only)
- [ ] Installer handles agents and rules
- [ ] Protocol document updated
- [ ] README updated
- [ ] GETTING_STARTED updated
- [ ] CLAUDE.md updated
- [ ] All commits pushed
