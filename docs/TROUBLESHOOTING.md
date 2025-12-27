# Troubleshooting

Common issues and how to fix them.

---

## Maximum Autonomy Warning

This kit uses maximum autonomy commands in examples and helpers, including `--dangerously-skip-permissions` (Claude) and `--yolo` (Codex). These bypass safety prompts and allow tools to run without confirmation.

Use only in trusted repos and isolated environments. Review diffs before committing, avoid running against production systems, and remove those flags if you want approval gates.

---

## Installation Issues

### "Claude command not found"

**Cause:** Claude Code CLI not installed or not in PATH.

**Fix:**

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version

# If still not found, check npm global bin path
npm bin -g
# Add that path to your PATH if needed
```

### "fd/bat/rg command not found"

**Cause:** CLI tools not installed.

**Fix:**

```bash
# macOS
brew install fd fzf bat git-delta zoxide jq yq sd ripgrep

# Verify
fd --version
bat --version
rg --version
```

### "autonomous-init: templates not found"

**Cause:** Templates not in expected location.

**Fix:**

The function looks for templates in these locations:
1. `$HOME/.claude/autonomous-dev-kit/templates`
2. `$HOME/Code/autonomous-dev-kit/templates`
3. `$HOME/autonomous-dev-kit/templates`

Either:
- Re-run `./install.sh` to copy templates
- Or update `possible_paths` in `~/.claude/shell/functions.zsh`

---

## API Issues

### "Claude isn't responding"

**Possible causes:**

1. **API key not set**
   ```bash
   echo $ANTHROPIC_API_KEY
   # Should show your key
   ```

2. **Rate limited**
   - Wait a few minutes and retry
   - Check your usage at [console.anthropic.com](https://console.anthropic.com/)

3. **Network issues**
   ```bash
   curl -I https://api.anthropic.com
   # Should return 200 OK
   ```

4. **Timeout on complex requests**
   - Claude may take 30 seconds to several minutes for complex reviews
   - Wait at least 60 seconds before assuming failure
   - Check your terminal isn't frozen (try pressing Enter)

### "Codex call failed"

**Possible causes:**

1. **API key not set**
   ```bash
   echo $OPENAI_API_KEY
   ```

2. **Incorrect command syntax**
   - Verify the Codex CLI is installed and check its current docs
   - Command syntax may vary by version

3. **Quota exceeded**
   - Check your usage at [platform.openai.com](https://platform.openai.com/)

---

## Build Issues

### "Build is stuck in a loop"

**Symptoms:** Same error 3+ times, going in circles.

**Fix:**

1. **Call the other agent for fresh perspective:**
   ```bash
   # If using Claude, call Codex
   codex exec --model gpt-5.2-codex --config model_reasoning_effort="xhigh" --yolo \
     "I'm stuck in an error loop. Error: [ERROR]. Tried: [APPROACHES]. What am I missing?"

   # If using Codex, call Claude
   claude -p --model opus --dangerously-skip-permissions --output-format text \
     "I'm stuck. Error: [ERROR]. Tried: [APPROACHES]. Suggest a different approach."
   ```

2. **Log the blocker in CONTEXT.md:**
   ```markdown
   ## Blockers
   - Phase 3: TypeScript error on line 42, can't resolve module path
     - Tried: relative imports, absolute imports, tsconfig paths
     - Moving to Phase 4, will return
   ```

3. **Skip to an unblocked phase, return later**

4. **If truly stuck:** Ask a human

### "Build failing mysteriously"

**Quick fixes:**

```bash
# Clear all caches
rm -rf node_modules .next dist .vite .cache
npm install

# Check for circular imports
npx madge --circular src/

# Rebuild from scratch
npm run build
```

**Check for:**
- Missing peer dependencies
- Stale package-lock.json (try deleting and reinstalling)
- TypeScript version mismatch
- Node.js version mismatch

### "Quality gates failing"

**Typecheck errors:**
```bash
npm run typecheck 2>&1 | head -50
# Read the actual errors
```

**Lint errors:**
```bash
npm run lint -- --fix
# Auto-fix what's possible, manually fix the rest
```

**Build errors:**
```bash
npm run build 2>&1 | tail -100
# Check the end for the actual error
```

**Test failures:**
```bash
npm run test -- --reporter=verbose
# Get detailed output on what failed
```

---

## Context Issues

### "Context feels stale"

**Symptoms:** Claude seems to have forgotten what we were working on, asks questions already answered.

**Fix:**

1. **Re-read CONTEXT.md:**
   ```bash
   cat CONTEXT.md
   ```

2. **Update CONTEXT.md if outdated:**
   Add current state, what you're working on, recent decisions.

3. **Trigger fresh context load:**
   ```bash
   # In Claude Code CLI
   /clear
   ```
   This reloads from auto-handoff if available.

4. **Re-read the protocol:**
   ```bash
   cat AUTONOMOUS_BUILD_CLAUDE_v2.md
   ```

### "Lost track of what phase I'm on"

**Fix:**

```bash
# Check implementation plan
head -30 IMPLEMENTATION_PLAN.md

# Check git history
git log --oneline -10

# Check status
autonomous-status
```

---

## Cross-Agent Issues

### "Reviews disagree"

**Scenario:** Claude approves but Codex finds issues (or vice versa).

**Resolution:**

1. **Address all issues from both agents** — if either finds a problem, fix it
2. **Re-run both reviews** until both approve
3. **If they fundamentally disagree** (rare): prefer the more conservative recommendation

### "Review taking too long"

**Claude reviews:**
- May take 30 seconds to several minutes
- Wait at least 60 seconds before interrupting
- If >5 minutes, check terminal isn't frozen

**Codex reviews:**
- May take up to 30 minutes for complex reviews
- Let it run; do something else
- Only interrupt after 15+ minutes with no output

### "Agent keeps delegating back"

**Symptoms:** Infinite loop of Claude calling Codex calling Claude.

**Fix:** The recursion guard should prevent this, but if it happens:

1. Interrupt the current call (Ctrl+C)
2. Do the requested task directly instead of delegating
3. Log the issue in LEARNINGS.md

---

## Git Issues

### "Can't commit - quality gates failing"

**Fix:** Quality gates must pass before committing.

```bash
quality-gates
# Fix all issues
# Then commit
```

### "Forgot to commit before phase change"

**Fix:**

```bash
# Check what's uncommitted
git status

# If it's phase N work, commit it now
git add -A
git commit -m "feat: complete phase N - [name]"

# Update IMPLEMENTATION_PLAN.md to match
```

### "Made a mess of commits"

**Fix (before push):**

```bash
# Interactive rebase to clean up
git rebase -i HEAD~5  # Adjust number as needed

# Squash, reword, reorder as needed
# Save and exit
```

**Fix (after push):** Generally don't rewrite history on shared branches. Just add cleanup commits.

---

## Session Issues

### "Session ended unexpectedly"

**Recovery:**

1. Check for auto-handoff:
   ```bash
   ls -la ~/.claude/handoffs/
   ls -la thoughts/handoffs/  # If in a project
   ```

2. Read the most recent handoff:
   ```bash
   cat ~/.claude/handoffs/auto-handoff-*.md | tail -100
   ```

3. Resume from CONTEXT.md:
   ```bash
   cat CONTEXT.md
   ```

4. Start new session with context:
   ```bash
   claude "Read CONTEXT.md and continue from where we left off."
   ```

### "How do I know when I'm done?"

**Completion checklist:**

- [ ] All phases in IMPLEMENTATION_PLAN.md marked complete
- [ ] All quality gates pass: `quality-gates`
- [ ] Final cross-check approved by both agents
- [ ] Manual verification shows core flows work
- [ ] All commits pushed
- [ ] PR opened (if feature branch)
- [ ] Learnings captured in LEARNINGS.md

---

## Performance Issues

### "Claude is slow"

**Possible causes:**

1. **Large context window** — Too much code/context being processed
   - Break into smaller tasks
   - Clear history: `/clear`

2. **Complex model** — Using Opus for simple tasks
   - Use Sonnet for simpler operations
   - Reserve Opus for complex reasoning

3. **Network latency**
   - Not much you can do here
   - Be patient

### "Build is slow"

**Possible fixes:**

```bash
# Use faster build tools
npm install -D esbuild  # For faster bundling

# Skip tests during development
quality-gates --skip-tests

# Incremental builds
npm run build -- --incremental  # If supported
```

---

## Getting More Help

### Check the Docs

- [GETTING_STARTED.md](GETTING_STARTED.md) — First project walkthrough
- [WORKFLOW_REFERENCE.md](WORKFLOW_REFERENCE.md) — Complete workflow details

### Check the Templates

```bash
ls templates/
# Read relevant template for guidance
```

### Check Recent Learnings

```bash
cat LEARNINGS.md
cat ~/.claude/learnings/LEARNINGS.md
```

### Ask the Agent

```bash
claude "I'm having trouble with [ISSUE]. What should I try?"
```

### Search for Similar Issues

The methodology is battle-tested. If you're hitting an issue, others probably have too. Check:
- Project issues on GitHub
- Claude Code documentation
- Anthropic Discord/forums

---

## Reporting Bugs

If you find a bug in the kit itself:

1. Check if it's already reported
2. Create a minimal reproduction
3. Open an issue with:
   - What you expected
   - What happened
   - Steps to reproduce
   - Your environment (OS, Node version, Claude Code version)
