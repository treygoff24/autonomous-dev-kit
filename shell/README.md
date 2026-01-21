# Shell Configuration

This directory contains shell functions for the autonomous development workflow.

## Maximum Autonomy Warning

The `claude-review` and `codex-review` helpers run with `--dangerously-skip-permissions` and `--yolo`, which bypass safety prompts. Use only in trusted repos, review diffs before committing, and remove those flags if you want approval gates.

## Files

| File | Purpose |
|------|---------|
| `functions.zsh` | Helper functions for autonomous builds |

## Installation

### Option 1: Source directly (recommended)

Add these lines to your `~/.zshrc` or `~/.bashrc`:

```bash
# autonomous-dev-kit shell config
source /path/to/autonomous-dev-kit/shell/functions.zsh
```

Replace `/path/to/autonomous-dev-kit` with the actual path.

### Option 2: Copy to ~/.claude/

The `install.sh` script copies this to `~/.claude/shell/`. You can source from there:

```bash
# In your ~/.zshrc or ~/.bashrc
if [ -f "$HOME/.claude/shell/functions.zsh" ]; then
    source "$HOME/.claude/shell/functions.zsh"
fi
```

### Option 3: Cherry-pick what you want

Open the file and copy specific functions you want to use.

## Functions Reference

### `autonomous-init`

Initialize a project for autonomous builds. Creates `CONTEXT.md`, `CLAUDE.md`, `LEARNINGS.md`, `.claude/`, and `.gemini/` (if the template exists).

```bash
mkdir my-project && cd my-project
autonomous-init
```

### `autonomous-status`

Display current autonomous build status by reading `CONTEXT.md` and `IMPLEMENTATION_PLAN.md`.

```bash
autonomous-status
```

### `quality-gates`

Run all quality gates: typecheck, lint, build, test.

```bash
quality-gates                # Run all
quality-gates --skip-tests   # Skip tests
quality-gates --skip-build   # Skip build
```

### `claude-review`

Run Claude code review for the current branch diff.

Note: This command uses `--dangerously-skip-permissions`.

```bash
claude-review                          # Review current changes
claude-review 'Phase 2 - Auth'         # Name the review
```

### `codex-review`

Run Codex code review for the current branch diff.

Note: This command uses `--yolo`.

```bash
codex-review                           # Review current changes
codex-review 'Phase 2 - Auth'          # Name the review
```

### `gemini-review`

Run Gemini code review for the current branch diff.

Note: This command pipes a context bundle (spec, plan, diff) into Gemini.
Requires the Gemini CLI and `GEMINI_API_KEY`.

```bash
gemini-review                          # Review current changes
gemini-review 'Phase 2 - Auth'         # Name the review
```

### `slop-check`

Grep for common AI-generated cruft patterns.

```bash
slop-check         # Check src/
slop-check lib/    # Check specific directory
```

### Git helpers

```bash
git-feature user-auth    # Create feature/user-auth branch
git-feat 'add login'     # Commit with feat: prefix
git-fix 'resolve bug'    # Commit with fix: prefix
git-chore 'update deps'  # Commit with chore: prefix
```

## Customization

This file is meant to be customized. Feel free to:

- Modify functions to match your workflow
- Add your own helpers

## Shell Compatibility

This file uses syntax compatible with both zsh and bash. However:

- Zoxide initialization auto-detects your shell
- If you're using bash, you may want to rename it to `.sh`

## Troubleshooting

### "command not found: fd" (or similar)

The CLI tools (fd, bat, delta, etc.) need to be installed. Run:

```bash
./install.sh
```

### "autonomous-init: templates not found"

The function looks for templates in these locations:

1. `$HOME/Code/autonomous-dev-kit/templates`
2. `$HOME/autonomous-dev-kit/templates`
3. `$HOME/.claude/autonomous-dev-kit/templates`

Either:
- Run `install.sh` to copy templates to `~/.claude/`
- Or update the `possible_paths` array in `functions.zsh`

### Functions not available

Make sure the file is sourced:

```bash
source /path/to/functions.zsh
```

Then restart your terminal or run `source ~/.zshrc`.
