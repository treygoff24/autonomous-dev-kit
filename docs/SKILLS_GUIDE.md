# Skills Authoring Guide

How to create and maintain skills for Claude Code and autonomous-dev-kit.

---

## What Is a Skill?

A skill is a markdown file with YAML frontmatter that teaches Claude a specific workflow or methodology. Skills live in `~/.claude/skills/<skill-name>/SKILL.md` (global) or `.claude/skills/<skill-name>/SKILL.md` (project-local).

Skills are invoked with `/skill-name` in Claude Code. They hot-reload — edit the file and changes apply immediately without restarting the session.

---

## Skill File Structure

```
skills/
  my-skill/
    SKILL.md          # Required: skill definition
    supporting-file.md # Optional: referenced by SKILL.md
    template.txt       # Optional: templates, examples
```

### SKILL.md Format

```yaml
---
name: my-skill
description: One-line description of when to use this skill
context: fork          # Optional: run in isolated sub-agent context
agent: my-agent        # Optional: specify agent type for forked context
skills:                # Optional: skills available to sub-agents
  - other-skill
  - another-skill
hooks:                 # Optional: lifecycle hooks
  Stop:
    - type: prompt
      prompt: "Verify the work is complete"
      once: true
---

# Skill Title

Skill instructions go here in markdown.
```

---

## Frontmatter Fields

### Required

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Skill identifier (matches directory name) |
| `description` | string | When to use this skill. Claude uses this to decide whether to suggest it. |

### Optional

| Field | Type | Description |
|-------|------|-------------|
| `context` | `"fork"` | Run in isolated sub-agent context (clean context, no conversation noise) |
| `agent` | string | Agent type to use when `context: fork` is set |
| `skills` | string[] | Skills available to sub-agents spawned by this skill |
| `hooks` | object | Lifecycle hooks (Stop, PreToolUse, PostToolUse) |
| `disable-model-invocation` | boolean | Prevent the skill from invoking models (rare) |

### The `context: fork` Pattern

When a skill sets `context: fork`, it runs in an isolated sub-agent context:

```yaml
---
name: code-review
context: fork
agent: code-reviewer
---
```

Benefits:
- Clean context without conversation noise
- Parallel execution without interference
- Focused task completion
- Agent-specific tools and permissions

Skills in this kit using `context: fork`:
- `task-builder` (agent: task-builder)
- `requesting-code-review` (agent: code-reviewer)
- `receiving-code-review` (agent: review-triager)
- `writing-plans` (forked context)
- `using-git-worktrees` (forked context)
- `spec-quality-checklist` (agent: spec-reviewer)
- `accessibility-checklist` (agent: a11y-reviewer)

### The `$ARGUMENTS` Substitution

When a skill is invoked with arguments, `$ARGUMENTS` in the skill body is replaced with the user's input:

```
/my-skill Build the auth module
```

In the skill body, `$ARGUMENTS` becomes `"Build the auth module"`.

### Hooks in Skills

Skills can define hooks that fire during their lifecycle:

```yaml
hooks:
  Stop:
    - type: prompt
      prompt: "Did you save the output file?"
      once: true
  PreToolUse:
    - type: command
      command: ./validate.sh
      matcher: "Bash"
```

**Hook types:**
- `prompt` — Claude evaluates the prompt (uses model judgment)
- `command` — Runs a shell command (deterministic)

**The `once: true` option:** Hook fires only once per session, even if the skill runs multiple times.

---

## Skill Dependencies (`skills:` field)

Skills can declare dependencies that are auto-loaded for sub-agents:

```yaml
---
name: brainstorming
skills:
  - using-git-worktrees
  - writing-plans
---
```

When `brainstorming` runs, its sub-agents automatically have access to `using-git-worktrees` and `writing-plans`.

---

## Supporting Files

Skills can reference supporting files in their directory:

```
skills/
  my-skill/
    SKILL.md
    checklist.md      # Referenced in SKILL.md
    template.txt      # Template for output
```

Reference them in the skill body with relative paths. Claude can read these files when the skill is loaded.

---

## Best Practices

### Writing Good Descriptions

The `description` field is how Claude decides whether to suggest a skill. Make it specific:

```yaml
# Good: specific trigger conditions
description: Use when creating or developing, before writing code - refines rough ideas into designs

# Bad: vague
description: Helps with brainstorming
```

### Skill vs Agent vs Rule

| Use a Skill when... | Use an Agent when... | Use a Rule when... |
|---------------------|---------------------|-------------------|
| Workflow needs conversation context | Work is isolated and parallel | Standard should auto-apply |
| Interactive methodology | Focused single task | Pattern matching on file types |
| Guides a process | Needs specific tools | No invocation needed |
| May spawn sub-agents | Runs in its own context | Always-on enforcement |

### Keep Skills Focused

Each skill should do one thing well. If a skill is getting long, consider:
- Breaking it into multiple skills
- Moving implementation details to an agent
- Using `skills:` dependencies for composition

### Test Your Skills

1. Edit the skill file
2. In Claude Code, invoke `/your-skill`
3. Verify it loads correctly (hot-reload, no restart needed)
4. Test edge cases (no arguments, wrong arguments)

---

## Examples

### Minimal Skill

```yaml
---
name: my-checklist
description: Run a quality checklist before committing
---

# Quality Checklist

Before committing, verify:
1. All tests pass
2. No TODO comments remain
3. No console.log statements
```

### Skill with Forked Context and Agent

```yaml
---
name: systematic-debug
context: fork
agent: debugger
skills:
  - using-git-worktrees
hooks:
  Stop:
    - type: prompt
      prompt: "Did you identify the root cause with evidence?"
      once: true
---

# Systematic Debugging

Follow the debugger agent's methodology...
```

### Skill with Dependencies

```yaml
---
name: full-build
description: Run a complete build cycle from spec to ship
skills:
  - brainstorming
  - writing-plans
  - autonomous-loop
  - requesting-code-review
---

# Full Build Cycle

1. Use /brainstorming to refine the idea
2. Use /writing-plans to create the implementation plan
3. Use /autonomous-loop to execute
4. Use /requesting-code-review at checkpoints
```
