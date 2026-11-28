#!/usr/bin/env bash
# ── Git configuration ────────────────────────────
# User-specific config goes in ~/.gitconfig_local (NOT the stowed .gitconfig)
set -euo pipefail

info "Configuring git..."

LOCAL_GITCONFIG="$HOME/.gitconfig_local"

if ! git config --file "$LOCAL_GITCONFIG" user.email &>/dev/null; then
    git_name="${DOTFILES_GIT_NAME:-}"
    git_email="${DOTFILES_GIT_EMAIL:-}"
    if interactive; then
        [[ -n "$git_name" ]] || read -rp "Git user name: " git_name
        [[ -n "$git_email" ]] || read -rp "Git user email: " git_email
    fi
    if [[ -n "$git_name" && -n "$git_email" ]]; then
        git config --file "$LOCAL_GITCONFIG" user.name "$git_name"
        git config --file "$LOCAL_GITCONFIG" user.email "$git_email"
        success "Git user config written to ~/.gitconfig_local"
    else
        warn "Skipping ~/.gitconfig_local (set DOTFILES_GIT_NAME and DOTFILES_GIT_EMAIL)"
    fi
else
    success "Git user config already exists (~/.gitconfig_local)"
fi

# Versioned hooks (.githooks/pre-commit runs gitleaks: this repo is public)
git -C "$DOTFILES" config core.hooksPath .githooks
success "Git hooks enabled (.githooks)"
