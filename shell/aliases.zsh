# autonomous-dev-kit shell aliases
# Source this file in your .zshrc or .bashrc

# =============================================================================
# File Discovery and Viewing
# =============================================================================

# fd - faster and friendlier find
alias find='fd'

# bat - syntax highlighted cat
alias cat='bat -n --paging=never'

# delta - better diffs
alias diff='delta'

# =============================================================================
# Git Shortcuts
# =============================================================================

alias gs='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline -20'
alias gla='git log --oneline --all --graph -20'
alias gco='git checkout'
alias gcb='git checkout -b'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpl='git pull'
alias gb='git branch'
alias gbd='git branch -d'
alias gst='git stash'
alias gstp='git stash pop'
alias grb='git rebase'
alias grbi='git rebase -i'

# =============================================================================
# Claude Code Shortcuts
# =============================================================================

# Quick invoke
alias cc='claude'

# Resume last session
alias ccr='claude --resume'

# Claude with specific model (adjust as needed)
alias cco='claude --model opus'
alias ccs='claude --model sonnet'

# =============================================================================
# Zoxide (Smart cd) - replaces cd command
# =============================================================================

# Initialize zoxide if available (--cmd cd replaces the cd command)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh --cmd cd 2>/dev/null || zoxide init bash --cmd cd 2>/dev/null)"
fi

# =============================================================================
# Direnv (Auto-load .envrc)
# =============================================================================

# Initialize direnv if available
if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh 2>/dev/null || direnv hook bash 2>/dev/null)"
fi

# =============================================================================
# Development Shortcuts
# =============================================================================

# npm shortcuts
alias ni='npm install'
alias nid='npm install --save-dev'
alias nr='npm run'
alias nrd='npm run dev'
alias nrb='npm run build'
alias nrt='npm run test'
alias nrl='npm run lint'

# pnpm shortcuts (if you prefer pnpm)
alias pi='pnpm install'
alias pid='pnpm add -D'
alias pr='pnpm run'
alias prd='pnpm dev'
alias prb='pnpm build'
alias prt='pnpm test'
alias prl='pnpm lint'

# =============================================================================
# Quick Navigation
# =============================================================================

# Go to common directories (customize these)
alias cdc='cd ~/Code'
alias cdp='cd ~/Projects'
alias cdd='cd ~/Downloads'

# Quick back navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# =============================================================================
# Utility
# =============================================================================

# Colorized grep
alias grep='grep --color=auto'

# Human-readable disk usage
alias df='df -h'
alias du='du -h'

# Safe rm (interactive for multiple files)
alias rm='rm -i'

# Make directories with parents
alias mkdir='mkdir -p'

# Clear terminal
alias c='clear'
