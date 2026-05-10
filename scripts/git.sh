#!/usr/bin/env bash
# ── Git configuration ────────────────────────────
# User-specific config goes in ~/.gitconfig_local (NOT the stowed .gitconfig)
set -euo pipefail

info "Configuring git..."

LOCAL_GITCONFIG="$HOME/.gitconfig_local"

if [[ ! -f "$LOCAL_GITCONFIG" ]]; then
    read -p "Git user name: " git_name
    read -p "Git user email: " git_email
    cat > "$LOCAL_GITCONFIG" << EOF
[user]
    name = $git_name
    email = $git_email
EOF
    success "Git user config written to ~/.gitconfig_local"
else
    success "Git user config already exists (~/.gitconfig_local)"
fi
