#!/usr/bin/env bash
#
# autonomous-dev-kit installer
# Sets up CLI tools, Claude Code, shell configuration, and environment
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# State
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG=""
OS=""
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"

# Install mode: full, additive, update, tools_only
INSTALL_MODE=""
INSTALL_MODE_SOURCE=""

# Detection results (populated by detect_* functions)
declare -a MISSING_TOOLS=()
declare -a INSTALLED_TOOLS=()
declare -a MISSING_ALIASES=()
declare -a EXISTING_ALIASES=()
declare -a MISSING_FILES=()
declare -a EXISTING_FILES=()
declare -a OUTDATED_ITEMS=()
MISSING_HOOKS=0
EXISTING_HOOKS=0

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

run() {
    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN]${NC} $*"
    else
        "$@"
    fi
}

command_exists() {
    command -v "$1" &> /dev/null
}

backup_file() {
    local src="$1"
    local backup="${src}.backup.${BACKUP_SUFFIX}"
    info "Backing up $src to $backup"
    run cp "$src" "$backup"
}

backup_dir() {
    local src="$1"
    local backup="${src}.backup.${BACKUP_SUFFIX}"
    info "Backing up $src to $backup"
    run cp -R "$src" "$backup"
}

# Prompt user if they want to backup before overwriting (default: No)
# Returns 0 if backup was made, 1 if skipped
prompt_backup_file() {
    local src="$1"
    local label="${2:-file}"

    if $DRY_RUN; then
        info "DRY-RUN: would prompt to backup $label"
        return 1
    fi

    # Skip prompt in non-interactive mode (default to no backup)
    if [ ! -t 0 ]; then
        return 1
    fi

    local response=""
    while true; do
        read -r -p "Backup existing $label before overwriting? [y/N] " response
        case "$response" in
            [yY]|[yY][eE][sS])
                backup_file "$src"
                return 0
                ;;
            [nN]|[nN][oO]|"") return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Prompt user if they want to backup directory before overwriting (default: No)
# Returns 0 if backup was made, 1 if skipped
prompt_backup_dir() {
    local src="$1"
    local label="${2:-directory}"

    if $DRY_RUN; then
        info "DRY-RUN: would prompt to backup $label"
        return 1
    fi

    # Skip prompt in non-interactive mode (default to no backup)
    if [ ! -t 0 ]; then
        return 1
    fi

    local response=""
    while true; do
        read -r -p "Backup existing $label before overwriting? [y/N] " response
        case "$response" in
            [yY]|[yY][eE][sS])
                backup_dir "$src"
                return 0
                ;;
            [nN]|[nN][oO]|"") return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Ask once if user wants to backup all items in a batch operation (default: No)
# Sets BATCH_BACKUP_CHOICE to "yes" or "no"
prompt_batch_backup() {
    local item_type="${1:-items}"
    local count="${2:-multiple}"

    BATCH_BACKUP_CHOICE="no"

    if $DRY_RUN; then
        info "DRY-RUN: would prompt to backup all $item_type"
        return 1
    fi

    # Skip prompt in non-interactive mode (default to no backup)
    if [ ! -t 0 ]; then
        return 1
    fi

    local response=""
    while true; do
        read -r -p "Backup all $count existing $item_type before overwriting? [y/N] " response
        case "$response" in
            [yY]|[yY][eE][sS])
                BATCH_BACKUP_CHOICE="yes"
                return 0
                ;;
            [nN]|[nN][oO]|"") return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

prompt_overwrite() {
    local label="$1"
    local dest="$2"

    if $DRY_RUN; then
        info "DRY-RUN: would prompt to overwrite $label at $dest"
        return 1
    fi

    local response=""
    while true; do
        read -r -p "Overwrite existing $label at $dest? [y/N] " response
        case "$response" in
            [yY]|[yY][eE][sS]) return 0 ;;
            [nN]|[nN][oO]|"") return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

normalize_install_mode() {
    local raw="$1"
    case "$raw" in
        update|full|additive)
            echo "$raw"
            ;;
        tools-only|tools_only|tools)
            echo "tools_only"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Detection Functions
# -----------------------------------------------------------------------------

detect_tools() {
    local tools=("fd" "fzf" "bat" "delta" "zoxide" "jq" "yq" "sd" "rg" "entr" "mise" "direnv" "uv")

    MISSING_TOOLS=()
    INSTALLED_TOOLS=()

    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            INSTALLED_TOOLS+=("$tool")
        else
            MISSING_TOOLS+=("$tool")
        fi
    done
}

detect_aliases() {
    # Define our aliases: name=value pairs
    local -a our_aliases=(
        "find=fd"
        "cat=bat"
        "diff=delta"
        "gs=git status"
        "gd=git diff"
        "gds=git diff --staged"
        "gl=git log"
        "gco=git checkout"
        "ga=git add"
        "gc=git commit"
        "gp=git push"
        "gpl=git pull"
        "cc=claude"
        "ccr=claude --resume"
    )
    
    MISSING_ALIASES=()
    EXISTING_ALIASES=()
    
    # Get currently loaded aliases via login shell
    local loaded_aliases=""
    if [ -n "${ZSH_VERSION:-}" ] || [ "$SHELL" = "/bin/zsh" ] || [ "$OS" = "macos" ]; then
        loaded_aliases=$(zsh -ilc 'alias' 2>/dev/null || true)
    else
        loaded_aliases=$(bash -ilc 'alias' 2>/dev/null || true)
    fi
    
    for alias_def in "${our_aliases[@]}"; do
        local alias_name="${alias_def%%=*}"
        
        # Check if this alias name exists in loaded aliases
        # Aliases appear as: alias_name=... or alias_name='...'
        if echo "$loaded_aliases" | grep -qE "^${alias_name}=|^alias ${alias_name}="; then
            EXISTING_ALIASES+=("$alias_name")
        else
            MISSING_ALIASES+=("$alias_def")
        fi
    done
}

detect_claude_files() {
    local -a our_files=(
        "$HOME/.claude/CLAUDE.md"
        "$HOME/.claude/shell/functions.zsh"
        "$HOME/.claude/shell/aliases.zsh"
        "$HOME/.claude/hooks/pre-compact.sh"
        "$HOME/.claude/hooks/session-start.sh"
        "$HOME/.claude/hooks/user-prompt-submit.sh"
        "$HOME/.claude/hooks/stop.sh"
        "$HOME/.claude/lib/loop-helpers.sh"
        "$HOME/.claude/lib/cheatsheet.md"
        "$HOME/.claude/autonomous-dev-kit/templates"
        "$HOME/.claude/skills"
        "$HOME/.claude/agents"
        "$HOME/.claude/rules"
    )
    
    MISSING_FILES=()
    EXISTING_FILES=()
    
    for file_path in "${our_files[@]}"; do
        if [ -e "$file_path" ]; then
            EXISTING_FILES+=("$file_path")
        else
            MISSING_FILES+=("$file_path")
        fi
    done
}

files_differ() {
    local src="$1"
    local dest="$2"
    if [ ! -f "$src" ] || [ ! -f "$dest" ]; then
        return 1
    fi
    ! diff -q "$src" "$dest" > /dev/null 2>&1
}

dirs_differ() {
    local src="$1"
    local dest="$2"
    if [ ! -d "$src" ] || [ ! -d "$dest" ]; then
        return 1
    fi
    ! diff -qr "$src" "$dest" > /dev/null 2>&1
}

record_outdated_item() {
    local kind="$1"
    local label="$2"
    local src="$3"
    local dest="$4"
    OUTDATED_ITEMS+=("$kind|$label|$src|$dest")
}

detect_updates() {
    OUTDATED_ITEMS=()

    local claude_dir="$HOME/.claude"
    local kit_dir="$claude_dir/autonomous-dev-kit"

    local -a file_items=(
        "global CLAUDE.md|$SCRIPT_DIR/templates/CLAUDE.md|$claude_dir/CLAUDE.md"
        "shell functions|$SCRIPT_DIR/shell/functions.zsh|$claude_dir/shell/functions.zsh"
        "shell aliases|$SCRIPT_DIR/shell/aliases.zsh|$claude_dir/shell/aliases.zsh"
        "pre-compact hook|$SCRIPT_DIR/hooks/pre-compact.sh|$claude_dir/hooks/pre-compact.sh"
        "session-start hook|$SCRIPT_DIR/hooks/session-start.sh|$claude_dir/hooks/session-start.sh"
        "user-prompt-submit hook|$SCRIPT_DIR/hooks/user-prompt-submit.sh|$claude_dir/hooks/user-prompt-submit.sh"
        "stop hook|$SCRIPT_DIR/hooks/stop.sh|$claude_dir/hooks/stop.sh"
        "loop helpers library|$SCRIPT_DIR/hooks/lib/loop-helpers.sh|$claude_dir/lib/loop-helpers.sh"
        "autonomous loop cheatsheet|$SCRIPT_DIR/hooks/lib/cheatsheet.md|$claude_dir/lib/cheatsheet.md"
    )

    for item in "${file_items[@]}"; do
        local label src dest
        IFS='|' read -r label src dest <<< "$item"
        if [ -f "$dest" ] && files_differ "$src" "$dest"; then
            record_outdated_item "file" "$label" "$src" "$dest"
        fi
    done

    if [ -d "$kit_dir/templates" ] && dirs_differ "$SCRIPT_DIR/templates" "$kit_dir/templates"; then
        record_outdated_item "dir" "templates" "$SCRIPT_DIR/templates" "$kit_dir/templates"
    fi
}

claude_version() {
    if ! command_exists claude; then
        echo ""
        return
    fi

    claude --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

claude_supports_skill_hooks() {
    local version
    version=$(claude_version)
    if [ -z "$version" ]; then
        return 1
    fi

    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"
    if [ "$major" -gt 2 ]; then
        return 0
    fi
    if [ "$major" -eq 2 ] && [ "$minor" -ge 1 ]; then
        return 0
    fi
    return 1
}

use_legacy_stop_hook() {
    if [ "${CLAUDE_CODE_LEGACY_STOP_HOOK:-}" = "1" ]; then
        return 0
    fi

    if ! claude_supports_skill_hooks; then
        return 0
    fi

    return 1
}

detect_hooks() {
    local settings_file="$HOME/.claude/settings.json"
    local hook_precompact="$HOME/.claude/hooks/pre-compact.sh"
    local hook_sessionstart="$HOME/.claude/hooks/session-start.sh"
    local hook_userprompt="$HOME/.claude/hooks/user-prompt-submit.sh"
    local hook_stop="$HOME/.claude/hooks/stop.sh"
    local require_stop_hook=true

    if ! use_legacy_stop_hook; then
        require_stop_hook=false
    fi
    local required_hooks=3
    if $require_stop_hook; then
        required_hooks=4
    fi

    MISSING_HOOKS=0
    EXISTING_HOOKS=0

    if [ ! -f "$settings_file" ]; then
        MISSING_HOOKS=$required_hooks
        return
    fi

    # Fall back to string matching when jq isn't available yet
    if ! command_exists jq; then
        if grep -Fq "$hook_precompact" "$settings_file" 2>/dev/null; then
            EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
        else
            MISSING_HOOKS=$((MISSING_HOOKS + 1))
        fi

        if grep -Fq "$hook_sessionstart" "$settings_file" 2>/dev/null; then
            EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
        else
            MISSING_HOOKS=$((MISSING_HOOKS + 1))
        fi

        if grep -Fq "$hook_userprompt" "$settings_file" 2>/dev/null; then
            EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
        else
            MISSING_HOOKS=$((MISSING_HOOKS + 1))
        fi

        if $require_stop_hook; then
            if grep -Fq "$hook_stop" "$settings_file" 2>/dev/null; then
                EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
            else
                MISSING_HOOKS=$((MISSING_HOOKS + 1))
            fi
        fi
        return
    fi

    # Check if settings.json is valid JSON
    if ! jq empty "$settings_file" 2>/dev/null; then
        MISSING_HOOKS=$required_hooks
        return
    fi

    # Check for PreCompact hook (handle both single-object and array formats)
    if jq -e --arg cmd "$hook_precompact" '
        (.hooks.PreCompact // []) |
        if type == "array" then . else [.] end |
        .[].hooks[]? | select(.command == $cmd)
    ' "$settings_file" > /dev/null 2>&1; then
        EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
    else
        MISSING_HOOKS=$((MISSING_HOOKS + 1))
    fi

    # Check for SessionStart hook (handle both single-object and array formats)
    if jq -e --arg cmd "$hook_sessionstart" '
        (.hooks.SessionStart // []) |
        if type == "array" then . else [.] end |
        .[].hooks[]? | select(.command == $cmd)
    ' "$settings_file" > /dev/null 2>&1; then
        EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
    else
        MISSING_HOOKS=$((MISSING_HOOKS + 1))
    fi

    # Check for UserPromptSubmit hook (handle both single-object and array formats)
    if jq -e --arg cmd "$hook_userprompt" '
        (.hooks.UserPromptSubmit // []) |
        if type == "array" then . else [.] end |
        .[].hooks[]? | select(.command == $cmd)
    ' "$settings_file" > /dev/null 2>&1; then
        EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
    else
        MISSING_HOOKS=$((MISSING_HOOKS + 1))
    fi

    if $require_stop_hook; then
        # Check for Stop hook (handle both single-object and array formats)
        if jq -e --arg cmd "$hook_stop" '
            (.hooks.Stop // []) |
            if type == "array" then . else [.] end |
            .[].hooks[]? | select(.command == $cmd)
        ' "$settings_file" > /dev/null 2>&1; then
            EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
        else
            MISSING_HOOKS=$((MISSING_HOOKS + 1))
        fi
    fi
}

run_detection() {
    echo ""
    info "Scanning existing environment..."
    echo ""
    
    detect_tools
    detect_aliases
    detect_claude_files
    detect_hooks
    detect_updates
}

display_detection_summary() {
    local total_tools=$((${#INSTALLED_TOOLS[@]} + ${#MISSING_TOOLS[@]}))
    local total_aliases=$((${#EXISTING_ALIASES[@]} + ${#MISSING_ALIASES[@]}))
    local total_files=$((${#EXISTING_FILES[@]} + ${#MISSING_FILES[@]}))
    local total_hooks=$((EXISTING_HOOKS + MISSING_HOOKS))
    
    # CLI Tools line
    if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
        echo -e "  CLI Tools:    ${GREEN}${#INSTALLED_TOOLS[@]}/${total_tools} installed${NC}"
    else
        echo -e "  CLI Tools:    ${#INSTALLED_TOOLS[@]}/${total_tools} installed ${YELLOW}(missing: ${MISSING_TOOLS[*]})${NC}"
    fi
    
    # Aliases line
    if [ ${#MISSING_ALIASES[@]} -eq 0 ]; then
        echo -e "  Aliases:      ${GREEN}${#EXISTING_ALIASES[@]}/${total_aliases} defined${NC}"
    else
        # Extract just alias names from missing (they're stored as name=value)
        local missing_names=()
        for alias_def in "${MISSING_ALIASES[@]}"; do
            missing_names+=("${alias_def%%=*}")
        done
        echo -e "  Aliases:      ${#EXISTING_ALIASES[@]}/${total_aliases} defined ${YELLOW}(missing: ${missing_names[*]})${NC}"
    fi
    
    # ~/.claude files line
    if [ ${#MISSING_FILES[@]} -eq 0 ]; then
        echo -e "  ~/.claude:    ${GREEN}${#EXISTING_FILES[@]}/${total_files} files exist${NC}"
    else
        # Shorten paths for display
        local missing_short=()
        for f in "${MISSING_FILES[@]}"; do
            missing_short+=("${f##*/}")
        done
        echo -e "  ~/.claude:    ${#EXISTING_FILES[@]}/${total_files} files exist ${YELLOW}(missing: ${missing_short[*]})${NC}"
    fi
    
    # Hooks line
    if [ $MISSING_HOOKS -eq 0 ]; then
        echo -e "  Hooks:        ${GREEN}${EXISTING_HOOKS}/${total_hooks} configured${NC}"
    else
        echo -e "  Hooks:        ${EXISTING_HOOKS}/${total_hooks} configured ${YELLOW}(missing: ${MISSING_HOOKS})${NC}"
    fi

    # Updates line
    if [ ${#OUTDATED_ITEMS[@]} -eq 0 ]; then
        echo -e "  Updates:      ${GREEN}none${NC}"
    else
        local outdated_labels=()
        for item in "${OUTDATED_ITEMS[@]}"; do
            local label
            IFS='|' read -r _ label _ _ <<< "$item"
            outdated_labels+=("$label")
        done
        local preview=""
        local max_preview=4
        local count=0
        for label in "${outdated_labels[@]}"; do
            if [ $count -ge $max_preview ]; then
                preview="$preview, ..."
                break
            fi
            if [ -n "$preview" ]; then
                preview="$preview, $label"
            else
                preview="$label"
            fi
            count=$((count + 1))
        done
        echo -e "  Updates:      ${YELLOW}${#OUTDATED_ITEMS[@]} available (${preview})${NC}"
    fi
    
    echo ""
}

prompt_install_mode() {
    if [[ "$INSTALL_MODE_SOURCE" == "cli" ]]; then
        case "$INSTALL_MODE" in
            update) info "Selected: Update to latest (from CLI)" ;;
            full) info "Selected: Full install (from CLI)" ;;
            additive) info "Selected: Add missing only (from CLI)" ;;
            tools_only) info "Selected: Tools only (from CLI)" ;;
            *)
                warn "Unknown install mode from CLI (defaulting to additive)"
                INSTALL_MODE="additive"
                ;;
        esac
        return
    fi

    # If everything is already installed, just inform and use additive (no-op)
    if [ ${#MISSING_TOOLS[@]} -eq 0 ] && [ ${#MISSING_ALIASES[@]} -eq 0 ] && \
       [ ${#MISSING_FILES[@]} -eq 0 ] && [ $MISSING_HOOKS -eq 0 ] && \
       [ ${#OUTDATED_ITEMS[@]} -eq 0 ]; then
        success "Everything is already installed and up to date!"
        INSTALL_MODE="additive"
        return
    fi
    
    if $DRY_RUN; then
        info "DRY-RUN: would prompt for install mode, defaulting to 'additive'"
        INSTALL_MODE="additive"
        return
    fi
    
    echo "How would you like to proceed?"
    echo ""
    local option_num=1
    local opt_update=""
    local opt_full=""
    local opt_additive=""
    local opt_tools=""

    if [ ${#OUTDATED_ITEMS[@]} -gt 0 ]; then
        opt_update=$option_num
        echo -e "  ${CYAN}[$opt_update]${NC} Update to latest  ${GREEN}(recommended)${NC}"
        echo "      Apply updates to existing files; you'll be prompted before overwrite"
        echo ""
        option_num=$((option_num + 1))
    fi

    opt_full=$option_num
    echo -e "  ${CYAN}[$opt_full]${NC} Full install"
    echo "      Backup existing configs, install everything fresh"
    echo ""
    option_num=$((option_num + 1))

    opt_additive=$option_num
    echo -e "  ${CYAN}[$opt_additive]${NC} Add missing only"
    echo "      Install missing tools/aliases, preserve your customizations"
    echo ""
    option_num=$((option_num + 1))

    opt_tools=$option_num
    echo -e "  ${CYAN}[$opt_tools]${NC} Tools only"
    echo "      Install CLI tools via Homebrew, skip all shell/config changes"
    echo ""

    local choices=""
    if [ -n "$opt_update" ]; then
        choices+="$opt_update/"
    fi
    choices+="$opt_full/$opt_additive/$opt_tools"
    choices="${choices%/}"

    local response=""
    while true; do
        read -r -p "Choice [$choices]: " response
        if [[ -z "$response" ]]; then
            if [ -n "$opt_update" ]; then
                INSTALL_MODE="update"
            else
                INSTALL_MODE="additive"
            fi
            break
        fi
        case "$response" in
            $opt_update) INSTALL_MODE="update"; break ;;
            $opt_full) INSTALL_MODE="full"; break ;;
            $opt_additive) INSTALL_MODE="additive"; break ;;
            $opt_tools) INSTALL_MODE="tools_only"; break ;;
            *) echo "Please enter one of: $choices." ;;
        esac
    done
    
    echo ""
    case "$INSTALL_MODE" in
        update) info "Selected: Update to latest" ;;
        full) info "Selected: Full install" ;;
        additive) info "Selected: Add missing only" ;;
        tools_only) info "Selected: Tools only" ;;
    esac
}

# -----------------------------------------------------------------------------
# OS Detection
# -----------------------------------------------------------------------------

detect_os() {
    case "$(uname -s)" in
        Darwin)
            OS="macos"
            SHELL_CONFIG="$HOME/.zshrc"
            ;;
        Linux)
            OS="linux"
            if [ -n "${ZSH_VERSION:-}" ] || [ "$SHELL" = "/bin/zsh" ]; then
                SHELL_CONFIG="$HOME/.zshrc"
            else
                SHELL_CONFIG="$HOME/.bashrc"
            fi
            ;;
        *)
            error "Unsupported OS: $(uname -s)"
            error "This installer supports macOS and Linux only."
            exit 1
            ;;
    esac
    info "Detected OS: $OS"
    info "Shell config: $SHELL_CONFIG"
}

# -----------------------------------------------------------------------------
# Package Manager
# -----------------------------------------------------------------------------

install_homebrew() {
    if ! command_exists brew; then
        info "Installing Homebrew..."
        run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session
        if [ "$OS" = "macos" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
        else
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null)"
        fi
    else
        success "Homebrew already installed"
    fi
}

install_cli_tools() {
    local tools=("fd" "fzf" "bat" "git-delta" "zoxide" "jq" "yq" "sd" "ripgrep" "entr" "mise" "direnv" "uv")

    info "Installing CLI tools..."
    for tool in "${tools[@]}"; do
        local cmd_name="$tool"
        # Map package names to command names where they differ
        case "$tool" in
            git-delta) cmd_name="delta" ;;
            ripgrep) cmd_name="rg" ;;
        esac

        if command_exists "$cmd_name"; then
            success "$tool already installed"
        else
            info "Installing $tool..."
            run brew install "$tool"
        fi
    done
}

# -----------------------------------------------------------------------------
# Node.js and Claude Code
# -----------------------------------------------------------------------------

check_nodejs() {
    if ! command_exists node; then
        info "Node.js not found, installing via Homebrew..."
        run brew install node
    fi

    local node_version
    node_version=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$node_version" -lt 18 ]; then
        error "Node.js 18+ required. Found: $(node -v)"
        exit 1
    fi
    success "Node.js $(node -v) found"
}

install_claude_code() {
    if command_exists claude; then
        success "Claude Code CLI already installed"
        claude --version 2>/dev/null || true
    else
        info "Installing Claude Code CLI..."
        run npm install -g @anthropic-ai/claude-code
    fi
}

# -----------------------------------------------------------------------------
# Shell Configuration
# -----------------------------------------------------------------------------

backup_shell_config() {
    if [ -f "$SHELL_CONFIG" ]; then
        local backup="$SHELL_CONFIG.backup.$(date +%Y%m%d%H%M%S)"
        info "Backing up $SHELL_CONFIG to $backup"
        run cp "$SHELL_CONFIG" "$backup"
    fi
}

# Get the full alias definition for a given alias name
get_alias_value() {
    local alias_name="$1"
    case "$alias_name" in
        find)  echo "alias find='fd'" ;;
        cat)   echo "alias cat='bat -n --paging=never'" ;;
        diff)  echo "alias diff='delta'" ;;
        gs)    echo "alias gs='git status'" ;;
        gd)    echo "alias gd='git diff'" ;;
        gds)   echo "alias gds='git diff --staged'" ;;
        gl)    echo "alias gl='git log --oneline -20'" ;;
        gco)   echo "alias gco='git checkout'" ;;
        ga)    echo "alias ga='git add'" ;;
        gc)    echo "alias gc='git commit'" ;;
        gp)    echo "alias gp='git push'" ;;
        gpl)   echo "alias gpl='git pull'" ;;
        cc)    echo "alias cc='claude'" ;;
        ccr)   echo "alias ccr='claude --resume'" ;;
    esac
}

install_shell_config() {
    local marker="# >>> autonomous-dev-kit >>>"
    local end_marker="# <<< autonomous-dev-kit <<<"

    # Skip if tools_only mode
    if [ "$INSTALL_MODE" = "tools_only" ]; then
        info "Skipping shell configuration (tools only mode)"
        return
    fi

    # Full mode: backup, remove old block, append fresh block
    if [ "$INSTALL_MODE" = "full" ]; then
        install_shell_config_full
        return
    fi

    # Additive mode: only append missing aliases
    install_shell_config_additive
}

install_shell_config_full() {
    local marker="# >>> autonomous-dev-kit >>>"
    local end_marker="# <<< autonomous-dev-kit <<<"

    # Remove existing block if present
    if [ -f "$SHELL_CONFIG" ] && grep -q "$marker" "$SHELL_CONFIG"; then
        info "Removing existing autonomous-dev-kit block..."
        if ! $DRY_RUN; then
            # Use sed to remove the block (marker to end_marker inclusive)
            sed -i.tmp "/$marker/,/$end_marker/d" "$SHELL_CONFIG"
            rm -f "$SHELL_CONFIG.tmp"
        else
            echo -e "${CYAN}[DRY-RUN]${NC} Would remove existing block from $SHELL_CONFIG"
        fi
    fi

    info "Adding full shell configuration to $SHELL_CONFIG..."

    local shell_additions
    shell_additions=$(cat << 'SHELL_CONFIG_EOF'

# >>> autonomous-dev-kit >>>
# CLI tool aliases
alias find='fd'
alias cat='bat -n --paging=never'
alias diff='delta'

# Git aliases
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

# Zoxide (smart cd) - replaces cd command
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh --cmd cd 2>/dev/null || zoxide init bash --cmd cd 2>/dev/null)"
fi

# Direnv (auto-load .envrc)
if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh 2>/dev/null || direnv hook bash 2>/dev/null)"
fi

# Source autonomous-dev-kit functions if they exist
if [ -f "$HOME/.claude/shell/functions.zsh" ]; then
    source "$HOME/.claude/shell/functions.zsh"
fi
# <<< autonomous-dev-kit <<<
SHELL_CONFIG_EOF
)

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would append to $SHELL_CONFIG:"
        echo "$shell_additions"
    else
        echo "$shell_additions" >> "$SHELL_CONFIG"
    fi
    
    success "Shell configuration installed"
}

install_shell_config_additive() {
    local needs_aliases=false
    local needs_zoxide=false
    local needs_functions=false

    if [ ${#MISSING_ALIASES[@]} -gt 0 ]; then
        needs_aliases=true
    fi

    if ! grep -q "zoxide init" "$SHELL_CONFIG" 2>/dev/null; then
        needs_zoxide=true
    fi

    if ! grep -q "functions.zsh" "$SHELL_CONFIG" 2>/dev/null; then
        needs_functions=true
    fi

    if ! $needs_aliases && ! $needs_zoxide && ! $needs_functions; then
        success "Shell configuration already up to date"
        return
    fi

    if $needs_aliases; then
        info "Adding ${#MISSING_ALIASES[@]} missing aliases to $SHELL_CONFIG..."
    else
        info "Adding missing shell configuration to $SHELL_CONFIG..."
    fi

    # Build the additions
    local additions=""
    additions+="\n# >>> autonomous-dev-kit (additive) >>>\n"
    
    if $needs_aliases; then
        for alias_def in "${MISSING_ALIASES[@]}"; do
            local alias_name="${alias_def%%=*}"
            local alias_line
            alias_line=$(get_alias_value "$alias_name")
            if [ -n "$alias_line" ]; then
                additions+="$alias_line\n"
            fi
        done
    fi
    
    # Add zoxide init if not already in config
    if $needs_zoxide; then
        additions+="\n# Zoxide (smart cd) - replaces cd command\n"
        additions+='if command -v zoxide &> /dev/null; then\n'
        additions+='    eval "$(zoxide init zsh --cmd cd 2>/dev/null || zoxide init bash --cmd cd 2>/dev/null)"\n'
        additions+='fi\n'
    fi

    # Add direnv hook if not already in config
    if ! grep -q "direnv hook" "$SHELL_CONFIG" 2>/dev/null; then
        additions+="\n# Direnv (auto-load .envrc)\n"
        additions+='if command -v direnv &> /dev/null; then\n'
        additions+='    eval "$(direnv hook zsh 2>/dev/null || direnv hook bash 2>/dev/null)"\n'
        additions+='fi\n'
    fi
    
    # Add functions source if not already in config
    if $needs_functions; then
        additions+="\n# Source autonomous-dev-kit functions if they exist\n"
        additions+='if [ -f "$HOME/.claude/shell/functions.zsh" ]; then\n'
        additions+='    source "$HOME/.claude/shell/functions.zsh"\n'
        additions+='fi\n'
    fi
    
    additions+="# <<< autonomous-dev-kit (additive) <<<\n"

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would append to $SHELL_CONFIG:"
        echo -e "$additions"
    else
        echo -e "$additions" >> "$SHELL_CONFIG"
    fi
    
    success "Added missing shell configuration"
}

# -----------------------------------------------------------------------------
# Directory Setup
# -----------------------------------------------------------------------------

install_file_with_prompt() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ ! -f "$src" ]; then
        warn "$label source not found at $src"
        return
    fi

    if [ -f "$dest" ]; then
        if prompt_overwrite "$label" "$dest"; then
            prompt_backup_file "$dest" "$label"
            run cp "$src" "$dest"
            success "Updated $label"
        else
            success "Keeping existing $label"
        fi
    else
        run cp "$src" "$dest"
        success "Installed $label"
    fi
}

install_dir_with_prompt() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local dest_parent
    dest_parent="$(dirname "$dest")"

    if [ ! -d "$src" ]; then
        warn "$label source not found at $src"
        return
    fi

    if [ ! -d "$dest_parent" ]; then
        run mkdir -p "$dest_parent"
    fi

    if [ -d "$dest" ]; then
        if prompt_overwrite "$label" "$dest"; then
            prompt_backup_dir "$dest" "$label"
            run rm -rf "$dest"
            run cp -R "$src" "$dest"
            success "Updated $label"
        else
            success "Keeping existing $label"
        fi
    else
        run cp -R "$src" "$dest"
        success "Installed $label"
    fi
}

setup_claude_directory() {
    local claude_dir="$HOME/.claude"
    local kit_dir="$claude_dir/autonomous-dev-kit"
    local templates_src="$SCRIPT_DIR/templates"
    local templates_dest="$kit_dir/templates"
    local skills_src="$SCRIPT_DIR/skills"
    local skills_dest="$claude_dir/skills"

    # Skip if tools_only mode
    if [ "$INSTALL_MODE" = "tools_only" ]; then
        info "Skipping ~/.claude setup (tools only mode)"
        return
    fi

    # Always ensure directories exist
    info "Setting up $claude_dir directory..."
    run mkdir -p "$claude_dir/shell"
    run mkdir -p "$claude_dir/hooks"
    run mkdir -p "$claude_dir/lib"
    run mkdir -p "$claude_dir/learnings"
    run mkdir -p "$claude_dir/handoffs"
    run mkdir -p "$claude_dir/skills"
    run mkdir -p "$claude_dir/agents"
    run mkdir -p "$claude_dir/rules"
    run mkdir -p "$claude_dir/autonomous-loop"
    run mkdir -p "$kit_dir"

    if [ "$INSTALL_MODE" = "full" ]; then
        setup_claude_directory_full
    else
        setup_claude_directory_additive
    fi
}

setup_claude_directory_full() {
    local claude_dir="$HOME/.claude"
    local kit_dir="$claude_dir/autonomous-dev-kit"
    local templates_src="$SCRIPT_DIR/templates"
    local templates_dest="$kit_dir/templates"
    local skills_src="$SCRIPT_DIR/skills"
    local skills_dest="$claude_dir/skills"

    info "Installing all ~/.claude files (full mode)..."

    # Backup and overwrite each file
    install_file_with_prompt "$SCRIPT_DIR/templates/CLAUDE.md" "$claude_dir/CLAUDE.md" "global CLAUDE.md"
    install_file_with_prompt "$SCRIPT_DIR/shell/functions.zsh" "$claude_dir/shell/functions.zsh" "shell functions"
    install_file_with_prompt "$SCRIPT_DIR/shell/aliases.zsh" "$claude_dir/shell/aliases.zsh" "shell aliases"
    install_dir_with_prompt "$templates_src" "$templates_dest" "templates"

    # Install skills
    if [ -d "$skills_src" ]; then
        info "Installing skills..."
        for skill_dir in "$skills_src"/*/; do
            if [ -d "$skill_dir" ]; then
                local skill_name=$(basename "$skill_dir")
                install_dir_with_prompt "$skill_dir" "$skills_dest/$skill_name" "skill: $skill_name"
            fi
        done
        # Clean up legacy single-file skill format
        if [ -f "$skills_dest/autonomous-loop.md" ]; then
            prompt_backup_file "$skills_dest/autonomous-loop.md" "legacy autonomous-loop.md"
            run rm "$skills_dest/autonomous-loop.md"
            success "Removed legacy autonomous-loop.md (replaced by autonomous-loop/ directory)"
        fi

        # Clean up deprecated skills (converted to agents/rules)
        local deprecated_skills=(
            "systematic-debugging"
            "test-driven-development"
            "executing-plans"
            "slop-cleanup"
            "defense-in-depth"
            "root-cause-tracing"
            "dispatching-parallel-agents"
            "subagent-driven-development"
            "testing-anti-patterns"
            "verification-before-completion"
            "condition-based-waiting"
        )
        for skill in "${deprecated_skills[@]}"; do
            if [ -d "$skills_dest/$skill" ]; then
                prompt_backup_dir "$skills_dest/$skill" "deprecated skill: $skill"
                run rm -rf "$skills_dest/$skill"
                success "Removed deprecated skill: $skill (converted to agent/rule)"
            fi
        done
    fi

    # Install agents
    local agents_src="$SCRIPT_DIR/agents"
    local agents_dest="$claude_dir/agents"
    if [ -d "$agents_src" ]; then
        info "Installing agents..."
        for agent_file in "$agents_src"/*.md; do
            if [ -f "$agent_file" ]; then
                local agent_name=$(basename "$agent_file")
                install_file_with_prompt "$agent_file" "$agents_dest/$agent_name" "agent: $agent_name"
            fi
        done
    fi

    # Install rules
    local rules_src="$SCRIPT_DIR/rules"
    local rules_dest="$claude_dir/rules"
    if [ -d "$rules_src" ]; then
        info "Installing rules..."
        for rule_file in "$rules_src"/*.md; do
            if [ -f "$rule_file" ]; then
                local rule_name=$(basename "$rule_file")
                install_file_with_prompt "$rule_file" "$rules_dest/$rule_name" "rule: $rule_name"
            fi
        done
    fi

    # Install hooks
    install_file_with_prompt "$SCRIPT_DIR/hooks/pre-compact.sh" "$claude_dir/hooks/pre-compact.sh" "pre-compact hook"
    install_file_with_prompt "$SCRIPT_DIR/hooks/session-start.sh" "$claude_dir/hooks/session-start.sh" "session-start hook"
    install_file_with_prompt "$SCRIPT_DIR/hooks/user-prompt-submit.sh" "$claude_dir/hooks/user-prompt-submit.sh" "user-prompt-submit hook"
    install_file_with_prompt "$SCRIPT_DIR/hooks/stop.sh" "$claude_dir/hooks/stop.sh" "stop hook"

    # Install lib files for autonomous loop
    install_file_with_prompt "$SCRIPT_DIR/hooks/lib/loop-helpers.sh" "$claude_dir/lib/loop-helpers.sh" "loop helpers library"
    install_file_with_prompt "$SCRIPT_DIR/hooks/lib/cheatsheet.md" "$claude_dir/lib/cheatsheet.md" "autonomous loop cheatsheet"

    # Make hooks executable
    if [ -f "$claude_dir/hooks/pre-compact.sh" ]; then
        run chmod +x "$claude_dir/hooks/pre-compact.sh"
    fi
    if [ -f "$claude_dir/hooks/session-start.sh" ]; then
        run chmod +x "$claude_dir/hooks/session-start.sh"
    fi
    if [ -f "$claude_dir/hooks/user-prompt-submit.sh" ]; then
        run chmod +x "$claude_dir/hooks/user-prompt-submit.sh"
    fi
    if [ -f "$claude_dir/hooks/stop.sh" ]; then
        run chmod +x "$claude_dir/hooks/stop.sh"
    fi
}

setup_claude_directory_additive() {
    local claude_dir="$HOME/.claude"
    local kit_dir="$claude_dir/autonomous-dev-kit"
    local templates_src="$SCRIPT_DIR/templates"
    local templates_dest="$kit_dir/templates"
    local skills_src="$SCRIPT_DIR/skills"
    local skills_dest="$claude_dir/skills"

    # Always install missing skills, even if other files exist
    local skills_installed=0
    local skills_updated=0
    local skills_skipped=0
    if [ -d "$skills_src" ]; then
        local updated_skills=()
        for skill_dir in "$skills_src"/*/; do
            if [ -d "$skill_dir" ]; then
                local skill_name=$(basename "$skill_dir")
                local dest_dir="$skills_dest/$skill_name"
                if [ ! -d "$dest_dir" ]; then
                    run cp -R "$skill_dir" "$dest_dir"
                    success "Installed skill: $skill_name"
                    skills_installed=$((skills_installed + 1))
                else
                    if diff -qr "$skill_dir" "$dest_dir" > /dev/null 2>&1; then
                        continue
                    else
                        local diff_status=$?
                        if [ $diff_status -eq 1 ]; then
                            updated_skills+=("$skill_name")
                        else
                            warn "Failed to compare skill: $skill_name"
                        fi
                    fi
                fi
            fi
        done

        if [ ${#updated_skills[@]} -gt 0 ]; then
            info "Skills with updates available:"
            for skill_name in "${updated_skills[@]}"; do
                echo "  - $skill_name"
            done
            local update_choice=""
            if $DRY_RUN; then
                info "DRY-RUN: would prompt to update ${#updated_skills[@]} skills"
                update_choice="none"
            elif [ ! -t 0 ] || [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
                info "Non-interactive mode: skipping skill updates"
                update_choice="none"
            else
                local response=""
                while true; do
                    read -r -p "Update all skills? [Y/n/i for individual] " response
                    case "$response" in
                        ""|[yY]|[yY][eE][sS]) update_choice="all"; break ;;
                        [nN]|[nN][oO]) update_choice="none"; break ;;
                        [iI]|[iI][nN][dD][iI][vV][iI][dD][uU][aA][lL]) update_choice="individual"; break ;;
                        *) echo "Please answer yes, no, or individual." ;;
                    esac
                done
            fi

            if [ "$update_choice" = "none" ]; then
                for skill_name in "${updated_skills[@]}"; do
                    success "Keeping existing skill: $skill_name"
                    skills_skipped=$((skills_skipped + 1))
                done
            elif [ "$update_choice" = "all" ]; then
                # Ask once for all skills
                prompt_batch_backup "skills" "${#updated_skills[@]}"
                for skill_name in "${updated_skills[@]}"; do
                    local dest_dir="$skills_dest/$skill_name"
                    local src_dir="$skills_src/$skill_name"
                    if [ "$BATCH_BACKUP_CHOICE" = "yes" ]; then
                        backup_dir "$dest_dir"
                    fi
                    run rm -rf "$dest_dir"
                    run cp -R "$src_dir" "$dest_dir"
                    success "Updated skill: $skill_name"
                    skills_updated=$((skills_updated + 1))
                done
            else
                for skill_name in "${updated_skills[@]}"; do
                    local dest_dir="$skills_dest/$skill_name"
                    local src_dir="$skills_src/$skill_name"
                    if prompt_overwrite "skill: $skill_name" "$dest_dir"; then
                        prompt_backup_dir "$dest_dir" "skill: $skill_name"
                        run rm -rf "$dest_dir"
                        run cp -R "$src_dir" "$dest_dir"
                        success "Updated skill: $skill_name"
                        skills_updated=$((skills_updated + 1))
                    else
                        success "Keeping existing skill: $skill_name"
                        skills_skipped=$((skills_skipped + 1))
                    fi
                done
            fi
        fi
        # Clean up legacy single-file skill format
        if [ -f "$skills_dest/autonomous-loop.md" ]; then
            prompt_backup_file "$skills_dest/autonomous-loop.md" "legacy autonomous-loop.md"
            run rm "$skills_dest/autonomous-loop.md"
            success "Removed legacy autonomous-loop.md (replaced by autonomous-loop/ directory)"
        fi

        # Clean up deprecated skills (converted to agents/rules)
        local deprecated_skills=(
            "systematic-debugging"
            "test-driven-development"
            "executing-plans"
            "slop-cleanup"
            "defense-in-depth"
            "root-cause-tracing"
            "dispatching-parallel-agents"
            "subagent-driven-development"
            "testing-anti-patterns"
            "verification-before-completion"
            "condition-based-waiting"
        )
        for skill in "${deprecated_skills[@]}"; do
            if [ -d "$skills_dest/$skill" ]; then
                prompt_backup_dir "$skills_dest/$skill" "deprecated skill: $skill"
                run rm -rf "$skills_dest/$skill"
                success "Removed deprecated skill: $skill (converted to agent/rule)"
            fi
        done

        if [ $skills_installed -eq 0 ] && [ $skills_updated -eq 0 ] && [ $skills_skipped -eq 0 ]; then
            success "All skills already installed"
        else
            if [ $skills_installed -gt 0 ]; then
                success "Installed $skills_installed skills"
            fi
            if [ $skills_updated -gt 0 ]; then
                success "Updated $skills_updated skills"
            fi
            if [ $skills_skipped -gt 0 ]; then
                success "Skipped $skills_skipped skills"
            fi
        fi
    fi

    # Install missing agents
    local agents_src="$SCRIPT_DIR/agents"
    local agents_dest="$claude_dir/agents"
    local agents_installed=0
    local agents_updated=0
    local agents_skipped=0
    if [ -d "$agents_src" ]; then
        local updated_agents=()
        for agent_file in "$agents_src"/*.md; do
            if [ -f "$agent_file" ]; then
                local agent_name=$(basename "$agent_file")
                local dest_file="$agents_dest/$agent_name"
                if [ ! -f "$dest_file" ]; then
                    run cp "$agent_file" "$dest_file"
                    success "Installed agent: $agent_name"
                    agents_installed=$((agents_installed + 1))
                else
                    if diff -q "$agent_file" "$dest_file" > /dev/null 2>&1; then
                        continue
                    else
                        local diff_status=$?
                        if [ $diff_status -eq 1 ]; then
                            updated_agents+=("$agent_name")
                        else
                            warn "Failed to compare agent: $agent_name"
                        fi
                    fi
                fi
            fi
        done

        if [ ${#updated_agents[@]} -gt 0 ]; then
            info "Agents with updates available:"
            for agent_name in "${updated_agents[@]}"; do
                echo "  - $agent_name"
            done
            local update_choice=""
            if $DRY_RUN; then
                info "DRY-RUN: would prompt to update ${#updated_agents[@]} agents"
                update_choice="none"
            elif [ ! -t 0 ] || [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
                info "Non-interactive mode: skipping agent updates"
                update_choice="none"
            else
                local response=""
                while true; do
                    read -r -p "Update all agents? [Y/n/i for individual] " response
                    case "$response" in
                        ""|[yY]|[yY][eE][sS]) update_choice="all"; break ;;
                        [nN]|[nN][oO]) update_choice="none"; break ;;
                        [iI]|[iI][nN][dD][iI][vV][iI][dD][uU][aA][lL]) update_choice="individual"; break ;;
                        *) echo "Please answer yes, no, or individual." ;;
                    esac
                done
            fi

            if [ "$update_choice" = "none" ]; then
                for agent_name in "${updated_agents[@]}"; do
                    success "Keeping existing agent: $agent_name"
                    agents_skipped=$((agents_skipped + 1))
                done
            elif [ "$update_choice" = "all" ]; then
                # Ask once for all agents
                prompt_batch_backup "agents" "${#updated_agents[@]}"
                for agent_name in "${updated_agents[@]}"; do
                    local src_file="$agents_src/$agent_name"
                    local dest_file="$agents_dest/$agent_name"
                    if [ "$BATCH_BACKUP_CHOICE" = "yes" ]; then
                        backup_file "$dest_file"
                    fi
                    run cp "$src_file" "$dest_file"
                    success "Updated agent: $agent_name"
                    agents_updated=$((agents_updated + 1))
                done
            else
                for agent_name in "${updated_agents[@]}"; do
                    local src_file="$agents_src/$agent_name"
                    local dest_file="$agents_dest/$agent_name"
                    if prompt_overwrite "agent: $agent_name" "$dest_file"; then
                        prompt_backup_file "$dest_file" "agent: $agent_name"
                        run cp "$src_file" "$dest_file"
                        success "Updated agent: $agent_name"
                        agents_updated=$((agents_updated + 1))
                    else
                        success "Keeping existing agent: $agent_name"
                        agents_skipped=$((agents_skipped + 1))
                    fi
                done
            fi
        fi

        if [ $agents_installed -eq 0 ] && [ $agents_updated -eq 0 ] && [ $agents_skipped -eq 0 ]; then
            success "All agents already installed"
        else
            if [ $agents_installed -gt 0 ]; then
                success "Installed $agents_installed agents"
            fi
            if [ $agents_updated -gt 0 ]; then
                success "Updated $agents_updated agents"
            fi
            if [ $agents_skipped -gt 0 ]; then
                success "Skipped $agents_skipped agents"
            fi
        fi
    fi

    # Install missing rules
    local rules_src="$SCRIPT_DIR/rules"
    local rules_dest="$claude_dir/rules"
    local rules_installed=0
    if [ -d "$rules_src" ]; then
        for rule_file in "$rules_src"/*.md; do
            if [ -f "$rule_file" ]; then
                local rule_name=$(basename "$rule_file")
                if [ ! -f "$rules_dest/$rule_name" ]; then
                    run cp "$rule_file" "$rules_dest/$rule_name"
                    success "Installed rule: $rule_name"
                    rules_installed=$((rules_installed + 1))
                fi
            fi
        done
        if [ $rules_installed -eq 0 ]; then
            success "All rules already installed"
        else
            success "Installed $rules_installed rules"
        fi
    fi

    if [ ${#MISSING_FILES[@]} -eq 0 ]; then
        success "All ~/.claude files already exist"
        if [ "$INSTALL_MODE" != "update" ]; then
            return
        fi
    else
        info "Installing ${#MISSING_FILES[@]} missing files (additive mode)..."

        # Only install files that don't exist
        for file_path in "${MISSING_FILES[@]}"; do
            case "$file_path" in
                *"/CLAUDE.md")
                    if [ -f "$SCRIPT_DIR/templates/CLAUDE.md" ]; then
                        run cp "$SCRIPT_DIR/templates/CLAUDE.md" "$claude_dir/CLAUDE.md"
                        success "Installed global CLAUDE.md"
                    fi
                    ;;
                *"/functions.zsh")
                    if [ -f "$SCRIPT_DIR/shell/functions.zsh" ]; then
                        run cp "$SCRIPT_DIR/shell/functions.zsh" "$claude_dir/shell/functions.zsh"
                        success "Installed shell functions"
                    fi
                    ;;
                *"/aliases.zsh")
                    if [ -f "$SCRIPT_DIR/shell/aliases.zsh" ]; then
                        run cp "$SCRIPT_DIR/shell/aliases.zsh" "$claude_dir/shell/aliases.zsh"
                        success "Installed shell aliases"
                    fi
                    ;;
                *"/pre-compact.sh")
                    if [ -f "$SCRIPT_DIR/hooks/pre-compact.sh" ]; then
                        run cp "$SCRIPT_DIR/hooks/pre-compact.sh" "$claude_dir/hooks/pre-compact.sh"
                        run chmod +x "$claude_dir/hooks/pre-compact.sh"
                        success "Installed pre-compact hook"
                    fi
                    ;;
                *"/session-start.sh")
                    if [ -f "$SCRIPT_DIR/hooks/session-start.sh" ]; then
                        run cp "$SCRIPT_DIR/hooks/session-start.sh" "$claude_dir/hooks/session-start.sh"
                        run chmod +x "$claude_dir/hooks/session-start.sh"
                        success "Installed session-start hook"
                    fi
                    ;;
                *"/user-prompt-submit.sh")
                    if [ -f "$SCRIPT_DIR/hooks/user-prompt-submit.sh" ]; then
                        run cp "$SCRIPT_DIR/hooks/user-prompt-submit.sh" "$claude_dir/hooks/user-prompt-submit.sh"
                        run chmod +x "$claude_dir/hooks/user-prompt-submit.sh"
                        success "Installed user-prompt-submit hook"
                    fi
                    ;;
                *"/stop.sh")
                    if [ -f "$SCRIPT_DIR/hooks/stop.sh" ]; then
                        run cp "$SCRIPT_DIR/hooks/stop.sh" "$claude_dir/hooks/stop.sh"
                        run chmod +x "$claude_dir/hooks/stop.sh"
                        success "Installed stop hook"
                    fi
                    ;;
                *"/loop-helpers.sh")
                    if [ -f "$SCRIPT_DIR/hooks/lib/loop-helpers.sh" ]; then
                        run cp "$SCRIPT_DIR/hooks/lib/loop-helpers.sh" "$claude_dir/lib/loop-helpers.sh"
                        success "Installed loop helpers library"
                    fi
                    ;;
                *"/cheatsheet.md")
                    if [ -f "$SCRIPT_DIR/hooks/lib/cheatsheet.md" ]; then
                        run cp "$SCRIPT_DIR/hooks/lib/cheatsheet.md" "$claude_dir/lib/cheatsheet.md"
                        success "Installed autonomous loop cheatsheet"
                    fi
                    ;;
                *"/templates")
                    if [ -d "$templates_src" ]; then
                        run cp -R "$templates_src" "$templates_dest"
                        success "Installed templates"
                    fi
                    ;;
            esac
        done
    fi

    if [ "$INSTALL_MODE" != "update" ]; then
        return
    fi

    if [ ${#OUTDATED_ITEMS[@]} -eq 0 ]; then
        success "All managed files already up to date"
        return
    fi

    info "Updating ${#OUTDATED_ITEMS[@]} existing files (update mode)..."
    for item in "${OUTDATED_ITEMS[@]}"; do
        local kind label src dest
        IFS='|' read -r kind label src dest <<< "$item"
        if [ "$kind" = "dir" ]; then
            install_dir_with_prompt "$src" "$dest" "$label"
        else
            install_file_with_prompt "$src" "$dest" "$label"
        fi
    done
}

# -----------------------------------------------------------------------------
# Hook Configuration
# -----------------------------------------------------------------------------

configure_hooks() {
    local settings_file="$HOME/.claude/settings.json"

    # Skip if tools_only mode
    if [ "$INSTALL_MODE" = "tools_only" ]; then
        info "Skipping hook configuration (tools only mode)"
        return
    fi

    # Use $HOME expanded path (not ~) for reliable execution
    local hook_path_precompact="$HOME/.claude/hooks/pre-compact.sh"
    local hook_path_sessionstart="$HOME/.claude/hooks/session-start.sh"
    local hook_path_userprompt="$HOME/.claude/hooks/user-prompt-submit.sh"
    local hook_path_stop="$HOME/.claude/hooks/stop.sh"
    local configure_stop_hook=true

    if ! use_legacy_stop_hook; then
        configure_stop_hook=false
    fi

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would configure hooks in $settings_file"
        return
    fi

    if [ "$INSTALL_MODE" = "full" ]; then
        configure_hooks_full "$settings_file" "$hook_path_precompact" "$hook_path_sessionstart" "$hook_path_userprompt" "$hook_path_stop" "$configure_stop_hook"
    else
        configure_hooks_additive "$settings_file" "$hook_path_precompact" "$hook_path_sessionstart" "$hook_path_userprompt" "$hook_path_stop" "$configure_stop_hook"
    fi
}

configure_hooks_full() {
    local settings_file="$1"
    local hook_path_precompact="$2"
    local hook_path_sessionstart="$3"
    local hook_path_userprompt="$4"
    local hook_path_stop="$5"
    local configure_stop_hook="$6"

    info "Configuring hooks (full mode)..."

    # Check if settings file exists and is valid JSON
    if [ -f "$settings_file" ]; then
        if ! jq empty "$settings_file" 2>/dev/null; then
            warn "Existing settings.json is invalid JSON, backing up and creating fresh"
            backup_file "$settings_file"
            rm "$settings_file"
        else
            backup_file "$settings_file"
            # Replace the hooks section entirely while preserving other settings
            if $configure_stop_hook; then
                jq --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" --arg user "$hook_path_userprompt" --arg stop "$hook_path_stop" '
                    .respectGitignore = (if .respectGitignore == null then true else .respectGitignore end) |
                    .hooks.PreCompact = [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}] |
                    .hooks.SessionStart = [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}] |
                    .hooks.UserPromptSubmit = [{"matcher": "", "hooks": [{"type": "command", "command": $user}]}] |
                    .hooks.Stop = [{"matcher": "", "hooks": [{"type": "command", "command": $stop}]}]
                ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            else
                jq --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" --arg user "$hook_path_userprompt" '
                    .respectGitignore = (if .respectGitignore == null then true else .respectGitignore end) |
                    .hooks.PreCompact = [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}] |
                    .hooks.SessionStart = [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}] |
                    .hooks.UserPromptSubmit = [{"matcher": "", "hooks": [{"type": "command", "command": $user}]}] |
                    del(.hooks.Stop)
                ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            fi
            success "Replaced hooks in settings.json"
            return
        fi
    fi

    # Create new settings file
    if $configure_stop_hook; then
        jq -n --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" --arg user "$hook_path_userprompt" --arg stop "$hook_path_stop" '{
            "respectGitignore": true,
            "hooks": {
                "PreCompact": [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}],
                "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}],
                "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": $user}]}],
                "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": $stop}]}]
            }
        }' > "$settings_file"
    else
        jq -n --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" --arg user "$hook_path_userprompt" '{
            "respectGitignore": true,
            "hooks": {
                "PreCompact": [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}],
                "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}],
                "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": $user}]}]
            }
        }' > "$settings_file"
    fi
    success "Created settings.json with hooks"
}

configure_hooks_additive() {
    local settings_file="$1"
    local hook_path_precompact="$2"
    local hook_path_sessionstart="$3"
    local hook_path_userprompt="$4"
    local hook_path_stop="$5"
    local configure_stop_hook="$6"
    local needs_respect_gitignore=false

    # Check if settings file exists and is valid JSON
    if [ -f "$settings_file" ]; then
        if ! jq empty "$settings_file" 2>/dev/null; then
            warn "Existing settings.json is invalid JSON, backing up and creating fresh"
            backup_file "$settings_file"
            rm "$settings_file"
        fi
    fi

    if [ -f "$settings_file" ] && command_exists jq; then
        if ! jq -e '.respectGitignore != null' "$settings_file" > /dev/null 2>&1; then
            needs_respect_gitignore=true
        fi
    fi

    if [ $MISSING_HOOKS -eq 0 ] && ! $needs_respect_gitignore; then
        success "All hooks already configured"
        return
    fi

    if [ $MISSING_HOOKS -eq 0 ] && $needs_respect_gitignore; then
        info "Setting respectGitignore default (additive mode)..."
        backup_file "$settings_file"
        jq '
            .respectGitignore = (if .respectGitignore == null then true else .respectGitignore end)
        ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
        success "Set respectGitignore in settings.json"
        return
    fi

    info "Adding ${MISSING_HOOKS} missing hooks (additive mode)..."

    if [ -f "$settings_file" ]; then
        # Guard: ensure .hooks exists and is an object (not array or other type)
        local hooks_type
        hooks_type=$(jq -r '.hooks | type // "null"' "$settings_file" 2>/dev/null || echo "null")
        if [ "$hooks_type" != "object" ] && [ "$hooks_type" != "null" ]; then
            warn "settings.json has malformed .hooks (type: $hooks_type), backing up and recreating hooks section"
            backup_file "$settings_file"
            # Reset .hooks to empty object
            jq '.hooks = {}' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
        fi

        # Check which specific hooks need to be added (handle both single-object and array formats)
        local needs_precompact=true
        local needs_sessionstart=true
        local needs_userprompt=true
        local needs_stop=true
        if ! $configure_stop_hook; then
            needs_stop=false
        fi

        if jq -e --arg cmd "$hook_path_precompact" '
            (.hooks.PreCompact // []) |
            if type == "array" then . else [.] end |
            .[].hooks[]? | select(.command == $cmd)
        ' "$settings_file" > /dev/null 2>&1; then
            needs_precompact=false
        fi
        if jq -e --arg cmd "$hook_path_sessionstart" '
            (.hooks.SessionStart // []) |
            if type == "array" then . else [.] end |
            .[].hooks[]? | select(.command == $cmd)
        ' "$settings_file" > /dev/null 2>&1; then
            needs_sessionstart=false
        fi
        if jq -e --arg cmd "$hook_path_userprompt" '
            (.hooks.UserPromptSubmit // []) |
            if type == "array" then . else [.] end |
            .[].hooks[]? | select(.command == $cmd)
        ' "$settings_file" > /dev/null 2>&1; then
            needs_userprompt=false
        fi
        if $configure_stop_hook; then
            if jq -e --arg cmd "$hook_path_stop" '
                (.hooks.Stop // []) |
                if type == "array" then . else [.] end |
                .[].hooks[]? | select(.command == $cmd)
            ' "$settings_file" > /dev/null 2>&1; then
                needs_stop=false
            fi
        fi

        if ! $needs_precompact && ! $needs_sessionstart && ! $needs_userprompt && ! $needs_stop; then
            success "Our hooks already configured in settings.json"
            return
        fi

        backup_file "$settings_file"

        # Add missing hooks while preserving existing ones
        # Note: We normalize single-object hooks to arrays before appending
        if $needs_precompact; then
            # Normalize to array if single object, then append
            jq --arg cmd "$hook_path_precompact" '
                .respectGitignore = (if .respectGitignore == null then true else .respectGitignore end) |
                .hooks.PreCompact = (
                    if .hooks.PreCompact == null then []
                    elif (.hooks.PreCompact | type) == "array" then .hooks.PreCompact
                    else [.hooks.PreCompact]
                    end
                ) + [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]
            ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            success "Added PreCompact hook"
        fi

        if $needs_sessionstart; then
            # Normalize to array if single object, then append
            jq --arg cmd "$hook_path_sessionstart" '
                .respectGitignore = (if .respectGitignore == null then true else .respectGitignore end) |
                .hooks.SessionStart = (
                    if .hooks.SessionStart == null then []
                    elif (.hooks.SessionStart | type) == "array" then .hooks.SessionStart
                    else [.hooks.SessionStart]
                    end
                ) + [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]
            ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            success "Added SessionStart hook"
        fi

        if $needs_userprompt; then
            # Normalize to array if single object, then append
            jq --arg cmd "$hook_path_userprompt" '
                .respectGitignore = (if .respectGitignore == null then true else .respectGitignore end) |
                .hooks.UserPromptSubmit = (
                    if .hooks.UserPromptSubmit == null then []
                    elif (.hooks.UserPromptSubmit | type) == "array" then .hooks.UserPromptSubmit
                    else [.hooks.UserPromptSubmit]
                    end
                ) + [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]
            ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            success "Added UserPromptSubmit hook"
        fi

        if $needs_stop; then
            # Normalize to array if single object, then append
            jq --arg cmd "$hook_path_stop" '
                .respectGitignore = (if .respectGitignore == null then true else .respectGitignore end) |
                .hooks.Stop = (
                    if .hooks.Stop == null then []
                    elif (.hooks.Stop | type) == "array" then .hooks.Stop
                    else [.hooks.Stop]
                    end
                ) + [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]
            ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            success "Added Stop hook"
        fi
    else
        # Create new settings file with hooks
        if $configure_stop_hook; then
            jq -n --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" --arg user "$hook_path_userprompt" --arg stop "$hook_path_stop" '{
                "respectGitignore": true,
                "hooks": {
                    "PreCompact": [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}],
                    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}],
                    "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": $user}]}],
                    "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": $stop}]}]
                }
            }' > "$settings_file"
        else
            jq -n --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" --arg user "$hook_path_userprompt" '{
                "respectGitignore": true,
                "hooks": {
                    "PreCompact": [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}],
                    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}],
                    "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": $user}]}]
                }
            }' > "$settings_file"
        fi
        success "Created settings.json with hooks"
    fi
}


# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------

verify_installation() {
    echo ""
    info "Verifying installation..."
    echo ""

    local all_good=true

    # Check CLI tools
    local tools=("fd" "fzf" "bat" "delta" "zoxide" "jq" "yq" "sd" "rg" "entr" "mise" "direnv" "uv")
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            success "$tool installed"
        else
            warn "$tool not found"
            all_good=false
        fi
    done

    # Check Node.js
    if command_exists node; then
        success "Node.js $(node -v)"
    else
        error "Node.js not found"
        all_good=false
    fi

    # Check Claude Code
    if command_exists claude; then
        success "Claude Code CLI installed"
    else
        warn "Claude Code CLI not found (run: npm install -g @anthropic-ai/claude-code)"
        all_good=false
    fi

    # Check directories
    if [ -d "$HOME/.claude" ]; then
        success "$HOME/.claude directory exists"
    else
        warn "$HOME/.claude directory not found"
    fi

    # Check skills (only count kit skills, not plugins/other sources)
    local skills_dir="$HOME/.claude/skills"
    local skills_src="$SCRIPT_DIR/skills"
    if [ -d "$skills_dir" ] && [ -d "$skills_src" ]; then
        local kit_skills_total=0
        local kit_skills_installed=0
        local missing_skills=()
        for skill_dir in "$skills_src"/*/; do
            if [ -d "$skill_dir" ]; then
                kit_skills_total=$((kit_skills_total + 1))
                local skill_name=$(basename "$skill_dir")
                if [ -d "$skills_dir/$skill_name" ]; then
                    kit_skills_installed=$((kit_skills_installed + 1))
                else
                    missing_skills+=("$skill_name")
                fi
            fi
        done
        if [ $kit_skills_installed -eq $kit_skills_total ]; then
            success "$kit_skills_installed/$kit_skills_total kit skills installed"
        else
            warn "$kit_skills_installed/$kit_skills_total kit skills installed"
            for missing in "${missing_skills[@]}"; do
                warn "  missing: $missing"
            done
            all_good=false
        fi
    else
        warn "Skills directory not found"
        all_good=false
    fi

    # Check agents (only count kit agents)
    local agents_dir="$HOME/.claude/agents"
    local agents_src="$SCRIPT_DIR/agents"
    if [ -d "$agents_dir" ] && [ -d "$agents_src" ]; then
        local kit_agents_total=0
        local kit_agents_installed=0
        local missing_agents=()
        for agent_file in "$agents_src"/*.md; do
            if [ -f "$agent_file" ]; then
                kit_agents_total=$((kit_agents_total + 1))
                local agent_name=$(basename "$agent_file")
                if [ -f "$agents_dir/$agent_name" ]; then
                    kit_agents_installed=$((kit_agents_installed + 1))
                else
                    missing_agents+=("$agent_name")
                fi
            fi
        done
        if [ $kit_agents_installed -eq $kit_agents_total ]; then
            success "$kit_agents_installed/$kit_agents_total kit agents installed"
        else
            warn "$kit_agents_installed/$kit_agents_total kit agents installed"
            for missing in "${missing_agents[@]}"; do
                warn "  missing: $missing"
            done
            all_good=false
        fi
    else
        warn "Agents directory not found"
        all_good=false
    fi

    # Check rules (only count kit rules)
    local rules_dir="$HOME/.claude/rules"
    local rules_src="$SCRIPT_DIR/rules"
    if [ -d "$rules_dir" ] && [ -d "$rules_src" ]; then
        local kit_rules_total=0
        local kit_rules_installed=0
        local missing_rules=()
        for rule_file in "$rules_src"/*.md; do
            if [ -f "$rule_file" ]; then
                kit_rules_total=$((kit_rules_total + 1))
                local rule_name=$(basename "$rule_file")
                if [ -f "$rules_dir/$rule_name" ]; then
                    kit_rules_installed=$((kit_rules_installed + 1))
                else
                    missing_rules+=("$rule_name")
                fi
            fi
        done
        if [ $kit_rules_installed -eq $kit_rules_total ]; then
            success "$kit_rules_installed/$kit_rules_total kit rules installed"
        else
            warn "$kit_rules_installed/$kit_rules_total kit rules installed"
            for missing in "${missing_rules[@]}"; do
                warn "  missing: $missing"
            done
            all_good=false
        fi
    else
        warn "Rules directory not found"
        all_good=false
    fi

    echo ""
    if $all_good; then
        success "All components installed successfully!"
    else
        warn "Some components may need attention (see warnings above)"
    fi
}

# -----------------------------------------------------------------------------
# Authentication Note
# -----------------------------------------------------------------------------

auth_note() {
    echo ""
    info "Authentication"
    echo "--------------"
    echo ""
    echo "When you first run 'claude', 'codex', or 'gemini', you'll be prompted to log in."
    echo "Choose whichever method works best for you:"
    echo ""
    echo "  - Subscription login (Claude Pro, Teams, etc.)"
    echo "  - API key (from console.anthropic.com, platform.openai.com, or aistudio.google.com)"
    echo ""
    echo "All tools support interactive login - just follow the prompts."
    echo ""
    echo "Optional CLI installations for cross-agent reviews:"
    echo ""
    echo "  npm install -g @openai/codex        # OpenAI Codex CLI"
    echo "  npm install -g @google/gemini-cli   # Google Gemini CLI"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

usage() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Install CLI tools and configure the autonomous development environment.

Options:
    --mode MODE  Install mode: update, full, additive, tools-only
    --dry-run    Preview changes without applying them
    --help       Show this help message

Examples:
    ./install.sh              # Run full installation
    ./install.sh --dry-run    # Preview what would be done
    ./install.sh --mode=update

EOF
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                info "Running in dry-run mode (no changes will be made)"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            --mode)
                shift
                if [[ $# -eq 0 ]]; then
                    error "Missing value for --mode"
                    usage
                    exit 1
                fi
                local normalized
                normalized=$(normalize_install_mode "$1" || true)
                if [[ -z "$normalized" ]]; then
                    error "Unknown install mode: $1"
                    usage
                    exit 1
                fi
                INSTALL_MODE="$normalized"
                INSTALL_MODE_SOURCE="cli"
                shift
                ;;
            --mode=*)
                local raw="${1#--mode=}"
                local normalized
                normalized=$(normalize_install_mode "$raw" || true)
                if [[ -z "$normalized" ]]; then
                    error "Unknown install mode: $raw"
                    usage
                    exit 1
                fi
                INSTALL_MODE="$normalized"
                INSTALL_MODE_SOURCE="cli"
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    echo ""
    echo "=================================="
    echo "  autonomous-dev-kit installer"
    echo "=================================="
    echo ""

    # Detect OS first (needed for shell config path)
    detect_os
    echo ""

    # Install Homebrew first (needed for jq in detection)
    install_homebrew
    echo ""

    # Run detection and prompt for install mode
    run_detection
    display_detection_summary
    prompt_install_mode
    echo ""

    # Install CLI tools (respects what's already installed)
    install_cli_tools
    echo ""

    # Node.js and Claude Code
    check_nodejs
    install_claude_code
    echo ""

    # Shell configuration (mode-aware)
    if [ "$INSTALL_MODE" = "full" ]; then
        backup_shell_config
    fi
    install_shell_config
    echo ""

    # ~/.claude directory setup (mode-aware)
    setup_claude_directory
    echo ""

    # Hook configuration (mode-aware)
    configure_hooks
    echo ""

    # Verification and wrap-up
    verify_installation

    # Only show auth note if not tools_only mode
    if [ "$INSTALL_MODE" != "tools_only" ]; then
        auth_note
    fi

    echo ""
    echo "=================================="
    echo "  Installation Complete!"
    echo "=================================="
    echo ""
    echo "Next steps:"
    if [ "$INSTALL_MODE" = "tools_only" ]; then
        echo "  1. CLI tools are installed and ready to use"
        echo "  2. Re-run without 'tools only' to set up shell config"
    else
        echo "  1. Restart your terminal (or run: source $SHELL_CONFIG)"
        echo "  2. Run 'claude' and log in (subscription or API key)"
        echo "  3. Run: autonomous-init in a new project directory"
        echo "  4. Follow docs/GETTING_STARTED.md"
    fi
    echo ""
success "Happy building!"
}

if [[ "${INSTALL_LIB_ONLY:-}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi

main "$@"
