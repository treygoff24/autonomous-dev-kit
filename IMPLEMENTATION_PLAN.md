# Implementation Plan: autonomous-dev-kit

> A bootstrap repo for setting up autonomous AI-assisted development with Claude Code and Codex CLI.

---

## Current Status

**Phase**: 7 - Complete
**Working on**: All phases complete
**Cross-agent reviews completed**: All
**Blockers**: None
**Runtime**: ~45m

---

## Overview

This repo provides everything needed to get started with autonomous AI-assisted web development using Claude Code CLI and OpenAI Codex CLI. It includes install scripts, protocol documentation, template files, shell configuration, and a worked example.

**Target user**: Developer who has never used Claude Code or Codex for autonomous builds, but is comfortable with CLI tools and web development fundamentals.

**Deliverables**:
1. One-command install script for CLI tools and shell config
2. Complete protocol documentation (autonomous build, spec writing, context management)
3. Template files for specs, plans, and context preservation
4. Shell aliases and functions
5. Comprehensive README with philosophy and workflow
6. Getting started guide with first-project walkthrough
7. Worked example showing a complete build cycle

---

## Phase 1: Repository Scaffold and Core Documentation

**Objective:** Create the directory structure, clean up pre-seeded template files, and write the foundational README that explains the philosophy and high-level workflow.

**Dependencies:** None

**Tasks:**
1. Rename template files to remove "copy" suffix:
   ```bash
   cd templates/
   for f in *copy*; do mv "$f" "${f// copy/}"; done
   ```
   Or manually rename each file to remove " copy" from the filename.

2. Create remaining directory structure (templates/ already exists with files):
   ```
   autonomous-dev-kit/
   ├── README.md
   ├── install.sh
   ├── docs/
   │   ├── GETTING_STARTED.md
   │   ├── WORKFLOW_REFERENCE.md
   │   └── TROUBLESHOOTING.md
   ├── templates/          # Already exists with pre-seeded files
   ├── skills/
   ├── shell/
   └── examples/
   ```

3. Write `README.md` covering:
   - What this is and why it exists (autonomous AI-assisted development)
   - The core philosophy: structured protocols beat ad-hoc prompting
   - High-level workflow overview (idea → spec → plan → build → deploy)
   - Prerequisites (Node.js, npm, Homebrew/apt, API keys for Claude/OpenAI)
   - Quick start (run install.sh, copy templates, follow GETTING_STARTED)
   - Directory structure explanation
   - Links to detailed docs

**Acceptance criteria:**
- All directories exist
- README.md is complete and explains the system coherently to a newcomer
- A developer can understand what they're getting into before running anything

**Estimated complexity:** Moderate (45-60 min)

---

## Phase 2: Install Script

**Objective:** Create a robust install script that sets up CLI tools, shell configuration, and validates the environment.

**Dependencies:** Phase 1 (directory structure exists)

**Tasks:**
1. Create `install.sh` with:
   - OS detection (macOS vs Linux)
   - Homebrew/apt package installation for CLI tools:
     - `fd` (file discovery)
     - `fzf` (fuzzy finder)
     - `bat` (syntax-highlighted cat)
     - `delta` (git diff pager)
     - `zoxide` (smart cd)
     - `jq` / `yq` (JSON/YAML processing)
     - `sd` (search/replace)
     - `ripgrep` (fast grep)
   - Node.js / npm verification
   - Claude Code CLI installation (`npm install -g @anthropic-ai/claude-code`)
   - Codex CLI installation guidance (link to OpenAI docs, as install method may vary)
   - Shell config backup and modification (append to .zshrc or .bashrc)
   - API key environment variable prompts (ANTHROPIC_API_KEY, OPENAI_API_KEY)
   - Verification step: run `claude --version` and confirm tools installed
   - Create `~/.claude/` directory for global config
   - Copy global CLAUDE.md to `~/.claude/CLAUDE.md`

2. Make script idempotent (safe to run multiple times)
3. Add `--dry-run` flag to preview changes without applying
4. Add colored output and progress indicators

**Acceptance criteria:**
- Running `./install.sh` on a fresh Mac or Linux system installs all required tools
- Running it again doesn't break anything or duplicate config
- Clear error messages if something fails
- `--dry-run` shows what would happen without doing it

**Estimated complexity:** Complex (60-90 min)

---

## Phase 3: Protocol Templates (Cleanup and Consolidation)

**Objective:** Clean up the pre-seeded template files, make them generic for any user, and consolidate the dual autonomous build protocols.

**Dependencies:** Phase 1 (template files renamed, directories exist)

**Pre-seeded files to clean up:**
- `AUTONOMOUS_BUILD_CODEX_v2.md`
- `AUTONOMOUS_BUILD_CLAUDE_v2.md`
- `CONTEXT_TEMPLATE.md`
- `SPEC_WRITING.md`
- `IMPLEMENTATION_PLAN_WRITING.md`
- `SPEC_QUALITY_CHECKLIST.md`
- `ACCESSIBILITY_CHECKLIST.md`

**Tasks:**
1. Clean up all pre-seeded templates:
   - Remove any Trey-specific or Sophon-specific references
   - Remove any project-specific examples (replace with generic placeholders)
   - Fix any encoding issues (curly quotes, special characters from copy/paste)
   - Ensure consistent formatting across all files
   - Verify all cross-references between templates are correct

2. Consolidate autonomous build protocols:
   - Option A: Merge into single `AUTONOMOUS_BUILD.md` with sections for "If using Codex as primary" vs "If using Claude as primary"
   - Option B: Keep both files but rename clearly: `AUTONOMOUS_BUILD_CODEX_PRIMARY.md` and `AUTONOMOUS_BUILD_CLAUDE_PRIMARY.md`
   - Add a brief header to each explaining when to use which
   - Ensure cross-agent call syntax is correct in both directions

3. Create `templates/CLAUDE.md` — Global Claude instructions:
   - Adapt from the global CLAUDE.md provided
   - Make generic (remove warpgrep references if user won't have it, etc.)
   - Keep the autonomous build mode detection logic
   - Keep CLI toolkit reference but note these are recommendations

4. Create `templates/LEARNINGS.md` — Learning accumulator template (new file):
   ```markdown
   # Project Learnings
   
   > Append entries at session end. Read recent entries at session start.
   
   ---
   
   ## YYYY-MM-DD — [Feature/Project Name]
   
   **What Worked:**
   - [Specific technique or decision that paid off]
   
   **What Failed:**
   - [Approach that didn't work and why]
   
   **Patterns:**
   - [Reusable insight for future builds]
   ```

5. Verify template completeness:
   - Each template is self-contained and usable without external context
   - Templates reference each other correctly (e.g., SPEC_WRITING points to SPEC_QUALITY_CHECKLIST)
   - No placeholder text, TODOs, or broken references

**Acceptance criteria:**
- All template files are cleaned up and generic
- No Trey-specific, Sophon-specific, or project-specific references remain
- Autonomous build protocols are clearly organized (merged or clearly labeled)
- LEARNINGS.md template exists
- All cross-references work

**Estimated complexity:** Moderate (30-45 min) — cleanup is faster than writing from scratch

---

## Phase 4: Shell Configuration

**Objective:** Create shell aliases and functions that streamline the autonomous development workflow.

**Dependencies:** Phase 1 (shell/ directory exists)

**Tasks:**
1. Create `shell/aliases.zsh`:
   - File discovery: `alias find='fd'`
   - Syntax highlighting: `alias cat='bat -n --paging=never'`
   - Diff viewing: `alias diff='delta'`
   - Smart cd: `alias cd='z'` (zoxide)
   - Git shortcuts: gs, gd, gds, gl, gco, ga, gc, gp, gpl
   - Claude shortcuts: `alias cc='claude'` and `alias ccr='claude --resume'`

2. Create `shell/functions.zsh`:
   - `autonomous-init`: Initialize a new project for autonomous builds
     - Creates CONTEXT.md from template
     - Creates .claude/ directory
     - Copies project CLAUDE.md template
   - `autonomous-status`: Show current phase and context summary
   - `claude-review`: Wrapper for calling Claude for code review with standard prompt
   - `codex-review`: Wrapper for calling Codex for code review with standard prompt
   - `quality-gates`: Run all quality checks (typecheck, lint, build, test)
   - `slop-check`: Quick grep for common slop patterns

3. Create `shell/README.md`:
   - How to source these files
   - Customization guidance
   - Shell compatibility notes (zsh vs bash)

**Acceptance criteria:**
- All shell files are valid zsh syntax
- Functions have helpful `--help` output
- README explains how to add to shell config

**Estimated complexity:** Moderate (45-60 min)

---

## Phase 5: Documentation

**Objective:** Write the detailed documentation that guides users from zero to autonomous builds.

**Dependencies:** Phases 1-4 (all templates and shell config exist)

**Tasks:**
1. Create `docs/GETTING_STARTED.md`:
   - Prerequisites checklist with verification commands
   - Step-by-step install walkthrough
   - First project setup:
     - Create a new directory
     - Run `autonomous-init`
     - Write a simple spec (guided example)
     - Get spec reviewed
     - Write implementation plan (guided example)
     - Get plan reviewed
     - Start the build
   - What to expect during your first autonomous build
   - Common first-timer mistakes and how to avoid them
   - Success criteria: "You'll know it's working when..."

2. Create `docs/WORKFLOW_REFERENCE.md`:
   - Complete workflow diagram (ASCII or Mermaid)
   - Phase-by-phase breakdown with exact commands
   - Cross-agent call reference (when to call which agent, exact syntax)
   - Quality gates reference
   - Context management best practices
   - Slop removal patterns with examples
   - Commit message conventions
   - Branch naming conventions

3. Create `docs/TROUBLESHOOTING.md`:
   - "Claude isn't responding" — timeout, API issues, rate limits
   - "Codex call failed" — API key, quota, syntax
   - "Build is stuck in a loop" — when to invoke stuck protocol
   - "Context feels stale" — recovery procedures
   - "Quality gates failing" — common causes and fixes
   - "Cross-agent reviews disagree" — how to resolve
   - "I don't understand the error" — when to ask for help vs push through
   - "How do I know when I'm done?" — completion criteria review

**Acceptance criteria:**
- A developer can go from zero to their first autonomous build using only these docs
- No assumed knowledge beyond "can use terminal and write code"
- All commands are copy-pasteable
- Troubleshooting covers the most common failure modes

**Estimated complexity:** Complex (60-75 min)

---

## Phase 6: Worked Example

**Objective:** Create a complete worked example showing the full autonomous build cycle from idea to deployed feature.

**Dependencies:** Phases 1-5 (all templates and docs exist)

**Tasks:**
1. Create `examples/todo-app/` directory with:
   - `SPEC.md` — Complete spec for a simple todo app:
     - Problem: "I need a todo app to track tasks"
     - Scope: CRUD operations, local storage, single user
     - User stories, data model, UI/UX requirements
     - Acceptance criteria
   - `IMPLEMENTATION_PLAN.md` — 4-phase plan:
     - Phase 1: Project setup and data model
     - Phase 2: Core CRUD operations
     - Phase 3: UI components
     - Phase 4: Polish and testing
   - `CONTEXT.md` — Filled-in context showing mid-build state
   - `LEARNINGS.md` — Example learnings from the build
   - `BUILD_LOG.md` — Annotated log of what happened during the build:
     - Timestamps for each phase
     - Cross-agent review excerpts
     - Issues encountered and how they were resolved
     - Total time to completion

2. Create `examples/todo-app/src/` with actual working code:
   - Simple Vite + React + TypeScript setup
   - Functional todo app that matches the spec
   - Clean code demonstrating post-slop-removal quality

3. Create `examples/README.md`:
   - What this example demonstrates
   - How to study it (read spec first, then plan, then context, then code)
   - How to run the example locally
   - Key takeaways

**Acceptance criteria:**
- Example is complete and runnable (`npm install && npm run dev`)
- Build log shows realistic timestamps and issues
- Someone can study this example and understand the full workflow
- Code is clean and demonstrates good practices

**Estimated complexity:** Complex (75-90 min)

---

## Phase 7: Final Polish and Verification

**Objective:** Ensure everything works together, cross-reference links are correct, and the repo is ready for use.

**Dependencies:** Phases 1-6 (everything exists)

**Tasks:**
1. Cross-reference verification:
   - All links between docs work
   - Templates reference each other correctly
   - README points to correct paths
   - Install script copies files to correct locations

2. Consistency check:
   - Terminology is consistent across all docs
   - Command syntax is consistent (same flags, same order)
   - Formatting is consistent (headers, code blocks, lists)

3. Validation testing:
   - Run install script with `--dry-run` and verify output
   - Source shell config and verify aliases/functions work
   - Verify example app runs
   - Walk through GETTING_STARTED mentally and verify steps make sense

4. Final files:
   - Create `CHANGELOG.md` with v1.0.0 entry
   - Create `LICENSE` (MIT)
   - Create `.gitignore` for common ignores
   - Verify all files are committed

**Acceptance criteria:**
- No broken links
- No inconsistent terminology
- Install script runs without errors
- Example app builds and runs
- A fresh reader could follow GETTING_STARTED without confusion

**Estimated complexity:** Moderate (45-60 min)

---

## Cross-Agent Review Checkpoints

Call for review at these points:

1. **After Phase 1**: Review README for clarity and completeness
2. **After Phase 2**: Review install script for robustness and cross-platform support
3. **After Phase 3**: Review cleaned-up templates for completeness, consistency, and successful de-personalization
4. **After Phase 5**: Review documentation for clarity and completeness
5. **After Phase 6**: Review worked example for realism and educational value
6. **After Phase 7**: Final cross-check before marking complete

---

## Completion Criteria

The repo is complete when:

1. All 7 phases marked complete
2. All cross-agent review checkpoints passed
3. Install script runs successfully on macOS
4. Example app builds and runs
5. A developer unfamiliar with the system can follow GETTING_STARTED and complete their first autonomous build
6. All commits pushed to main branch
7. README is compelling and clear

---

## Notes for the Implementing Agent

- This is a greenfield documentation/tooling repo, not an application
- Quality gates are lighter: no typecheck/lint/build/test in the traditional sense
- Instead, validate: shell scripts run, markdown renders, example code builds
- The worked example code should be minimal but functional—don't over-engineer
- Write for a smart developer who's new to this workflow, not for yourself
- Be opinionated—this is Trey's battle-tested system, not a generic guide
- **Pre-seeded templates**: The templates/ directory already contains copied files with " copy" in the filename—rename these first (Phase 1), then clean them up (Phase 3)
- Watch for encoding issues in the copied files (curly quotes, em-dashes, etc.)—normalize to ASCII-safe markdown
