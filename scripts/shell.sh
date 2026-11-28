#!/usr/bin/env bash
# ── Shell setup (zsh + zinit) ────────────────────
set -euo pipefail

# Set zsh as default shell (login shell from passwd: $SHELL may be unset or stale)
login_shell=$(getent passwd "$(id -un)" | cut -d: -f7)
if [[ "$login_shell" != */zsh ]]; then
    info "Setting zsh as default shell..."
    if interactive; then
        chsh -s "$(command -v zsh)"
    else
        # No password prompt: sudo is already authorised by install.sh
        sudo chsh -s "$(command -v zsh)" "$(id -un)"
    fi
    success "zsh set as default shell"
else
    success "zsh already default shell"
fi

# Pre-install zinit for a clean first zsh launch
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    info "Pre-installing zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    success "zinit installed"
else
    success "zinit already installed"
fi
