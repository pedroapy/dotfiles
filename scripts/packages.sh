#!/usr/bin/env bash
# ── Install packages from lists ──────────────────

# Parse package files: strip comments and blank lines
parse_packages() {
    grep -v '^#' "$1" | grep -v '^$' | tr -d ' '
}

# Official repos
info "Installing official packages..."
official_pkgs=$(parse_packages "$DOTFILES/packages/official.txt")
if [[ -n "$official_pkgs" ]]; then
    echo "$official_pkgs" | xargs yay -S --needed --noconfirm
    success "Official packages installed"
fi

# AMD GPU drivers
info "Installing AMD GPU drivers..."
amd_pkgs=$(parse_packages "$DOTFILES/packages/amd-gpu.txt")
if [[ -n "$amd_pkgs" ]]; then
    echo "$amd_pkgs" | xargs yay -S --needed --noconfirm
    success "AMD GPU drivers installed"
fi

# AUR packages (no --noconfirm to allow PKGBUILD review)
info "Installing AUR packages..."
aur_pkgs=$(parse_packages "$DOTFILES/packages/aur.txt")
if [[ -n "$aur_pkgs" ]]; then
    echo "$aur_pkgs" | xargs yay -S --needed
    success "AUR packages installed"
fi

# Install Node.js LTS via n (n must be installed first from AUR)
if command -v n &>/dev/null; then
    if ! command -v node &>/dev/null; then
        info "Installing Node.js LTS via n..."
        sudo n lts
        success "Node.js LTS installed"
    else
        success "Node.js already installed"
    fi

    # Global npm packages
    info "Installing global npm packages..."
    for pkg in yarn serve yalc cloc; do
        if ! npm list -g "$pkg" &>/dev/null 2>&1; then
            npm install -g "$pkg"
        fi
    done
    success "npm global packages installed"
else
    warn "n not found — skipping Node.js and npm packages"
fi
