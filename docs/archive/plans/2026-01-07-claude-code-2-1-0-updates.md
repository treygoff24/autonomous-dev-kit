# Claude Code 2.1.0 Alignment Implementation Plan

> **For Claude:** Spawn `plan-executor` agent to implement this plan task-by-task.

**Goal:** Align the kit with Claude Code 2.1.0 features (forked skills + agent binding, skill/agent-scoped hooks, respectGitignore default) and document hot-reload behavior.

**Architecture:** Add a `code-reviewer` agent, wire `requesting-code-review` skill to run in a forked agent context, move autonomous-loop Stop hook to skill frontmatter with a legacy fallback, and update installer/docs to set `respectGitignore` and explain hot-reload.

**Tech Stack:** Bash (`install.sh`), Markdown with YAML frontmatter (`skills/`, `agents/`, `templates/`, `docs/`)

---

### Task 1: Preflight and feature branch

**Files:**
- Modify: `CONTEXT.md`

**Step 1: Create feature branch**

Run:
```bash
git checkout -b feature/claude-code-2-1-0-updates
```
Expected: Switched to new branch message.

**Step 2: Update CONTEXT.md with current goal**

Add a short entry noting the 2.1.0 alignment goal and that you are following this plan.

**Step 3: Commit**

```bash
git add CONTEXT.md
git commit -m "chore: note 2.1.0 alignment work"
```

---

### Task 2: Add `code-reviewer` custom agent

**Files:**
- Create: `agents/code-reviewer.md`
- Modify: `README.md`
- Modify: `docs/GETTING_STARTED.md`
- Modify: `templates/AUTONOMOUS_BUILD_CLAUDE_v2.md`

**Step 1: Create agent definition**

Create `agents/code-reviewer.md`:
```markdown
---
name: code-reviewer
description: Review diffs against specs/plans for correctness, risks, and missing tests. Use before commits. Read-only.
tools: Read, Grep, Glob, Bash
model: sonnet
---

# Code Reviewer Agent

You perform code review against the spec and implementation plan.

## Inputs
- Spec at `SPEC.md` (if present)
- Plan at `IMPLEMENTATION_PLAN.md` or plan path provided
- Git diff from BASE_SHA..HEAD_SHA or current branch

## Output Format
```
Critical:
- [issue]
Warnings:
- [issue]
Suggestions:
- [issue]
Verdict: approve | revise
```

## Review Focus
- Correctness, edge cases, and regressions
- Missing tests or weak assertions
- Security and data handling
- Accessibility for UI changes
```

**Step 2: Update agent lists in docs/templates**

Add `code-reviewer` to agent tables:
- `README.md` agent list
- `docs/GETTING_STARTED.md` agent list
- `templates/AUTONOMOUS_BUILD_CLAUDE_v2.md` custom agent list (not built-in list)

**Step 3: Verify formatting**

No tests required. Ensure Markdown tables render correctly.

**Step 4: Commit**

```bash
git add agents/code-reviewer.md README.md docs/GETTING_STARTED.md templates/AUTONOMOUS_BUILD_CLAUDE_v2.md
git commit -m "feat: add code-reviewer agent"
```

---

### Task 3: Run requesting-code-review skill in forked agent context

**Files:**
- Modify: `skills/requesting-code-review/SKILL.md`
- Modify: `templates/AUTONOMOUS_BUILD_CODEX_v2.md`
- Modify: `templates/AUTONOMOUS_BUILD_CLAUDE_v2.md`

**Step 1: Update skill frontmatter to use forked agent**

Adjust frontmatter in `skills/requesting-code-review/SKILL.md`:
```yaml
---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements - runs code review in a forked code-reviewer agent
context: fork
agent: code-reviewer
---
```

**Step 2: Update skill body to remove manual Task instructions**

Replace the "Dispatch code-reviewer subagent" section with skill usage and fallback:
```markdown
## How to Request

**1. Provide inputs (spec/plan/diff):**
- Confirm `SPEC.md` and `IMPLEMENTATION_PLAN.md` are up to date
- Provide BASE/HEAD SHAs or instruct the reviewer to use `git diff`

**2. Invoke the skill:**
```
/requesting-code-review
```
This runs in a forked `code-reviewer` agent context (Claude Code 2.1.0+).

**Fallback (older versions):**
If forked skills aren’t available, spawn the agent manually with Task tool and use `requesting-code-review/code-reviewer.md` as the prompt.
```

**Step 3: Update protocol templates**

Update `templates/AUTONOMOUS_BUILD_CODEX_v2.md` and `templates/AUTONOMOUS_BUILD_CLAUDE_v2.md` to:
- Reference `/requesting-code-review` for review checkpoints
- Mention it runs `code-reviewer` in a forked context

**Step 4: Commit**

```bash
git add skills/requesting-code-review/SKILL.md templates/AUTONOMOUS_BUILD_CODEX_v2.md templates/AUTONOMOUS_BUILD_CLAUDE_v2.md
git commit -m "feat: fork requesting-code-review into code-reviewer agent"
```

---

### Task 4: Scope autonomous-loop Stop hook to the skill

**Files:**
- Modify: `skills/autonomous-loop/index.md`
- Modify: `install.sh`
- Modify: `docs/TROUBLESHOOTING.md`
- Modify: `README.md`

**Step 1: Add skill-scoped Stop hook**

Update `skills/autonomous-loop/index.md` frontmatter:
```yaml
---
name: autonomous-loop
description: Activate autonomous loop mode for persistent development sessions. Use when user says "go autonomous" or wants unattended iteration until completion.
hooks:
  Stop:
    - type: command
      command: ~/.claude/hooks/stop.sh
      once: true
---
```

**Step 2: Preserve legacy Stop hook for older Claude Code versions**

Update `install.sh` to conditionally configure the global Stop hook only when Claude Code < 2.1.0 or when the user opts into legacy mode.

Suggested helper:
```bash
claude_supports_skill_hooks() {
    local version
    version=$(claude --version 2>/dev/null | rg -o '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    # If version missing, default to legacy behavior
    if [ -z "$version" ]; then
        return 1
    fi
    # Compare major/minor: >= 2.1.0
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"
    if [ "$major" -gt 2 ]; then
        return 0
    fi
    if [ "$major" -eq 2 ] && [ "$minor" -ge 1 ]; then
        return 0
    fi
    return 1
}
```

Then in `configure_hooks_*`, only add Stop hook if `! claude_supports_skill_hooks` or a new `CLAUDE_CODE_LEGACY_STOP_HOOK=1` env var is set.

**Step 3: Document the behavior**

Update `README.md` and `docs/TROUBLESHOOTING.md`:
- Note that the autonomous loop Stop hook is now skill-scoped in Claude Code 2.1.0+
- Mention `CLAUDE_CODE_LEGACY_STOP_HOOK=1` to keep global Stop hook if needed

**Step 4: Commit**

```bash
git add skills/autonomous-loop/index.md install.sh README.md docs/TROUBLESHOOTING.md
git commit -m "feat: scope autonomous-loop stop hook to skill"
```

---

### Task 5: Set respectGitignore default in installer

**Files:**
- Modify: `install.sh`
- Modify: `docs/GETTING_STARTED.md`

**Step 1: Add `respectGitignore` to settings.json updates**

In `configure_hooks_full` and `configure_hooks_additive`, ensure `respectGitignore` is set to `true` unless already defined:
```bash
jq --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" --arg stop "$hook_path_stop" '
  .respectGitignore = (.respectGitignore // true) |
  .hooks.PreCompact = [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}] |
  .hooks.SessionStart = [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}] |
  .hooks.Stop = [{"matcher": "", "hooks": [{"type": "command", "command": $stop}]}]
'
```

In additive mode, add a similar `respectGitignore` default when writing or updating the file.

**Step 2: Document how to override**

Update `docs/GETTING_STARTED.md` with a short note:
- `respectGitignore: true` is set by default
- Set to `false` in `~/.claude/settings.json` if you want to @-mention ignored paths like `.claude/`

**Step 3: Commit**

```bash
git add install.sh docs/GETTING_STARTED.md
git commit -m "chore: default respectGitignore in settings"
```

---

### Task 6: Document skill hot-reload behavior

**Files:**
- Modify: `README.md`
- Modify: `docs/GETTING_STARTED.md`
- Modify: `docs/TROUBLESHOOTING.md`

**Step 1: Add hot-reload notes**

Add a short note in each doc:
- Skills in `~/.claude/skills` and `.claude/skills` auto-reload in Claude Code 2.1.0+
- No CLI restart needed for skills; if behavior doesn’t appear, run `/context` or restart as fallback

**Step 2: Commit**

```bash
git add README.md docs/GETTING_STARTED.md docs/TROUBLESHOOTING.md
git commit -m "docs: note skill hot-reload behavior"
```

---

### Task 7: Verify installer behavior (dry run)

**Files:**
- None

**Step 1: Run installer dry-run**

```bash
./install.sh --dry-run
```
Expected: No errors; output shows hooks configured and respectGitignore update.

**Step 2: Commit (if any doc updates needed after dry-run)**

If dry-run reveals missing docs or confusing output, update docs and commit with:
```bash
git add README.md docs/GETTING_STARTED.md docs/TROUBLESHOOTING.md
git commit -m "docs: clarify 2.1.0 installer behavior"
```
