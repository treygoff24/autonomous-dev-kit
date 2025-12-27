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
    local tools=("fd" "fzf" "bat" "git-delta" "zoxide" "jq" "yq" "sd" "ripgrep")

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

install_shell_config() {
    local marker="# >>> autonomous-dev-kit >>>"
    local end_marker="# <<< autonomous-dev-kit <<<"

    # Check if already installed
    if [ -f "$SHELL_CONFIG" ] && grep -q "$marker" "$SHELL_CONFIG"; then
        success "Shell configuration already installed in $SHELL_CONFIG"
        return
    fi

    info "Adding shell configuration to $SHELL_CONFIG..."

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

# Zoxide (smart cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh 2>/dev/null || zoxide init bash 2>/dev/null)"
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

    if [ ! -d "$claude_dir" ]; then
        info "Creating $claude_dir directory..."
        run mkdir -p "$claude_dir"
        run mkdir -p "$claude_dir/shell"
        run mkdir -p "$claude_dir/learnings"
        run mkdir -p "$claude_dir/handoffs"
        run mkdir -p "$kit_dir"
    else
        success "$claude_dir already exists"
        run mkdir -p "$claude_dir/shell"
        run mkdir -p "$claude_dir/learnings"
        run mkdir -p "$claude_dir/handoffs"
        run mkdir -p "$kit_dir"
    fi

    install_file_with_prompt "$SCRIPT_DIR/templates/CLAUDE.md" "$claude_dir/CLAUDE.md" "global CLAUDE.md"
    install_file_with_prompt "$SCRIPT_DIR/shell/functions.zsh" "$claude_dir/shell/functions.zsh" "shell functions"
    install_file_with_prompt "$SCRIPT_DIR/shell/aliases.zsh" "$claude_dir/shell/aliases.zsh" "shell aliases"
    install_dir_with_prompt "$templates_src" "$templates_dest" "templates"
}

# -----------------------------------------------------------------------------
# API Keys
# -----------------------------------------------------------------------------

setup_api_keys() {
    echo ""
    info "API Key Setup"
    echo "-------------"

    # Check for existing keys
    local anthropic_set=false
    local openai_set=false

    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        success "ANTHROPIC_API_KEY already set"
        anthropic_set=true
    fi

    if [ -n "${OPENAI_API_KEY:-}" ]; then
        success "OPENAI_API_KEY already set"
        openai_set=true
    fi

    if $anthropic_set && $openai_set; then
        return
    fi

    echo ""
    echo "To use this system, you'll need API keys:"
    echo ""
    echo "  ANTHROPIC_API_KEY - Get from https://console.anthropic.com/"
    echo "  OPENAI_API_KEY    - Get from https://platform.openai.com/"
    echo ""
    echo "Add these to your shell config ($SHELL_CONFIG):"
    echo ""
    echo '  export ANTHROPIC_API_KEY="your-key-here"'
    echo '  export OPENAI_API_KEY="your-key-here"'
    echo ""

    if ! $DRY_RUN; then
        read -p "Press Enter to continue..."
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
    local tools=("fd" "fzf" "bat" "delta" "jq" "yq" "sd" "rg")
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            success "$tool installed"
        else
            warn "$tool not found"
            all_good=false
        fi
    done

    # Check zoxide
    if command_exists zoxide; then
        success "zoxide installed"
    else
        warn "zoxide not found"
        all_good=false
    fi

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

    echo ""
    if $all_good; then
        success "All components installed successfully!"
    else
        warn "Some components may need attention (see warnings above)"
    fi
}

# -----------------------------------------------------------------------------
# Codex CLI Note
# -----------------------------------------------------------------------------

codex_note() {
    echo ""
    info "Codex CLI Setup"
    echo "---------------"
    echo ""
    echo "Codex CLI (OpenAI) installation varies by setup. Common methods:"
    echo ""
    echo "  # Via npm (if available)"
    echo "  npm install -g @openai/codex"
    echo ""
    echo "  # Or check OpenAI's current docs:"
    echo "  https://platform.openai.com/docs/guides/codex"
    echo ""
    echo "The autonomous build protocol will call Codex for cross-agent review."
    echo "Ensure the 'codex' command is available before starting builds."
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

    # Run installation steps
    detect_os
    echo ""

    install_homebrew
    echo ""

    install_cli_tools
    echo ""

    check_nodejs
    install_claude_code
    echo ""

    backup_shell_config
    install_shell_config
    echo ""

    setup_claude_directory
    echo ""

    verify_installation

    setup_api_keys

    codex_note

    echo ""
    echo "=================================="
    echo "  Installation Complete!"
    echo "=================================="
    echo ""
    echo "Next steps:"
    echo "  1. Restart your terminal (or run: source $SHELL_CONFIG)"
    echo "  2. Set your API keys in $SHELL_CONFIG"
    echo "  3. Run: autonomous-init in a new project directory"
    echo "  4. Follow docs/GETTING_STARTED.md"
    echo ""
    success "Happy building!"
}

main "$@"
