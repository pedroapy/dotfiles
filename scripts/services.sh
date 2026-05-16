#!/usr/bin/env bash
# ── Systemd services ────────────────────────────
set -euo pipefail

info "Enabling system services..."

# System services
declare -a system_services=(
    "bluetooth.service"
    "NetworkManager.service"
    "docker.service"
    "systemd-timesyncd.service"
    "ufw.service"
    "greetd.service"
    # Required because /etc/pam.d/system-auth stacks pam_systemd_home.so
    # before pam_unix.so with try_first_pass — if homed is dead, no module
    # asks for the password and sudo fails with "could not identify password"
    # (even for non-homed users).
    "systemd-homed.service"
    # Memory pressure handler (no swap on disk → need a killer that arrives early)
    "systemd-oomd.service"
    # Periodic maintenance
    "btrfs-scrub@-.timer"
    "fstrim.timer"
    "paccache.timer"
    "pkgfile-update.timer"
    "snapper-timeline.timer"
    "snapper-cleanup.timer"
    # CPU governor → performance on boot
    "cpupower.service"
    # sched_ext (scx) userspace scheduler (config in /etc/default/scx)
    "scx_loader.service"
)

for service in "${system_services[@]}"; do
    if ! systemctl is-enabled "$service" &>/dev/null; then
        sudo systemctl enable --now "$service" || warn "Could not enable $service"
        success "Enabled $service"
    else
        success "$service already enabled"
    fi
done

# User services (socket-activated for pipewire)
declare -a user_services=(
    "pipewire.socket"
    "pipewire-pulse.socket"
    "wireplumber.service"
    "swaync.service"
)

for service in "${user_services[@]}"; do
    if ! systemctl --user is-enabled "$service" &>/dev/null; then
        systemctl --user enable --now "$service" || warn "Could not enable $service"
        success "Enabled (user) $service"
    else
        success "$service (user) already enabled"
    fi
done

# ── Firewall (ufw) ──────────────────────────────
info "Configuring firewall..."
if command -v ufw &>/dev/null; then
    # Use status verbose first line; robust against UFW output format changes
    if ! sudo ufw status verbose 2>/dev/null | head -1 | grep -qw active; then
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw --force enable
        success "Firewall enabled (deny incoming, allow outgoing)"
    else
        success "Firewall already active"
    fi
fi
