# Agent Instructions

This is the autonomous-dev-kit repository — a harness for long-running autonomous AI development using Claude Code.

## Repo Structure

- `agents/` — Custom agent definitions (YAML frontmatter + markdown)
- `skills/` — Skill definitions (YAML frontmatter + markdown)
- `rules/` — Auto-loaded rules for code quality, testing, verification
- `hooks/` — Shell hooks (session-start, stop, pre-compact, user-prompt-submit)
- `hooks/lib/` — Shared libraries for hooks (loop-helpers.sh, task-helpers.sh)
- `templates/` — Project initialization templates
- `shell/` — Shell functions (autonomous-init, quality-gates, etc.)
- `docs/` — User-facing documentation
- `install.sh` — Interactive installer
- `tests/` — Integration tests for the harness

## Development Workflow

1. Changes to hooks, agents, skills, or rules should be tested via `tests/test-integration.sh`
2. Documentation changes should be cross-referenced for consistency across README.md, docs/, and inline references
3. The installer (`install.sh`) copies files to `~/.claude/` — changes to source files need re-install to take effect

## Session Completion

- Run `bash tests/test-integration.sh` if hooks or lib files changed
- Verify no broken cross-references (`grep -r` for skill/agent names)
- Commit and push your changes
