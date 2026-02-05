---
name: codex
description: This skill should be used when the user asks to "use Codex CLI", "codex exec", "get a Codex second opinion", or "run a Codex review" as a separate agent.
---

# Codex CLI Delegation

Use Codex CLI as a parallel agent with its own context window. Prefer `codex exec` for headless runs and `codex` for the TUI.

## When to Use

- Code review or spec/plan review
- Debugging second opinion
- Parallel implementation in an isolated worktree

## Quickstart

```bash
codex exec --sandbox read-only "Review src/auth against SPEC.md. Focus on security and tests."
codex exec --full-auto --cd ../worktrees/task-3 "Implement Task 3 from IMPLEMENTATION_PLAN.md."
```

## Exec Inputs

- PROMPT string, or `-` to read stdin.
- `--image, -i` attaches one or more images to the first message.

## Config and Model Overrides

- `--model, -m` overrides the configured model (e.g., `gpt-5-codex`).
- `--profile, -p` selects a profile from `~/.codex/config.toml`.
- `--config, -c key=value` overrides config values (repeatable).
- `--oss` uses the local open source provider (requires Ollama).
- `--cd, -C` sets the working directory before execution.
- `--skip-git-repo-check` allows running outside a Git repo.

## Safety Controls

- `--sandbox, -s`: `read-only` | `workspace-write` | `danger-full-access`.
- `--ask-for-approval, -a`: `untrusted` | `on-failure` | `on-request` | `never`.
- `--full-auto`: sets `--ask-for-approval on-request` and `--sandbox workspace-write`.
- `--dangerously-bypass-approvals-and-sandbox`, `--yolo`: no approvals or sandbox.
- `--add-dir`: grant extra write roots.
- `--search`: enable web search tool usage.

## Output and Scripting

- `--json` / `--experimental-json`: newline-delimited JSON events.
- `--output-last-message, -o <path>`: write final assistant message to a file.
- `--output-schema <path>`: validate the final response against a JSON Schema.
- `--color <always|never|auto>`: control ANSI output.

## Session Control

- `codex resume [SESSION_ID]` or `codex resume --last [--all]`.
- `codex exec resume [SESSION_ID]` to continue non-interactive runs.
- `codex fork [SESSION_ID]` to branch a prior interactive session.

## Notes

- Global flags apply to subcommands; place them after the subcommand (e.g., `codex exec --oss ...`).
- Codex runs with its own context window; include all necessary context in the prompt.
