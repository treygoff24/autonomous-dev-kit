# Gemini CLI integration for a multi model autonomous dev kit
Last updated: 2026-01-08 (America/Chicago)

This document is written for the engineer implementing Gemini CLI as a third “frontier reviewer” alongside Claude Code and GPT-5.2 Codex CLI in an autonomous agentic software development workflow. It assumes you already have a working orchestration loop (Claude as planner/executor) and you want Gemini to add independent critique, patch proposals, and optional sandboxed remediation.

## Why add Gemini CLI to a Claude + Codex stack
If Claude is your primary agent and Codex is your second opinion, Gemini CLI is a useful third brain because it comes with three things you can exploit in automation:

1. A clean headless interface for scripting: prompt in, response out, optional JSON envelope.
2. A ReAct-style agent loop that can use tools (filesystem, shell, web, MCP) when you explicitly allow it.
3. A fairly rich configuration surface (project settings, tool allowlists, sandboxing) that lets you treat it as either:
   - A pure offline critic that never touches your repo, or
   - A constrained actor that edits files in a sandboxed worktree and runs tests under strict command allowlists.

The right mental model is: Gemini CLI is a subprocess-driven agent runtime. Your dev kit should treat it as a controlled worker with explicit permissions.

## Gemini CLI concepts you must understand before wiring it into an agent loop

### 1) Headless mode is your stable “API” surface
Gemini CLI’s headless mode is invoked with `--prompt` (or `-p`). You can also pipe stdin into it, which is ideal for diffs, logs, or concatenated file snippets.

Minimal calls:

```bash
gemini -p "Summarize this repo."
```

Piped context:

```bash
git diff --cached | gemini -p "Review this diff for correctness and risk."
```

For orchestration, always prefer JSON output to avoid scraping text:

```bash
git diff --cached | gemini -p "Review this diff. Return actionable issues." --output-format json
```

The JSON output includes `response` (the main content) plus `stats` and possibly `error`. This is useful for budgeting, telemetry, and automated failure handling.

### 2) Gemini CLI can be an “agent”, not just a text generator
Gemini CLI supports tool use (filesystem read/write/edit, shell, web fetch/search, memory, MCP servers). This is the dangerous part. It is powerful and absolutely not something you want uncontrolled in an unattended loop.

Your integration should have explicit operating modes where tool permissions are tightly scoped. Treat tool use as “capability escalation.”

### 3) Configuration is layered and project-scoped
Gemini CLI reads settings from multiple locations. For automation, you should standardize on project-scoped configuration so that behavior is reproducible in CI and for other developers.

The key file locations to know:

- User settings: `~/.gemini/settings.json`
- Project settings: `.gemini/settings.json` in repo root
- Optional project env file: `.gemini/.env`

In the dev kit, assume the repo includes `.gemini/settings.json` under version control, while `.gemini/.env` is local and never committed.

### 4) Auth must be non-interactive for true headless operation
Headless runs need environment variables. The simplest is an API key:

```bash
export GEMINI_API_KEY="..."
```

Vertex auth is also supported, but it is more moving parts (ADC, service accounts, location, project). If the goal is “third model reviewer,” API key auth is usually the fastest path.

### 5) Exit codes matter in orchestration
Gemini CLI uses specific exit codes for common fatal errors (auth failure, invalid input, sandbox failure, invalid config, turn limits). Your wrapper should map these into structured orchestration events (retry, degrade, fail-fast, request human input).

## Recommended architecture for a three model checker loop

### The safe default: Gemini as a non-mutating critic
Start with Gemini as a reviewer only. No file writes, no shell, no edits. It reads only what you feed it via stdin and responds with structured critique and optionally a patch.

Flow:
1. Claude Code produces a plan and edits in your working tree.
2. Orchestrator generates context bundle:
   - `git diff` (primary)
   - Optional: relevant file excerpts, test output, lint output
3. Orchestrator calls Codex CLI to review.
4. Orchestrator calls Gemini CLI to review.
5. Orchestrator merges critiques and decides next action (apply patch, adjust plan, run tests).

Gemini call pattern:

```bash
git diff --cached \
  | gemini -p "You are a code reviewer. Find correctness, security, and maintainability issues. Output JSON with severity and fixes." \
  --output-format json
```

Your wrapper parses `.response` and then parses the JSON that Gemini produced inside that response.

Why double JSON?
- Gemini CLI returns a JSON envelope.
- Inside `response`, you can ask Gemini to return another JSON object with your own schema.
This avoids brittle parsing while keeping CLI stats available.

### The next step: Gemini proposes a git-apply patch, but still does not touch disk
When you want Gemini to “fix,” do not grant it edit tools. Make it emit a unified diff patch and let your orchestrator apply it.

Prompt pattern:

```bash
git diff --cached | gemini -p '
You are a reviewer and patch author.
1) Identify the highest impact correctness issues.
2) Provide a minimal fix as a UNIFIED DIFF (git apply compatible).
Output ONLY the diff.
' --output-format json | jq -r '.response'
```

Then:
- Validate patch applies cleanly in a throwaway worktree.
- Run tests.
- If green, merge into main worktree.

This gives you the benefit of independent repair without giving Gemini direct write access.

### Full autonomy: Gemini as an actor inside a sandboxed worktree
Only do this if you need it and you can tolerate more complexity.

Key rules:
- Never run Gemini with broad permissions on your main worktree.
- Always use a sandbox plus an ephemeral git worktree or full repo copy.
- Use command allowlists for shell.
- Prefer `--approval-mode auto_edit` rather than YOLO unless you have excellent sandboxing and strict tool allowlists.

Example:

```bash
# 1) Create isolated worktree
git worktree add -f /tmp/repo_gemini_fix HEAD

# 2) Run Gemini in that worktree, sandboxed, auto approving only edit tools
cd /tmp/repo_gemini_fix
gemini -s -p "Fix failing tests. Do not change behavior beyond what is needed." --approval-mode auto_edit

# 3) Run your own test harness as the final gate
npm test
```

Your orchestrator should treat this as a subordinate agent that works in a controlled environment. It produces a patch or a commit, then the orchestrator decides whether to accept.

## Concrete implementation guidance

### 1) Build a single wrapper interface in your dev kit
Create a single library entrypoint that all agents use, for example:

- `tools/llm_workers/gemini_cli_worker.{ts,py}`
- `tools/llm_workers/codex_cli_worker.{ts,py}`
- `tools/llm_workers/claude_code_worker.{ts,py}`

Each worker should have the same shape:

- `run(task: WorkerTask, context: ContextBundle) -> WorkerResult`
- `WorkerResult` includes:
  - `model_provider`: `"gemini-cli"`
  - `model_name`
  - `raw_stdout`
  - `raw_json_envelope` (if output-format json)
  - `parsed_payload` (your own schema)
  - `usage`: tokens, latency, tool calls (if available)
  - `exit_code`
  - `warnings`: policy violations, unsafe tool attempts, oversized context

### 2) Standardize your “review schema” across models
Do not let each model invent a new format. Define one schema and enforce it. Example:

```json
{
  "summary": "string",
  "verdict": "approve|needs_changes|block",
  "issues": [
    {
      "id": "ISSUE-1",
      "severity": "low|medium|high|critical",
      "category": "correctness|security|performance|api|ux|tests|style|build",
      "file": "path or null",
      "lines": "e.g. 12-38 or null",
      "problem": "string",
      "evidence": "string",
      "fix": "string",
      "patch": "optional unified diff or null"
    }
  ],
  "recommended_tests": ["command strings"],
  "questions": ["string"],
  "confidence": 0.0
}
```

Then prompt Gemini and Codex to output exactly this JSON. If parsing fails, the orchestrator should fall back to a strict “text mode” parser and mark the result as degraded.

### 3) Context packaging: keep it small, relevant, and deterministic
Avoid feeding entire repos. Gemini CLI can include all files (`--all-files`) but you should avoid that in automated review because it increases cost, latency, and leakage risk.

Preferred approach:
- Always include `git diff`.
- Include only the files touched by the diff, and only relevant sections.
- Include test output if the task is “fix tests.”
- Include a short repo manifest (language, build tool, test command).

A simple deterministic “context bundle” format is:

```text
=== TASK ===
<one-paragraph goal>

=== DIFF (git) ===
<git diff>

=== FILE SNIPPETS ===
path: <file>
<snippet>

=== TEST OUTPUT ===
<last failing logs>

=== CONSTRAINTS ===
- no new dependencies
- keep behavior stable
- minimal patch
```

Pipe this bundle into Gemini. This keeps the model grounded and your process reproducible.

### 4) Use Gemini CLI stats for budgeting and guardrails
When you run with `--output-format json`, the CLI returns `stats` including per-model token usage and tool usage counts. Capture it and log it.

At minimum, record:
- `stats.models.*.tokens.total`
- `stats.models.*.api.totalLatencyMs`
- `stats.tools.totalCalls`
- `stats.files.totalLinesAdded / totalLinesRemoved`

This gives you:
- cost controls
- alerts when a supposedly “review only” run starts using tools
- evidence for debugging “why did it take 30 seconds”

### 5) Tool safety: lock down the shell tool if you ever allow it
If Gemini is allowed to run shell commands, treat that as high risk. Gemini CLI supports command allowlists and blocklists for `run_shell_command`.

The important mechanics:
- Commands chained with `&&`, `||`, or `;` are split and each part is validated.
- Prefix matching is used (allow `git` covers `git status`).
- The blocklist takes precedence over allowlist.
- Simple string matching can be bypassed, so do not treat exclude lists as a security boundary.

Recommended baseline if you enable shell at all:

- In `.gemini/settings.json`, allow only a small set of prefixes, like `git`, `npm`, `pnpm`, `pytest`, `go`, `cargo`, `make` depending on repo.
- Explicitly block `rm`, `sudo`, `curl`, `wget`, `bash`, `sh` unless you truly need them.
- Always use sandboxing.

Example `.gemini/settings.json` segment:

```json
{
  "tools": {
    "core": [
      "run_shell_command(git)",
      "run_shell_command(npm)"
    ],
    "exclude": [
      "run_shell_command(rm)",
      "run_shell_command(sudo)"
    ],
    "sandbox": true
  }
}
```

### 6) Sandboxing: make it the default for any mutating run
Gemini CLI supports sandboxing via:
- `-s` / `--sandbox`
- `GEMINI_SANDBOX` env var
- `tools.sandbox` in settings

macOS supports Seatbelt profiles, and Docker/Podman is supported cross-platform.

Recommendation:
- For review-only runs with no tools, sandboxing is optional.
- For any run that might write files or run shell, sandboxing should be mandatory.

Practical profile guidance:
- Prefer a restrictive profile when possible (no network if not needed).
- If your workflow requires web search inside Gemini CLI, keep network enabled but use container sandboxing and isolate secrets.

### 7) Approval modes: avoid accidental tool escalation in headless runs
For automated calls, explicitly choose one of these strategies:

Strategy A: No tools at all
- Configure tools to be excluded or heavily restricted.
- Prompt Gemini to never call tools.
- Use headless `-p` with JSON output.

Strategy B: Auto approve only edit tools, still block shell
- Use `--approval-mode auto_edit` and configure `tools.core` to exclude `run_shell_command`.
- Run in a sandbox and isolated worktree.
- Expect Gemini to write files. Treat results as untrusted until tests pass.

Strategy C: YOLO mode for fully autonomous agent behavior
- This auto approves all tool calls, and it also enables sandboxing by default.
- Only acceptable in a locked down sandbox plus isolated worktree with no secrets.
- Use sparingly.

### 8) MCP integration: the cleanest way to give Gemini “safe powers”
If you already have an autonomous dev kit toolkit, you likely have internal tools you want LLMs to call. Gemini CLI supports MCP servers and multiple transport types (stdio, SSE, HTTP streaming).

This is ideal for building a policy enforced tool surface, for example:

- `repo.get_changed_files()`
- `repo.read_file(path, range)`
- `repo.apply_patch(unified_diff)`
- `ci.run_tests(profile)`
- `security.scan_dependency_diff()`

Design principle:
- Disable Gemini’s raw shell tool.
- Provide an MCP tool that runs a curated test harness and returns structured results.
- Provide an MCP tool that applies patches only inside a worktree and only if they pass your policy engine.

If you do this, Gemini becomes a consumer of your dev kit’s “capability API” rather than an unbounded shell user.

## Suggested implementation plan (phased)

### Phase 0: install, auth, and smoke tests
- Add Gemini CLI installation to your toolkit bootstrap.
- Confirm `gemini --version` works.
- Confirm headless call with `--output-format json` works.
- Confirm auth is available via `.gemini/.env` or environment variables.

### Phase 1: reviewer only integration
- Implement `GeminiCliWorker.runReview(contextBundle)`.
- Require output schema JSON and validate it.
- Add retry and timeouts.
- Log CLI stats for every call.

### Phase 2: patch proposer mode
- Add a `runPatchProposal()` method that requests a unified diff only.
- Add a patch validation step:
  - Apply in temporary worktree.
  - Run formatting and unit tests.
  - Revert on failure.

### Phase 3: sandboxed fixer mode
- Add a workflow that creates a worktree, runs Gemini with `--approval-mode auto_edit`, and then runs your own test harness.
- Treat any successful output as a candidate patch, not an automatic merge.
- Add diff size limits, file allowlists, and dependency change gates.

### Phase 4: MCP hardened agent mode
- Stand up an MCP server as part of your toolkit.
- Remove reliance on `run_shell_command` for Gemini.
- Give Gemini only the tools you can audit and enforce.

## Operational concerns you must handle

### Version pinning and upgrades
Gemini CLI changes quickly. Your toolkit should pin versions in CI or at least track versions in logs. If you rely on specific flags like `--approval-mode` or the JSON schema fields, you want deterministic behavior across environments.

Minimum recommendation:
- log `gemini --version` once per run
- alert on version drift in CI

### Secret hygiene
Assume any tool-enabled run can exfiltrate secrets if you allow web fetch or shell. Protect yourself with:
- no secrets in worktrees used by autonomous agents
- sandboxing with minimal mounts
- environment variable allowlists
- avoid sending `.env` and secret files in context bundles

### CI environment variables
Gemini CLI may detect CI and switch behavior when environment variables like `CI` or `CI_*` exist. This can change whether interactive mode appears. For your use, always use headless `-p`, but your wrapper should still avoid surprising behavior by explicitly selecting non-interactive mode and using clear flags.

### Timeouts and failure modes
Implement a hard timeout around the Gemini subprocess. If the process hangs, kill it. Common failure causes:
- missing auth env vars
- invalid `.gemini/settings.json`
- sandbox runtime failure (Docker not running, Seatbelt issues)
- turn limit reached

Map exit codes into clear error categories.

## Suggested `.gemini` directory layout for repos
This layout works well for automation and keeps local secrets out of git.

```text
.gemini/
  settings.json              # versioned project config
  .env                       # local only, ignored
  sandbox.Dockerfile         # optional, versioned if you need a custom sandbox image
  sandbox-macos-custom.sb    # optional seatbelt profile for macOS
GEMINI.md                    # optional repo instruction file
```

Add `.gemini/.env` to `.gitignore`.

## Reference snippets you can lift into the toolkit

### A) Headless review command template
```bash
bundle_file="${1:?bundle file required}"
model="${2:-gemini-2.5-flash}"

cat "$bundle_file" \
  | gemini -p "Return JSON only. Follow the review schema exactly." \
      --output-format json \
      --model "$model"
```

### B) Parse the JSON envelope and extract response
```bash
result="$(cat "$bundle_file" | gemini -p "..." --output-format json)"
response="$(printf '%s' "$result" | jq -r '.response')"
stats="$(printf '%s' "$result" | jq -c '.stats')"
```

### C) Enforce no-tool policy in analysis runs
- Ensure `tools.core` excludes shell, edit, write tools.
- Ensure `--approval-mode default` and do not pass `--allowed-tools`.
- Include a prompt clause: “Do not call tools. You cannot execute commands. Only analyze the provided text.”

Then assert: `stats.tools.totalCalls == 0`.

### D) Patch proposal that the orchestrator applies
```bash
diff="$(git diff --cached)"
patch="$(printf '%s' "$diff" | gemini -p "Output ONLY a unified diff patch." --output-format json | jq -r '.response')"

# validate patch is not empty and begins with diff markers
printf '%s' "$patch" | head -n 5
```

## Sources
These are the primary upstream docs used for this integration. Keep them handy when maintaining the toolkit.

```text
Headless mode and JSON schema:
https://google-gemini.github.io/gemini-cli/docs/cli/headless.html

Configuration and flags (approval modes, allowed tools, settings locations, memory files):
https://google-gemini.github.io/gemini-cli/docs/get-started/configuration.html

Authentication for headless environments:
https://google-gemini.github.io/gemini-cli/docs/get-started/authentication.html

Sandboxing guide:
https://google-gemini.github.io/gemini-cli/docs/cli/sandbox.html

Shell tool and command restrictions:
https://google-gemini.github.io/gemini-cli/docs/tools/shell.html

MCP server integration:
https://geminicli.com/docs/tools/mcp-server/

Google Cloud overview and ReAct notes:
https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli

Troubleshooting and exit codes:
https://google-gemini.github.io/gemini-cli/docs/troubleshooting.html
```
