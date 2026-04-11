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

# greetd configuration (tuigreet → Hyprland)
GREETD_CONF="/etc/greetd/config.toml"
if ! grep -q "tuigreet" "$GREETD_CONF" 2>/dev/null; then
    sudo mkdir -p /etc/greetd
    sudo tee "$GREETD_CONF" > /dev/null << 'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --asterisks --cmd start-hyprland"
user = "greeter"
EOF
    success "greetd configured (tuigreet → Hyprland)"
else
    success "greetd already configured"
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

# Static IP & DNS (NetworkManager)
CONN_NAME="Wired connection 1"
if nmcli connection show "$CONN_NAME" &>/dev/null; then
    CURRENT_METHOD=$(nmcli -g ipv4.method connection show "$CONN_NAME")
    if [[ "$CURRENT_METHOD" != "manual" ]]; then
        nmcli connection modify "$CONN_NAME" \
            ipv4.method manual \
            ipv4.addresses REDACTED_IP/24 \
            ipv4.gateway REDACTED_IP \
            ipv4.dns "REDACTED_IP,REDACTED_IP,REDACTED_IP,REDACTED_IP"
        success "Static IP (REDACTED_IP) and DNS configured"
    else
        success "Static IP already configured"
    fi
else
    warn "Connection '$CONN_NAME' not found — configure network manually"
fi

# Detect sensors
info "Detecting hardware sensors..."
if command -v sensors-detect &>/dev/null; then
    sudo sensors-detect --auto > /dev/null 2>&1 || true
    success "Sensors detected"
fi
