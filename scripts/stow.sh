#!/usr/bin/env bash
# ── Stow configuration symlinks ──────────────────

info "Applying configuration symlinks with stow..."

# Ensure target directories exist
mkdir -p ~/.config ~/.zsh ~/bin

# Stow packages — each directory in stow/ is a package
STOW_DIR="$DOTFILES/stow"

for package in "$STOW_DIR"/*/; do
    package_name=$(basename "$package")
    info "  Stowing $package_name..."
    if ! stow -d "$STOW_DIR" -t "$HOME" --restow "$package_name" 2>&1; then
        warn "  Failed to stow $package_name — check for existing files"
    fi
done

success "All configs stowed"
