#!/usr/bin/env bash
#
# Tests for install.sh update detection
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TESTS_RUN=0
TESTS_PASSED=0

INSTALL_LIB_ONLY=1 source "$REPO_ROOT/install.sh"

contains_outdated_label() {
    local label="$1"
    for item in "${OUTDATED_ITEMS[@]}"; do
        local item_label
        IFS='|' read -r _ item_label _ _ <<< "$item"
        if [[ "$item_label" == "$label" ]]; then
            return 0
        fi
    done
    return 1
}

test_detect_updates_flags_modified_stop_hook() {
    echo "Testing update detection flags modified stop hook..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local temp_home
    temp_home=$(mktemp -d)
    HOME="$temp_home"
    export HOME

    mkdir -p "$HOME/.claude/hooks"
    cp "$REPO_ROOT/hooks/stop.sh" "$HOME/.claude/hooks/stop.sh"
    printf '\n# modified\n' >> "$HOME/.claude/hooks/stop.sh"

    detect_updates

    if contains_outdated_label "stop hook"; then
        echo "  OK Modified stop hook detected"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL Expected stop hook to be flagged as outdated"
    fi

    rm -rf "$temp_home"
}

test_detect_updates_skips_matching_files() {
    echo "Testing update detection skips matching files..."
    TESTS_RUN=$((TESTS_RUN + 1))

    local temp_home
    temp_home=$(mktemp -d)
    HOME="$temp_home"
    export HOME

    mkdir -p "$HOME/.claude/hooks"
    cp "$REPO_ROOT/hooks/stop.sh" "$HOME/.claude/hooks/stop.sh"

    detect_updates

    if [[ ${#OUTDATED_ITEMS[@]} -eq 0 ]]; then
        echo "  OK No updates when files match"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL Expected no updates when files match"
    fi

    rm -rf "$temp_home"
}

# Run tests
echo "=== Installer Update Detection Tests ==="
echo ""

test_detect_updates_flags_modified_stop_hook
test_detect_updates_skips_matching_files

# Summary
echo ""
echo "=== Results ==="
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
