# Global Claude Instructions

## First Thing to Do — Every Session

**Before doing ANY work in a repository, ALWAYS read the project's `CLAUDE.md` file first.**

This is mandatory. The project CLAUDE.md contains critical context about:
- Project architecture and structure
- Required tools and CLI preferences
- Testing commands and verification steps
- Coding standards and patterns
- Provider/model configurations

Run `cat CLAUDE.md` or use the Read tool on `CLAUDE.md` at the project root before starting any task.

---

## Autonomous Build Mode

If `CONTEXT.md` exists in the project root, you may be in an autonomous build session:
1. **Read `CONTEXT.md` first** — it contains critical context and the Protocol Reminder
2. If the Protocol Reminder references `AUTONOMOUS_BUILD_CLAUDE_v2.md`, read that file
3. Continue from whatever phase you were on

This applies after every context compaction. CONTEXT.md is your source of truth for what you're building and how.

**The bootstrap chain:**
```
CLAUDE.md (always fresh)
    ↓ "if CONTEXT.md exists, read it"
CONTEXT.md (updated every phase, survives in working directory)
    ↓ Protocol Reminder section
    ↓ "if stale, re-read AUTONOMOUS_BUILD_CLAUDE_v2.md"
AUTONOMOUS_BUILD_CLAUDE_v2.md (full protocol, re-read on demand)
```

---

## General Preferences

- Keep responses concise and actionable
- Prioritize understanding existing code before making changes
- Always run linting/tests as specified in the project CLAUDE.md

---

## Recommended CLI Toolkit

These CLI helpers improve workflow speed and consistency:

| Tool | Purpose | Example |
|------|---------|---------|
| `fd` | File discovery | `fd -t f hook src/hooks` |
| `fzf` | Fuzzy finder | Pair with `fd` or `rg` |
| `bat` | Syntax-highlighted reader | `bat -n --paging=never file.tsx` |
| `delta` | Git diff pager | Auto-configured as git pager |
| `zoxide` | Smart directory jumper | `z project` |
| `jq` / `yq` | JSON/YAML processing | `jq '.path' file.json` |
| `sd` | Search/replace | `sd 'old' 'new' file.tsx` |
| `rg` | Fast grep (ripgrep) | `rg 'pattern' src/` |

---

## Shell Aliases

Recommended aliases for your shell config:

```bash
# File operations
alias find='fd'
alias cat='bat -n --paging=never'
alias diff='delta'

# Git shortcuts
alias gs='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline -20'
alias gco='git checkout'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gpl='git pull'

# Claude shortcuts
alias cc='claude'
alias ccr='claude --resume'
```

---

## When Asked for Ideas or Recommendations

**ALWAYS read the relevant code FIRST before giving suggestions.**

When asked for ideas on how to change, implement, or improve something:
1. **Step 1**: Find and read the actual code related to that area
2. **Step 2**: Understand how it's currently implemented
3. **Step 3**: THEN provide informed recommendations based on what's actually there

Never guess or make generic suggestions when you have full codebase access.

---

## Project-Specific Instructions

This file provides global defaults. Project-specific CLAUDE.md files override these settings for their respective projects. Always check for and read the project CLAUDE.md first.
