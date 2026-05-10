#!/usr/bin/env bash
# ── System configuration ─────────────────────────
set -euo pipefail

info "Applying system configuration..."

# Sysctl: inotify limits + kernel/network hardening
SYSCTL_CONF="/etc/sysctl.d/99-dotfiles.conf"
if [[ ! -f "$SYSCTL_CONF" ]]; then
    sudo tee "$SYSCTL_CONF" > /dev/null << 'EOF'
# Inotify watchers (VS Code, file watchers)
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512

# Kernel hardening
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.printk=3 3 3 3
kernel.kexec_load_disabled=1

# Network hardening
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
EOF
    sudo sysctl --system > /dev/null 2>&1
    success "sysctl configured (inotify + hardening)"
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
    # Conflicts with getty@tty1: prevents both fighting for VT1
    sudo mkdir -p /etc/systemd/system/greetd.service.d
    sudo tee /etc/systemd/system/greetd.service.d/override.conf > /dev/null << 'OVERRIDE'
[Unit]
Conflicts=getty@tty1.service
After=systemd-user-sessions.service multi-user.target
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

# Default browser
if command -v xdg-settings &>/dev/null; then
    xdg-settings set default-web-browser brave-browser.desktop 2>/dev/null && \
        success "Default browser set to Brave" || \
        warn "Could not set default browser"
fi

# NetworkManager-wait-online: disabled (chronically fails on cable-only
# desktops, harmless to skip — nothing here actually needs network at boot)
if systemctl is-enabled NetworkManager-wait-online.service &>/dev/null; then
    sudo systemctl disable --now NetworkManager-wait-online.service
    success "NetworkManager-wait-online disabled"
else
    success "NetworkManager-wait-online already disabled"
fi

# Detect sensors
info "Detecting hardware sensors..."
if command -v sensors-detect &>/dev/null; then
    sudo sensors-detect --auto > /dev/null 2>&1 || true
    success "Sensors detected"
fi
