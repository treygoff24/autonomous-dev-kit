# Bundling Custom Agents with Claude Code: A Complete Guide

**Yes, you can bundle pre-configured agents with an installable dev kit.** Claude Code's architecture explicitly supports project-level agent distribution through the `.claude/agents/` directory. When users clone a repository containing this directory, all custom agents become immediately available via the `/agents` command with no additional setup required.

## How agent discovery and distribution works

Claude Code discovers agents at startup by scanning multiple locations in priority order: project-level agents in `.claude/agents/` take precedence over CLI-defined agents (`--agents` flag), which override user-level agents in `~/.claude/agents/`, which finally fall back to plugin-bundled agents. This hierarchy means **your dev kit's agents automatically override any conflicting user configurations**, ensuring consistent behavior across all users.

The `/agents` command provides an interactive management interface that displays all available agents grouped by source (built-in, project, user, plugin). Users can view, create, edit, and delete agents—though project-level agents committed to version control remain protected from local deletion until the user modifies the repository itself.

| Location | Scope | When to use |
|----------|-------|-------------|
| `.claude/agents/` | Repository-wide | Dev kit distribution |
| `~/.claude/agents/` | All user projects | Personal workflows |
| `--agents '{}'` flag | Single session | Testing and overrides |
| Plugin `agents/` | Per installation | Marketplace distribution |

## Agent file format uses Markdown with YAML frontmatter

Each agent is a standalone `.md` file combining configuration metadata with a system prompt. The schema supports **six configuration fields**:

```markdown
---
name: code-reviewer
description: Expert code reviewer. Use PROACTIVELY after any code modifications.
tools: Read, Grep, Glob, Bash
model: sonnet
permissionMode: default
skills: security-audit, best-practices
---

You are a senior code reviewer ensuring high standards of quality and security.

When invoked:
1. Run `git diff` to identify recent changes
2. Focus analysis on modified files
3. Begin review immediately without asking for confirmation

Organize feedback by severity:
- **Critical** - Security vulnerabilities, data loss risks
- **Warning** - Performance issues, code smells
- **Suggestion** - Style improvements, readability
```

The `description` field is critical for automatic delegation—Claude reads these descriptions to decide when to spawn each agent. Including phrases like **"Use PROACTIVELY"** or **"MUST BE USED"** increases the likelihood of automatic invocation. Tools can be restricted to create read-only agents (useful for reviewers) or granted full access for code-writing agents.

## Subagent runtime architecture isolates context windows

When Claude spawns a subagent, it uses the **Task tool** internally to create an isolated execution context. The parent agent passes task instructions and receives distilled results back, but the subagent operates in its own context window without access to the parent's full conversation history. This isolation prevents context pollution during deep exploration tasks.

Three built-in subagents ship with Claude Code: the **General-purpose agent** (Sonnet model, all tools, read-write access) handles complex multi-step operations; the **Plan agent** (Sonnet, limited tools) researches codebases during planning phases; and the **Explore agent** (Haiku for speed, read-only tools) performs rapid file searches. Custom agents supplement these rather than replacing them.

Subagents **cannot spawn additional subagents**—this hard constraint prevents infinite recursion and runaway context consumption. However, subagents can be **resumed** using their unique `agentId`, allowing long-running tasks to continue across multiple interactions. Each execution persists to `agent-{agentId}.jsonl` for later retrieval.

## Complete dev kit structure for agent distribution

For maximum configurability, a dev kit can bundle agents alongside skills, commands, settings, and rules:

```
your-dev-kit/
├── .claude/
│   ├── agents/                    # Custom subagents (auto-discovered)
│   │   ├── test-runner.md
│   │   ├── code-reviewer.md
│   │   └── security-scanner.md
│   ├── skills/                    # Expertise packages (auto-loaded on demand)
│   │   └── api-design/
│   │       ├── SKILL.md
│   │       └── examples/
│   ├── commands/                  # Slash commands (/review, /deploy)
│   │   ├── review.md
│   │   └── deploy.md
│   ├── rules/                     # Auto-loaded instruction modules
│   │   ├── code-style.md
│   │   └── testing-standards.md
│   └── settings.json              # Permissions, hooks, environment
├── CLAUDE.md                      # Project memory (always loaded)
└── README.md
```

Skills differ from agents in an important way: skills add knowledge to the **current conversation** context, while agents run in **isolated context windows** and return summarized results. Use skills for coding standards, architectural patterns, and reference documentation. Use agents for task-specific workflows requiring independent execution.

## Configuration inheritance enables layered customization

Claude Code reads `CLAUDE.md` files recursively from the current directory upward to the filesystem root. This allows **nested configuration**: a monorepo can have root-level standards with package-specific overrides in subdirectories. Files discovered in subdirectories load when Claude reads files from those locations.

The rules directory (`.claude/rules/*.md`) provides modular instruction loading—all markdown files automatically merge into project memory. Rules can be scoped to specific file patterns using YAML frontmatter:

```yaml
---
paths: src/api/**/*.ts
---
# API Development Rules
All endpoints must include input validation and error handling...
```

Settings follow a similar hierarchy with enterprise, user, project, and local-project levels. Enterprise-managed settings (`/etc/claude-code/managed-settings.json`) cannot be overridden, while `settings.local.json` allows gitignored personal preferences.

## Environment variables and CLI flags extend behavior

Several environment variables affect agent execution:

- **`CLAUDE_CODE_SUBAGENT_MODEL`** - Override the model used for all subagents
- **`CLAUDE_CONFIG_DIR`** - Point to an alternative configuration directory
- **`ANTHROPIC_MODEL`** - Override the main conversation model
- **`MAX_THINKING_TOKENS`** - Expand extended thinking budget

The `--agents` flag accepts JSON for session-specific agent definitions, useful for testing configurations before committing them:

```bash
claude --agents '{"quick-test": {"description": "Run tests", "prompt": "Execute test suite", "tools": ["Bash"]}}'
```

## Known limitations and workarounds

GitHub issues reveal that **manually-created agent files sometimes fail discovery** until Claude Code restarts. Using the `/agents create` interactive command ensures immediate availability. The community reports this as a bug in versions around 2.0.35, though the interactive creation path works reliably.

For multi-instance environments running parallel Claude Code sessions, file locking on shared configuration can cause contention. A feature request exists for `CLAUDE_HOME` or `CLAUDE_CONFIG_DIR` environment variables to isolate instances—this may already be available in recent versions.

CLAUDE.md files cannot achieve true agent isolation—they add instructions to the main context rather than spawning separate execution environments. For genuine task delegation with context isolation, subagents remain necessary.

## Conclusion

Claude Code provides a robust distribution mechanism for custom agents through the `.claude/agents/` directory. **Committing this directory to version control automatically provisions all team members with your custom agents**—no manual setup required. The priority system ensures project-level configurations override user preferences, guaranteeing consistent behavior across installations.

For comprehensive dev kit distribution, combine agents with skills (expertise packages), commands (slash command triggers), rules (modular instructions), and a root CLAUDE.md (project memory). The plugin system offers an alternative distribution path through marketplaces if you need cross-project sharing beyond a single repository. Community repositories like VoltAgent's collection (6,200+ stars) demonstrate widespread adoption of these patterns for agent distribution.