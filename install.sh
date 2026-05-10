#!/usr/bin/env bash
# ══════════════════════════════════════════════════
#  Arch Linux Dotfiles Installer
#  Idempotent — safe to run multiple times
# ══════════════════════════════════════════════════
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

# ── Pre-flight checks ───────────────────────────
if [[ ! -f /etc/arch-release ]]; then
    echo "This script is designed for Arch Linux only."
    exit 1
fi

info "Dotfiles directory: $DOTFILES"

# Get sudo upfront and keep it alive throughout the script
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT INT TERM

# ── Step 1: Base dependencies ────────────────────
info "Installing base dependencies..."
sudo pacman -S --needed --noconfirm git base-devel curl wget

# ── Step 2: yay (AUR helper) ────────────────────
if ! command -v yay &>/dev/null; then
    info "Installing yay..."
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    success "yay installed"
else
    success "yay already installed"
fi

# ── Step 3: Enable multilib (for 32-bit AMD drivers) ─
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    info "Enabling multilib repository..."
    sudo bash -c 'cat >> /etc/pacman.conf << EOF

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF'
    sudo pacman -Sy
    success "multilib enabled"
else
    success "multilib already enabled"
fi

# ── Step 4: Install packages ────────────────────
source "$DOTFILES/scripts/packages.sh"

# ── Step 5: Shell setup ─────────────────────────
source "$DOTFILES/scripts/shell.sh"

# ── Step 6: Stow configs ────────────────────────
source "$DOTFILES/scripts/stow.sh"

# ── Step 7: Git configuration ───────────────────
source "$DOTFILES/scripts/git.sh"

# ── Step 8: System configuration ────────────────
source "$DOTFILES/scripts/system.sh"

# ── Step 9: Services ────────────────────────────
source "$DOTFILES/scripts/services.sh"

# ── Done ─────────────────────────────────────────
echo ""
success "════════════════════════════════════════════"
success "  Installation complete!"
success "  Log out and back in for all changes."
success "  Start Hyprland from TTY: Hyprland"
success "════════════════════════════════════════════"
echo ""
info "Post-install tips:"
info "  - Edit ~/.config/hypr/monitors.conf for your display setup"
info "  - Run 'fastfetch' to see system info"
info "  - Run 'hyprctl monitors' to detect monitors"
