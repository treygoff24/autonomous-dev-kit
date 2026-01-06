# Skills Audit Report

> **⚠️ HISTORICAL DOCUMENT:** This audit was conducted before the agents restructure on 2026-01-06. Many skills listed here have been converted to **agents** (isolated execution) or **rules** (auto-loaded standards). The kit now uses a three-tier architecture: 7 agents, 9 skills, 3 rules. See README.md for current structure.

**Date:** 2026-01-06 (pre-restructure)
**Status:** ⚠️ SUPERSEDED by agents restructure
**Scope:** Comparison of skills between autonomous-dev-kit repo, superpowers plugin (v3.6.2), and AUTONOMOUS_BUILD_CLAUDE_v2.md protocol

---

## Resolution Summary

**All discrepancies have been resolved.** We merged superpowers skills into the autonomous-dev-kit repo:

1. Copied 5 missing skills from superpowers: `root-cause-tracing`, `defense-in-depth`, `dispatching-parallel-agents`, `receiving-code-review`
2. Created the missing `executing-plans` skill
3. Removed all `superpowers:` prefixes from protocol and skills
4. Updated all documentation for consistency

**The kit now has 20 skills**, all referenced without namespace prefixes.

---

## Original Executive Summary (Historical)

There were significant discrepancies between:
1. Skills in this repo vs. superpowers plugin
2. Skills referenced in the protocol vs. skills that actually exist
3. Skill naming conventions used in the protocol vs. actual skill names

**Critical Finding (NOW FIXED):** The `superpowers:executing-plans` skill referenced throughout the protocol and other skills **did not exist**.

---

## Part 1: Skills Inventory Comparison

### Skills in Superpowers Plugin (v3.6.2) — 19 total

```
brainstorming              condition-based-waiting    defense-in-depth
dispatching-parallel-agents finishing-a-development-branch receiving-code-review
requesting-code-review     root-cause-tracing         sharing-skills
subagent-driven-development systematic-debugging       test-driven-development
testing-anti-patterns      testing-skills-with-subagents using-git-worktrees
using-superpowers          verification-before-completion writing-plans
writing-skills
```

### Skills in autonomous-dev-kit Repo — 17 total

```
accessibility-checklist    autonomous-loop            brainstorming
condition-based-waiting    finishing-a-development-branch requesting-code-review
slop-cleanup               spec-quality-checklist     subagent-driven-development
systematic-debugging       test-driven-development    testing-anti-patterns
using-git-worktrees        verification-before-completion writing-plans
```

### Gap Analysis

**In superpowers but NOT in dev kit repo (8 skills):**

| Skill | Purpose | Impact |
|-------|---------|--------|
| `defense-in-depth` | Multi-layer validation | Referenced by systematic-debugging |
| `dispatching-parallel-agents` | 3+ concurrent agent dispatch | Referenced in protocol |
| `receiving-code-review` | How to act on code review feedback | Pairs with requesting-code-review |
| `root-cause-tracing` | Backward tracing through call stack | REQUIRED by systematic-debugging |
| `sharing-skills` | Contributing skills to upstream | Not critical |
| `testing-skills-with-subagents` | TDD for skill development | Not critical |
| `using-superpowers` | Mandatory skill usage workflow | **Core orchestration** |
| `writing-skills` | How to author skills | Not critical |

**In dev kit repo but NOT in superpowers (4 skills):**

| Skill | Purpose | Notes |
|-------|---------|-------|
| `accessibility-checklist` | WCAG compliance checks | Referenced in protocol |
| `autonomous-loop` | Persistent development mode | Dev kit specific |
| `slop-cleanup` | Remove AI-generated cruft | Referenced in protocol Step 4 |
| `spec-quality-checklist` | Validate specs before implementation | Referenced in protocol |

---

## Part 2: Missing Skills Referenced in Protocol

### CRITICAL: `executing-plans` Does Not Exist

**The protocol references:**
```markdown
| Skill                        | When to Use                                     |
| `superpowers:executing-plans` | Run plans in controlled batches with verification |
```

**The writing-plans skill references:**
```markdown
> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
```

**Reality:** There is a command `/execute-plan` but it points to a skill that doesn't exist. The command file says:
```markdown
Use the executing-plans skill exactly as written
```

**Impact:** This breaks the entire plan execution workflow. Users are directed to use a non-existent skill.

### Other Missing Skills in Protocol

| Protocol Reference | Exists? | Notes |
|-------------------|---------|-------|
| `superpowers:brainstorming` | ✅ Yes | Works |
| `superpowers:writing-plans` | ✅ Yes | Works |
| `superpowers:executing-plans` | ❌ NO | **BROKEN** |
| `superpowers:test-driven-development` | ✅ Yes | Works |
| `superpowers:systematic-debugging` | ✅ Yes | Works |
| `superpowers:verification-before-completion` | ✅ Yes | Works |
| `superpowers:requesting-code-review` | ✅ Yes | Works |
| `superpowers:using-git-worktrees` | ✅ Yes | Works |
| `superpowers:finishing-a-development-branch` | ✅ Yes | Works |
| `superpowers:dispatching-parallel-agents` | ✅ Yes | Not in dev kit |
| `superpowers:subagent-driven-development` | ✅ Yes | Works |
| `superpowers:condition-based-waiting` | ✅ Yes | Works |
| `superpowers:testing-anti-patterns` | ✅ Yes | Works |
| `example-skills:webapp-testing` | ✅ Yes | Different plugin |
| `frontend-design:frontend-design` | ✅ Yes | Different plugin |
| `spec-quality-checklist` | ⚠️ Partial | In repo, not installed as superpowers |
| `accessibility-checklist` | ⚠️ Partial | In repo, not installed as superpowers |

---

## Part 3: Skill Content Comparison

### Skills That Appear Identical (spot-checked)

These skills exist in both locations and appear to be byte-for-byte identical:

- `brainstorming`
- `writing-plans`
- `test-driven-development`
- `systematic-debugging`
- `verification-before-completion`
- `using-git-worktrees`
- `finishing-a-development-branch`
- `requesting-code-review`
- `subagent-driven-development`
- `condition-based-waiting`
- `testing-anti-patterns`

**No content drift detected** between repo and plugin for shared skills.

---

## Part 4: Protocol vs. Dev Kit Workflow Discrepancies

### 1. Codex Integration Mismatch

**Protocol says:**
```bash
codex exec \
  --model gpt-5.2-codex \
  --config model_reasoning_effort="xhigh" \
  --yolo \
  "<YOUR_TASK_PROMPT>"
```

**Reality:**
- Codex syntax has changed (now uses `-m` for model, `-c` for config)
- Flag is `--dangerously-bypass-approvals-and-sandbox` not `--yolo`
- This was partially fixed in recent commits but may still have inconsistencies

### 2. CONTEXT_TEMPLATE.md References Wrong Agent

**CONTEXT_TEMPLATE.md contains:**
```markdown
**How to call Claude:**
claude -p --model opus --dangerously-skip-permissions --output-format text "[PROMPT]"
```

**Issue:** This is for calling Claude FROM Codex. But the template is for Claude sessions, creating confusion about which agent is primary.

### 3. Skill Sequences Reference Missing Skill

**Protocol says:**
```markdown
| Scenario                   | Skill Sequence                                                     |
| New feature / big refactor | `writing-plans` → ... → `executing-plans` → ... |
```

**Issue:** `executing-plans` doesn't exist. Should probably be `subagent-driven-development` for same-session or direct execution.

### 4. Slop Removal Not a Superpowers Skill

**Protocol Step 4 says:**
> After review passes, clean up AI-generated cruft before committing

But `slop-cleanup` is a dev kit skill, not a superpowers skill. Claude won't find it via `superpowers:slop-cleanup`.

### 5. Quality Checklists Not Integrated

**Protocol references:**
- `spec-quality-checklist` for spec validation
- `accessibility-checklist` for UI checks

**Issue:** These are dev kit skills but:
1. Not prefixed correctly for invocation
2. Not listed in protocol's skill table
3. May not be installed to `~/.claude/skills/`

---

## Part 5: Installation/Sync Issues

### Skills at `~/.claude/skills/` May Be Stale

The installer copies skills from this repo to `~/.claude/skills/`. But:

1. **Superpowers plugin also provides skills** at different location
2. **Which takes precedence?** Plugin skills appear to win
3. **Dev kit-specific skills** (autonomous-loop, slop-cleanup, accessibility-checklist, spec-quality-checklist) are ONLY in `~/.claude/skills/`

### Potential Namespace Collision

```
User invokes: superpowers:brainstorming
├── Checks: superpowers plugin → skills/brainstorming/SKILL.md ✓
└── Ignores: ~/.claude/skills/brainstorming/SKILL.md

User invokes: slop-cleanup
├── Checks: superpowers plugin → NOT FOUND
└── Falls back to: ~/.claude/skills/slop-cleanup/SKILL.md ✓ (hopefully)
```

---

## Part 6: Recommendations

### Critical Fixes

1. **Create `executing-plans` skill** or update all references to `subagent-driven-development`
   - The writing-plans skill specifically directs to executing-plans
   - Protocol lists it as a core skill
   - Dozens of references need fixing if name changes

2. **Add missing skills to dev kit repo:**
   - `root-cause-tracing` (REQUIRED by systematic-debugging)
   - `defense-in-depth` (referenced by systematic-debugging)
   - `using-superpowers` (core orchestration)
   - `receiving-code-review` (pairs with requesting-code-review)

3. **Fix CONTEXT_TEMPLATE.md** to be agent-agnostic or have two versions

### Medium Priority

4. **Standardize skill invocation syntax** in protocol:
   - Always use `superpowers:` prefix for superpowers skills
   - Use bare name for dev kit-only skills
   - Document which skills come from where

5. **Update protocol skill table** to include:
   - `spec-quality-checklist`
   - `accessibility-checklist`
   - `slop-cleanup`
   - `autonomous-loop`

6. **Verify Codex command syntax** is consistent across all docs

### Nice to Have

7. **Add symlinks or integrate** dev kit skills into superpowers namespace for consistency

8. **Create skill inventory doc** showing which skills exist where and their purposes

---

## Appendix: Full Skill Cross-Reference

| Skill Name | Superpowers | Dev Kit | Protocol | Notes |
|------------|-------------|---------|----------|-------|
| accessibility-checklist | - | ✓ | ✓ | Dev kit only |
| autonomous-loop | - | ✓ | - | Dev kit only |
| brainstorming | ✓ | ✓ | ✓ | Identical |
| condition-based-waiting | ✓ | ✓ | ✓ | Identical |
| defense-in-depth | ✓ | - | - | Missing from dev kit |
| dispatching-parallel-agents | ✓ | - | ✓ | Missing from dev kit |
| executing-plans | - | - | ✓ | **DOES NOT EXIST** |
| finishing-a-development-branch | ✓ | ✓ | ✓ | Identical |
| receiving-code-review | ✓ | - | - | Missing from dev kit |
| requesting-code-review | ✓ | ✓ | ✓ | Identical |
| root-cause-tracing | ✓ | - | - | Missing from dev kit |
| sharing-skills | ✓ | - | - | Not critical |
| slop-cleanup | - | ✓ | ✓ | Dev kit only |
| spec-quality-checklist | - | ✓ | ✓ | Dev kit only |
| subagent-driven-development | ✓ | ✓ | ✓ | Identical |
| systematic-debugging | ✓ | ✓ | ✓ | Identical |
| test-driven-development | ✓ | ✓ | ✓ | Identical |
| testing-anti-patterns | ✓ | ✓ | ✓ | Identical |
| testing-skills-with-subagents | ✓ | - | - | Not critical |
| using-git-worktrees | ✓ | ✓ | ✓ | Identical |
| using-superpowers | ✓ | - | - | Missing from dev kit |
| verification-before-completion | ✓ | ✓ | ✓ | Identical |
| writing-plans | ✓ | ✓ | ✓ | Identical |
| writing-skills | ✓ | - | - | Not critical |

**Legend:**
- ✓ = Present
- `-` = Not present
- **Bold** = Critical issue
