# Arch Linux Dotfiles

Modern Arch Linux setup with Hyprland, Ghostty, Starship, and Catppuccin Macchiato theme.

## Hardware

| Component | Model |
|-----------|-------|
| CPU | AMD Ryzen 7 9800X3D |
| GPU | AMD Radeon RX 9070 XT (RDNA 4) |
| Motherboard | MSI MS-7E51 (AMD 600) |
| RAM | 32GB |
| Storage | NVMe 477GB (Arch) + WD SN850 1TB (Windows) + Micron T705 2TB (Data) |
| WiFi | Qualcomm WCN785x (Wi-Fi 7) |
| Keyboard | Keychron K2 Pro |

## Stack

| Component | Tool |
|-----------|------|
| WM | Hyprland |
| Bar | Waybar |
| Terminal | Ghostty |
| Shell | zsh + Zinit + Starship |
| Launcher | Rofi (Wayland) |
| Notifications | SwayNC |
| File Manager | yazi (CLI) / Nemo (GUI) |
| Screenshots | grim + slurp + swappy |
| Clipboard | cliphist + wl-clipboard |
| Lock Screen | hyprlock |
| Idle | hypridle |
| Wallpaper | swww |
| Git | lazygit + delta |
| Theme | Catppuccin Macchiato |
| GPU Drivers | mesa + vulkan-radeon |
| Firewall | ufw |

## Installation (from scratch)

### Step 1: Arch Linux base install

Boot the Arch ISO (2026.04.01+) and connect to the internet:

```bash
# Ethernet: automatic
# WiFi:
iwctl station wlan0 connect <SSID>
```

Download and run the install script:

```bash
curl -LO https://raw.githubusercontent.com/pedroapy/dotfiles/archlinux/docs/arch-install.sh
bash arch-install.sh
```

This will:
- Partition `nvme1n1` (EFI 1GB + Btrfs with subvolumes)
- Install base Arch + systemd-boot
- Configure dual boot with Windows (on `nvme0n1`)
- Set up user, locale, hostname, NFS mounts, NTFS data disks
- Optimize for AMD Ryzen 9800X3D + RX 9070 XT

### Step 2: Dotfiles setup

After reboot, log in and connect to the internet:

```bash
# WiFi (if needed)
nmcli device wifi connect <SSID> password <PASS>
```

Clone and run the dotfiles installer:

```bash
git clone https://github.com/pedroapy/dotfiles.git ~/dotfiles-arch
cd ~/dotfiles-arch
git checkout archlinux
chmod +x install.sh
./install.sh
```

This installs all packages, applies configs via GNU Stow, enables services, and sets up the firewall. It is idempotent — safe to re-run at any time.

### Step 3: Post-install (manual)

See [docs/post-install.md](docs/post-install.md) for:
- Monitor configuration (`hyprctl monitors`)
- YubiKey U2F authentication for sudo
- SSH key setup
- Git commit signing
- Docker verification
- Firewall port management
- Bluetooth pairing

### Step 4: Start Hyprland

Log out and from the TTY:

```bash
Hyprland
```

## Disk layout

```
nvme1n1 (477GB) — Arch Linux
├── p1: EFI (1GB, FAT32)
└── p2: Btrfs
    ├── @           → /
    ├── @home       → /home
    ├── @snapshots  → /.snapshots
    ├── @var_log    → /var/log
    ├── @var_cache  → /var/cache
    └── @docker     → /var/lib/docker

nvme0n1 (1TB)   — Windows (not touched)
nvme2n1 (2TB)   — Data NTFS → /media/gdisk
sda     (2TB)   — Data NTFS
```

## Structure

```
├── install.sh              # Dotfiles installer (idempotent)
├── docs/
│   ├── arch-install.sh     # Arch base install script
│   └── post-install.md     # Manual post-install steps
├── packages/
│   ├── official.txt        # Pacman packages
│   ├── aur.txt             # AUR packages
│   └── amd-gpu.txt         # AMD GPU drivers
├── stow/                   # Configs (GNU Stow)
│   ├── hyprland/           # WM + hyprlock + hypridle
│   ├── waybar/             # Status bar
│   ├── ghostty/            # Terminal
│   ├── zsh/                # Shell (zinit + starship)
│   ├── starship/           # Prompt
│   ├── git/                # Git + delta
│   ├── rofi/               # App launcher
│   ├── swaync/             # Notifications
│   ├── btop/               # System monitor
│   ├── yazi/               # File manager
│   ├── fastfetch/          # System info
│   ├── ripgrep/            # Search config
│   ├── swappy/             # Screenshot editor
│   ├── fuzzel/             # Alt launcher
│   └── bin/                # Custom scripts
└── scripts/                # Modular install scripts
    ├── packages.sh
    ├── shell.sh
    ├── stow.sh
    ├── git.sh
    ├── system.sh
    └── services.sh
```

## Keybindings

| Key | Action |
|-----|--------|
| `Super + Return` | Terminal (Ghostty) |
| `Super + D` | App launcher (Rofi) |
| `Super + B` | Browser (Firefox) |
| `Super + E` | File manager (Nemo) |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + Space` | Toggle floating |
| `Super + V` | Clipboard history |
| `Super + L` | Lock screen |
| `Super + N` | Toggle notifications |
| `Super + 1-0` | Switch workspace |
| `Super + Shift + 1-0` | Move to workspace |
| `Print` | Screenshot (region) |
| `Shift + Print` | Screenshot (full) |
| `Super + hjkl` | Focus (vim keys) |
| `Super + Shift + hjkl` | Move window |
| `Super + Ctrl + arrows` | Resize window |
| `Alt + Shift` | Toggle keyboard US/ES |
