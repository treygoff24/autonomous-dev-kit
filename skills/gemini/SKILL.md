---
name: gemini
description: Delegate work to Google Gemini CLI. Use for second opinions on bugs, code reviews, spec/plan reviews, debugging help, or parallel work. Gemini runs as a separate AI agent with its own tools and context.
---

# Gemini Delegation

Invoke Google Gemini CLI to perform tasks in this codebase.

## Usage

Always run in background (Gemini can take minutes to complete):

```bash
gemini -p "task description" --yolo 2>/dev/null
```

Use `run_in_background: true` parameter on Bash tool. This returns a task ID - use TaskOutput to get results when ready.

## Flags

- `--yolo` / `-y` - Auto-approve all actions. Default for automation.
- `--model` / `-m` - Specify model (e.g., `gemini-2.5-pro`, `gemini-2.5-flash`).
- `--all-files` / `-a` - Include all files in context.
- `--include-directories` - Add directories to context (comma-separated).
- `--output-format json` - Get structured output (use with `jq -r '.response'`).

## When to Use Each Approach

| Task | Approach |
|------|----------|
| Code review | Default (reads files as needed) |
| Broad codebase question | `--all-files` or `--include-directories` |
| Specific file analysis | Include paths in prompt |
| Structured output | `--output-format json` |

## Workflow

1. Determine the task
2. Run gemini with `run_in_background: true`
3. Inform user that Gemini is working
4. Use TaskOutput to wait for completion and get results
5. Report findings back to user

## Example

```
Bash(
  command="gemini -p 'Review the auth module for security issues' --yolo 2>/dev/null",
  run_in_background=true
)
# Returns task_id
# Then: TaskOutput(task_id=..., block=true) to get results
```

## Notes

- Gemini has its own context window - it doesn't see our conversation
- Provide clear, self-contained task descriptions
- For file-specific tasks, include paths in the prompt
- Background execution means no timeout issues - Gemini can take as long as needed
- Stdin piping supported: `cat file.txt | gemini -p "analyze this"`
