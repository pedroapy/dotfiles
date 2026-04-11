#!/usr/bin/env bash
# ── Install packages from lists ──────────────────

# Parse package files: strip comments and blank lines
parse_packages() {
    grep -v '^#' "$1" | grep -v '^$' | tr -d ' '
}

# Clean up any conflicting -git mesa packages (cache + installed + yay vcs db)
for conflict in mesa-rk35xx-git mesa-git; do
    if pacman -Q "$conflict" &>/dev/null; then
        warn "Removing conflicting package: $conflict"
        sudo pacman -Rdd --noconfirm "$conflict"
    fi
    rm -rf "${HOME}/.cache/yay/${conflict}" 2>/dev/null || true
done
# Remove stale -git entries from yay's VCS database
if [[ -f "${HOME}/.local/share/yay/vcs.json" ]]; then
    sed -i '/mesa-rk35xx-git\|mesa-git/d' "${HOME}/.local/share/yay/vcs.json" 2>/dev/null || true
fi

# Official repos (use pacman directly — no yay interference)
info "Installing official packages..."
official_pkgs=$(parse_packages "$DOTFILES/packages/official.txt")
if [[ -n "$official_pkgs" ]]; then
    echo "$official_pkgs" | xargs sudo pacman -S --needed --noconfirm
    success "Official packages installed"
fi

# AMD GPU drivers (official repos — use pacman directly)
info "Installing AMD GPU drivers..."
amd_pkgs=$(parse_packages "$DOTFILES/packages/amd-gpu.txt")
if [[ -n "$amd_pkgs" ]]; then
    echo "$amd_pkgs" | xargs sudo pacman -S --needed --noconfirm
    success "AMD GPU drivers installed"
fi

# AUR packages
info "Installing AUR packages..."
aur_pkgs=$(parse_packages "$DOTFILES/packages/aur.txt")
if [[ -n "$aur_pkgs" ]]; then
    echo "$aur_pkgs" | xargs yay -S --needed --noconfirm
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
