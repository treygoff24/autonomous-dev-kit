# Autonomous Loop Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `executing-plans` skill to implement this plan task-by-task.

**Goal:** Implement persistent development loops with safety net and explicit loop mode for autonomous Claude Code sessions.

**Architecture:** Two-layer system: (1) Safety net always-on layer checking git state and optional quality gates, (2) Explicit loop mode with continuation prompts, protocol cheat sheet injection, and verification-based protocol re-reads every 3 iterations. State stored in `~/.claude/autonomous-loop/` keyed by project hash with session tokens.

**Tech Stack:** Bash (hooks), Zsh (shell functions), jq (JSON manipulation), Claude Code hooks API

**Design Doc:** `docs/plans/2025-01-05-autonomous-loop-design.md`

---

## Phase 1: Helper Library Foundation

### Task 1.1: Create lib directory and helper script skeleton

**Files:**
- Create: `lib/loop-helpers.sh`

**Step 1: Create the lib directory**

```bash
mkdir -p lib
```

**Step 2: Create helper script with header**

```bash
#!/usr/bin/env bash
#
# loop-helpers.sh — Shared functions for autonomous loop state management
#
# Source this file in hooks: source "$HOME/.claude/lib/loop-helpers.sh"
#

set -euo pipefail

# Constants
LOOP_STATE_DIR="$HOME/.claude/autonomous-loop"

# Ensure state directory exists
mkdir -p "$LOOP_STATE_DIR"
```

**Step 3: Commit skeleton**

```bash
git add lib/loop-helpers.sh
git commit -m "feat(loop): add helper library skeleton"
```

---

### Task 1.2: Implement get_project_hash function

**Files:**
- Modify: `lib/loop-helpers.sh`
- Create: `tests/test-loop-helpers.sh`

**Step 1: Write the failing test**

Create `tests/test-loop-helpers.sh`:

```bash
#!/usr/bin/env bash
#
# Tests for loop-helpers.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/loop-helpers.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "✓ $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $msg"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
    fi
}

assert_not_empty() {
    local value="$1"
    local msg="${2:-}"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -n "$value" ]]; then
        echo "✓ $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $msg (was empty)"
    fi
}

# --- Tests ---

test_get_project_hash() {
    echo "Testing get_project_hash..."

    # Same path should return same hash
    local hash1=$(get_project_hash "/Users/test/project")
    local hash2=$(get_project_hash "/Users/test/project")
    assert_equals "$hash1" "$hash2" "Same path returns same hash"

    # Different paths should return different hashes
    local hash3=$(get_project_hash "/Users/test/other")
    if [[ "$hash1" != "$hash3" ]]; then
        echo "✓ Different paths return different hashes"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Different paths return different hashes"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # Hash should be 12 characters
    assert_equals "12" "${#hash1}" "Hash is 12 characters"
}

# Run tests
test_get_project_hash

# Summary
echo ""
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
```

**Step 2: Run test to verify it fails**

```bash
chmod +x tests/test-loop-helpers.sh
./tests/test-loop-helpers.sh
```

Expected: FAIL with "get_project_hash: command not found"

**Step 3: Implement get_project_hash**

Add to `lib/loop-helpers.sh`:

```bash
# Get a consistent 12-char hash for a project path
# Usage: get_project_hash "/path/to/project"
get_project_hash() {
    local project_path="$1"
    # Use shasum (macOS) or sha256sum (Linux)
    if command -v shasum &> /dev/null; then
        echo -n "$project_path" | shasum -a 256 | cut -c1-12
    else
        echo -n "$project_path" | sha256sum | cut -c1-12
    fi
}
```

**Step 4: Run test to verify it passes**

```bash
./tests/test-loop-helpers.sh
```

Expected: PASS - "Tests: 3/3 passed"

**Step 5: Commit**

```bash
git add lib/loop-helpers.sh tests/test-loop-helpers.sh
git commit -m "feat(loop): add get_project_hash function with tests"
```

---

### Task 1.3: Implement get_state_file_path function

**Files:**
- Modify: `lib/loop-helpers.sh`
- Modify: `tests/test-loop-helpers.sh`

**Step 1: Add the failing test**

Add to `tests/test-loop-helpers.sh` before "# Run tests":

```bash
test_get_state_file_path() {
    echo "Testing get_state_file_path..."

    local path=$(get_state_file_path "/Users/test/project")

    # Should be in the state directory
    assert_equals "$HOME/.claude/autonomous-loop/" "${path%/*}/" "Path is in state directory"

    # Should end with .json
    [[ "$path" == *.json ]] && {
        echo "✓ Path ends with .json"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    } || {
        echo "✗ Path ends with .json"
    }
    TESTS_RUN=$((TESTS_RUN + 1))

    # Should contain project hash
    local hash=$(get_project_hash "/Users/test/project")
    [[ "$path" == *"$hash"* ]] && {
        echo "✓ Path contains project hash"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    } || {
        echo "✗ Path contains project hash"
    }
    TESTS_RUN=$((TESTS_RUN + 1))
}
```

Update "# Run tests" section:

```bash
# Run tests
test_get_project_hash
test_get_state_file_path
```

**Step 2: Run test to verify it fails**

```bash
./tests/test-loop-helpers.sh
```

Expected: FAIL with "get_state_file_path: command not found"

**Step 3: Implement get_state_file_path**

Add to `lib/loop-helpers.sh`:

```bash
# Get the state file path for a project
# Usage: get_state_file_path "/path/to/project"
get_state_file_path() {
    local project_path="$1"
    local hash=$(get_project_hash "$project_path")
    echo "$LOOP_STATE_DIR/$hash.json"
}
```

**Step 4: Run test to verify it passes**

```bash
./tests/test-loop-helpers.sh
```

Expected: PASS - "Tests: 6/6 passed"

**Step 5: Commit**

```bash
git add lib/loop-helpers.sh tests/test-loop-helpers.sh
git commit -m "feat(loop): add get_state_file_path function"
```

---

### Task 1.4: Implement generate_verification_code function

**Files:**
- Modify: `lib/loop-helpers.sh`
- Modify: `tests/test-loop-helpers.sh`

**Step 1: Add the failing test**

Add to `tests/test-loop-helpers.sh`:

```bash
test_generate_verification_code() {
    echo "Testing generate_verification_code..."

    local code1=$(generate_verification_code)
    local code2=$(generate_verification_code)

    # Should be 4 digits
    assert_equals "4" "${#code1}" "Code is 4 digits"

    # Should be numeric
    if [[ "$code1" =~ ^[0-9]+$ ]]; then
        echo "✓ Code is numeric"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Code is numeric"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # Should be >= 1000 (4 digits)
    if [[ "$code1" -ge 1000 ]]; then
        echo "✓ Code is >= 1000"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Code is >= 1000"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
```

Update "# Run tests":

```bash
# Run tests
test_get_project_hash
test_get_state_file_path
test_generate_verification_code
```

**Step 2: Run test to verify it fails**

```bash
./tests/test-loop-helpers.sh
```

Expected: FAIL

**Step 3: Implement generate_verification_code**

Add to `lib/loop-helpers.sh`:

```bash
# Generate a random 4-digit verification code (OS-agnostic)
generate_verification_code() {
    if command -v shuf &> /dev/null; then
        shuf -i 1000-9999 -n 1
    else
        echo $((RANDOM % 9000 + 1000))
    fi
}
```

**Step 4: Run test to verify it passes**

```bash
./tests/test-loop-helpers.sh
```

Expected: PASS

**Step 5: Commit**

```bash
git add lib/loop-helpers.sh tests/test-loop-helpers.sh
git commit -m "feat(loop): add generate_verification_code function"
```

---

### Task 1.5: Implement generate_session_token function

**Files:**
- Modify: `lib/loop-helpers.sh`
- Modify: `tests/test-loop-helpers.sh`

**Step 1: Add the failing test**

```bash
test_generate_session_token() {
    echo "Testing generate_session_token..."

    local token=$(generate_session_token)

    # Should be 16 characters
    assert_equals "16" "${#token}" "Token is 16 characters"

    # Should be alphanumeric
    if [[ "$token" =~ ^[a-f0-9]+$ ]]; then
        echo "✓ Token is hex"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Token is hex"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
```

Update "# Run tests" to include `test_generate_session_token`.

**Step 2: Run test to verify it fails**

```bash
./tests/test-loop-helpers.sh
```

**Step 3: Implement generate_session_token**

Add to `lib/loop-helpers.sh`:

```bash
# Generate a random session token
generate_session_token() {
    if command -v openssl &> /dev/null; then
        openssl rand -hex 8
    elif [[ -r /dev/urandom ]]; then
        head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 16
    else
        # Fallback: use date + random
        echo "$(date +%s%N)$RANDOM" | shasum -a 256 | cut -c1-16
    fi
}
```

**Step 4: Run test to verify it passes**

```bash
./tests/test-loop-helpers.sh
```

**Step 5: Commit**

```bash
git add lib/loop-helpers.sh tests/test-loop-helpers.sh
git commit -m "feat(loop): add generate_session_token function"
```

---

### Task 1.6: Implement read/write state functions

**Files:**
- Modify: `lib/loop-helpers.sh`
- Modify: `tests/test-loop-helpers.sh`

**Step 1: Add the failing tests**

```bash
test_state_file_operations() {
    echo "Testing state file operations..."

    # Create temp project path
    local test_project="/tmp/test-project-$$"
    local state_file=$(get_state_file_path "$test_project")

    # Clean up any existing state
    rm -f "$state_file"

    # read_state_file should return empty/default for missing file
    local state=$(read_state_file "$test_project")
    assert_equals "" "$state" "Missing file returns empty"

    # write_state_file should create file
    write_state_file "$test_project" '{"active":true,"iteration":1}'

    if [[ -f "$state_file" ]]; then
        echo "✓ State file created"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ State file created"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # read_state_file should return contents
    state=$(read_state_file "$test_project")
    if [[ "$state" == *'"active":true'* ]]; then
        echo "✓ State file contents readable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ State file contents readable"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clean up
    rm -f "$state_file"
}

test_read_malformed_state() {
    echo "Testing malformed state file handling..."

    local test_project="/tmp/test-malformed-$$"
    local state_file=$(get_state_file_path "$test_project")

    # Write malformed JSON
    echo "not valid json" > "$state_file"

    # Should return empty, not crash
    local state=$(read_state_file "$test_project" 2>/dev/null)
    assert_equals "" "$state" "Malformed JSON returns empty"

    # Clean up
    rm -f "$state_file"
}
```

**Step 2: Run test to verify it fails**

**Step 3: Implement read/write functions**

Add to `lib/loop-helpers.sh`:

```bash
# Read state file for a project, returns empty string if missing/invalid
# Usage: state=$(read_state_file "/path/to/project")
read_state_file() {
    local project_path="$1"
    local state_file=$(get_state_file_path "$project_path")

    if [[ ! -f "$state_file" ]]; then
        echo ""
        return 0
    fi

    # Validate JSON before returning
    if jq -e . "$state_file" > /dev/null 2>&1; then
        cat "$state_file"
    else
        echo ""
    fi
}

# Write state to file for a project
# Usage: write_state_file "/path/to/project" '{"active":true}'
write_state_file() {
    local project_path="$1"
    local state="$2"
    local state_file=$(get_state_file_path "$project_path")

    echo "$state" > "$state_file"
}

# Update a single field in state file
# Usage: update_state_field "/path/to/project" ".iteration" "5"
update_state_field() {
    local project_path="$1"
    local field="$2"
    local value="$3"
    local state_file=$(get_state_file_path "$project_path")

    if [[ ! -f "$state_file" ]]; then
        echo "{}" > "$state_file"
    fi

    local tmp_file=$(mktemp)
    jq "$field = $value" "$state_file" > "$tmp_file" && mv "$tmp_file" "$state_file"
}

# Delete state file for a project
# Usage: delete_state_file "/path/to/project"
delete_state_file() {
    local project_path="$1"
    local state_file=$(get_state_file_path "$project_path")
    rm -f "$state_file"
}
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add lib/loop-helpers.sh tests/test-loop-helpers.sh
git commit -m "feat(loop): add state file read/write functions"
```

---

### Task 1.7: Implement is_loop_active function

**Files:**
- Modify: `lib/loop-helpers.sh`
- Modify: `tests/test-loop-helpers.sh`

**Step 1: Add the failing test**

```bash
test_is_loop_active() {
    echo "Testing is_loop_active..."

    local test_project="/tmp/test-active-$$"
    delete_state_file "$test_project"

    # No state file = not active
    if ! is_loop_active "$test_project"; then
        echo "✓ No state file = not active"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ No state file = not active"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # State file with active=false = not active
    write_state_file "$test_project" '{"active":false}'
    if ! is_loop_active "$test_project"; then
        echo "✓ active=false = not active"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ active=false = not active"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # State file with active=true = active
    write_state_file "$test_project" '{"active":true}'
    if is_loop_active "$test_project"; then
        echo "✓ active=true = active"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ active=true = active"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # Clean up
    delete_state_file "$test_project"
}
```

**Step 2: Run test to verify it fails**

**Step 3: Implement is_loop_active**

Add to `lib/loop-helpers.sh`:

```bash
# Check if loop mode is active for a project
# Usage: if is_loop_active "/path/to/project"; then ...
is_loop_active() {
    local project_path="$1"
    local state=$(read_state_file "$project_path")

    if [[ -z "$state" ]]; then
        return 1
    fi

    local active=$(echo "$state" | jq -r '.active // false')
    [[ "$active" == "true" ]]
}
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add lib/loop-helpers.sh tests/test-loop-helpers.sh
git commit -m "feat(loop): add is_loop_active function"
```

---

## Phase 2: Safety Net Layer

### Task 2.1: Create stop.sh hook skeleton

**Files:**
- Create: `hooks/stop.sh`

**Step 1: Create the hook skeleton**

```bash
#!/usr/bin/env bash
#
# Stop Hook: Safety net + autonomous loop continuation
#
# Exit codes:
#   0 = allow exit
#   2 = block exit (inject continuation prompt via stdout)
#

set -euo pipefail

# Source helper library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$HOME/.claude/lib/loop-helpers.sh" ]]; then
    source "$HOME/.claude/lib/loop-helpers.sh"
elif [[ -f "$SCRIPT_DIR/../lib/loop-helpers.sh" ]]; then
    source "$SCRIPT_DIR/../lib/loop-helpers.sh"
fi

# Read input from stdin (Claude Code sends JSON)
INPUT=$(cat)

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Main logic will be added in subsequent tasks
# For now, always allow exit
exit 0
```

**Step 2: Make executable and commit**

```bash
chmod +x hooks/stop.sh
git add hooks/stop.sh
git commit -m "feat(loop): add stop hook skeleton"
```

---

### Task 2.2: Implement git dirty check

**Files:**
- Modify: `hooks/stop.sh`
- Create: `tests/test-stop-hook.sh`

**Step 1: Create test file**

```bash
#!/usr/bin/env bash
#
# Tests for stop.sh hook
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/../hooks/stop.sh"

# Test helper
run_hook() {
    local project_dir="$1"
    CLAUDE_PROJECT_DIR="$project_dir" echo '{}' | "$HOOK_PATH"
    return $?
}

TESTS_RUN=0
TESTS_PASSED=0

# --- Tests ---

test_safety_net_allows_clean_git() {
    echo "Testing safety net allows clean git state..."
    TESTS_RUN=$((TESTS_RUN + 1))

    # Create temp git repo
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # Run hook - should allow exit (code 0)
    if CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$HOOK_PATH"; then
        echo "✓ Clean git state allows exit"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Clean git state allows exit"
    fi

    # Clean up
    rm -rf "$test_dir"
}

test_safety_net_blocks_dirty_git() {
    echo "Testing safety net blocks dirty git state..."
    TESTS_RUN=$((TESTS_RUN + 1))

    # Create temp git repo with uncommitted changes
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"
    echo "modified" > file.txt  # Uncommitted change

    # Run hook - should block exit (code 2)
    if ! CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$HOOK_PATH"; then
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            echo "✓ Dirty git state blocks exit with code 2"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ Expected exit code 2, got $exit_code"
        fi
    else
        echo "✗ Dirty git state should block exit"
    fi

    # Clean up
    rm -rf "$test_dir"
}

# Run tests
test_safety_net_allows_clean_git
test_safety_net_blocks_dirty_git

# Summary
echo ""
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
```

**Step 2: Run test to verify it fails**

```bash
chmod +x tests/test-stop-hook.sh
./tests/test-stop-hook.sh
```

Expected: Second test fails (hook currently always exits 0)

**Step 3: Implement git dirty check**

Update `hooks/stop.sh`:

```bash
#!/usr/bin/env bash
#
# Stop Hook: Safety net + autonomous loop continuation
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$HOME/.claude/lib/loop-helpers.sh" ]]; then
    source "$HOME/.claude/lib/loop-helpers.sh"
elif [[ -f "$SCRIPT_DIR/../lib/loop-helpers.sh" ]]; then
    source "$SCRIPT_DIR/../lib/loop-helpers.sh"
fi

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# --- Safety Net: Git State Check ---

check_git_clean() {
    if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
        # Not a git repo, skip check
        return 0
    fi

    # Check for uncommitted changes
    if [[ -n "$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)" ]]; then
        return 1
    fi

    return 0
}

# --- Main Logic ---

# Safety net check
if ! check_git_clean; then
    cat << 'EOF'
## Exit Blocked: Uncommitted Changes

You have uncommitted changes in your working directory.
Either commit your changes or use Ctrl+C to force quit.

To see changes: `git status`
To commit: `git add . && git commit -m "your message"`
EOF
    exit 2
fi

# All checks passed
exit 0
```

**Step 4: Run test to verify it passes**

```bash
./tests/test-stop-hook.sh
```

**Step 5: Commit**

```bash
git add hooks/stop.sh tests/test-stop-hook.sh
git commit -m "feat(loop): add git dirty check to safety net"
```

---

### Task 2.3: Implement quality gates check

**Files:**
- Modify: `hooks/stop.sh`
- Modify: `tests/test-stop-hook.sh`
- Create: `templates/.claude-quality-gates.example`

**Step 1: Create example quality gates file**

```bash
# .claude-quality-gates - opt-in to automatic quality gate checks
# Each line is a command to run. All must pass (exit 0) for exit to be allowed.
# Comment lines starting with # are ignored.

npm run typecheck
npm run lint
npm run build
npm run test
```

**Step 2: Add tests**

Add to `tests/test-stop-hook.sh`:

```bash
test_safety_net_skips_quality_gates_if_missing() {
    echo "Testing safety net skips quality gates if file missing..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(mktemp -d)
    cd "$test_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # No .claude-quality-gates file - should allow exit
    if CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$HOOK_PATH"; then
        echo "✓ No quality gates file = skip checks"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ No quality gates file = skip checks"
    fi

    rm -rf "$test_dir"
}

test_safety_net_runs_quality_gates_if_present() {
    echo "Testing safety net runs quality gates if file present..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(mktemp -d)
    cd "$test_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # Create quality gates file with failing command
    echo "exit 1  # Always fail" > .claude-quality-gates

    # Should block exit
    if ! CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$HOOK_PATH"; then
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            echo "✓ Quality gates failure blocks exit"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ Expected exit code 2, got $exit_code"
        fi
    else
        echo "✗ Quality gates failure should block exit"
    fi

    rm -rf "$test_dir"
}
```

**Step 3: Implement quality gates check**

Add to `hooks/stop.sh` before "# --- Main Logic ---":

```bash
# --- Safety Net: Quality Gates Check ---

check_quality_gates() {
    local gates_file="$PROJECT_DIR/.claude-quality-gates"

    if [[ ! -f "$gates_file" ]]; then
        # No quality gates file, skip checks
        return 0
    fi

    local failed_gates=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Run the command
        if ! (cd "$PROJECT_DIR" && eval "$line") > /dev/null 2>&1; then
            failed_gates+=("$line")
        fi
    done < "$gates_file"

    if [[ ${#failed_gates[@]} -gt 0 ]]; then
        FAILED_QUALITY_GATES=("${failed_gates[@]}")
        return 1
    fi

    return 0
}

FAILED_QUALITY_GATES=()
```

Update main logic:

```bash
# --- Main Logic ---

BLOCKERS=()

# Safety net: git check
if ! check_git_clean; then
    BLOCKERS+=("Uncommitted changes in git")
fi

# Safety net: quality gates
if ! check_quality_gates; then
    for gate in "${FAILED_QUALITY_GATES[@]}"; do
        BLOCKERS+=("Quality gate failed: $gate")
    done
fi

# If blockers, output message and block
if [[ ${#BLOCKERS[@]} -gt 0 ]]; then
    echo "## Exit Blocked: Safety Net"
    echo ""
    echo "The following issues must be resolved:"
    for blocker in "${BLOCKERS[@]}"; do
        echo "- $blocker"
    done
    echo ""
    echo "Fix the issues above or use Ctrl+C to force quit."
    exit 2
fi

exit 0
```

**Step 4: Run tests to verify**

```bash
./tests/test-stop-hook.sh
```

**Step 5: Commit**

```bash
git add hooks/stop.sh tests/test-stop-hook.sh templates/.claude-quality-gates.example
git commit -m "feat(loop): add quality gates check to safety net"
```

---

## Phase 3: Loop Mode Core

### Task 3.1: Implement loop state initialization

**Files:**
- Modify: `lib/loop-helpers.sh`
- Modify: `tests/test-loop-helpers.sh`

**Step 1: Add test**

```bash
test_initialize_loop_state() {
    echo "Testing initialize_loop_state..."

    local test_project="/tmp/test-init-$$"
    delete_state_file "$test_project"

    initialize_loop_state "$test_project" "Test goal" 100

    local state=$(read_state_file "$test_project")

    # Check all required fields
    local active=$(echo "$state" | jq -r '.active')
    assert_equals "true" "$active" "active is true"

    local goal=$(echo "$state" | jq -r '.goal')
    assert_equals "Test goal" "$goal" "goal is set"

    local max=$(echo "$state" | jq -r '.max_iterations')
    assert_equals "100" "$max" "max_iterations is set"

    local iteration=$(echo "$state" | jq -r '.iteration')
    assert_equals "0" "$iteration" "iteration starts at 0"

    local token=$(echo "$state" | jq -r '.session_token')
    assert_not_empty "$token" "session_token is set"

    delete_state_file "$test_project"
}
```

**Step 2: Run test to verify it fails**

**Step 3: Implement initialize_loop_state**

Add to `lib/loop-helpers.sh`:

```bash
# Initialize a new loop state for a project
# Usage: initialize_loop_state "/path/to/project" "goal description" max_iterations
initialize_loop_state() {
    local project_path="$1"
    local goal="$2"
    local max_iterations="${3:-100}"

    local session_token=$(generate_session_token)
    local verification_code=$(generate_verification_code)
    local started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local state=$(jq -n \
        --arg active "true" \
        --arg token "$session_token" \
        --arg path "$project_path" \
        --arg goal "$goal" \
        --arg started "$started_at" \
        --argjson iter 0 \
        --argjson max "$max_iterations" \
        --argjson last_reread 0 \
        --arg paused "false" \
        --arg awaiting "false" \
        --arg code "$verification_code" \
        '{
            active: ($active == "true"),
            session_token: $token,
            project_path: $path,
            goal: $goal,
            started_at: $started,
            iteration: $iter,
            max_iterations: $max,
            last_protocol_reread: $last_reread,
            paused: ($paused == "true"),
            awaiting_verification: ($awaiting == "true"),
            verification_response: null,
            expected_verification_code: $code
        }')

    write_state_file "$project_path" "$state"
}
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add lib/loop-helpers.sh tests/test-loop-helpers.sh
git commit -m "feat(loop): add initialize_loop_state function"
```

---

### Task 3.2: Add loop mode detection to stop hook

**Files:**
- Modify: `hooks/stop.sh`
- Modify: `tests/test-stop-hook.sh`

**Step 1: Add test**

```bash
test_loop_mode_blocks_when_incomplete() {
    echo "Testing loop mode blocks when work incomplete..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(mktemp -d)
    cd "$test_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # Initialize loop state
    source "$SCRIPT_DIR/../lib/loop-helpers.sh"
    initialize_loop_state "$test_dir" "Test goal" 100

    # Run hook - should block (loop active, work not complete)
    if ! CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$HOOK_PATH" > /dev/null 2>&1; then
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            echo "✓ Loop mode blocks incomplete work"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "✗ Expected exit code 2, got $exit_code"
        fi
    else
        echo "✗ Loop mode should block incomplete work"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}
```

**Step 2: Run test to verify it fails**

**Step 3: Implement loop mode detection**

Add to `hooks/stop.sh` after safety net checks:

```bash
# --- Loop Mode Check ---

if is_loop_active "$PROJECT_DIR"; then
    # Read state
    STATE=$(read_state_file "$PROJECT_DIR")
    ITERATION=$(echo "$STATE" | jq -r '.iteration')
    MAX_ITERATIONS=$(echo "$STATE" | jq -r '.max_iterations')
    GOAL=$(echo "$STATE" | jq -r '.goal')
    PAUSED=$(echo "$STATE" | jq -r '.paused')

    # If paused, allow exit
    if [[ "$PAUSED" == "true" ]]; then
        exit 0
    fi

    # Check completion criteria (for now: just git clean + no quality gate failures)
    # Full completion check will be added in later task

    # Increment iteration
    NEW_ITERATION=$((ITERATION + 1))
    update_state_field "$PROJECT_DIR" ".iteration" "$NEW_ITERATION"

    # Check max iterations
    if [[ $NEW_ITERATION -ge $MAX_ITERATIONS ]]; then
        update_state_field "$PROJECT_DIR" ".paused" "true"
        echo "## Max Iterations Reached"
        echo ""
        echo "Completed $NEW_ITERATION iterations on: $GOAL"
        echo ""
        echo "Options:"
        echo "- Continue working: say 'resume autonomous mode' or 'continue'"
        echo "- Adjust direction: provide feedback and then resume"
        echo "- Stop: say 'stop autonomous mode'"
        exit 2
    fi

    # Work not complete, block exit and continue
    echo "## Autonomous Loop Continuing"
    echo ""
    echo "**Iteration:** $NEW_ITERATION/$MAX_ITERATIONS"
    echo "**Goal:** $GOAL"
    echo ""
    echo "Continue working toward completion."
    exit 2
fi
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add hooks/stop.sh tests/test-stop-hook.sh
git commit -m "feat(loop): add loop mode detection to stop hook"
```

---

### Task 3.3: Implement completion criteria check

**Files:**
- Modify: `hooks/stop.sh`
- Modify: `tests/test-stop-hook.sh`

**Step 1: Add test**

```bash
test_loop_mode_allows_when_complete() {
    echo "Testing loop mode allows exit when complete..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(mktemp -d)
    cd "$test_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create IMPLEMENTATION_PLAN.md with all phases complete
    cat > IMPLEMENTATION_PLAN.md << 'PLAN'
# Implementation Plan

## Phase 1: Setup
- [x] Task 1
- [x] Task 2

## Phase 2: Build
- [x] Task 3
- [x] Task 4

**Status: COMPLETE**
PLAN

    git add .
    git commit -q -m "initial"

    # Initialize loop state
    source "$SCRIPT_DIR/../lib/loop-helpers.sh"
    initialize_loop_state "$test_dir" "Test goal" 100

    # Run hook - should allow exit (work complete)
    if CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$HOOK_PATH" > /dev/null 2>&1; then
        echo "✓ Loop mode allows exit when complete"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Loop mode should allow exit when complete"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}
```

**Step 2: Run test to verify it fails**

**Step 3: Implement completion check**

Add function before loop mode check in `hooks/stop.sh`:

```bash
# Check if implementation plan shows completion
check_plan_complete() {
    local plan_file="$PROJECT_DIR/IMPLEMENTATION_PLAN.md"

    if [[ ! -f "$plan_file" ]]; then
        # No plan file = assume complete (for non-plan projects)
        return 0
    fi

    # Check for incomplete tasks (unchecked boxes)
    if grep -q '\- \[ \]' "$plan_file"; then
        return 1
    fi

    # Check for "COMPLETE" status marker
    if grep -qi 'status.*complete\|complete.*status' "$plan_file"; then
        return 0
    fi

    # If has checkboxes and all checked, consider complete
    if grep -q '\- \[x\]' "$plan_file"; then
        return 0
    fi

    return 1
}

# Check all completion criteria
check_completion() {
    # Must have clean git
    if ! check_git_clean; then
        return 1
    fi

    # Must pass quality gates (if file exists)
    if ! check_quality_gates; then
        return 1
    fi

    # Must have plan complete (if file exists)
    if ! check_plan_complete; then
        return 1
    fi

    return 0
}
```

Update loop mode check to use completion:

```bash
if is_loop_active "$PROJECT_DIR"; then
    STATE=$(read_state_file "$PROJECT_DIR")
    # ... existing code ...

    # Check if work is complete
    if check_completion; then
        # Clear loop state and allow exit
        delete_state_file "$PROJECT_DIR"
        echo "## Build Complete!"
        echo ""
        echo "All completion criteria met. Loop state cleared."
        exit 0
    fi

    # ... rest of existing code ...
fi
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add hooks/stop.sh tests/test-stop-hook.sh
git commit -m "feat(loop): add completion criteria check"
```

---

## Phase 4: Continuation Prompts

### Task 4.1: Create cheatsheet file

**Files:**
- Create: `lib/cheatsheet.md`

**Step 1: Create the cheatsheet**

```bash
cat > lib/cheatsheet.md << 'CHEATSHEET'
## AUTONOMOUS BUILD MODE ACTIVE

You are in an autonomous build session. This cheat sheet summarizes
AUTONOMOUS_BUILD_CLAUDE.md — re-read the full protocol if anything is unclear.

DO NOT STOP until completion criteria are met. Execute with precision.

---

**Implementation Loop (every phase):**
IMPLEMENT → TYPECHECK → LINT → BUILD → TEST → REVIEW → SLOP REMOVAL → COMMIT

**Codex = External AI Reviewer:**
Codex is OpenAI's coding model. Call it for external review at checkpoints.
May take up to 30 min to respond. Wait for the full response.

Mandatory checkpoints:
- After drafting spec
- After drafting implementation plan
- After completing each phase
- Before declaring build complete
- When stuck 3+ times on same error

Syntax:
codex exec --model gpt-5.2-codex --config model_reasoning_effort="xhigh" --yolo "<PROMPT>"

**Subagents (spawn via Task tool):**
- code-reviewer → after each phase (before Codex)
- bug-hunter → first step when hitting errors
- Explore → understand unfamiliar code
- security-auditor → auth, inputs, sensitive changes
- accessibility-auditor → UI changes
- test-architect → comprehensive test coverage

**Skills:**
- Stuck in error loop → systematic-debugging
- Writing tests → test-driven-development (red-green-refactor)
- Before claiming done → verification-before-completion
- UI work → frontend-design + accessibility-checklist

**Context Hygiene:**
- Update CONTEXT.md 2x per phase minimum
- Update IMPLEMENTATION_PLAN.md after each phase

**Completion Criteria:**
All phases complete + all quality gates pass + Codex final verdict "ship it"
CHEATSHEET
```

**Step 2: Commit**

```bash
git add lib/cheatsheet.md
git commit -m "feat(loop): add protocol cheatsheet"
```

---

### Task 4.2: Inject cheatsheet in continuation prompt

**Files:**
- Modify: `hooks/stop.sh`
- Modify: `tests/test-stop-hook.sh`

**Step 1: Add test**

```bash
test_cheatsheet_injected() {
    echo "Testing cheatsheet is injected in continuation..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(mktemp -d)
    cd "$test_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"
    echo "uncommitted" > dirty.txt  # Make it dirty so we block

    source "$SCRIPT_DIR/../lib/loop-helpers.sh"
    initialize_loop_state "$test_dir" "Test goal" 100

    # Capture output
    local output=$(CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$HOOK_PATH" 2>&1 || true)

    if [[ "$output" == *"AUTONOMOUS BUILD MODE ACTIVE"* ]]; then
        echo "✓ Cheatsheet header present"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Cheatsheet header present"
        echo "Output was: $output"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}
```

**Step 2: Run test to verify it fails**

**Step 3: Implement cheatsheet injection**

Add function to `hooks/stop.sh`:

```bash
# Get cheatsheet content
get_cheatsheet() {
    local cheatsheet_path="$HOME/.claude/lib/cheatsheet.md"
    if [[ -f "$cheatsheet_path" ]]; then
        cat "$cheatsheet_path"
    elif [[ -f "$SCRIPT_DIR/../lib/cheatsheet.md" ]]; then
        cat "$SCRIPT_DIR/../lib/cheatsheet.md"
    fi
}

# Build continuation prompt
build_continuation_prompt() {
    local iteration="$1"
    local max_iterations="$2"
    local goal="$3"
    local elapsed="$4"

    # Start with cheatsheet
    get_cheatsheet

    echo ""
    echo "---"
    echo "## Loop Status"
    echo "Iteration: $iteration/$max_iterations | Elapsed: $elapsed"
    echo "Goal: $goal"
    echo ""

    # Add blockers if any
    if [[ ${#BLOCKERS[@]} -gt 0 ]]; then
        echo "Exit blocked because:"
        for blocker in "${BLOCKERS[@]}"; do
            echo "- $blocker"
        done
        echo ""
    fi

    echo "Continue working. Re-read CONTEXT.md for current state."
}

# Calculate elapsed time
get_elapsed_time() {
    local started_at="$1"
    local now=$(date +%s)
    local started=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s 2>/dev/null || date -d "$started_at" +%s 2>/dev/null || echo "$now")
    local elapsed=$((now - started))

    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))

    echo "${hours}h ${minutes}m"
}
```

Update loop mode continuation output:

```bash
# Work not complete, block exit and continue
STARTED_AT=$(echo "$STATE" | jq -r '.started_at')
ELAPSED=$(get_elapsed_time "$STARTED_AT")
build_continuation_prompt "$NEW_ITERATION" "$MAX_ITERATIONS" "$GOAL" "$ELAPSED"
exit 2
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add hooks/stop.sh tests/test-stop-hook.sh
git commit -m "feat(loop): inject cheatsheet in continuation prompt"
```

---

## Phase 5: Protocol Verification

### Task 5.1: Implement verification check

**Files:**
- Modify: `hooks/stop.sh`
- Modify: `tests/test-stop-hook.sh`

**Step 1: Add test**

```bash
test_verification_required_every_3() {
    echo "Testing verification required every 3 iterations..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(mktemp -d)
    cd "$test_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"

    source "$SCRIPT_DIR/../lib/loop-helpers.sh"
    initialize_loop_state "$test_dir" "Test goal" 100

    # Set iteration to 2 (next will be 3, triggering verification)
    update_state_field "$test_dir" ".iteration" "2"

    local output=$(CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$HOOK_PATH" 2>&1 || true)

    if [[ "$output" == *"Protocol Re-Read Required"* ]]; then
        echo "✓ Verification triggered at iteration 3"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Verification triggered at iteration 3"
    fi

    delete_state_file "$test_dir"
    rm -rf "$test_dir"
}
```

**Step 2: Run test to verify it fails**

**Step 3: Implement verification check**

Add to loop mode section in `hooks/stop.sh`:

```bash
# Check if verification is required (every 3 iterations)
AWAITING_VERIFICATION=$(echo "$STATE" | jq -r '.awaiting_verification')
LAST_REREAD=$(echo "$STATE" | jq -r '.last_protocol_reread')

if [[ "$AWAITING_VERIFICATION" == "true" ]]; then
    # Check if verification response provided
    VERIFICATION_RESPONSE=$(echo "$STATE" | jq -r '.verification_response // ""')
    EXPECTED_CODE=$(echo "$STATE" | jq -r '.expected_verification_code')

    if [[ "$VERIFICATION_RESPONSE" == "$EXPECTED_CODE" ]]; then
        # Verification passed! Generate new code and continue
        NEW_CODE=$(generate_verification_code)
        update_state_field "$PROJECT_DIR" ".expected_verification_code" "\"$NEW_CODE\""
        update_state_field "$PROJECT_DIR" ".verification_response" "null"
        update_state_field "$PROJECT_DIR" ".awaiting_verification" "false"
        update_state_field "$PROJECT_DIR" ".last_protocol_reread" "$NEW_ITERATION"
    else
        # Still awaiting verification
        STATE_FILE=$(get_state_file_path "$PROJECT_DIR")
        cat << EOF
## Protocol Re-Read Required (Iteration $NEW_ITERATION)

Full protocol re-read required before continuing.

1. Read AUTONOMOUS_BUILD_CLAUDE.md completely (from start to end)
2. After reading, check $STATE_FILE for expected_verification_code
3. Update the same file's verification_response field with that code
4. Resume work

You cannot proceed until verification is complete.
EOF
        exit 2
    fi
fi

# Check if it's time for verification (every 3 iterations from last reread)
if [[ $((NEW_ITERATION - LAST_REREAD)) -ge 3 ]]; then
    # Trigger verification
    NEW_CODE=$(generate_verification_code)
    update_state_field "$PROJECT_DIR" ".expected_verification_code" "\"$NEW_CODE\""
    update_state_field "$PROJECT_DIR" ".awaiting_verification" "true"

    STATE_FILE=$(get_state_file_path "$PROJECT_DIR")
    cat << EOF
## Protocol Re-Read Required (Iteration $NEW_ITERATION)

Full protocol re-read required before continuing.

1. Read AUTONOMOUS_BUILD_CLAUDE.md completely (from start to end)
2. After reading, check $STATE_FILE for expected_verification_code
3. Update the same file's verification_response field with that code
4. Resume work

You cannot proceed until verification is complete.
EOF
    exit 2
fi
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add hooks/stop.sh tests/test-stop-hook.sh
git commit -m "feat(loop): add protocol verification every 3 iterations"
```

---

## Phase 6: Activation Skill

### Task 6.1: Create autonomous-loop skill

**Files:**
- Create: `skills/autonomous-loop.md`

**Step 1: Create the skill file**

```bash
mkdir -p skills
cat > skills/autonomous-loop.md << 'SKILL'
---
name: autonomous-loop
description: Activate autonomous loop mode for persistent development sessions
---

# Autonomous Loop Activation

This skill activates autonomous loop mode, which keeps Claude working toward a goal until completion criteria are met.

## Usage

**Fire and Forget (explicit goal):**
```
/autonomous-loop "Build comprehensive Playwright tests for the auth flow"
```

**Interactive Activation (after brainstorming):**
User says: "Go autonomous" or "Start autonomous mode"
Claude: Generates goal from current context, confirms, activates

## Activation Steps

1. **Determine goal:**
   - If explicit goal provided in command, use it
   - Otherwise, generate goal from CONTEXT.md, SPEC.md, or recent conversation
   - Confirm goal with user if unclear

2. **Initialize loop state:**
   - Call `initialize_loop_state` with project path, goal, max_iterations
   - Default max_iterations: 100

3. **Confirm activation:**
   ```
   Autonomous loop activated:
   - Goal: [goal]
   - Max iterations: 100
   - State file: ~/.claude/autonomous-loop/[hash].json

   I'll keep working until all completion criteria are met:
   - All quality gates pass (if .claude-quality-gates exists)
   - All phases in IMPLEMENTATION_PLAN.md complete
   - Clean git state

   To pause: press Escape and say "stop autonomous mode"
   To force quit: Ctrl+C
   ```

4. **Begin working:**
   - If IMPLEMENTATION_PLAN.md exists, start from current phase
   - Otherwise, start with the goal directly

## Deactivation

User says any of:
- "Stop autonomous mode"
- "Pause the loop"
- "Exit autonomous mode"

Claude should:
1. Delete the state file: `rm ~/.claude/autonomous-loop/[hash].json`
2. Confirm: "Autonomous loop stopped. State cleared."

## Max Iterations Reached

When max iterations hit, the loop pauses automatically. User can:
- Say "continue" or "resume" to add 50 more iterations
- Provide feedback and then resume
- Say "stop" to end the loop
SKILL
```

**Step 2: Commit**

```bash
git add skills/autonomous-loop.md
git commit -m "feat(loop): add autonomous-loop skill definition"
```

---

## Phase 7: Installation Integration

### Task 7.1: Update install.sh

**Files:**
- Modify: `install.sh`

**Step 1: Add lib directory creation**

Find the `setup_claude_directory` function and add:

```bash
run mkdir -p "$claude_dir/lib"
run mkdir -p "$claude_dir/autonomous-loop"
```

**Step 2: Add file installations**

Add to file copy section:

```bash
# Install lib files
install_file_with_prompt "$SCRIPT_DIR/lib/loop-helpers.sh" "$claude_dir/lib/loop-helpers.sh" "loop helpers"
install_file_with_prompt "$SCRIPT_DIR/lib/cheatsheet.md" "$claude_dir/lib/cheatsheet.md" "protocol cheatsheet"

# Install stop hook
install_file_with_prompt "$SCRIPT_DIR/hooks/stop.sh" "$claude_dir/hooks/stop.sh" "stop hook"

# Make hooks executable
if [ -f "$claude_dir/hooks/stop.sh" ]; then
    run chmod +x "$claude_dir/hooks/stop.sh"
fi
```

**Step 3: Add Stop hook to settings.json configuration**

Update `configure_hooks_full` and `configure_hooks_additive` functions to include Stop hook:

```bash
local hook_path_stop="$HOME/.claude/hooks/stop.sh"

# In the jq command, add:
.hooks.Stop = [{"matcher": "", "hooks": [{"type": "command", "command": $stop}]}]
```

**Step 4: Commit**

```bash
git add install.sh
git commit -m "feat(loop): integrate autonomous loop into installer"
```

---

## Phase 8: Final Integration Tests

### Task 8.1: Create integration test suite

**Files:**
- Create: `tests/test-integration.sh`

**Step 1: Create comprehensive integration tests**

```bash
#!/usr/bin/env bash
#
# Integration tests for autonomous loop system
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/loop-helpers.sh"

TESTS_RUN=0
TESTS_PASSED=0

# Helper to create test repo
create_test_repo() {
    local dir=$(mktemp -d)
    cd "$dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"
    echo "$dir"
}

test_full_loop_cycle() {
    echo "Testing full loop cycle..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local test_dir=$(create_test_repo)

    # Create implementation plan
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [ ] Task 1
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "add plan"

    # Initialize loop
    initialize_loop_state "$test_dir" "Complete the test plan" 10

    # Run hook - should block (task incomplete)
    if ! CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$SCRIPT_DIR/../hooks/stop.sh" > /dev/null 2>&1; then
        echo "  Step 1: Loop blocks incomplete work ✓"
    else
        echo "  Step 1: Loop should block ✗"
        delete_state_file "$test_dir"
        rm -rf "$test_dir"
        return
    fi

    # Mark task complete
    cat > "$test_dir/IMPLEMENTATION_PLAN.md" << 'PLAN'
# Test Plan
- [x] Task 1
**Status: COMPLETE**
PLAN
    git -C "$test_dir" add .
    git -C "$test_dir" commit -q -m "complete plan"

    # Run hook - should allow exit
    if CLAUDE_PROJECT_DIR="$test_dir" echo '{}' | "$SCRIPT_DIR/../hooks/stop.sh" > /dev/null 2>&1; then
        echo "  Step 2: Loop allows exit when complete ✓"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  Step 2: Loop should allow exit ✗"
    fi

    rm -rf "$test_dir"
}

test_hook_chain_integration() {
    echo "Testing hook chain integration..."
    TESTS_RUN=$((TESTS_RUN + 1))

    # Verify all hooks exist and are executable
    local hooks_ok=true
    for hook in pre-compact.sh session-start.sh stop.sh; do
        if [[ ! -x "$SCRIPT_DIR/../hooks/$hook" ]]; then
            echo "  Missing or not executable: $hook"
            hooks_ok=false
        fi
    done

    if $hooks_ok; then
        echo "✓ All hooks present and executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Hook chain incomplete"
    fi
}

# Run tests
test_full_loop_cycle
test_hook_chain_integration

# Summary
echo ""
echo "Integration Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
```

**Step 2: Run integration tests**

```bash
chmod +x tests/test-integration.sh
./tests/test-integration.sh
```

**Step 3: Commit**

```bash
git add tests/test-integration.sh
git commit -m "test(loop): add integration test suite"
```

---

### Task 8.2: Run all tests and verify

**Step 1: Run all test suites**

```bash
./tests/test-loop-helpers.sh && \
./tests/test-stop-hook.sh && \
./tests/test-integration.sh
```

**Step 2: Fix any failures**

If any tests fail, fix the issues and re-run.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(loop): complete autonomous loop implementation

- Safety net layer: blocks exit on dirty git, failing quality gates
- Explicit loop mode: continuation prompts with cheatsheet injection
- Protocol verification: every 3 iterations with code verification
- Activation skill: /autonomous-loop command
- Comprehensive test coverage

Closes: autonomous loop design doc"
```

---

## Completion Checklist

- [ ] All unit tests pass (`test-loop-helpers.sh`)
- [ ] All hook tests pass (`test-stop-hook.sh`)
- [ ] All integration tests pass (`test-integration.sh`)
- [ ] `install.sh` updated with new files
- [ ] Skills file created
- [ ] Cheatsheet created
- [ ] Design doc implementation phases all addressed

---

**Plan complete and saved to `docs/plans/2025-01-05-autonomous-loop-implementation.md`.**

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
