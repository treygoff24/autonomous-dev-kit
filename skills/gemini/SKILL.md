---
name: gemini
description: This skill should be used when the user asks to "use Gemini", "get a Gemini review", "delegate to Gemini CLI", or "run Gemini headless" for a second opinion.
---

# Gemini Headless Delegation

Run Gemini CLI in headless mode to perform tasks in this codebase.

## Usage

Run with a direct prompt or stdin:

```bash
gemini --prompt "task description"
echo "Explain this code" | gemini
```

If the host tool supports background execution, use it for long-running calls and poll for output.

## Output Formats

- `text` (default) for human-readable output.
- `json` for structured output with `response`, `stats`, and optional `error`.
- `stream-json` for JSONL events: `init`, `message`, `tool_use`, `tool_result`, `error`, `result`.

## Flags

- `--prompt`, `-p` - Headless prompt.
- `--output-format` - `text`, `json`, `stream-json`.
- `--model`, `-m` - Specify model (e.g., `gemini-2.5-flash`).
- `--debug`, `-d` - Enable debug mode.
- `--include-directories` - Add directories to context (comma-separated).
- `--yolo`, `-y` - Auto-approve all actions.
- `--approval-mode` - Set approval mode (e.g., `auto_edit`).

## When to Use Each Approach

| Task | Approach |
|------|----------|
| Code review | Default headless prompt |
| Broad codebase question | Include paths in prompt or use `--include-directories` |
| Specific file analysis | Pipe file contents and include the file path in prompt |
| Structured output | `--output-format json` with `jq -r '.response'` |
| Live progress | `--output-format stream-json` and parse `.type` |

## Workflow

1. Define a clear, self-contained task prompt and include file paths.
2. Choose input method and output format.
3. Run Gemini and capture output.
4. Parse `response` from JSON or monitor `stream-json` events.
5. Report findings back to the user.

## Example

```bash
gemini --prompt "Review the auth module for security issues" --output-format json | jq -r '.response'
```

## Notes

- Gemini has its own context window; include all relevant context in the prompt.
- Use redirection/pipes for automation: `>`, `>>`, `|`.
- Stdin piping supported: `cat file.txt | gemini --prompt "Analyze this"`.
