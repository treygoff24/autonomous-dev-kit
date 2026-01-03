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

# Install mode: full, additive, tools_only
INSTALL_MODE=""

# Detection results (populated by detect_* functions)
declare -a MISSING_TOOLS=()
declare -a INSTALLED_TOOLS=()
declare -a MISSING_ALIASES=()
declare -a EXISTING_ALIASES=()
declare -a MISSING_FILES=()
declare -a EXISTING_FILES=()
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
        "$HOME/.claude/autonomous-dev-kit/templates"
        "$HOME/.claude/skills"
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

detect_hooks() {
    local settings_file="$HOME/.claude/settings.json"
    local hook_precompact="$HOME/.claude/hooks/pre-compact.sh"
    local hook_sessionstart="$HOME/.claude/hooks/session-start.sh"
    
    MISSING_HOOKS=0
    EXISTING_HOOKS=0
    
    if [ ! -f "$settings_file" ]; then
        MISSING_HOOKS=2
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
        return
    fi

    # Check if settings.json is valid JSON
    if ! jq empty "$settings_file" 2>/dev/null; then
        MISSING_HOOKS=2
        return
    fi

    # Check for PreCompact hook
    if jq -e ".hooks.PreCompact[]?.hooks[]? | select(.command == \"$hook_precompact\")" "$settings_file" > /dev/null 2>&1; then
        EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
    else
        MISSING_HOOKS=$((MISSING_HOOKS + 1))
    fi

    # Check for SessionStart hook
    if jq -e ".hooks.SessionStart[]?.hooks[]? | select(.command == \"$hook_sessionstart\")" "$settings_file" > /dev/null 2>&1; then
        EXISTING_HOOKS=$((EXISTING_HOOKS + 1))
    else
        MISSING_HOOKS=$((MISSING_HOOKS + 1))
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
    
    echo ""
}

prompt_install_mode() {
    # If everything is already installed, just inform and use additive (no-op)
    if [ ${#MISSING_TOOLS[@]} -eq 0 ] && [ ${#MISSING_ALIASES[@]} -eq 0 ] && \
       [ ${#MISSING_FILES[@]} -eq 0 ] && [ $MISSING_HOOKS -eq 0 ]; then
        success "Everything is already installed!"
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
    echo -e "  ${CYAN}[1]${NC} Full install"
    echo "      Backup existing configs, install everything fresh"
    echo ""
    echo -e "  ${CYAN}[2]${NC} Add missing only  ${GREEN}(recommended)${NC}"
    echo "      Install missing tools/aliases, preserve your customizations"
    echo ""
    echo -e "  ${CYAN}[3]${NC} Tools only"
    echo "      Install CLI tools via Homebrew, skip all shell/config changes"
    echo ""
    
    local response=""
    while true; do
        read -r -p "Choice [1/2/3]: " response
        case "$response" in
            1) INSTALL_MODE="full"; break ;;
            2) INSTALL_MODE="additive"; break ;;
            3) INSTALL_MODE="tools_only"; break ;;
            *) echo "Please enter 1, 2, or 3." ;;
        esac
    done
    
    echo ""
    case "$INSTALL_MODE" in
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
        backup_file "$dest"
        if prompt_overwrite "$label" "$dest"; then
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
        backup_dir "$dest"
        if prompt_overwrite "$label" "$dest"; then
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
    run mkdir -p "$claude_dir/learnings"
    run mkdir -p "$claude_dir/handoffs"
    run mkdir -p "$claude_dir/skills"
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
    fi

    # Install hooks
    install_file_with_prompt "$SCRIPT_DIR/hooks/pre-compact.sh" "$claude_dir/hooks/pre-compact.sh" "pre-compact hook"
    install_file_with_prompt "$SCRIPT_DIR/hooks/session-start.sh" "$claude_dir/hooks/session-start.sh" "session-start hook"

    # Make hooks executable
    if [ -f "$claude_dir/hooks/pre-compact.sh" ]; then
        run chmod +x "$claude_dir/hooks/pre-compact.sh"
    fi
    if [ -f "$claude_dir/hooks/session-start.sh" ]; then
        run chmod +x "$claude_dir/hooks/session-start.sh"
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
    if [ -d "$skills_src" ]; then
        for skill_dir in "$skills_src"/*/; do
            if [ -d "$skill_dir" ]; then
                local skill_name=$(basename "$skill_dir")
                if [ ! -d "$skills_dest/$skill_name" ]; then
                    run cp -R "$skill_dir" "$skills_dest/$skill_name"
                    success "Installed skill: $skill_name"
                    skills_installed=$((skills_installed + 1))
                fi
            fi
        done
        if [ $skills_installed -eq 0 ]; then
            success "All skills already installed"
        else
            success "Installed $skills_installed skills"
        fi
    fi

    if [ ${#MISSING_FILES[@]} -eq 0 ]; then
        success "All ~/.claude files already exist"
        return
    fi

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
            *"/templates")
                if [ -d "$templates_src" ]; then
                    run cp -R "$templates_src" "$templates_dest"
                    success "Installed templates"
                fi
                ;;
        esac
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

    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would configure hooks in $settings_file"
        return
    fi

    if [ "$INSTALL_MODE" = "full" ]; then
        configure_hooks_full "$settings_file" "$hook_path_precompact" "$hook_path_sessionstart"
    else
        configure_hooks_additive "$settings_file" "$hook_path_precompact" "$hook_path_sessionstart"
    fi
}

configure_hooks_full() {
    local settings_file="$1"
    local hook_path_precompact="$2"
    local hook_path_sessionstart="$3"

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
            jq --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" '
                .hooks.PreCompact = [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}] |
                .hooks.SessionStart = [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}]
            ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            success "Replaced hooks in settings.json"
            return
        fi
    fi

    # Create new settings file
    jq -n --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" '{
        "hooks": {
            "PreCompact": [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}],
            "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}]
        }
    }' > "$settings_file"
    success "Created settings.json with hooks"
}

configure_hooks_additive() {
    local settings_file="$1"
    local hook_path_precompact="$2"
    local hook_path_sessionstart="$3"

    if [ $MISSING_HOOKS -eq 0 ]; then
        success "All hooks already configured"
        return
    fi

    info "Adding ${MISSING_HOOKS} missing hooks (additive mode)..."

    # Check if settings file exists and is valid JSON
    if [ -f "$settings_file" ]; then
        if ! jq empty "$settings_file" 2>/dev/null; then
            warn "Existing settings.json is invalid JSON, backing up and creating fresh"
            backup_file "$settings_file"
            rm "$settings_file"
        fi
    fi

    if [ -f "$settings_file" ]; then
        # Check which specific hooks need to be added (by our exact command path)
        local needs_precompact=true
        local needs_sessionstart=true

        if jq -e ".hooks.PreCompact[]?.hooks[]? | select(.command == \"$hook_path_precompact\")" "$settings_file" > /dev/null 2>&1; then
            needs_precompact=false
        fi
        if jq -e ".hooks.SessionStart[]?.hooks[]? | select(.command == \"$hook_path_sessionstart\")" "$settings_file" > /dev/null 2>&1; then
            needs_sessionstart=false
        fi

        if ! $needs_precompact && ! $needs_sessionstart; then
            success "Our hooks already configured in settings.json"
            return
        fi

        backup_file "$settings_file"

        # Add missing hooks while preserving existing ones
        if $needs_precompact; then
            # Append to existing PreCompact array or create it
            if jq -e '.hooks.PreCompact' "$settings_file" > /dev/null 2>&1; then
                jq --arg cmd "$hook_path_precompact" \
                    '.hooks.PreCompact += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
                    "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            else
                jq --arg cmd "$hook_path_precompact" \
                    '.hooks.PreCompact = [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
                    "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            fi
            success "Added PreCompact hook"
        fi

        if $needs_sessionstart; then
            # Append to existing SessionStart array or create it
            if jq -e '.hooks.SessionStart' "$settings_file" > /dev/null 2>&1; then
                jq --arg cmd "$hook_path_sessionstart" \
                    '.hooks.SessionStart += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
                    "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            else
                jq --arg cmd "$hook_path_sessionstart" \
                    '.hooks.SessionStart = [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]' \
                    "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
            fi
            success "Added SessionStart hook"
        fi
    else
        # Create new settings file with hooks
        jq -n --arg pre "$hook_path_precompact" --arg sess "$hook_path_sessionstart" '{
            "hooks": {
                "PreCompact": [{"matcher": "", "hooks": [{"type": "command", "command": $pre}]}],
                "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": $sess}]}]
            }
        }' > "$settings_file"
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

    # Check skills
    local skills_dir="$HOME/.claude/skills"
    if [ -d "$skills_dir" ]; then
        local skill_count=$(find "$skills_dir" -maxdepth 1 -type d | wc -l)
        skill_count=$((skill_count - 1))  # Subtract 1 for the directory itself
        if [ $skill_count -gt 0 ]; then
            success "$skill_count skills installed in $skills_dir"
        else
            warn "No skills found in $skills_dir"
        fi
    else
        warn "Skills directory not found"
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
    echo "When you first run 'claude' or 'codex', you'll be prompted to log in."
    echo "Choose whichever method works best for you:"
    echo ""
    echo "  - Subscription login (Claude Pro, Teams, etc.)"
    echo "  - API key (from console.anthropic.com or platform.openai.com)"
    echo ""
    echo "Both tools support interactive login - just follow the prompts."
    echo ""
    echo "Codex CLI (OpenAI) installation if needed:"
    echo ""
    echo "  npm install -g @openai/codex"
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
    --dry-run    Preview changes without applying them
    --help       Show this help message

Examples:
    ./install.sh              # Run full installation
    ./install.sh --dry-run    # Preview what would be done

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

main "$@"
