# Spec: Agents Architecture Restructure

**Date:** 2026-01-06
**Status:** APPROVED
**Scope:** Restructure autonomous-dev-kit from skills-only to agents + skills + rules architecture

---

## Problem Statement

The current skills-only architecture has four critical bottlenecks:

1. **Context saturation** — Skills load into main context, get lost across compactions
2. **Sequential blocking** — Claude waits for Codex/subagents doing nothing
3. **Skill proliferation** — 20 skills, unclear when to invoke which
4. **Wrong abstraction level** — Execution-focused skills should be isolated agents

## Solution

Restructure the kit using Claude Code's native agent discovery system:

- **Agents** (`~/.claude/agents/`) — Isolated execution workers with fresh context
- **Skills** (`~/.claude/skills/`) — Methodology requiring conversation context
- **Rules** (`~/.claude/rules/`) — Auto-loaded standards, always present

This enables:
- Parallel execution (agents run in background)
- Context isolation (agents don't pollute main conversation)
- Automatic invocation (description field triggers delegation)
- Zero manual setup (installer handles everything)

---

## Architecture

### Agents (New: ~/.claude/agents/)

Isolated execution workers. Run in separate context windows. Can run in parallel.

| Agent | Purpose | Model | Tools |
|-------|---------|-------|-------|
| `debugger.md` | Systematic debugging with root cause analysis | sonnet | All |
| `tdd-implementer.md` | Red-green-refactor implementation | sonnet | All |
| `plan-executor.md` | Execute implementation plans task-by-task | sonnet | All |
| `slop-cleaner.md` | Remove AI-generated cruft | haiku | Read, Edit, Grep, Glob |
| `validator.md` | Defense-in-depth validation | haiku | Read, Grep, Glob, Bash |
| `root-cause-tracer.md` | Trace bugs backward through call stack | sonnet | All |
| `parallel-investigator.md` | Investigate independent failures | sonnet | All |

**Agent file format:**
```markdown
---
name: agent-name
description: When to use. Include "Use PROACTIVELY" for auto-invocation.
tools: Read, Edit, Grep, Glob, Bash (or subset)
model: sonnet | haiku
---

System prompt with methodology...
```

### Skills (Reduced: ~/.claude/skills/)

Methodology requiring conversation context and user interaction.

| Skill | Purpose | Why Skill (not Agent) |
|-------|---------|----------------------|
| `brainstorming` | Refine ideas into designs | Back-and-forth with user |
| `writing-plans` | Create implementation plans | Collaborative refinement |
| `using-git-worktrees` | Isolated workspaces | Modifies main session state |
| `finishing-a-development-branch` | Clean up for merge/PR | User decisions required |
| `autonomous-loop` | Persistent development mode | Session state management |
| `requesting-code-review` | Request review from agent | Orchestration (spawns agent) |
| `receiving-code-review` | Handle review feedback | Needs conversation context |

**Remove from skills/ (converted to agents):**
- `systematic-debugging` → `debugger.md`
- `test-driven-development` → `tdd-implementer.md`
- `executing-plans` → `plan-executor.md`
- `slop-cleanup` → `slop-cleaner.md`
- `defense-in-depth` → `validator.md`
- `root-cause-tracing` → `root-cause-tracer.md`
- `dispatching-parallel-agents` → `parallel-investigator.md`
- `subagent-driven-development` → merged into `plan-executor.md`

### Rules (New: ~/.claude/rules/)

Auto-loaded standards. Always present in context. No invocation needed.

| Rule | Purpose |
|------|---------|
| `testing-standards.md` | Testing anti-patterns, condition-based waiting |
| `verification-standards.md` | Evidence-based validation, no claims without proof |
| `code-quality.md` | Slop patterns to avoid, what to preserve |
| `accessibility-standards.md` | WCAG compliance checklist |
| `spec-quality.md` | Spec validation checklist |

---

## Installation Changes

### New Directory Structure

```
~/.claude/
├── agents/                    # NEW: Custom agents
│   ├── debugger.md
│   ├── tdd-implementer.md
│   ├── plan-executor.md
│   ├── slop-cleaner.md
│   ├── validator.md
│   ├── root-cause-tracer.md
│   └── parallel-investigator.md
├── skills/                    # REDUCED: Interactive workflows only
│   ├── brainstorming/
│   ├── writing-plans/
│   ├── using-git-worktrees/
│   ├── finishing-a-development-branch/
│   ├── autonomous-loop/
│   ├── requesting-code-review/
│   └── receiving-code-review/
├── rules/                     # NEW: Auto-loaded standards
│   ├── testing-standards.md
│   ├── verification-standards.md
│   ├── code-quality.md
│   ├── accessibility-standards.md
│   └── spec-quality.md
├── hooks/
├── lib/
└── settings.json
```

### Installer Updates

1. Create `~/.claude/agents/` directory
2. Create `~/.claude/rules/` directory
3. Copy agent files from `agents/` to `~/.claude/agents/`
4. Copy rule files from `rules/` to `~/.claude/rules/`
5. Remove deprecated skills from `~/.claude/skills/`
6. Update skills (copy reduced set)

---

## Protocol Updates

### AUTONOMOUS_BUILD_CLAUDE_v2.md Changes

**Subagents table:** Add custom agents alongside built-in ones

**Skills table:** Reduce to interactive-only skills

**Skill sequences:** Update to use agents where appropriate

```
BEFORE:
| Bug with reproduction | `test-driven-development` → `systematic-debugging` → ...

AFTER:
| Bug with reproduction | Spawn `tdd-implementer` → Spawn `debugger` if stuck → ...
```

**Parallel execution section:** Add guidance on running agents in background

---

## Migration

### For Existing Users

The installer handles migration:
1. Detects existing `~/.claude/skills/` with old skills
2. Removes deprecated skills (those converted to agents)
3. Installs agents to `~/.claude/agents/`
4. Installs rules to `~/.claude/rules/`
5. Preserves user customizations (files not in our manifest)

### Breaking Changes

- Skills that become agents will no longer respond to `Skill` tool
- Users must use `Task` tool with agent name instead
- Protocol references updated to match

---

## Success Criteria

1. **Parallel execution works:** Can spawn multiple agents simultaneously
2. **Context isolation verified:** Agents don't pollute main conversation
3. **Auto-invocation triggers:** Descriptions cause automatic delegation
4. **Installer completes cleanly:** Fresh install and upgrade both work
5. **Protocol is self-consistent:** All references valid
6. **No skill regressions:** Remaining skills work as before

---

## Out of Scope

- Codex integration changes (separate effort)
- New agents beyond conversions
- Plugin marketplace distribution
- Per-project agent overrides (users can add manually)
