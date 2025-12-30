# autonomous-dev-kit shell functions
# Source this file in your .zshrc or .bashrc

# =============================================================================
# Autonomous Development Functions
# =============================================================================

# Initialize a project for autonomous builds
autonomous-init() {
    local help_text="
Usage: autonomous-init [OPTIONS]

Initialize the current directory for autonomous AI-assisted development.

Creates:
  - CONTEXT.md — session state preservation
  - CLAUDE.md — project instructions for Claude
  - LEARNINGS.md — capturing insights across sessions
  - AUTONOMOUS_BUILD_CLAUDE.md — protocol for Claude Code
  - AUTONOMOUS_BUILD_CODEX.md — protocol for Codex
  - SPEC_WRITING.md — guide for writing specs
  - IMPLEMENTATION_PLAN_WRITING.md — guide for writing plans
  - SPEC_QUALITY_CHECKLIST.md — spec review checklist
  - ACCESSIBILITY_CHECKLIST.md — a11y review checklist
  - .claude/ directory for project-specific config

Options:
  --help    Show this help message

Example:
  mkdir my-project && cd my-project
  autonomous-init
"

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "$help_text"
        return 0
    fi

    local core_path="/usr/bin:/bin:/usr/sbin:/sbin"
    if ! command -v cp >/dev/null 2>&1 || ! command -v mkdir >/dev/null 2>&1; then
        PATH="${core_path}:${PATH:-}"
    fi

    # Find the autonomous-dev-kit templates directory
    local kit_dir=""
    local possible_paths=(
        "$HOME/.claude/autonomous-dev-kit/templates"
        "$HOME/Code/autonomous-dev-kit/templates"
        "$HOME/autonomous-dev-kit/templates"
    )

    for _p in "${possible_paths[@]}"; do
        if [[ -d "$_p" ]]; then
            kit_dir="$_p"
            break
        fi
    done

    if [[ -z "$kit_dir" ]]; then
        echo "Error: Could not find autonomous-dev-kit templates directory."
        echo "Searched in:"
        for _p in "${possible_paths[@]}"; do
            echo "  - $_p"
        done
        return 1
    fi

    echo "Initializing autonomous build environment..."

    # Create CONTEXT.md
    if [[ -f "CONTEXT.md" ]]; then
        echo "  CONTEXT.md already exists, skipping"
    else
        if [[ -f "$kit_dir/CONTEXT_TEMPLATE.md" ]]; then
            if cp "$kit_dir/CONTEXT_TEMPLATE.md" CONTEXT.md; then
                echo "  Created CONTEXT.md"
            else
                echo "  Warning: failed to create CONTEXT.md"
            fi
        else
            echo "  Warning: CONTEXT_TEMPLATE.md not found in $kit_dir"
        fi
    fi

    # Create .claude directory
    if [[ ! -d ".claude" ]]; then
        if mkdir -p .claude; then
            echo "  Created .claude/ directory"
        else
            echo "  Warning: failed to create .claude/ directory"
        fi
    else
        echo "  .claude/ already exists, skipping"
    fi

    # Copy project CLAUDE.md
    if [[ -f "CLAUDE.md" ]]; then
        echo "  CLAUDE.md already exists, skipping"
    else
        if [[ -f "$kit_dir/CLAUDE.md" ]]; then
            if cp "$kit_dir/CLAUDE.md" CLAUDE.md; then
                echo "  Created CLAUDE.md"
            else
                echo "  Warning: failed to create CLAUDE.md"
            fi
        fi
    fi

    # Create LEARNINGS.md
    if [[ -f "LEARNINGS.md" ]]; then
        echo "  LEARNINGS.md already exists, skipping"
    else
        if [[ -f "$kit_dir/LEARNINGS.md" ]]; then
            if cp "$kit_dir/LEARNINGS.md" LEARNINGS.md; then
                echo "  Created LEARNINGS.md"
            else
                echo "  Warning: failed to create LEARNINGS.md"
            fi
        fi
    fi

    # Copy autonomous build protocols
    if [[ -f "AUTONOMOUS_BUILD_CLAUDE.md" ]]; then
        echo "  AUTONOMOUS_BUILD_CLAUDE.md already exists, skipping"
    else
        if [[ -f "$kit_dir/AUTONOMOUS_BUILD_CLAUDE_v2.md" ]]; then
            if cp "$kit_dir/AUTONOMOUS_BUILD_CLAUDE_v2.md" AUTONOMOUS_BUILD_CLAUDE.md; then
                echo "  Created AUTONOMOUS_BUILD_CLAUDE.md"
            else
                echo "  Warning: failed to create AUTONOMOUS_BUILD_CLAUDE.md"
            fi
        fi
    fi

    if [[ -f "AUTONOMOUS_BUILD_CODEX.md" ]]; then
        echo "  AUTONOMOUS_BUILD_CODEX.md already exists, skipping"
    else
        if [[ -f "$kit_dir/AUTONOMOUS_BUILD_CODEX_v2.md" ]]; then
            if cp "$kit_dir/AUTONOMOUS_BUILD_CODEX_v2.md" AUTONOMOUS_BUILD_CODEX.md; then
                echo "  Created AUTONOMOUS_BUILD_CODEX.md"
            else
                echo "  Warning: failed to create AUTONOMOUS_BUILD_CODEX.md"
            fi
        fi
    fi

    # Copy writing guides
    if [[ -f "SPEC_WRITING.md" ]]; then
        echo "  SPEC_WRITING.md already exists, skipping"
    else
        if [[ -f "$kit_dir/SPEC_WRITING.md" ]]; then
            if cp "$kit_dir/SPEC_WRITING.md" SPEC_WRITING.md; then
                echo "  Created SPEC_WRITING.md"
            else
                echo "  Warning: failed to create SPEC_WRITING.md"
            fi
        fi
    fi

    if [[ -f "IMPLEMENTATION_PLAN_WRITING.md" ]]; then
        echo "  IMPLEMENTATION_PLAN_WRITING.md already exists, skipping"
    else
        if [[ -f "$kit_dir/IMPLEMENTATION_PLAN_WRITING.md" ]]; then
            if cp "$kit_dir/IMPLEMENTATION_PLAN_WRITING.md" IMPLEMENTATION_PLAN_WRITING.md; then
                echo "  Created IMPLEMENTATION_PLAN_WRITING.md"
            else
                echo "  Warning: failed to create IMPLEMENTATION_PLAN_WRITING.md"
            fi
        fi
    fi

    # Copy checklists
    if [[ -f "SPEC_QUALITY_CHECKLIST.md" ]]; then
        echo "  SPEC_QUALITY_CHECKLIST.md already exists, skipping"
    else
        if [[ -f "$kit_dir/SPEC_QUALITY_CHECKLIST.md" ]]; then
            if cp "$kit_dir/SPEC_QUALITY_CHECKLIST.md" SPEC_QUALITY_CHECKLIST.md; then
                echo "  Created SPEC_QUALITY_CHECKLIST.md"
            else
                echo "  Warning: failed to create SPEC_QUALITY_CHECKLIST.md"
            fi
        fi
    fi

    if [[ -f "ACCESSIBILITY_CHECKLIST.md" ]]; then
        echo "  ACCESSIBILITY_CHECKLIST.md already exists, skipping"
    else
        if [[ -f "$kit_dir/ACCESSIBILITY_CHECKLIST.md" ]]; then
            if cp "$kit_dir/ACCESSIBILITY_CHECKLIST.md" ACCESSIBILITY_CHECKLIST.md; then
                echo "  Created ACCESSIBILITY_CHECKLIST.md"
            else
                echo "  Warning: failed to create ACCESSIBILITY_CHECKLIST.md"
            fi
        fi
    fi

    echo ""
    echo "Autonomous build environment initialized!"
    echo ""
    echo "Next steps:"
    echo "  1. Edit CLAUDE.md with project-specific instructions"
    echo "  2. Create SPEC.md for your feature"
    echo "  3. Run: claude 'Read AUTONOMOUS_BUILD_CLAUDE.md and build this'"
}

# Show current autonomous build status
autonomous-status() {
    local help_text="
Usage: autonomous-status

Display the current autonomous build status by reading CONTEXT.md
and IMPLEMENTATION_PLAN.md.
"

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "$help_text"
        return 0
    fi

    echo "=== Autonomous Build Status ==="
    echo ""

    # Check for CONTEXT.md
    if [[ -f "CONTEXT.md" ]]; then
        echo "📋 CONTEXT.md found"
        # Extract last updated line
        local last_updated=$(grep -m1 "^\*\*Last Updated\*\*:" CONTEXT.md 2>/dev/null || echo "")
        if [[ -n "$last_updated" ]]; then
            echo "   $last_updated"
        fi
        # Extract current phase from context
        local current_phase=$(grep -m1 "## Current Phase" CONTEXT.md 2>/dev/null || echo "")
        if [[ -n "$current_phase" ]]; then
            echo ""
            echo "📍 Current Phase:"
            sed -n '/## Current Phase/,/^##/p' CONTEXT.md | head -10 | tail -n +2
        fi
    else
        echo "❌ No CONTEXT.md found"
        echo "   Run: autonomous-init"
    fi

    echo ""

    # Check for IMPLEMENTATION_PLAN.md
    if [[ -f "IMPLEMENTATION_PLAN.md" ]]; then
        echo "📝 IMPLEMENTATION_PLAN.md found"
        # Extract status section
        local status=$(sed -n '/## Current Status/,/^---/p' IMPLEMENTATION_PLAN.md 2>/dev/null | head -10)
        if [[ -n "$status" ]]; then
            echo "$status"
        fi
    else
        echo "❌ No IMPLEMENTATION_PLAN.md found"
    fi

    echo ""

    # Show recent git activity
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "📦 Recent commits:"
        git log --oneline -5 2>/dev/null || echo "   No commits yet"
    fi
}

# Check if an npm script exists in package.json.
has_npm_script() {
    local script="$1"

    if [[ ! -f "package.json" ]]; then
        return 1
    fi

    if command -v jq &> /dev/null; then
        jq -e --arg script "$script" '.scripts[$script]' package.json > /dev/null 2>&1
        return $?
    fi

    if command -v node &> /dev/null; then
        node -e "const script=process.argv[1];const pkg=require('./package.json');process.exit(pkg.scripts && Object.prototype.hasOwnProperty.call(pkg.scripts, script) ? 0 : 1)" "$script" > /dev/null 2>&1
        return $?
    fi

    if command -v rg &> /dev/null; then
        rg -q "\"$script\"[[:space:]]*:" package.json
    else
        grep -q "\"$script\"[[:space:]]*:" package.json
    fi
}

# Run all quality gates
quality-gates() {
    local help_text="
Usage: quality-gates [OPTIONS]

Run all quality gates: typecheck, lint, build, test.

Options:
  --skip-tests    Skip running tests
  --skip-build    Skip running build
  --help          Show this help message
"

    local skip_tests=false
    local skip_build=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-tests) skip_tests=true; shift ;;
            --skip-build) skip_build=true; shift ;;
            --help|-h) echo "$help_text"; return 0 ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
    done

    echo "=== Running Quality Gates ==="
    echo ""

    local failed=false

    # Typecheck
    if has_npm_script "typecheck"; then
        echo "🔍 Running typecheck..."
        if npm run typecheck; then
            echo "✅ Typecheck passed"
        else
            echo "❌ Typecheck failed"
            failed=true
        fi
        echo ""
    fi

    # Lint
    if has_npm_script "lint"; then
        echo "🧹 Running lint..."
        if npm run lint; then
            echo "✅ Lint passed"
        else
            echo "❌ Lint failed"
            failed=true
        fi
        echo ""
    fi

    # Build
    if [[ "$skip_build" == false ]]; then
        if has_npm_script "build"; then
            echo "🏗️  Running build..."
            if npm run build; then
                echo "✅ Build passed"
            else
                echo "❌ Build failed"
                failed=true
            fi
            echo ""
        fi
    else
        echo "⏭️  Skipping build"
        echo ""
    fi

    # Test
    if [[ "$skip_tests" == false ]]; then
        if has_npm_script "test"; then
            echo "🧪 Running tests..."
            if npm run test; then
                echo "✅ Tests passed"
            else
                echo "❌ Tests failed"
                failed=true
            fi
            echo ""
        fi
    else
        echo "⏭️  Skipping tests"
        echo ""
    fi

    # Summary
    echo "=== Summary ==="
    if [[ "$failed" == true ]]; then
        echo "❌ Some quality gates failed. Fix issues before proceeding."
        return 1
    else
        echo "✅ All quality gates passed!"
        return 0
    fi
}

# Quick Claude code review
claude-review() {
    local help_text="
Usage: claude-review [PHASE_NAME]

Run Claude code review for the current branch diff.

Arguments:
  PHASE_NAME    Optional name for the phase being reviewed

Example:
  claude-review 'Phase 2 - Authentication'
"

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "$help_text"
        return 0
    fi

    local phase_name="${1:-Current changes}"

    echo "Requesting Claude code review for: $phase_name"
    echo ""

    claude -p --model opus --dangerously-skip-permissions --output-format text \
        "Review the current branch diff for '$phase_name'. Check for: security issues, edge cases, test coverage gaps, performance concerns, code quality. If SPEC.md exists, verify against it. Output format: Critical issues / Warnings / Suggestions / Verdict (approve or revise)."
}

# Quick Codex code review
codex-review() {
    local help_text="
Usage: codex-review [PHASE_NAME]

Run Codex code review for the current branch diff.

Arguments:
  PHASE_NAME    Optional name for the phase being reviewed

Example:
  codex-review 'Phase 2 - Authentication'
"

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "$help_text"
        return 0
    fi

    local phase_name="${1:-Current changes}"

    echo "Requesting Codex code review for: $phase_name"
    echo ""

    # Note: Adjust the codex command based on actual CLI syntax
    codex exec \
        --model gpt-5.2-codex \
        --config model_reasoning_effort="xhigh" \
        --yolo \
        "Review the current branch diff for '$phase_name'. Check for: security issues, edge cases, test coverage gaps, performance concerns, code quality. If SPEC.md exists, verify against it. Output format: Critical issues / Warnings / Suggestions / Verdict (approve or revise)."
}

# Check for common slop patterns
slop-check() {
    local help_text="
Usage: slop-check [PATH]

Grep for common AI-generated cruft patterns.

Arguments:
  PATH    Optional path to search (defaults to src/)

Checks for:
  - Unnecessary comments restating code
  - console.log/debug statements
  - TODO/FIXME comments
  - any type casts
  - Empty catch blocks
  - Commented-out code blocks
"

    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "$help_text"
        return 0
    fi

    local search_path="${1:-src/}"

    if [[ ! -d "$search_path" ]]; then
        echo "Warning: $search_path not found, searching current directory"
        search_path="."
    fi

    echo "=== Checking for slop patterns in $search_path ==="
    echo ""

    # console.log/debug
    echo "📍 Console statements:"
    rg -n "console\.(log|debug|info|warn)" "$search_path" --type ts --type tsx --type js --type jsx 2>/dev/null || echo "   None found"
    echo ""

    # TODO/FIXME
    echo "📍 TODO/FIXME comments:"
    rg -n "TODO|FIXME|XXX|HACK" "$search_path" 2>/dev/null || echo "   None found"
    echo ""

    # any type
    echo "📍 'any' type casts:"
    rg -n ": any\b|as any" "$search_path" --type ts --type tsx 2>/dev/null || echo "   None found"
    echo ""

    # Empty catch blocks
    echo "📍 Potentially empty catch blocks:"
    rg -n "catch\s*\([^)]*\)\s*\{\s*\}" "$search_path" --type ts --type tsx --type js --type jsx 2>/dev/null || echo "   None found"
    echo ""

    # Commented code blocks (multi-line)
    echo "📍 Large comment blocks (potential commented-out code):"
    rg -n -U "(?m)(^\\s*//.*\\n){5,}" "$search_path" --type ts --type tsx --type js --type jsx 2>/dev/null || echo "   None found"
    echo ""

    echo "=== Done ==="
    echo "Review findings and clean up as needed."
}

# =============================================================================
# Git Helpers
# =============================================================================

# Create a feature branch with standard naming
git-feature() {
    local help_text="
Usage: git-feature <branch-name>

Create a feature branch with 'feature/' prefix.

Example:
  git-feature user-auth
  # Creates: feature/user-auth
"

    if [[ "$1" == "--help" || "$1" == "-h" || -z "$1" ]]; then
        echo "$help_text"
        return 0
    fi

    git checkout -b "feature/$1"
}

# Quick commit with conventional commit format
git-feat() {
    local help_text="
Usage: git-feat <message>

Create a 'feat:' commit with the given message.

Example:
  git-feat 'add user authentication'
"

    if [[ "$1" == "--help" || "$1" == "-h" || -z "$1" ]]; then
        echo "$help_text"
        return 0
    fi

    git commit -m "feat: $1"
}

git-fix() {
    local help_text="
Usage: git-fix <message>

Create a 'fix:' commit with the given message.

Example:
  git-fix 'resolve login redirect loop'
"

    if [[ "$1" == "--help" || "$1" == "-h" || -z "$1" ]]; then
        echo "$help_text"
        return 0
    fi

    git commit -m "fix: $1"
}

git-chore() {
    local help_text="
Usage: git-chore <message>

Create a 'chore:' commit with the given message.

Example:
  git-chore 'update dependencies'
"

    if [[ "$1" == "--help" || "$1" == "-h" || -z "$1" ]]; then
        echo "$help_text"
        return 0
    fi

    git commit -m "chore: $1"
}
