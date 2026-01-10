# Smart Installer Design

**Date:** 2025-12-29
**Status:** Approved

## Problem

The current `install.sh` script assumes a fresh environment. Existing developers with their own tools and aliases don't want their setup overwritten. They want to add only what's missing.

## Solution

Add a 3-mode installer that detects existing environment and lets users choose:

1. **Full install** — backup and overwrite everything
2. **Add missing only** — preserve existing, add what's missing
3. **Tools only** — install CLI tools, skip shell/config changes

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Alias conflict handling | Skip if exists | Respects user customizations |
| Alias detection method | `zsh -ilc 'alias'` subshell | Sees ALL loaded aliases regardless of source file |
| Prompt UX | Single upfront prompt after detection | Clean, one decision, less interruption |
| ~/.claude handling | Same 3-mode treatment | Consistent behavior |
| Hook conflicts | Idempotent append | Hooks can coexist; add ours if not present |
| CLI flags | None | Keep it simple, always interactive |
| Upgrades | Detect and add new aliases | Script is idempotent, run anytime for updates |

## Detection Phase

Before prompting, gather complete inventory:

### CLI Tools
```bash
tools=(fd fzf bat delta zoxide jq yq sd rg)
for tool in tools:
    if command -v $tool exists → "installed"
    else → "missing"
```

### Aliases
```bash
# Get all currently loaded aliases
existing_aliases=$(zsh -ilc 'alias' 2>/dev/null || bash -ilc 'alias' 2>/dev/null)

# Check each alias we want to install
our_aliases=(find cat diff gs gd gds gl gco ga gc gp gpl cc ccr)
for alias_name in our_aliases:
    if grep "^${alias_name}=" in existing_aliases → "exists"
    else → "missing"
```

### ~/.claude Files
```bash
files=(~/.claude/CLAUDE.md ~/.claude/shell/functions.zsh ...)
for file in files:
    if exists → "exists"
    else → "missing"
```

### Hooks
```bash
# Parse settings.json, check if our specific hook commands are present
if settings.json exists and contains our hook path → "exists"
else → "missing"
```

## Prompt UX

```
==================================
  autonomous-dev-kit installer
==================================

Scanning existing environment...

  CLI Tools:    5/9 installed (missing: fzf, delta, sd, yq)
  Aliases:      7/14 defined (missing: gds, gco, cc, ccr, diff, cat, find)
  ~/.claude:    3/6 files exist (missing: hooks/pre-compact.sh, ...)
  Hooks:        0/2 configured

How would you like to proceed?

  [1] Full install
      Backup existing configs, install everything fresh

  [2] Add missing only  (recommended)
      Install missing tools/aliases, preserve your customizations

  [3] Tools only
      Install CLI tools via Homebrew, skip all shell/config changes

Choice [1/2/3]:
```

## Behavior Matrix

| Choice | CLI Tools | Aliases | ~/.claude files | Hooks |
|--------|-----------|---------|-----------------|-------|
| Full | Install all | Backup & overwrite block | Backup & overwrite | Replace hooks section |
| Add missing | Install missing | Append missing only | Create missing only | Append if not present |
| Tools only | Install missing | Skip | Skip | Skip |

## Implementation Details

### Full Mode
1. Backup `$SHELL_CONFIG` → `$SHELL_CONFIG.backup.TIMESTAMP`
2. Remove existing `# >>> autonomous-dev-kit >>>` block if present
3. Append fresh block with all aliases
4. Backup `~/.claude/settings.json` if exists
5. Overwrite all `~/.claude` files with fresh copies
6. Install all CLI tools (brew skips already-installed)

### Add Missing Mode
1. For each missing alias:
   - Append single alias line to `$SHELL_CONFIG`
   - Use marker: `# autonomous-dev-kit: <alias-name>`
2. For each missing `~/.claude` file:
   - Create it (parent dirs as needed)
3. For hooks:
   - Parse `settings.json`, append our hook to array if not present
   - Create `settings.json` if doesn't exist

### Tools Only Mode
1. Run `brew install` for missing tools
2. Exit without touching shell config or `~/.claude`

### Alias Append Format (Add Missing mode)
```bash
# autonomous-dev-kit: cat
alias cat='bat -n --paging=never'
```

Per-alias marker lets future runs detect which aliases we installed vs user-defined.

## Files Changed

- `install.sh` — main refactor to add detection + 3-mode logic
