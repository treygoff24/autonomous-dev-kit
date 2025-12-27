# Shell Configuration

This directory contains shell aliases and functions for the autonomous development workflow.

## Files

| File | Purpose |
|------|---------|
| `aliases.zsh` | Common shell aliases for CLI tools, git, npm |
| `functions.zsh` | Helper functions for autonomous builds |

## Installation

### Option 1: Source directly (recommended)

Add these lines to your `~/.zshrc` or `~/.bashrc`:

```bash
# autonomous-dev-kit shell config
source /path/to/autonomous-dev-kit/shell/aliases.zsh
source /path/to/autonomous-dev-kit/shell/functions.zsh
```

Replace `/path/to/autonomous-dev-kit` with the actual path.

### Option 2: Copy to ~/.claude/

The `install.sh` script copies these to `~/.claude/shell/`. You can source from there:

```bash
# In your ~/.zshrc or ~/.bashrc
if [ -f "$HOME/.claude/shell/functions.zsh" ]; then
    source "$HOME/.claude/shell/functions.zsh"
fi
if [ -f "$HOME/.claude/shell/aliases.zsh" ]; then
    source "$HOME/.claude/shell/aliases.zsh"
fi
```

### Option 3: Cherry-pick what you want

Open the files and copy specific aliases or functions you want to use.

## Functions Reference

### `autonomous-init`

Initialize a project for autonomous builds. Creates `CONTEXT.md`, `CLAUDE.md`, `LEARNINGS.md`, and `.claude/` directory.

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

```bash
claude-review                          # Review current changes
claude-review 'Phase 2 - Auth'         # Name the review
```

### `codex-review`

Run Codex code review for the current branch diff.

```bash
codex-review                           # Review current changes
codex-review 'Phase 2 - Auth'          # Name the review
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

These files are meant to be customized. Feel free to:

- Remove aliases you don't use
- Modify functions to match your workflow
- Add your own helpers

## Shell Compatibility

These files use syntax compatible with both zsh and bash. However:

- The aliases file is named `.zsh` but works in bash
- Zoxide initialization auto-detects your shell
- If you're using bash, you may want to rename them to `.sh`

## Troubleshooting

### "command not found: fd" (or similar)

The CLI tools (fd, bat, delta, etc.) need to be installed. Run:

```bash
./install.sh
```

### "autonomous-init: templates not found"

The function looks for templates in these locations:

1. `$HOME/.claude/autonomous-dev-kit/templates`
2. `$HOME/Code/autonomous-dev-kit/templates`
3. `$HOME/autonomous-dev-kit/templates`

Either:
- Run `install.sh` to copy templates to `~/.claude/`
- Or update the `possible_paths` array in `functions.zsh`

### Functions work but aliases don't

Make sure both files are sourced:

```bash
source /path/to/aliases.zsh
source /path/to/functions.zsh
```

Then restart your terminal or run `source ~/.zshrc`.
