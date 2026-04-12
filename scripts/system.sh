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
    # Delay greetd start to wait for GPU/DRM (RDNA4 takes longer to init)
    sudo mkdir -p /etc/systemd/system/greetd.service.d
    sudo tee /etc/systemd/system/greetd.service.d/override.conf > /dev/null << 'OVERRIDE'
[Unit]
After=systemd-user-sessions.service getty@tty1.service multi-user.target
Wants=multi-user.target

[Service]
ExecStartPre=/usr/bin/sleep 2
OVERRIDE
    sudo systemctl daemon-reload
    success "greetd configured (tuigreet → Hyprland)"
else
    success "greetd already configured"
fi

# gnome-keyring PAM integration for greetd
GREETD_PAM="/etc/pam.d/greetd"
if ! grep -q "pam_gnome_keyring" "$GREETD_PAM" 2>/dev/null; then
    sudo tee "$GREETD_PAM" > /dev/null << 'EOF'
#%PAM-1.0

auth       required     pam_securetty.so
auth       requisite    pam_nologin.so
auth       include      system-local-login
auth       optional     pam_gnome_keyring.so
account    include      system-local-login
session    include      system-local-login
session    optional     pam_gnome_keyring.so auto_start
EOF
    success "gnome-keyring PAM configured for greetd"
else
    success "gnome-keyring PAM already configured"
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

# Default browser
if command -v xdg-settings &>/dev/null; then
    xdg-settings set default-web-browser brave-browser.desktop 2>/dev/null && \
        success "Default browser set to Brave" || \
        warn "Could not set default browser"
fi

# Reduce NetworkManager-wait-online timeout (cable-only, no need for 30s default)
NM_OVERRIDE="/etc/systemd/system/NetworkManager-wait-online.service.d/timeout.conf"
if [[ ! -f "$NM_OVERRIDE" ]]; then
    sudo mkdir -p /etc/systemd/system/NetworkManager-wait-online.service.d
    sudo tee "$NM_OVERRIDE" > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/nm-online -s -q --timeout=5
EOF
    sudo systemctl daemon-reload
    success "NetworkManager-wait-online timeout reduced to 5s"
else
    success "NetworkManager-wait-online override already in place"
fi

# Detect sensors
info "Detecting hardware sensors..."
if command -v sensors-detect &>/dev/null; then
    sudo sensors-detect --auto > /dev/null 2>&1 || true
    success "Sensors detected"
fi
