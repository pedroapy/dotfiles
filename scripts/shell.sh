#!/usr/bin/env bash
# ── Shell setup (zsh + zinit) ────────────────────
set -euo pipefail

# Set zsh as default shell
if [[ "$SHELL" != */zsh ]]; then
    info "Setting zsh as default shell..."
    chsh -s "$(command -v zsh)"
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
