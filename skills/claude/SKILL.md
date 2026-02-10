---
name: claude
description: This skill should be used when the user asks to "use Claude Code", "Claude Code best practices", "run Claude headless", "claude -p", "plan mode", "configure Claude Code", or "optimize Claude Code workflows".
---

# Claude Code Best Practices

Use Claude Code as an agentic environment. Emphasize verification, context discipline, and structured workflows.

## When to Use

- Onboarding or workflow questions about Claude Code
- Designing prompts for multi-step changes
- Headless automation (`claude -p`) and CI usage
- Scaling via subagents, hooks, MCP, skills, or parallel sessions

## Core Principles

- Provide verification criteria (tests, screenshots, expected output).
- Explore → Plan → Implement → Commit; skip planning for tiny edits.
- Scope prompts tightly (file paths, constraints, patterns, edge cases).
- Manage context aggressively; avoid kitchen-sink sessions.
- Fix root causes; avoid suppressing errors.

## Workflow Pattern

1. Explore in Plan Mode: read files, answer questions, no edits.
2. Plan: list file changes, risk areas, and checks.
3. Implement: make edits and verify against the plan.
4. Commit/PR: only when explicitly requested.

## Prompting Patterns

- Reference files with `@path/to/file` instead of describing locations.
- Include examples and expected outcomes; supply failing cases.
- Describe symptoms and "fixed" criteria.
- Ask for an interview using `AskUserQuestion` for large features.
- Paste screenshots/images for UI work and specify what to match.
- Provide URLs for docs/APIs; allowlist domains via `/permissions` when needed.
- Provide data via pipes: `cat error.log | claude`.

## Headless Mode

- One-off query: `claude -p "Explain this project"`
- JSON output: `claude -p "List API endpoints" --output-format json`
- Streaming: `claude -p "Analyze logs" --output-format stream-json`
- Stream event types: `init`, `message`, `tool_use`, `tool_result`, `error`, `result`.
- Batch/fan-out: loop through files and use `--allowedTools` to scope actions.
- Use `--verbose` for debugging.
- Use `--dangerously-skip-permissions` only inside a sandbox without internet.

## Environment Setup

- Keep `CLAUDE.md` concise; include only non-obvious rules and commands.
- Use `@` imports in `CLAUDE.md` for related docs.
- Configure permissions with `/permissions` or isolation with `/sandbox`.
- Prefer CLI tools (gh, aws, gcloud, sentry-cli) over API calls.
- Connect MCP servers with `claude mcp add`.
- Use `/plugin` to discover and install plugins.
- Use hooks for must-run actions; configure with `/hooks` or `.claude/settings.json`.
- In this kit, `hooks/stop.sh` provides deterministic autonomous-loop enforcement based on `.claude/autonomous-loop.json` (git clean + task list complete + quality gates + scoped plan checks before exit).
- Create skills in `.claude/skills/` and subagents in `.claude/agents/`.

## Context Management

- Use `/clear` between unrelated tasks.
- Use `/compact <instructions>` to guide compaction.
- Use `Esc` to stop runaway actions while preserving context.
- Use `/rewind` or double-ESC to restore checkpoints.
- Resume with `claude --continue` or `claude --resume`; rename with `/rename`.

## Parallelism

- Run parallel sessions for writer/reviewer workflows.
- Use subagents for investigations or second-pass reviews.

## Common Pitfalls

- Kitchen-sink sessions: reset with `/clear`.
- Repeated corrections: restart with a cleaner prompt.
- Overlong `CLAUDE.md`: prune until only essential rules remain.
