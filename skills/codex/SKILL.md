---
name: codex
description: Delegate work to OpenAI Codex CLI. Use for second opinions on bugs, code reviews, spec/plan reviews, debugging help, or parallel work. Codex runs as a separate AI agent with its own tools and context.
---

# Codex Delegation

Invoke OpenAI Codex CLI to perform tasks in this codebase.

## Usage

Always run in background (Codex can take minutes to complete):

```bash
codex exec --full-auto "task description" 2>/dev/null
```

Use `run_in_background: true` parameter on Bash tool. This returns a task ID - use TaskOutput to get results when ready.

## Flags

- `--full-auto` - Default. Workspace-write sandbox with auto-approval. Can edit files and run commands.
- `-s read-only` - Read-only sandbox mode. Use for reviews where you don't want changes.
- `--dangerously-bypass-approvals-and-sandbox` - No approvals, no sandbox. Use only for trusted tasks.
- `-C <path>` or `--cd <path>` - Set working directory.
- `--add-dir <path>` - Grant additional directory access.
- `-m <model>` - Specify model (e.g., `-m o3`, `-m gpt-4.1`).

## When to Use Each Mode

| Task | Mode |
|------|------|
| Code review | `--full-auto` (default, can read everything) |
| Spec/plan review | `--full-auto` (default) |
| Debugging investigation | `--full-auto` |
| Implement feature | `--full-auto` |
| Untrusted environment | `-s read-only` |

## Workflow

1. Determine the task and appropriate mode
2. Run codex exec with `run_in_background: true`
3. Inform user that Codex is working
4. Use TaskOutput to wait for completion and get results
5. Report findings back to user

## Example

```
Bash(
  command="codex exec --full-auto 'Review the auth module for security issues' 2>/dev/null",
  run_in_background=true
)
# Returns task_id
# Then: TaskOutput(task_id=..., block=true) to get results
```

## Notes

- Codex has its own context window - it doesn't see our conversation
- Provide clear, self-contained task descriptions
- For file-specific tasks, include paths in the prompt
- Background execution means no timeout issues - Codex can take as long as needed
