#!/usr/bin/env bash
# ── System configuration ─────────────────────────

info "Applying system configuration..."

# Increase inotify watchers (for VS Code, file watchers, etc.)
SYSCTL_CONF="/etc/sysctl.d/99-dotfiles.conf"
SYSCTL_CONTENT="fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512"
if [[ ! -f "$SYSCTL_CONF" ]]; then
    echo "$SYSCTL_CONTENT" | sudo tee "$SYSCTL_CONF" > /dev/null
    sudo sysctl --system > /dev/null 2>&1
    success "sysctl configured"
else
    success "sysctl already configured"
fi

# SDDM configuration (Wayland + astronaut theme)
SDDM_CONF="/etc/sddm.conf.d/10-wayland.conf"
if [[ ! -f "$SDDM_CONF" ]]; then
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee "$SDDM_CONF" > /dev/null << 'EOF'
[General]
DisplayServer=wayland
CompositorCommand=cage -ds --

[Theme]
Current=sddm-astronaut-theme
EOF
    success "SDDM configured (Wayland via cage + astronaut theme)"
else
    success "SDDM already configured"
fi

# Create user directories
for dir in ~/workspace ~/captures ~/bin ~/BingWallpaper; do
    mkdir -p "$dir"
done
success "User directories created"

# Font cache
info "Rebuilding font cache..."
fc-cache -f > /dev/null 2>&1
success "Font cache rebuilt"

# Add user to docker group
if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    success "Added to docker group (re-login required)"
else
    success "Already in docker group"
fi

# Detect sensors
info "Detecting hardware sensors..."
if command -v sensors-detect &>/dev/null; then
    sudo sensors-detect --auto > /dev/null 2>&1 || true
    success "Sensors detected"
fi
